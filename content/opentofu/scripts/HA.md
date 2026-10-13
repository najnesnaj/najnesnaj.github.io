# High Availability (HA) cluster

This document describes the steps to turn the current single-endpoint Talos
cluster (3 nodes, bootstrap on `10.10.50.10`) into a **high availability**
cluster, based on the existing OpenTofu configuration in this directory.

## 1. What the current setup does

| Concern | Current state | File |
| --- | --- | --- |
| Nodes | `node_count = 3`, one VM each | `main.tf` |
| Machine config | **all** nodes get the `controlplane` config | `talos.tf:44-52` |
| Bootstrap | single node `var.node_ips[0]` (`10.10.50.10`) | `talos.tf:55-60` |
| API endpoint | `https://10.10.50.10:6443` (node-bound) | `talos.tf:17` |
| Client endpoints | `var.node_ips` (all 3 IPs) | `talos.tf:10,74` |
| Network | isolated `vmbr1` `10.10.50.0/24`, router `10.10.50.1` | `router.tf` |
| Management | LXC `105`, `talosctl`/`kubectl` on `10.10.50.10` | `management.tf` |

This is *almost* HA: there are already 3 control-plane nodes (enough for an
etcd quorum), but the Kubernetes API endpoint is pinned to a **single node**.
If `10.10.50.10` dies, `kubectl`/`talosctl` and node-to-API connectivity break
even though etcd still has quorum.

## 2. What "HA" requires

1. **Odd number of control-plane nodes** (3 or 5) so etcd can maintain quorum
   when one node fails. `3` is the minimum.
2. **A stable API endpoint** that survives the loss of any single control-plane
   node. Talos provides a built-in **VIP** (`machine.network.interfaces[].vip`)
   that floats between control-plane nodes via gratuitous ARP — no external
   load balancer required on the `vmbr1` L2 segment.
3. **Dedicated worker nodes** (recommended) so workloads do not compete with
   control-plane components. With only 3 nodes, all are control planes and no
   workload capacity is separated from the control plane.
4. **Failure domains**: on a *single* Proxmox host, all VMs share one physical
   machine, so it is still a single point of failure. Real infrastructure HA
   means spreading the control-plane VMs across **multiple Proxmox nodes** in a
   Proxmox cluster (`proxmox_node` must then be set per resource).
5. **Reserve static IPs outside the DHCP range.** `dnsmasq` on the router hands
   out `10.10.50.50–10.10.50.150` (`router.tf:41`). Keep nodes and the VIP in
   `10.10.50.2–10.10.50.49` to avoid lease conflicts.

Target layout (example):

```
VIP           10.10.50.5         floating API endpoint (owned by a CP node)
control-plane 10.10.50.11/.12/.13  (3 nodes, etcd quorum)
workers       10.10.50.21/.22      (2+ nodes)
router        10.10.50.1
management    10.10.50.10
```

## 3. Step 1 — Split control-plane and worker variables

In `variables.tf`, replace the single `node_ips` list with explicit groups and
add the VIP:

```hcl
variable "controlplane_count" {
  type        = number
  description = "Number of control-plane nodes (use an odd number: 3 or 5)"
  default     = 3
}

variable "worker_count" {
  type        = number
  description = "Number of worker nodes"
  default     = 2
}

variable "controlplane_ips" {
  type        = list(string)
  description = "Control-plane node IPs on 10.10.50.0/24"
  default     = ["10.10.50.11", "10.10.50.12", "10.10.50.13"]
}

variable "worker_ips" {
  type        = list(string)
  description = "Worker node IPs on 10.10.50.0/24"
  default     = ["10.10.50.21", "10.10.50.22"]
}

variable "cluster_vip" {
  type        = string
  description = "Floating virtual IP for the Kubernetes API (outside the DHCP range)"
  default     = "10.10.50.5"
}
```

> Keep `management_lan_ip` (`10.10.50.10`) and the router IPs as they are.
> Adjust the management LXC IP if it would collide, and never place the VIP or
> nodes inside the `10.10.50.50–150` DHCP pool.

## 4. Step 2 — Create control-plane and worker VMs

In `main.tf`, replace the single `talos_nodes` resource with two resources (or
keep one resource with `count` and a per-role lookup). The cleanest option is a
`for_each`/`count` pair so each role gets its own IPs and the right Talos config.

```hcl
resource "proxmox_virtual_environment_vm" "controlplane" {
  count     = var.controlplane_count
  name      = "talos-cp-${count.index + 1}"
  node_name = var.proxmox_node
  # ... same cpu/memory/disk/cdrom/agent blocks as today ...

  network_device { bridge = var.lan_bridge }

  initialization {
    interface = "ide0"
    dns { servers = var.cluster_dns_servers }
    ip_config {
      ipv4 {
        address = "${var.controlplane_ips[count.index]}/24"
        gateway = var.cluster_gateway
      }
    }
  }

  boot_order = ["scsi0", "ide2"]
  depends_on = [proxmox_virtual_environment_container.router]
}

resource "proxmox_virtual_environment_vm" "worker" {
  count     = var.worker_count
  name      = "talos-worker-${count.index + 1}"
  node_name = var.proxmox_node
  # ... same hardware blocks ...

  network_device { bridge = var.lan_bridge }

  initialization {
    interface = "ide0"
    dns { servers = var.cluster_dns_servers }
    ip_config {
      ipv4 {
        address = "${var.worker_ips[count.index]}/24"
        gateway = var.cluster_gateway
      }
    }
  }

  boot_order = ["scsi0", "ide2"]
  depends_on = [proxmox_virtual_environment_container.router]
}
```

### Multi-host note

To remove the Proxmox single point of failure, give each VM an explicit
`node_name` spread across the Proxmox cluster members, e.g.
`node_name = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]`, and
make sure the `vmbr1` bridge and the storage pools exist on every host.

## 5. Step 3 — Add the floating VIP patch

In `talos.tf`, add the VIP to the **control-plane** config patches so the
address floats between all control-plane nodes:

```hcl
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.cluster_vip}:6443"   # <-- VIP, not node IP
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              vip = { ip = var.cluster_vip }
            }
          ]
        }
        certSANs = [var.cluster_vip]           # allow VIP in API server cert
        disks = [
          { device = "/dev/sdb", partitions = [{ mountpoint = "/var/mnt/storage" }] }
        ]
      }
    })
  ]
}
```

Important:
- The VIP patch only belongs on **control-plane** nodes. Workers must never own
  the VIP.
- `cluster_endpoint` now points at the VIP, so every control-plane node serves
  the API on `https://10.10.50.5:6443` regardless of which node holds it.
- Keep the static `eth0` addressing from Proxmox cloud-init; the VIP is an
  *additional* address, so do **not** reintroduce a `dhcp: true` patch.

## 6. Step 4 — Separate worker machine configuration

Add a worker config data source and apply it to the worker VMs (workers join
without a bootstrap step):

```hcl
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.cluster_vip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = [
    yamlencode({
      machine = {
        disks = [
          { device = "/dev/sdb", partitions = [{ mountpoint = "/var/mnt/storage" }] }
        ]
      }
    })
  ]
}
```

## 7. Step 5 — Apply configs and bootstrap once

Update the apply/bootstrap resources so **all** control-plane and worker nodes
receive their config, then bootstrap exactly **one** control-plane node:

```hcl
resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.controlplane_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ips[count.index]
  depends_on                  = [proxmox_virtual_environment_vm.controlplane]
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.worker_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[count.index]
  depends_on                  = [proxmox_virtual_environment_vm.worker]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips[0]     # bootstrap ONE CP node only

  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker,
  ]
}
```

Talos forms a single etcd cluster automatically: the bootstrapped node starts
etcd, and the remaining control-plane nodes join it as soon as their config is
applied. **Never run `talosctl bootstrap` on more than one node.**

## 8. Step 6 — Cluster endpoint in client config and health checks

`data.talos_client_configuration` should advertise every control-plane IP as an
endpoint and the VIP as a stable endpoint; point the health check at all
control-plane nodes:

```hcl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = var.controlplane_ips
}

data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = var.controlplane_ips
  worker_nodes         = var.worker_ips
  endpoints            = var.controlplane_ips
  # wait until etcd reports a healthy quorum
  timeouts = { read = "20m" }

  depends_on = [talos_cluster_kubeconfig.this]
}
```

## 9. Step 7 — Update the management container

The management LXC uses `talosctl`/`kubectl`. Update the client config inside
the container (or the Terraform outputs) so it uses the VIP and the full
endpoint list instead of the single node `10.10.50.10`:

```
talosctl --talosconfig talosconfig config endpoint 10.10.50.5
talosctl --talosconfig talosconfig config endpoint 10.10.50.11 10.10.50.12 10.10.50.13
kubectl config set-cluster <cluster> --server=https://10.10.50.5:6443
```

The kubeconfig produced by `talos_cluster_kubeconfig` already points at the
cluster endpoint (now the VIP), so refreshing the output is usually enough.

## 10. Step 8 — Apply and verify

```bash
# from this directory, on the management container or a host with the token
export PROXMOX_VE_API_TOKEN="$(cat export-proxmox-api-token)"   # if used
tofu plan
tofu apply
```

Verification:

```bash
# API reachable through the floating VIP (from the management LXC)
talosctl --talosconfig talosconfig -n 10.10.50.5 health

# all control planes are etcd members (expect 3 members)
talosctl --talosconfig talosconfig -n 10.10.50.5 etcd members

# all nodes Ready
kubectl --kubeconfig kubeconfig get nodes -o wide
```

HA checks worth performing:

- **VIP failover**: stop the control-plane node currently holding the VIP
  (`talosctl shutdown` in a test window) and confirm `https://10.10.50.5:6443`
  stays reachable and the VIP moves to another control-plane node.
- **Quorum**: stop one control-plane node; the cluster must keep serving
  (`etcd members` still shows the majority healthy). Stopping two of three
  control-plane nodes loses quorum — that is expected.
- **Worker loss**: deleting/stopping a worker should only reschedule its pods.

## 11. Rollback

The old single-endpoint layout is preserved in git history. To revert, restore
the previous `variables.tf`, `main.tf`, and `talos.tf` and run `tofu apply`.
Because VM names/IDs change between layouts, choose one of:

- `tofu state mv` the existing resources to their new addresses (avoids a
  rebuild of already-joined nodes), or
- recreate the VMs and re-apply the Talos machine configs, then bootstrap once.

> Reminder: entrypoint changes to the router/management LXCs require a
> `-replace` (see `router_changes.md` and `management-changes.md`); the Talos VM
> changes above are applied by Terraform in place.

## 12. Summary checklist

- [ ] 3 (or 5) control-plane nodes, odd count.
- [ ] Talos VIP configured via `machine.network.interfaces[].vip` on control
      planes only; `cluster_endpoint` and `certSANs` use the VIP.
- [ ] Separate worker config and worker VMs.
- [ ] Bootstrap exactly one control-plane node.
- [ ] Nodes/VIP outside the router DHCP pool (`10.10.50.50–150`).
- [ ] Client config and health checks list all control-plane IPs.
- [ ] (Infrastructure HA) spread VMs across multiple Proxmox hosts.
- [ ] Verify etcd member count, VIP failover, and worker rescheduling.
