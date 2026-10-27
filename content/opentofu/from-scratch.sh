#!/bin/bash
set -e

# from-scratch.sh - Create complete Talos Kubernetes cluster on Proxmox with ArgoCD and nginx demo
# This script orchestrates: Proxmox infra (OpenTofu), Talos cluster setup, Ansible config,
# Forgejo, ArgoCD with GitOps, Traefik ingress, and nginx demo accessible on local network

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Talos Kubernetes Cluster - From Scratch"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prereqs() {
    log_info "Checking prerequisites..."
    
    command -v tofu >/dev/null 2>&1 || { log_error "OpenTofu (tofu) not found"; exit 1; }
    command -v ansible-playbook >/dev/null 2>&1 || { log_error "ansible-playbook not found"; exit 1; }
    command -v ssh >/dev/null 2>&1 || { log_error "ssh not found"; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_warn "jq not found - some inventory updates may fail"; }
    
    # Check SSH key exists
    if [ ! -f ~/.ssh/id_ed25519.pub ]; then
        log_error "SSH public key ~/.ssh/id_ed25519.pub not found"
        exit 1
    fi
    
    log_info "Prerequisites OK"
}

# Step 1: Initialize and apply OpenTofu to create Proxmox infrastructure
step_opentofu() {
    log_info "Step 1: Creating Proxmox infrastructure with OpenTofu..."
    
    # Check if we need to init
    if [ ! -d ".terraform" ]; then
        log_info "Initializing OpenTofu..."
        tofu init
    fi
    
    log_info "Planning infrastructure..."
    tofu plan -out=tfplan
    
    log_warn "About to create infrastructure on Proxmox. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_error "Aborted by user"
        exit 1
    fi
    
    log_info "Applying infrastructure..."
    tofu apply tfplan
    
    log_info "Infrastructure created successfully"
    echo ""
    
    # Display outputs
    log_info "Infrastructure outputs:"
    tofu output router 2>/dev/null || true
    tofu output management 2>/dev/null || true
    echo ""
}

# Step 2: Update Ansible inventory with management container IP
step_inventory() {
    log_info "Step 2: Updating Ansible inventory..."
    
    cd "$SCRIPT_DIR/ansible2"
    
    # Get management container IP from tofu state/output
    if command -v jq >/dev/null 2>&1; then
        MGMT_IP=$(cd .. && tofu output -json management 2>/dev/null | jq -r '.wan_ips.eth0' 2>/dev/null)
        if [ "$MGMT_IP" != "null" ] && [ -n "$MGMT_IP" ]; then
            log_info "Management container IP: $MGMT_IP"
            # Update hosts.yml
            sed -i "s/ansible_host:.*/ansible_host: $MGMT_IP/" hosts.yml
            log_info "Inventory updated"
        else
            log_warn "Could not auto-detect management IP. Current inventory:"
            grep ansible_host hosts.yml
            log_warn "Update hosts.yml manually if needed"
        fi
    else
        log_warn "jq not available, please verify ansible2/hosts.yml has correct ansible_host"
    fi
    
    cd "$SCRIPT_DIR"
    echo ""
}

# Step 3: Wait for management container to be ready
step_wait_mgmt() {
    log_info "Step 3: Waiting for management container to be ready..."
    
    MGMT_IP=$(grep ansible_host "$SCRIPT_DIR/ansible2/hosts.yml" | awk '{print $2}')
    log_info "Checking SSH connectivity to $MGMT_IP..."
    
    for i in {1..60}; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$MGMT_IP" "echo 'ready'" >/dev/null 2>&1; then
            log_info "Management container is ready"
            break
        fi
        echo -n "."
        sleep 10
    done
    echo ""
    echo ""
}

# Step 4: Configure management container with Ansible (site.yml)
step_ansible_site() {
    log_info "Step 4: Configuring management container (SSH, tools, talosctl, kubectl)..."
    
    cd "$SCRIPT_DIR/ansible2"
    
    ansible-galaxy collection install -r requirements.yml 2>/dev/null || true
    
    log_info "Running site.yml..."
    ansible-playbook site.yml
    
    log_info "Management container configured"
    cd "$SCRIPT_DIR"
    echo ""
}

# Step 5: Deploy Forgejo to Kubernetes
step_forgejo() {
    log_info "Step 5: Deploying Forgejo to Kubernetes cluster..."
    
    cd "$SCRIPT_DIR/ansible2"
    
    log_info "Running forgejo.yml..."
    ansible-playbook forgejo.yml
    
    log_info "Forgejo deployed"
    cd "$SCRIPT_DIR"
    echo ""
}

# Step 6: Deploy ArgoCD with GitOps and nginx demo
step_argocd() {
    log_info "Step 6: Deploying ArgoCD with Forgejo GitOps and nginx demo..."
    
    cd "$SCRIPT_DIR/ansible2"
    
    log_info "Running argocd.yml..."
    ansible-playbook argocd.yml
    
    log_info "ArgoCD and nginx demo deployed"
    cd "$SCRIPT_DIR"
    echo ""
}

# Step 7: Deploy Traefik ingress for local network access
step_traefik() {
    log_info "Step 7: Deploying Traefik ingress controller..."
    
    cd "$SCRIPT_DIR/ansible2"
    
    log_info "Running traefik.yml..."
    ansible-playbook traefik.yml
    
    log_info "Traefik deployed with local network access"
    cd "$SCRIPT_DIR"
    echo ""
}

# Step 8: Display final information
step_summary() {
    log_info "========================================"
    log_info "SETUP COMPLETE!"
    log_info "========================================"
    echo ""
    
    MGMT_IP=$(grep ansible_host "$SCRIPT_DIR/ansible2/hosts.yml" | awk '{print $2}')
    
    echo -e "${GREEN}Access Information:${NC}"
    echo ""
    echo "1. ArgoCD UI (via SSH tunnel):"
    echo "   ssh root@$MGMT_IP 'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'"
    echo "   URL: https://$MGMT_IP:8080 (admin user)"
    echo "   Get password: ssh root@$MGMT_IP \"kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d\""
    echo ""
    echo "2. nginx-demo (accessible from local network via Traefik):"
    echo "   Add to /etc/hosts on your local machine:"
    echo "   $MGMT_IP  nginx-demo.kubernetes.local"
    echo "   Then access: http://nginx-demo.kubernetes.local"
    echo ""
    echo "3. Management container:"
    echo "   SSH: ssh jan@$MGMT_IP (or ssh root@$MGMT_IP)"
    echo "   LAN IP: 10.10.50.5 (on Talos subnet)"
    echo ""
    echo "4. Talos cluster nodes:"
    echo "   Control Plane/API: 10.10.50.22 (talos-node-3)"
    echo "   Nodes: 10.10.50.10, 10.10.50.21, 10.10.50.22"
    echo ""
    echo "5. Forgejo Git repository:"
    echo "   Internal: http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git"
    echo ""
    log_info "All components deployed successfully!"
}

# Main execution
main() {
    check_prereqs
    
    log_warn "This script will:"
    log_warn "  1. Create Proxmox VMs/LXCs with OpenTofu (router, management, 3 Talos nodes)"
    log_warn "  2. Configure management container with Ansible"
    log_warn "  3. Deploy Forgejo, ArgoCD, Traefik to Kubernetes"
    log_warn "  4. Deploy nginx demo accessible via Traefik on local network"
    echo ""
    log_warn "This may take 30-60 minutes. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_error "Aborted by user"
        exit 1
    fi
    echo ""
    
    step_opentofu
    step_inventory
    step_wait_mgmt
    step_ansible_site
    step_forgejo
    step_argocd
    step_traefik
    step_summary
}

# Run main function
main "$@"
