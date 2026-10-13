# =============================================================================
# Argo CD - automated GitOps controller installation.
#
# `tofu apply` installs Argo CD with the Helm provider, reusing the kubeconfig
# that the Talos resources in talos.tf already produce. No manual kubectl /
# talosctl step is required: the Helm provider is configured straight from the
# generated kubeconfig and the release waits for the cluster health check.
#
# Argo CD is reachable via:
#   kubectl --kubeconfig <talos kubeconfig> -n argocd port-forward svc/argocd-server 8080:443
#
# The initial admin password is stored in the secret `argocd-initial-admin-secret`.
# =============================================================================

locals {
  # Decode the Talos-generated kubeconfig into the pieces the Helm provider needs.
  kubeconfig   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw)
  kube_cluster = local.kubeconfig.clusters[0].cluster
  kube_user    = local.kubeconfig.users[0].user

  kube_host                   = local.kube_cluster.server
  kube_cluster_ca_certificate = base64decode(local.kube_cluster["certificate-authority-data"])
  kube_client_certificate     = base64decode(local.kube_user["client-certificate-data"])
  kube_client_key             = base64decode(local.kube_user["client-key-data"])
}

provider "helm" {
  kubernetes {
    host                   = local.kube_host
    cluster_ca_certificate = local.kube_cluster_ca_certificate
    client_certificate     = local.kube_client_certificate
    client_key             = local.kube_client_key
  }
}

# Install Argo CD (argoproj/argo-helm chart)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true

  # Wait for the whole stack (server, repo-server, application-controller, CRDs)
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      server = {
        service = {
          type = var.argocd_service_type
        }
      }
    })
  ]

  depends_on = [data.talos_cluster_health.this]
}

# Optional app-of-apps bootstrap: creates a root Argo CD Application that points
# at the Git repository containing the rest of the GitOps manifests. Disabled
# unless var.argocd_git_repo_url is set.
resource "helm_release" "argocd_apps" {
  count = var.argocd_git_repo_url != "" ? 1 : 0

  name       = "argocd-apps"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = var.argocd_namespace

  wait    = true
  timeout = 300

  values = [
    yamlencode({
      applications = {
        root = {
          namespace = var.argocd_namespace
          project   = "default"
          source = {
            repoURL        = var.argocd_git_repo_url
            targetRevision = var.argocd_git_target_revision
            path           = var.argocd_git_path
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.argocd_destination_namespace
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}

output "argocd" {
  description = "Argo CD installation details"
  value = {
    namespace = var.argocd_namespace
    service   = "argocd-server"
    port_fwd  = "kubectl -n ${var.argocd_namespace} port-forward svc/argocd-server 8080:443"
    admin_cmd = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  }
}
