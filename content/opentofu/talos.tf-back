# Secrets en Client Config
resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = "talos-cluster"
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = var.node_ips
}

# Machine Config Generatie voor Control Plane Nodes
data "talos_machine_configuration" "controlplane" {
  cluster_name     = "talos-cluster"
  cluster_endpoint = "https://${var.node_ips[0]}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

# Bootstrap Configuration (Toestaan van Workloads + Extra Disk Mount voor Longhorn)
resource "talos_machine_configuration_apply" "controlplane" {
  count                       = 3
  client_configuration        = talos_machine_secrets.this.client_configuration
  node                        = var.node_ips[count.index]
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration

  config_patches = [
    yamlencode({
      cluster = {
        # Zorgt ervoor dat pods op de control plane mogen draaien
        allowSchedulingOnControlPlanes = true
      }
      machine = {
        # Extra 20 GB schijf formatteren en koppelen voor Longhorn Storage
        disks = [
          {
            device = "/dev/sdb" # Tweede SCSI schijf
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

# Cluster Bootstrapping
resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ips[0]
}

# Helm Provider configuratie na behalen van Kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.node_ips[0]
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  }
}

# Installatie van Longhorn Distributed Block Storage via Helm
resource "helm_release" "longhorn" {
  depends_on       = [talos_machine_bootstrap.this]
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true

  set {
    name  = "defaultSettings.defaultDataPath"
    value = "/var/mnt/longhorn"
  }
}
