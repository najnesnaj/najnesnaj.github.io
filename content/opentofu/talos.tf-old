resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for vm in proxmox_virtual_environment_vm.talos_nodes : vm.ipv4_addresses[1][0]]
}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${proxmox_virtual_environment_vm.talos_nodes[0].ipv4_addresses[1][0]}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  # Patch to format and mount scsi1 (/dev/sdb) to /var/mnt/longhorn on Talos boot
  config_patches = [
    yamlencode({
      machine = {
        disks = [
          {
            device = "/dev/sdb"
            partitions = [
              {
                mountpoint = "/var/mnt/longhorn"
              }
            ]
          }
        ]
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "nodes" {
  count                       = var.node_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = proxmox_virtual_environment_vm.talos_nodes[count.index].ipv4_addresses[1][0]

  depends_on = [proxmox_virtual_environment_vm.talos_nodes]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = proxmox_virtual_environment_vm.talos_nodes[0].ipv4_addresses[1][0]

  depends_on = [talos_machine_configuration_apply.nodes]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = proxmox_virtual_environment_vm.talos_nodes[0].ipv4_addresses[1][0]

  depends_on = [talos_machine_bootstrap.this]
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
