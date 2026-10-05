# 1. Generate Talos machine secrets (cluster PKI, tokens, keys)
resource "talos_machine_secrets" "this" {
  talos_version = "v1.7.0"
}

# 2. Client configuration (talosconfig) for interacting with the cluster via talosctl
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = var.node_ips
}

# 3. Control Plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.node_ips[0]}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  # Optional config patches (e.g., node network config or additional disk mounts)
  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
            }
          ]
        }
        # Mount scsi1 data disk if specified in your setup
        disks = [
          {
            device = "/dev/sdb"
            partitions = [
              {
                mountpoint = "/var/mnt/storage"
              }
            ]
          }
        ]
      }
    })
  ]
}

# 4. Apply machine configuration to each boot node in Proxmox
resource "talos_machine_configuration_apply" "nodes" {
  count                       = var.node_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.node_ips[count.index]

  # Ensure VMs are up and running before trying to send Talos API calls
  depends_on = [proxmox_virtual_environment_vm.talos_nodes]
}

# 5. Bootstrap the cluster on the primary control plane node
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ips[0]

  depends_on = [talos_machine_configuration_apply.nodes]
}

# 6. Retrieve the generated administrative kubeconfig from the bootstrapped cluster
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ips[0]

  depends_on = [talos_machine_bootstrap.this]
}

# 7. Cluster Health Check - waits for API server and Kubernetes node readiness
data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = var.node_ips
  endpoints            = var.node_ips

  depends_on = [talos_cluster_kubeconfig.this]
}

# Outputs
output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
