# router.tf changes

Summary of the changes made to `router.tf` so that container **106 (`k8s-router`)**
acts as the NAT gateway for the isolated `vmbr1` network and serves DHCP on `eth1`.

## Requirements

- `eth0` on the home network (`vmbr0`): static `192.168.0.250/24`, gateway `192.168.0.1`.
- `eth1` on the isolated network (`vmbr1`): fixed IP `10.10.50.1/24`.
- Router hands out DHCP addresses over `eth1`.
- NAT (masquerade) between the isolated subnet and the home network.

## Background

The Ubuntu 26.04 LXC template does **not** honour Proxmox's static `ip_config`
(there is no ifupdown, and the template's netplan / systemd-networkd never reads
it). The container therefore configures its own addresses with `ip` commands at
every boot.

Also note: the bpg Proxmox provider applies an `entrypoint` change to an existing
container **in place**, but entrypoint files are only written when the container
is **created**. Changes to the entrypoint scripts/units therefore require a
recreate:

```
tofu apply -refresh=false -auto-approve \
  -replace=proxmox_virtual_environment_container.router \
  -target=proxmox_virtual_environment_container.router
```

## Changes made

### 1. Container definition

- Added `vm_id = 106`.
- `network_interface` `eth0` → `var.wan_bridge` (`vmbr0`).
- `network_interface` `eth1` → `var.lan_bridge` (`vmbr1`).
- `initialization.ip_config` for the WAN IP (`var.router_wan_ip/24` + gateway) and
  for `var.cluster_gateway/24`.
- `wait_for_ip { ipv4 = true }`.

### 2. Static network bootstrap — `k8s-router-net.service`

New one-shot unit (script staged by the entrypoint, run on every boot):

- Stops and masks `systemd-networkd` and `NetworkManager` so nothing fights the
  manual configuration.
- `ip link set up` / `ip addr replace` / `ip route replace` for both interfaces:
  - `eth0 = ${var.router_wan_ip}/24`, default route via `${var.router_wan_gateway}`
  - `eth1 = ${var.cluster_gateway}/24`
- Writes `/etc/resolv.conf` from `var.cluster_dns_servers`.
- Runs **before** `k8s-router.service`.

### 3. NAT + DHCP — `k8s-router.service`

One-shot unit that runs after the network is up:

- Installs `iptables` and `dnsmasq` if missing.
- Enables IPv4 forwarding (`/proc/sys/net/ipv4/ip_forward` and sysctl).
- Writes `/etc/dnsmasq.d/talos.conf`:

  ```
  interface=eth1
  bind-interfaces
  dhcp-range=10.10.50.50,10.10.50.150,255.255.255.0,12h
  dhcp-option=3,10.10.50.1
  dhcp-option=6,1.1.1.1,8.8.8.8
  dhcp-authoritative
  ```

  then restarts `dnsmasq`.
- Adds idempotent NAT rules (checked with `-C` before `-A`):
  - `nat POSTROUTING -o eth0 -j MASQUERADE`
  - `filter FORWARD -i eth1 -o eth0 -j ACCEPT`
  - `filter FORWARD -i eth0 -o eth1 -j ACCEPT`

### 4. Entrypoint

Writes and enables the two scripts and units:

- `/usr/local/sbin/k8s-router-net.sh` + `k8s-router-net.service`
- `/usr/local/sbin/k8s-router-nat.sh` + `k8s-router.service`
- `/etc/sysctl.d/99-k8s-router.conf`

## Verification (live)

Router 106, `GET /nodes/proxmox/lxc/106/interfaces`:

```
eth0 192.168.0.250/24
eth1 10.10.50.1/24
```

DHCP lease from a scratch client on `vmbr1`:

```
round 1: reply from ('10.10.50.1', 67) yiaddr=10.10.50.123 msgtype=2   (OFFER)
  REQUEST_SENT 10.10.50.123
  RSP msgtype=5 lease=10.10.50.123 server=10.10.50.1                 (ACK)
LEASE_ACK=10.10.50.123
DHCP_CLIENT_DONE leased=True rounds=1 elapsed=3s
```

NAT from the same client: `NAT_TCP_OK` (TCP to `1.1.1.1:80` via masquerade).

Idempotency: `tofu plan -refresh=false -target=proxmox_virtual_environment_container.router`
reports **No changes**.

## Root cause of the "DHCP not answering" symptom

The router was correct from the start. The scratch test client built its BOOTP
header with `struct.pack('!BBBBIHHH', ...)` — an extra `H` inserted 2 bytes and
shifted the DHCP magic cookie to offset 238 and the client MAC by one byte.
dnsmasq parsed those packets as **BOOTP** and ignored them:

```
dnsmasq-dhcp: ... tags: bootp, eth1
dnsmasq-dhcp: ... BOOTP(eth1) 00:00:02:00:00:00 no address configured
```

Fixing the client header to `'!BBBBIHH'` produced an immediate full lease.

## Cleanup

- Scratch containers 666 and 667 deleted.
- Backup `local:backup/vzdump-lxc-666-2026_10_12-14_02_00.tar.zst` removed.
- All temporary bring-up diagnostics removed from `router.tf` (iptables LOG
  counters, dnsmasq `log-dhcp`/`log-facility`, phone-home, watch service,
  DHCP self-test).

## Note

Container **101 `k8s-router`** (stopped) is an orphan duplicate of this router
created before `vm_id = 106` was pinned. It is not tracked by the current state
and was left untouched.
