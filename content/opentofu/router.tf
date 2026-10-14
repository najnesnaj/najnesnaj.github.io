# =============================================================================
# k8s-router - Ubuntu LXC NAT gateway between vmbr0 (home network) and the
# isolated vmbr1 subnet that hosts the Talos nodes.
#
#   eth0 (WAN) -> vmbr0, static IP (192.168.0.250/24, gw 192.168.0.1)
#   eth1 (LAN) -> vmbr1, 10.10.50.1/24  default gateway of all Talos nodes
#
# NOTE: the Ubuntu 26.04 template does NOT honour PVE's static `ip_config`
# (no ifupdown; netplan/systemd-networkd inside the container never reads it),
# so the router configures its own static addresses at every boot with `ip`
# commands (k8s-router-net.service), then starts dnsmasq (DHCP on vmbr1) and
# NAT (k8s-router.service).
# =============================================================================


locals {
  router_nat_script = <<-EOT
    #!/bin/sh
    LOG=/var/log/k8s-router.log
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') k8s-router: $1" >> "$LOG"; }
    WAN=eth0; LAN=eth1
    if [ ! -s /etc/resolv.conf ]; then printf "%s\n" "nameserver 1.1.1.1" "nameserver 192.168.0.1" > /etc/resolv.conf; fi
    for i in $(seq 1 60); do
      ip -4 -o addr show dev "$WAN" | grep -q 'inet ' && break
      sleep 2
    done
    if ! command -v iptables >/dev/null 2>&1 || ! command -v dnsmasq >/dev/null 2>&1; then
      log "iptables or dnsmasq missing, installing"
      for i in $(seq 1 30); do
        DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOG" 2>&1 && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iptables dnsmasq >> "$LOG" 2>&1 && break
        sleep 10
      done
    fi
    echo 1 > /proc/sys/net/ipv4/ip_forward; sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

    # Configure and start dnsmasq for the isolated Talos network
    cat <<EOF > /etc/dnsmasq.d/talos.conf
    interface=eth1
    bind-interfaces
    dhcp-range=10.10.50.50,10.10.50.150,255.255.255.0,12h
    dhcp-option=3,10.10.50.1
    dhcp-option=6,1.1.1.1,8.8.8.8
    dhcp-authoritative
    EOF
    systemctl restart dnsmasq

    add() { t=$1; c=$2; shift 2; iptables -t "$t" -C "$c" "$@" 2>/dev/null || iptables -t "$t" -A "$c" "$@"; }
    add nat POSTROUTING -o "$WAN" -j MASQUERADE
    add filter FORWARD -i "$LAN" -o "$WAN" -j ACCEPT
    add filter FORWARD -i "$WAN" -o "$LAN" -j ACCEPT
    log "NAT and DHCP active"
  EOT

  # The template's own network managers do not apply the PVE ip_config, so we
  # bring the interfaces up with `ip` directly (deterministic, idempotent).
  router_net_script = <<-EOT
    #!/bin/sh
    LOG=/var/log/k8s-router.log
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') k8s-router-net: $1" >> "$LOG"; }
    WAN=eth0; LAN=eth1
    WAN_IP="${var.router_wan_ip}/24"
    WAN_GW="${var.router_wan_gateway}"
    LAN_IP="${var.cluster_gateway}/24"
    DNS1="${var.cluster_dns_servers[0]}"
    DNS2="${var.cluster_dns_servers[1]}"

    # stop/mask the template network managers so nothing fights our config
    systemctl stop systemd-networkd 2>/dev/null
    systemctl mask systemd-networkd 2>/dev/null
    systemctl stop NetworkManager 2>/dev/null
    systemctl mask NetworkManager 2>/dev/null

    ip link set "$WAN" up
    ip link set "$LAN" up
    ip addr flush dev "$WAN" 2>/dev/null
    ip addr flush dev "$LAN" 2>/dev/null
    ip addr replace "$WAN_IP" dev "$WAN"
    ip addr replace "$LAN_IP" dev "$LAN"
    ip route replace default via "$WAN_GW" dev "$WAN"
    printf "nameserver %s\nnameserver %s\n" "$DNS1" "$DNS2" > /etc/resolv.conf
    log "network up: $WAN=$WAN_IP gw $WAN_GW; $LAN=$LAN_IP"
  EOT

  router_net_unit = <<-EOT
    [Unit]
    Description=k8s-router static network bootstrap
    Wants=network-pre.target
    After=network-pre.target
    Before=network-online.target k8s-router.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/k8s-router-net.sh
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOT

  router_unit = <<-EOT
    [Unit]
    Description=k8s-router NAT and DHCP
    Wants=network-online.target
    After=network-online.target networking.service k8s-router-net.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/k8s-router-nat.sh
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOT

  router_entrypoint = format(
    "/bin/sh -c 'mkdir -p /etc/systemd/system/multi-user.target.wants && printf %%s %s | base64 -d > /usr/local/sbin/k8s-router-net.sh && chmod +x /usr/local/sbin/k8s-router-net.sh && printf %%s %s | base64 -d > /etc/systemd/system/k8s-router-net.service && printf %%s %s | base64 -d > /etc/systemd/system/k8s-router.service && printf %%s %s | base64 -d > /usr/local/sbin/k8s-router-nat.sh && chmod +x /usr/local/sbin/k8s-router-nat.sh && echo net.ipv4.ip_forward=1 > /etc/sysctl.d/99-k8s-router.conf && ln -sf /etc/systemd/system/k8s-router-net.service /etc/systemd/system/multi-user.target.wants/k8s-router-net.service && ln -sf /etc/systemd/system/k8s-router.service /etc/systemd/system/multi-user.target.wants/k8s-router.service; exec /sbin/init'",
    base64encode(local.router_net_script),
    base64encode(local.router_net_unit),
    base64encode(local.router_unit),
    base64encode(local.router_nat_script)
  )
}


resource "proxmox_virtual_environment_container" "router" {
  description   = "NAT router/gateway for the isolated K8s subnet (vmbr1)"
  vm_id         = 106
  node_name     = var.proxmox_node
  unprivileged  = true
  started       = true
  start_on_boot = true
  cpu { cores = var.router_cpus }
  memory {
    dedicated = var.router_memory
    swap      = 0
  }
  disk {
    datastore_id = var.storage_pool_system
    size         = var.router_disk_size
  }
  operating_system {
    template_file_id = var.router_template_file_id
    type             = "ubuntu"
  }
  network_interface {
    name   = "eth0"
    bridge = var.wan_bridge
  }
  network_interface {
    name   = "eth1"
    bridge = var.lan_bridge
  }
  initialization {
    hostname   = "k8s-router"
    entrypoint = local.router_entrypoint
    dns { servers = var.cluster_dns_servers }
    ip_config {
      ipv4 {
        address = "${var.router_wan_ip}/24"
        gateway = var.router_wan_gateway
      }
    }
    ip_config {
      ipv4 { address = "${var.cluster_gateway}/24" }
    }
  }
  wait_for_ip { ipv4 = true }
}

output "router" {
  description = "Router LXC details"
  value = {
    vm_id    = proxmox_virtual_environment_container.router.vm_id
    hostname = "k8s-router"
    gateway  = "${var.cluster_gateway}/24"
    ips      = proxmox_virtual_environment_container.router.ipv4
  }
}