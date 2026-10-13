# Argo CD installation (automated)

This document describes the automated Argo CD installation added to the
OpenTofu configuration in this directory. Running `tofu apply` installs Argo CD
into the existing Talos Kubernetes cluster — no manual `kubectl` / `helm` /
`talosctl` step is required.

## What was added / changed

| File | Change |
| --- | --- |
| `main.tf` | Added the `hashicorp/helm` provider to `required_providers`. |
| `variables.tf` | Added the `argocd_*` variables (see below). |
| `argocd.tf` | New file: Helm provider wired to the Talos kubeconfig + Argo CD release(s). |

### `main.tf`

The Helm provider is now declared:

```hcl
required_providers {
  proxmox = { source = "bpg/proxmox",     version = ">= 0.60.0" }
  talos   = { source = "siderolabs/talos", version = ">= 0.5.0" }
  helm    = { source = "hashicorp/helm",   version = ">= 2.0.0" }
}
```

### `variables.tf`

| Variable | Default | Purpose |
| --- | --- | --- |
| `argocd_namespace` | `argocd` | Namespace Argo CD is installed into. |
| `argocd_chart_version` | `null` | `argo-cd` chart version; `null` picks the latest release. |
| `argocd_service_type` | `ClusterIP` | Service type for `argocd-server` (`ClusterIP`, `NodePort`, `LoadBalancer`). |
| `argocd_git_repo_url` | `""` | Root Application Git repo URL; **empty disables** the GitOps bootstrap app. |
| `argocd_git_target_revision` | `main` | Git revision the root Application tracks. |
| `argocd_git_path` | `.` | Path in the repo holding the manifests. |
| `argocd_destination_namespace` | `default` | Namespace the root Application deploys into. |

### `argocd.tf`

1. **Kubeconfig parsing** — decodes the kubeconfig produced by
   `talos_cluster_kubeconfig.this` (`talos.tf`) into the host / CA / client cert
   / client key the Helm provider needs:

   ```hcl
   locals {
     kubeconfig   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw)
     kube_cluster = local.kubeconfig.clusters[0].cluster
     kube_user    = local.kubeconfig.users[0].user

     kube_host                   = local.kube_cluster.server
     kube_cluster_ca_certificate = base64decode(local.kube_cluster["certificate-authority-data"])
     kube_client_certificate     = base64decode(local.kube_user["client-certificate-data"])
     kube_client_key             = base64decode(local.kube_user["client-key-data"])
   }
   ```

2. **Helm provider** — configured from those locals (no `config_path`, no
   separate kubeconfig file on disk).

3. **`helm_release.argocd`** — installs the `argo-cd` chart
   (`https://argoproj.github.io/argo-helm`) into `var.argocd_namespace`,
   `create_namespace = true`, `wait = true`, `timeout = 600`, and sets
   `server.service.type`. It `depends_on = [data.talos_cluster_health.this]` so
   the release only starts once the cluster is healthy.

4. **`helm_release.argocd_apps`** (optional) — when `argocd_git_repo_url` is
   set, installs the `argocd-apps` chart creating a root Argo CD `Application`
   (app-of-apps pattern) with automated prune + self-heal. Because it is a Helm
   chart applied against the live cluster, CRD ordering is handled by Helm, so
   no `kubernetes_manifest` plan-time CRD issues.

5. **`output "argocd"`** — prints the namespace, port-forward command and the
   command to read the initial admin password.

## Usage

```bash
cd content/opentofu/scripts
tofu init      # fetches the helm provider
tofu apply
```

Access the Argo CD UI:

```bash
# from the management LXC (has kubectl), or any host with the kubeconfig
kubectl -n argocd port-forward svc/argocd-server 8080:443

# initial admin credentials (user: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Enable the optional GitOps bootstrap by adding to `terraform.tfvars`:

```hcl
argocd_git_repo_url       = "https://forgejo.example.local/org/gitops.git"
argocd_git_target_revision = "main"
argocd_git_path            = "apps"
```

## Ordering / dependencies

The Helm provider config derives from `talos_cluster_kubeconfig.this`, so
Terraform always creates/bootstrap the Talos cluster before configuring the
provider and installing Argo CD. `helm_release.argocd` additionally waits for
`talos_cluster_health.this`.

## Notes

- `argocd_chart_version` defaults to `null` (latest). Pin it for reproducible
  upgrades.
- Default service type is `ClusterIP`; use `NodePort` if you want to reach the
  UI without `port-forward`, or `LoadBalancer` if a service load balancer is
  available in the cluster.
- If `argocd_git_repo_url` points at a private Forgejo repo, add the repository
  credentials as a Kubernetes secret and reference it via the `argocd-apps`
  values (`applications.root.source` / repo secret) or configure it in the
  Argo CD UI.
