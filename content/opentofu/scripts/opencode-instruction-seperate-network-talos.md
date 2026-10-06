# TASK: Refactor Proxmox OpenTofu Code for Isolated K8s Subnet with Router LXC

## Goal
Modify the existing OpenTofu configuration for the Talos Kubernetes cluster in Proxmox. Instead of putting Talos nodes directly on the physical home network (`vmbr0`) with static/DHCP conflicts, refactor the layout to use an isolated internal Proxmox bridge (`vmbr1`) and a lightweight Alpine Linux LXC container acting as a NAT Router/Gateway.

---

## Key Requirements & Code Changes

### 1. Add Network Bridge & Router LXC Resource
Add a new Alpine Linux LXC container resource to act as the gateway (`10.10.50.1`) between your physical network (`vmbr0`) and the isolated Kubernetes network (`vmbr1`).

- **WAN Interface (`eth0`):** Bridge `vmbr0`, DHCP enabled.
- **LAN Interface (`eth1`):** Bridge `vmbr1`, static IP `10.10.50.1/24`.
- **Provisioner / Script:** Enable IPv4 forwarding (`net.ipv4.ip_forward = 1`) and set up an `iptables` or `nftables` MASQUERADE rule on `eth0` so K8s nodes have outbound internet access.

---

### 2. Update Proxmox VM Resources (`proxmox_virtual_environment_vm`)
Update all Talos Control Plane and Worker VM definitions:

1. **Bridge Attachment:** Change `network_device.bridge` from `vmbr0` to `vmbr1`.
2. **Subnet & Gateway Alignment:** Update IP assignments to the new `10.10.50.0/24` subnet:
   - Control Plane 1: `10.10.50.10/24` (or desired IP)
   - Workers: `10.10.50.21/24`, `10.10.50.22/24`, etc.
   - Gateway: Explicitly set to `10.10.50.1`.
3. **Dependencies:** Add `depends_on = [proxmox_virtual_environment_container.router]` to ensure VMs do not start booting until the network router is active.

---

### 3. Fix Talos Machine Configuration & Circular IP Patch
In `data.talos_machine_configuration` resources:

1. **Remove DHCP Override:** Delete any inline YAML patch overriding `eth0` with `dhcp: true`. Because static IPs are assigned via Proxmox cloud-init / ip_config, forcing DHCP in Talos causes configuration conflicts.
2. **Cluster & API Endpoints:** Update all cluster control plane endpoints, VIPs, and node IP references from the old `192.168.x.x` addresses to their new `10.10.50.x` addresses.

---

### 4. Resolve Bootstrap Race Conditions
Ensure `talos_machine_bootstrap` and `talos_machine_configuration_apply` resources have explicit execution ordering:

1. Update the `node` parameter in `talos_machine_bootstrap` to point to the new control plane IP (e.g., `10.10.50.10`).
2. Add an explicit dependency on `talos_machine_configuration_apply` inside `talos_machine_bootstrap`:
   ```hcl
   depends_on = [
     talos_machine_configuration_apply.nodes
   ]
