terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.5.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

# Talos Control Plane / Worker Nodes
resource "proxmox_virtual_environment_vm" "talos_nodes" {
  count     = var.node_count
  name      = "talos-node-${count.index + 1}"
  node_name = var.proxmox_node

  # Disable wait for QEMU guest agent during initial boot
  agent {
    enabled = false
  }

  cpu {
    cores = var.node_cpus
    type  = "host"
  }

  memory {
    dedicated = var.node_memory
  }

  cdrom {
    file_id   = var.talos_iso_file_id
    interface = "ide2"
  }

  disk {
    datastore_id = var.storage_pool_system
    interface    = "scsi0"
    size         = var.disk_size_system
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  disk {
    datastore_id = var.storage_pool_data
    interface    = "scsi1"
    size         = var.disk_size_data
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  # Isolated Kubernetes network (vmbr1) - egress goes through k8s-router.
  network_device {
    bridge = var.lan_bridge
  }

  # Static IPs are provisioned through the Proxmox cloud-init drive
  # (Talos reads them from the nocloud datasource) on the isolated
  # 10.10.50.0/24 subnet; the default gateway is the router LXC.
  initialization {
    interface = "ide0" # ide2 is taken by the Talos nocloud ISO below
    dns {
      servers = var.cluster_dns_servers
    }
    ip_config {
      ipv4 {
        address = "${var.node_ips[count.index]}/24"
        gateway = var.cluster_gateway
      }
    }
  }

  operating_system {
    type = "l26"
  }

  boot_order = ["scsi0", "ide2"]

  # Nodes must not boot before the NAT router is up and running.
  depends_on = [proxmox_virtual_environment_container.router]
}
