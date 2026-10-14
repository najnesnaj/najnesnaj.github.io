# =============================================================================
# k8s-management - Ubuntu LXC container inside the Talos subnet (vmbr1)
# and home network (vmbr0) for running talosctl and kubectl.
#
#   eth0 (WAN/Home) -> vmbr0, DHCP address on your home network
#   eth1 (Talos LAN) -> vmbr1, static IP (e.g., 10.10.50.10/24) inside the cluster network
#
# NOTE: the Ubuntu 26.04 template ships `systemd-networkd` (which fails to start
# in this unprivileged container) and an otherwise empty /etc/netplan, so PVE's
# `ip=dhcp` / `ip=10.10.50.10/24` settings are never applied - both interfaces
# come up with no address. As with the router, the container therefore brings
# its own interfaces up at every boot (k8s-management-net.service): eth1 is
# configured statically with `ip`, eth0 gets an address via `dhclient`.
#
# SSH login and tooling are provisioned by the Ansible project in ./ansible:
# the boot script only seeds root's key so Ansible can connect, then
# `ansible-playbook ansible/site.yml` configures sshd, the 'jan' sudo login and
# installs talosctl/kubectl.
# =============================================================================

locals {
  # Bring up both interfaces: eth1 static, eth0 via DHCP.
  management_net_script = <<-EOT
    #!/bin/sh
    LOG=/var/log/k8s-management.log
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') k8s-management-net: $1" >> "$LOG"; }
    WAN=eth0; LAN=eth1
    LAN_IP="${var.management_lan_ip}/24"
    DNS1="${var.cluster_dns_servers[0]}"
    DNS2="${var.cluster_dns_servers[1]}"

    # the template's networkd fails in this container; make sure nothing else
    # fights our configuration
    systemctl stop systemd-networkd 2>/dev/null
    systemctl mask systemd-networkd 2>/dev/null
    systemctl mask systemd-networkd-wait-online.service 2>/dev/null
    systemctl stop NetworkManager 2>/dev/null
    systemctl mask NetworkManager 2>/dev/null
    systemctl stop dhcpcd 2>/dev/null
    systemctl mask dhcpcd 2>/dev/null

    # isolated Talos LAN - static address
    ip link set "$LAN" up
    ip addr flush dev "$LAN" 2>/dev/null
    ip addr replace "$LAN_IP" dev "$LAN"

    # home network - obtain an address via DHCP
    ip link set "$WAN" up
    ip addr flush dev "$WAN" 2>/dev/null
    if command -v dhclient >/dev/null 2>&1; then
      for i in $(seq 1 10); do
        dhclient -4 -1 "$WAN" >> "$LOG" 2>&1 || true
        ip -4 -o addr show dev "$WAN" | grep -q 'inet ' && break
        sleep 3
      done
    fi

    if [ ! -s /etc/resolv.conf ]; then
      printf "nameserver %s\nnameserver %s\n" "$DNS1" "$DNS2" > /etc/resolv.conf
    fi
    log "network up: $LAN=$LAN_IP; $WAN=$(ip -4 -o addr show dev "$WAN" | awk '{print $4}')"
  EOT

  management_setup_script = <<-EOT
    #!/bin/sh
    LOG=/var/log/k8s-management.log
    log() { echo "$(date '+%Y-%m-%d %H:%M:%S') k8s-management: $1" >> "$LOG"; }
    
    log "Bootstrapping management container..."
    # DNS must resolve before the Ansible playbook (ansible/site.yml) can apt.
    if [ ! -s /etc/resolv.conf ]; then
      printf "%s\n" "nameserver 1.1.1.1" "nameserver 192.168.0.1" > /etc/resolv.conf
    fi

    # Seed root's authorized key only. This is the bootstrap access the control
    # node needs to run the Ansible playbook (ansible/site.yml), which owns the
    # SSH server (sshd hardening and the 'jan' login) and the tooling
    # (talosctl/kubectl). Nothing else is configured here.
    mkdir -p /root/.ssh
    printf '%s\n' "${file("/home/jan/.ssh/id_ed25519.pub")}" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys

    log "Bootstrap complete - run ansible/site.yml to finish provisioning."
  EOT

  management_net_unit = <<-EOT
    [Unit]
    Description=k8s-management network bootstrap (static LAN + DHCP WAN)
    Wants=network-pre.target
    After=network-pre.target
    Before=network-online.target k8s-management.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/k8s-management-net.sh
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOT

  management_unit = <<-EOT
    [Unit]
    Description=K8s Management Setup
    Wants=network-online.target
    After=network-online.target networking.service k8s-management-net.service

    [Service]
    Type=oneshot
    ExecStart=/usr/local/sbin/k8s-management-setup.sh
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
  EOT

  management_entrypoint = format(
    "/bin/sh -c 'mkdir -p /etc/systemd/system/multi-user.target.wants && printf %%s %s | base64 -d > /usr/local/sbin/k8s-management-net.sh && chmod +x /usr/local/sbin/k8s-management-net.sh && printf %%s %s | base64 -d > /etc/systemd/system/k8s-management-net.service && printf %%s %s | base64 -d > /usr/local/sbin/k8s-management-setup.sh && chmod +x /usr/local/sbin/k8s-management-setup.sh && printf %%s %s | base64 -d > /etc/systemd/system/k8s-management.service && ln -sf /etc/systemd/system/k8s-management-net.service /etc/systemd/system/multi-user.target.wants/k8s-management-net.service && ln -sf /etc/systemd/system/k8s-management.service /etc/systemd/system/multi-user.target.wants/k8s-management.service; exec /sbin/init'",
    base64encode(local.management_net_script),
    base64encode(local.management_net_unit),
    base64encode(local.management_setup_script),
    base64encode(local.management_unit)
  )
}

resource "proxmox_virtual_environment_container" "management" {
  description   = "Management LXC container for Talos cluster administration"
  vm_id         = 105
  node_name     = var.proxmox_node
  unprivileged  = true
  started       = true
  start_on_boot = true

  cpu { cores = 2 }
  memory {
    dedicated = 2048
    swap      = 0
  }
  disk {
    datastore_id = var.storage_pool_system
    size         = 10
  }
  operating_system {
    template_file_id = var.router_template_file_id # Hergebruik je Ubuntu template
    type             = "ubuntu"
  }

  # Netwerkinterface 1: Je eigen netwerk (om in te loggen via SSH / Proxmox console)
  network_interface {
    name   = "eth0"
    bridge = var.wan_bridge
  }

  # Netwerkinterface 2: Het geïsoleerde Talos netwerk (om met talosctl de nodes te bereiken op 10.10.50.x)
  network_interface {
    name   = "eth1"
    bridge = var.lan_bridge
  }

  initialization {
    hostname   = "k8s-management"
    entrypoint = local.management_entrypoint
    dns { servers = var.cluster_dns_servers }

    # DHCP voor je thuisnetwerk (vmbr0)
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    # Vast IP binnen het Talos subnet (vmbr1) blijft wel handig voor de bereikbaarheid van de nodes
    ip_config {
      ipv4 { address = "${var.management_lan_ip}/24" }
    }
  }

  wait_for_ip { ipv4 = true }
}

output "management" {
  description = "Management LXC details"
  value = {
    vm_id    = proxmox_virtual_environment_container.management.vm_id
    hostname = "k8s-management"
    lan_ip   = var.management_lan_ip
    wan_ips  = proxmox_virtual_environment_container.management.ipv4
  }
}
