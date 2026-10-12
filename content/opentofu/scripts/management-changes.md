# management.tf changes

Summary of the changes made to `management.tf` so that container
**105 (`k8s-management`)** gets an address on **both** interfaces:

- `eth0` on the home network (`vmbr0`) — via **DHCP**.
- `eth1` on the isolated Talos network (`vmbr1`) — static `10.10.50.10/24`.

## Problem

The container was running, but `GET /nodes/proxmox/lxc/105/interfaces` reported
**no IPv4 address on either interface**:

```
lo   127.0.0.1/8
eth0 None
eth1 None
```

Although the Proxmox config correctly held `net0: ip=dhcp` and
`net1: ip=10.10.50.10/24`, those settings were never applied.

## Root cause

Same class of problem as the router. Probing a throwaway container built from
the same template (`ubuntu-26.04-standard_26.04-1_amd64.tar.zst`) showed:

- `/etc/netplan` is **empty**.
- `systemd-networkd` is installed and enabled but **fails to start** in the
  unprivileged container (`systemd-networkd failed`, `systemd-resolved failed`).
- Proxmox does generate `/etc/systemd/network/eth0.network` and
  `/etc/systemd/network/eth1.network`, but because `systemd-networkd` never
  runs, they are never applied.
- `dhclient` and `dhcpcd` **are installed**, so a DHCP client is available
  without needing network access first.

Result: both interfaces stayed down with no address.

## Changes made

### 1. New boot service — `k8s-management-net.service`

A one-shot unit (script staged by the entrypoint) that runs at every boot and:

- Masks `systemd-networkd`, `systemd-networkd-wait-online`, `NetworkManager`
  and `dhcpcd` so nothing fights the manual configuration.
- Configures `eth1` statically:
  `ip link set eth1 up` + `ip addr replace 10.10.50.10/24 dev eth1`.
- Brings up `eth0` and obtains an address with `dhclient -4 -1 eth0`
  (retried up to 10 times), then falls back to writing `/etc/resolv.conf`
  from `var.cluster_dns_servers` if it is empty.
- Runs **before** `k8s-management.service`.

### 2. Ordering of the existing setup service

`k8s-management.service` now also starts `After=k8s-management-net.service`, so
`talosctl` / `kubectl` installation happens once the interfaces are up.

### 3. Entrypoint

Writes and enables both scripts/units:

- `/usr/local/sbin/k8s-management-net.sh` + `k8s-management-net.service`
- `/usr/local/sbin/k8s-management-setup.sh` + `k8s-management.service`

### 4. Pinned container ID

Added `vm_id = 105` so a `-replace` recreates the same container ID.

> Note: as with the router, the entrypoint files are only written when the
> container is **created**, so the change requires a recreate:
>
> ```
> tofu apply -refresh=false -auto-approve \
>   -replace=proxmox_virtual_environment_container.management \
>   -target=proxmox_virtual_environment_container.management
> ```

## Verification (live)

`GET /nodes/proxmox/lxc/105/interfaces`:

```
eth0 192.168.0.137/24     (DHCP)
eth1 10.10.50.10/24       (static)
```

- `eth0` reachable from the home network (TCP `192.168.0.137:22` → open).
- `eth1` on `vmbr1` shares the subnet with the router (`10.10.50.1`) and the
  Talos nodes.
- Idempotency: `tofu plan -refresh=false -target=proxmox_virtual_environment_container.management`
  reports **No changes**.

## Cleanup

- Throwaway probe container 668 deleted.
- Local diagnostic listener stopped.
