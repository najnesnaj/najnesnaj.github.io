#!/usr/bin/env bash
# from-scratch.sh - Create a complete Talos Kubernetes cluster on Proxmox with
# Forgejo, Argo CD, Traefik and the nginx demo.
#
# The script orchestrates:
#   1. Proxmox infrastructure with OpenTofu (router LXC, management LXC, 3 VMs)
#   2. Talos machine configuration, bootstrap, kubeconfig and Argo CD
#   3. Ansible configuration of the management container (SSH + tooling)
#   4. Forgejo, Argo CD and Traefik, including the nginx demo
#
# IMPORTANT: the Talos nodes live on the isolated 10.10.50.0/24 network. This
# control host is usually on the home network only, so the Talos part of the
# OpenTofu apply is executed *inside* the dual-homed management container.
# That container has an interface on both networks (eth0 DHCP + eth1 10.10.50.5).
#
# Usage:
#   ./from-scratch.sh [--yes] [--skip-ansible]
#
#   -y, --yes          Do not ask for confirmation (also applies to tofu)
#   --skip-ansible     Only create infrastructure + bootstrap the cluster
#   -h, --help         Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

AUTO_APPROVE=false
SKIP_ANSIBLE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--auto-approve) AUTO_APPROVE=true ;;
        --skip-ansible)          SKIP_ANSIBLE=true ;;
        -h|--help)               usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

confirm() {
    if $AUTO_APPROVE; then
        return 0
    fi
    read -r -p "$1 [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || { log_error "$1 not found"; exit 1; }
}

# Read a quoted string value from terraform.tfvars (fallback only).
tfvar() {
    local key="$1"
    sed -n -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" \
        terraform.tfvars 2>/dev/null | head -n1
}

PROXMOX_ENDPOINT="${PROXMOX_ENDPOINT:-$(tfvar proxmox_endpoint)}"
PROXMOX_API_TOKEN="${PROXMOX_API_TOKEN:-$(tfvar proxmox_api_token)}"
PROXMOX_NODE="${PROXMOX_NODE:-$(tfvar proxmox_node)}"
PROXMOX_NODE="${PROXMOX_NODE:-pve}"

MGMT_IP=""

proxmox_api() {
    curl -fsSk --max-time 20 \
        -H "Authorization: PVEAPIToken=${PROXMOX_API_TOKEN}" \
        "${PROXMOX_ENDPOINT%/}/api2/json$1"
}

mgmt_vmid() {
    tofu output -json management 2>/dev/null |
        python3 -c 'import json,sys; print(json.load(sys.stdin)["vm_id"])'
}

mgmt_wan_ip() {
    local vmid json
    vmid="$(mgmt_vmid)" || return 1
    json="$(proxmox_api "/nodes/${PROXMOX_NODE}/lxc/${vmid}/interfaces")" || return 1
    printf '%s' "$json" | python3 -c '
import json, sys
for iface in json.load(sys.stdin).get("data", []):
    if iface.get("name") == "eth0" and iface.get("inet"):
        print(iface["inet"].split("/")[0])
        break
'
}

wait_for_mgmt_ip() {
    local i ip
    for i in $(seq 1 60); do
        ip="$(mgmt_wan_ip 2>/dev/null || true)"
        if [[ -n "$ip" ]]; then
            MGMT_IP="$ip"
            log_info "Management container WAN IP: $MGMT_IP"
            return 0
        fi
        sleep 5
    done
    log_error "Could not determine the management container's eth0 address"
    return 1
}

wait_for_ssh() {
    local host="$1" i
    for i in $(seq 1 60); do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               -o BatchMode=yes "root@${host}" "echo ready" >/dev/null 2>&1; then
            log_info "SSH to ${host} is ready"
            return 0
        fi
        echo -n "."
        sleep 10
    done
    echo ""
    log_error "SSH to ${host} did not become ready"
    return 1
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
check_prereqs() {
    log_info "Checking prerequisites..."

    require_cmd tofu
    require_cmd ansible-playbook
    require_cmd ansible-galaxy
    require_cmd ssh
    require_cmd rsync
    require_cmd scp
    require_cmd curl
    require_cmd python3

    if [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
        log_error "SSH public key ~/.ssh/id_ed25519.pub not found"
        exit 1
    fi

    if [[ -z "$PROXMOX_ENDPOINT" || -z "$PROXMOX_API_TOKEN" ]]; then
        log_error "Proxmox endpoint/token missing."
        log_error "Set proxmox_endpoint and proxmox_api_token in terraform.tfvars,"
        log_error "or export PROXMOX_ENDPOINT and PROXMOX_API_TOKEN."
        exit 1
    fi

    if ! proxmox_api "/version" >/dev/null 2>&1; then
        log_error "Cannot authenticate to the Proxmox API at ${PROXMOX_ENDPOINT}"
        exit 1
    fi

    log_info "Prerequisites OK"
}

# ---------------------------------------------------------------------------
# Step 1: base Proxmox infrastructure
# ---------------------------------------------------------------------------
step_opentofu() {
    log_info "Step 1: Creating Proxmox infrastructure with OpenTofu..."

    # Always init: a stale .terraform directory without the locked providers
    # used to make this script fail on the first plan.
    log_info "Initializing OpenTofu..."
    tofu init -input=false

    local targets=(
        -target=proxmox_virtual_environment_container.router
        -target=proxmox_virtual_environment_container.management
        -target=proxmox_virtual_environment_vm.talos_nodes
    )

    log_info "Planning base infrastructure (router, management, Talos VMs)..."
    tofu plan -input=false -out=tfplan "${targets[@]}"

    if ! confirm "Create/update the base infrastructure on Proxmox?"; then
        log_error "Aborted by user"
        exit 1
    fi

    log_info "Applying base infrastructure..."
    tofu apply -input=false tfplan

    log_info "Base infrastructure created"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 2: find the management container and wait for SSH
# ---------------------------------------------------------------------------
step_wait_mgmt() {
    log_info "Step 2: Waiting for the management container..."

    # The provider can return before DHCP has handed out eth0, so poll the
    # Proxmox API instead of relying on the output of the last apply.
    wait_for_mgmt_ip
    wait_for_ssh "$MGMT_IP"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 3: finish the cluster from inside the management container
# ---------------------------------------------------------------------------
remote_state_serial() {
    ssh -o StrictHostKeyChecking=no "root@${MGMT_IP}" \
        'python3 -c "import json;print(json.load(open(\"/root/opentofu/terraform.tfstate\"))[\"serial\"])"' \
        2>/dev/null || echo 0
}

local_state_serial() {
    python3 -c 'import json;print(json.load(open("terraform.tfstate"))["serial"])' \
        2>/dev/null || echo 0
}

step_cluster() {
    log_info "Step 3: Bootstrapping Talos + Argo CD from the management container..."

    # The management container is the only host with a route to 10.10.50.0/24.
    # Copy the OpenTofu project, the state and the tofu binary there.
    log_info "Copying the OpenTofu project to root@${MGMT_IP}:/root/opentofu..."
    ssh -o StrictHostKeyChecking=no "root@${MGMT_IP}" \
        "mkdir -p /root/opentofu /home/jan/.ssh"

    # Never overwrite a newer remote state with an older local copy (for
    # example after an apply that finished remotely but failed to sync back).
    local local_serial remote_serial
    local_serial="$(local_state_serial)"
    remote_serial="$(remote_state_serial)"
    if [[ "$remote_serial" =~ ^[0-9]+$ ]] && (( remote_serial > local_serial )); then
        log_warn "Remote state serial ${remote_serial} is newer than local ${local_serial}; syncing it back first"
        scp -q "root@${MGMT_IP}:/root/opentofu/terraform.tfstate" \
            "$SCRIPT_DIR/terraform.tfstate"
        scp -q "root@${MGMT_IP}:/root/opentofu/terraform.tfstate.backup" \
            "$SCRIPT_DIR/terraform.tfstate.backup" 2>/dev/null || true
    fi

    rsync -a \
        --exclude='.git' \
        --exclude='.terraform.tfstate.lock.info' \
        --exclude='logs' \
        "$SCRIPT_DIR/" "root@${MGMT_IP}:/root/opentofu/"

    rsync -a "$(command -v tofu)" "root@${MGMT_IP}:/usr/local/bin/tofu"

    # management.tf reads /home/jan/.ssh/id_ed25519.pub at plan time, so the
    # same path must exist on the machine that runs the remote apply.
    ssh -o StrictHostKeyChecking=no "root@${MGMT_IP}" \
        "chmod 0755 /usr/local/bin/tofu; mkdir -p /home/jan/.ssh; cat > /home/jan/.ssh/id_ed25519.pub" \
        < ~/.ssh/id_ed25519.pub

    log_info "Running OpenTofu init + apply on the management container..."
    ssh -o StrictHostKeyChecking=no "root@${MGMT_IP}" \
        "cd /root/opentofu && /usr/local/bin/tofu init -input=false && /usr/local/bin/tofu apply -auto-approve -input=false"

    # Keep the local state in sync: the Ansible talos_client role reads
    # `tofu output -raw talosconfig` on this control host.
    log_info "Syncing the OpenTofu state back to this host..."
    scp -q "root@${MGMT_IP}:/root/opentofu/terraform.tfstate" \
        "$SCRIPT_DIR/terraform.tfstate"
    if ssh -o StrictHostKeyChecking=no "root@${MGMT_IP}" \
           "test -f /root/opentofu/terraform.tfstate.backup"; then
        scp -q "root@${MGMT_IP}:/root/opentofu/terraform.tfstate.backup" \
            "$SCRIPT_DIR/terraform.tfstate.backup"
    fi
    scp -q "root@${MGMT_IP}:/root/opentofu/.terraform.lock.hcl" \
        "$SCRIPT_DIR/.terraform.lock.hcl" 2>/dev/null || true

    log_info "Talos cluster and Argo CD bootstrapped"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 4: point Ansible at the (possibly new) management container
# ---------------------------------------------------------------------------
step_inventory() {
    log_info "Step 4: Updating Ansible inventory..."

    if [[ ! -f "$SCRIPT_DIR/ansible2/hosts.yml" ]]; then
        log_error "ansible2/hosts.yml not found"
        exit 1
    fi

    sed -i -E "s#^([[:space:]]*ansible_host:[[:space:]]*).*#\1${MGMT_IP}#" \
        "$SCRIPT_DIR/ansible2/hosts.yml"

    log_info "Inventory ansible_host:"
    grep -E 'ansible_host' "$SCRIPT_DIR/ansible2/hosts.yml"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 5: management container configuration
# ---------------------------------------------------------------------------
step_ansible_site() {
    log_info "Step 5: Configuring the management container (SSH, tools, talosctl, kubectl)..."

    cd "$SCRIPT_DIR/ansible2"

    log_info "Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yml

    log_info "Running site.yml..."
    ansible-playbook site.yml

    log_info "Management container configured"
    cd "$SCRIPT_DIR"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 6: Forgejo
# ---------------------------------------------------------------------------
step_forgejo() {
    log_info "Step 6: Deploying Forgejo to the Kubernetes cluster..."

    cd "$SCRIPT_DIR/ansible2"
    ansible-playbook forgejo.yml
    cd "$SCRIPT_DIR"

    log_info "Forgejo deployed"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 7: Argo CD + GitOps + nginx demo
# ---------------------------------------------------------------------------
step_argocd() {
    log_info "Step 7: Deploying Argo CD with Forgejo GitOps and the nginx demo..."

    cd "$SCRIPT_DIR/ansible2"
    ansible-playbook argocd.yml
    cd "$SCRIPT_DIR"

    log_info "Argo CD and nginx demo deployed"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 8: Traefik ingress
# ---------------------------------------------------------------------------
step_traefik() {
    log_info "Step 8: Deploying the Traefik ingress controller..."

    cd "$SCRIPT_DIR/ansible2"
    ansible-playbook traefik.yml
    cd "$SCRIPT_DIR"

    log_info "Traefik deployed"
    echo ""
}

# ---------------------------------------------------------------------------
# Step 9: summary
# ---------------------------------------------------------------------------
step_summary() {
    local cluster_endpoint node_ips
    cluster_endpoint="$(tofu output -json cluster_endpoint 2>/dev/null | \
        python3 -c 'import json,sys; print(json.load(sys.stdin))' 2>/dev/null || true)"
    node_ips="$(tofu output -json talos_nodes 2>/dev/null | \
        python3 -c 'import json,sys; print(", ".join(json.load(sys.stdin)))' 2>/dev/null || true)"

    log_info "========================================"
    log_info "SETUP COMPLETE!"
    log_info "========================================"
    echo ""

    echo -e "${GREEN}Access Information:${NC}"
    echo ""
    echo "1. Argo CD UI (via SSH tunnel):"
    echo "   ssh root@${MGMT_IP} 'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'"
    echo "   URL: https://${MGMT_IP}:8080 (admin user)"
    echo "   Get password: ssh root@${MGMT_IP} \"kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d\""
    echo ""
    echo "2. nginx demo (via Traefik, from the local network):"
    echo "   Add to /etc/hosts on your workstation:"
    echo "   ${MGMT_IP}  nginx-demo.kubernetes.local"
    echo "   Then open: http://nginx-demo.kubernetes.local"
    echo ""
    echo "3. Management container:"
    echo "   SSH: ssh root@${MGMT_IP} (or ssh jan@${MGMT_IP})"
    echo "   LAN IP: 10.10.50.5 (isolated Talos subnet)"
    echo ""
    echo "4. Talos cluster:"
    [[ -n "$cluster_endpoint" ]] && echo "   Control-plane endpoint: ${cluster_endpoint} (API :6443)"
    [[ -n "$node_ips" ]]         && echo "   Nodes: ${node_ips}"
    echo ""
    echo "5. Forgejo Git repository:"
    echo "   Internal: http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git"
    echo ""
    log_info "All components deployed successfully!"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    check_prereqs

    log_warn "This script will:"
    log_warn "  1. Create/reconcile Proxmox VMs/LXCs with OpenTofu (router, management, 3 Talos nodes)"
    log_warn "  2. Bootstrap Talos and Argo CD from the management container"
    log_warn "  3. Configure the management container with Ansible"
    log_warn "  4. Deploy Forgejo, Argo CD, Traefik and the nginx demo"
    echo ""
    log_warn "This may take 30-60 minutes."

    if ! confirm "Continue?"; then
        log_error "Aborted by user"
        exit 1
    fi
    echo ""

    step_opentofu
    step_wait_mgmt
    step_cluster
    step_inventory

    if $SKIP_ANSIBLE; then
        log_warn "Skipping Ansible steps (--skip-ansible)"
        step_summary
        return
    fi

    step_ansible_site
    step_forgejo
    step_argocd
    step_traefik
    step_summary
}

main "$@"
