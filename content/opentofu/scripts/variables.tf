# Proxmox Provider Variables
variable "proxmox_endpoint" {
  type        = string
  description = "The Proxmox VE API endpoint URL (e.g. https://192.168.0.141:8006/)"
}

variable "proxmox_api_token" {
  type        = string
  description = "The Proxmox API token (TOKEN_ID=SECRET)"
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification"
  default     = true
}

# Cluster Infrastructure Variables
variable "proxmox_node" {
  type        = string
  description = "Target Proxmox node name"
  default     = "pve"
}

variable "cluster_name" {
  type        = string
  description = "Talos cluster name"
  default     = "talos-cluster"
}

variable "node_count" {
  type        = number
  description = "Number of Talos nodes"
  default     = 3
}

variable "node_cpus" {
  type        = number
  description = "CPU cores per node"
  default     = 2
}

variable "node_memory" {
  type        = number
  description = "RAM (in MB) per node"
  default     = 4096
}

variable "talos_iso_file_id" {
  type        = string
  description = "Proxmox ISO image location"
  default     = "local:iso/nocloud-amd64-utils-scsi-talos.iso"
}

variable "storage_pool_system" {
  type        = string
  description = "Datastore for OS disk (scsi0)"
  default     = "local-lvm"
}

variable "storage_pool_data" {
  type        = string
  description = "Datastore for data disk (scsi1)"
  default     = "local-lvm"
}

variable "disk_size_system" {
  type        = number
  description = "System disk size in GB"
  default     = 20
}

variable "disk_size_data" {
  type        = number
  description = "Data disk size in GB"
  default     = 20
}

# Network layout
#
#   vmbr0 (wan_bridge)  -- physical home network, router LXC eth0 (DHCP)
#   vmbr1 (lan_bridge)  -- isolated 10.10.50.0/24 K8s network:
#                          router LXC eth1 (.1) + Talos nodes (.10/.21/.22)
#
variable "wan_bridge" {
  type        = string
  description = "Proxmox bridge carrying the physical/home network (router WAN side)"
  default     = "vmbr0"
}

variable "lan_bridge" {
  type        = string
  description = "Proxmox bridge for the isolated Kubernetes network (router LAN + Talos nodes)"
  default     = "vmbr1"
}

variable "cluster_gateway" {
  type        = string
  description = "Default gateway of the isolated K8s subnet - owned by the router LXC (eth1)"
  default     = "10.10.50.1"
}

variable "cluster_dns_servers" {
  type        = list(string)
  description = "DNS servers handed to the router LXC and to the Talos nodes (via cloud-init)"
  default     = ["192.168.0.1", "1.1.1.1"]
}

variable "node_ips" {
  type        = list(string)
  description = "Talos node IPs on 10.10.50.0/24 - index 0 is control plane 1 and the cluster endpoint"
  default     = ["10.10.50.10", "10.10.50.21", "10.10.50.22"]
}

# Router LXC
variable "router_template_file_id" {
  type        = string
  description = "Existing CT template on the node used for the router LXC (the node cannot reach download.proxmox.com, so nothing is downloaded)"
  default     = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
}

variable "router_wan_ip" {
  type        = string
  description = "Static WAN IP for the router LXC on vmbr0"
  default     = "192.168.0.250"
}

variable "router_wan_gateway" {
  type        = string
  description = "Gateway for the router LXC on vmbr0"
  default     = "192.168.0.1"
}

variable "router_cpus" {
  type        = number
  description = "CPU cores for the router LXC"
  default     = 1
}

variable "router_memory" {
  type        = number
  description = "RAM (in MB) for the router LXC (Ubuntu + systemd)"
  default     = 512
}

variable "router_disk_size" {
  type        = number
  description = "Root disk size (in GB) for the router LXC"
  default     = 4
}
