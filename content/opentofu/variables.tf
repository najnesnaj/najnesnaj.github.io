# Proxmox Provider Variables
variable "proxmox_endpoint" {
  type        = string
  description = "The Proxmox VE API endpoint URL (e.g., https://192.168.0.141:8006/)"
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

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge"
  default     = "vmbr0"
}

variable "node_ips" {
  type        = list(string)
  description = "IP addresses for Talos nodes in sequential order"
  default     = ["192.168.0.150", "192.168.0.151", "192.168.0.152"]
}
