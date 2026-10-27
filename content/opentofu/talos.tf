# 1. Generate Talos machine secrets (cluster PKI, tokens, keys)
resource "talos_machine_secrets" "this" {
  # Keep this pinned: the provider folds talos_version into the generated
  # machine_secrets, so bumping it on a live cluster would rotate the PKI.
  # The boot ISO (v1.8.1) and the generated installer image already match;
  # verify with `talosctl -n <node> get machineconfig -o yaml`.
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
  cluster_endpoint = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  # Config patches. NOTE: no network/DHCP patch here on purpose - eth0 is
  # configured statically by Proxmox cloud-init (initialization.ip_config in
  # main.tf) and a `dhcp: true` override would fight that configuration on
  # the isolated 10.10.50.0/24 subnet.
  config_patches = [
    yamlencode({
      machine = {
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
      cluster = {
        # This cluster has no dedicated workers: all three nodes are control
        # planes. Without this, every workload (including Argo CD's
        # redis-secret-init pre-install job) stays Pending on the default
        # node-role.kubernetes.io/control-plane:NoSchedule taint.
        allowSchedulingOnControlPlanes = true
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

  # First boot pulls the control-plane images, which can take longer than the
  # provider's 10-minute default on a slow link.
  timeouts = {
    read = "30m"
  }

  depends_on = [talos_cluster_kubeconfig.this]
}

# Outputs
output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talos_nodes" {
  description = "Talos node IP addresses on the isolated cluster network"
  value       = var.node_ips
}

output "cluster_endpoint" {
  description = "Talos/Kubernetes control-plane endpoint IP"
  value       = var.cluster_endpoint_ip
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}
