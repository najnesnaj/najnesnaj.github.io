# =============================================================================
# k8s-router - Ubuntu LXC NAT gateway between vmbr0 (home network) and the
# isolated vmbr1 subnet that hosts the Talos nodes.
#
#   eth0 (WAN) -> vmbr0, static IP (fallback to DHCP if preferred)
#   eth1 (LAN) -> vmbr1, 10.10.50.1/24  default gateway of all Talos nodes
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
    if ! command -v iptables >/dev/null 2>&1; then
      log "iptables missing, installing"
      for i in $(seq 1 30); do
        DEBIAN_FRONTEND=noninteractive apt-get update >> "$LOG" 2>&1 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends iptables >> "$LOG" 2>&1 && break
        sleep 10
      done
    fi
    echo 1 > /proc/sys/net/ipv4/ip_forward; sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    add() { t=$1; c=$2; shift 2; iptables -t "$t" -C "$c" "$@" 2>/dev/null || iptables -t "$t" -A "$c" "$@"; }
    add nat POSTROUTING -o "$WAN" -j MASQUERADE
    add filter FORWARD -i "$LAN" -o "$WAN" -j ACCEPT
    add filter FORWARD -i "$WAN" -o "$LAN" -j ACCEPT
    log "NAT active"
  EOT
  router_unit       = <<-EOT
    [Unit]
    Description=k8s-router NAT
    Wants=network-online.target
    After=network-online.target networking.service
    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/k8s-router-nat.sh
    RemainAfterExit=yes
    [Install]
    WantedBy=multi-user.target
  EOT
  router_entrypoint = format(
    "/bin/sh -c 'mkdir -p /etc/systemd/system/multi-user.target.wants && printf %%s %s | base64 -d > /etc/systemd/system/k8s-router.service && printf %%s %s | base64 -d > /usr/local/sbin/k8s-router-nat.sh && chmod +x /usr/local/sbin/k8s-router-nat.sh && echo net.ipv4.ip_forward=1 > /etc/sysctl.d/99-k8s-router.conf && ln -sf /etc/systemd/system/k8s-router.service /etc/systemd/system/multi-user.target.wants/k8s-router.service; exec /sbin/init'",
    base64encode(local.router_unit),
    base64encode(local.router_nat_script)
  )
}

resource "proxmox_virtual_environment_container" "router" {
  description   = "NAT router/gateway for the isolated K8s subnet (vmbr1)"
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
