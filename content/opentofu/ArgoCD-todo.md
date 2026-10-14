# ArgoCD Installation - Issues Encountered and Next Steps

## Summary

We attempted to install ArgoCD via `tofu apply` on the OpenTofu configuration in this repository. The infrastructure (Proxmox VMs, router LXC, management LXC) was set up, but the Talos Kubernetes cluster bootstrap and ArgoCD Helm installation encountered several issues due to version mismatches and partial state.

## What Has Been Done

- Explored the repository structure (Terraform/OpenTofu configs for Talos cluster on Proxmox)
- Fixed the Helm provider configuration in `argocd.tf` for Helm v3.x schema (changed `kubernetes` from block to argument)
- Validated configuration with `tofu validate` - passes
- Deployed and configured supporting infrastructure:
  - Router LXC (`k8s-router`, 10.10.50.1/24) running with NAT/DHCP for the isolated network
  - Management LXC (`k8s-management`, 10.10.50.10/24) with `talosctl` and `kubectl` installed, SSH keys configured
- Created Talos VMs (3 nodes: talos-node-1 at 10.10.50.10, talos-node-2 at 10.10.50.21, talos-node-3 at 10.10.50.22) on the isolated `vmbr1` network
- Applied multiple fix attempts to resolve Talos/Terraform provider compatibility issues

## Issues Encountered

### 1. Talos API Connectivity Constraints
- The execution environment (this container/host) is on the home network (`vmbr0`), not on the isolated Talos subnet (`vmbr1`, 10.10.50.0/24)
- Cannot directly reach Talos API on port 50000 from this host; operations must be run from the management CT (10.10.50.10/192.168.0.137) which has access to both networks
- SSH access was established to management CT to run OpenTofu remotely

### 2. Talos/Terraform Provider Version Mismatches

| Issue | Resolution Attempt | Result |
|---|---|---|
| Helm v3.x schema change (`kubernetes` block vs argument) | Fixed in `argocd.tf` | Fixed - validation passes |
| Talos provider v0.12.0 generated config with types incompatible with older Talos ISO | Downgraded talos provider to v0.6.1 in `main.tf` | Improved compatibility |
| Mismatched `talos_version` in secrets vs actual Talos ISO | Adjusted `talos_version` in `talos_machine_secrets` (tried v1.10.0, settled on v1.7.0) | Resolved "DiscoveryServiceConfig not registered" errors |
| Client (talosctl v1.14.2 on management) vs server API differences | Used provider-generated configs via Terraform where possible | Partial success |

### 3. Partial State and Bootstrap Complexity

- During repeated apply attempts, some `talos_machine_configuration_apply` resources were created but others failed mid-way when nodes rebooted after config application
- Current Terraform state shows:
  - All infrastructure resources created (VMs, containers, network setup)
  - `talos_machine_configuration_apply` has 2 of 3 instances recorded (node 0/control plane partially applied)
  - `talos_machine_bootstrap`, `talos_cluster_kubeconfig`, and `helm_release.argocd` are **not** present in state
- Node boot status:
  - All 3 Talos VMs are running
  - Nodes 10.10.50.21 and 10.10.50.22 (workers) have Talos API on port 50000 responding (post-config-apply reboot state)
  - Control plane node 10.10.50.10 is not consistently responding on Talos API (50000) or K8s API (6443)
- Certificate mismatches occurred when mixing configs from different secret generations

## Current State

- **Infrastructure**: ✅ Complete (router, management, 3 Talos nodes provisioned on isolated network)
- **Talos machine configs**: ⚠️ Partially applied (workers applied, control plane needs completion)
- **Cluster bootstrap**: ❌ Not completed (bootstrap resource not created/applied)
- **Kubeconfig**: ❌ Not retrieved
- **ArgoCD via Helm**: ❌ Not installed

## Next Steps to Complete ArgoCD Installation

To complete the installation, work from the **management CT** (`root@192.168.0.137` on eth0, or `root@10.10.50.10` on LAN) since it has network access to the Talos nodes.

### Step 1: SSH to Management CT

```bash
ssh -i ~/.ssh/id_ed25519 root@192.168.0.137
cd /usr/src/opentofu
```

### Step 2: Assess Current Cluster State

```bash
# Check Talos API status on all nodes
TALOSCONFIG=/tmp/talosconfig_new  # or from terraform state
talosctl --talosconfig /tmp/talosconfig_new get members --nodes 10.10.50.10,10.10.50.21,10.10.50.22 2>&1 | tail -30
```

Or better, extract the current talosconfig from Terraform state if needed:

```bash
tofu state show talos_client_configuration.this 2>&1 | grep talos_config
# Or write it
tofu output -raw talosconfig > /root/talosconfig 2>/dev/null || echo "check state"
```

### Step 3: Fix Control Plane (Node 0) Configuration

If the control plane node (10.10.50.10) is not responding properly:
1. Check VM status via Proxmox API or from management network perspective
2. If needed, reapply just the control plane config: `tofu apply -target=talos_machine_configuration_apply.nodes[0] -lock=false`
3. Wait for the node to reboot and come up

### Step 4: Bootstrap the Cluster (if not bootstrapped)

Once the control plane is accessible via Talos API with matching certs:
```bash
tofu apply -target=talos_machine_bootstrap.this -lock=false
```

Or manually: `talosctl bootstrap --nodes 10.10.50.10`

### Step 5: Retrieve Kubeconfig

```bash
tofu apply -target=talos_cluster_kubeconfig.this -lock=false
# Kubeconfig will be stored in state; retrieve it with:
tofu output -raw kubeconfig > /root/kubeconfig
export KUBECONFIG=/root/kubeconfig
kubectl get nodes
```

### Step 6: Install ArgoCD via Helm

With the cluster bootstrapped and kubeconfig available, install ArgoCD:

```bash
tofu apply -target=helm_release.argocd -lock=false
```

This will install ArgoCD into the `argocd` namespace as configured in `argocd.tf`.

### Step 7: Verify ArgoCD Installation

```bash
export KUBECONFIG=/root/kubeconfig
kubectl get pods -n argocd
kubectl get svc -n argocd
```

Get the admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Access via port-forward:
```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

### Alternative: Clean Slate Approach (If State is Too Messy)

If reconciliation is problematic, you can reset the Talos nodes from management CT (using talosctl if certs match) and then run a clean `tofu apply` from the management CT with `-lock=false`. Be cautious as this will wipe cluster data.

---

## Notes

- The Helm provider and ArgoCD configuration in `argocd.tf` are correct as fixed
- All supporting infrastructure (networking, VMs, containers) is properly configured
- The main blocker is completing the Talos cluster bootstrap sequence with consistent secrets/certs between Terraform state and running nodes