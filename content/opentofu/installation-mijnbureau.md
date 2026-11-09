# Installing MijnBureau with ArgoCD

This guide describes how to install
[MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra)
on the existing Talos/Kubernetes cluster using ArgoCD and the Helmfile
ConfigManagementPlugin described in the upstream GitOps documentation.

MijnBureau is a Helmfile-based application. ArgoCD does not support
Helmfile natively, so the ArgoCD repo server needs a Helmfile plugin
before the Application can be synced.

---

## 1. Check cluster fit before installing

MijnBureau is resource-heavy. The upstream sizing table starts at roughly:

| Size | Demo CPU / memory requests |
| --- | --- |
| `nano` | 4.7 cores / 7.5 GiB |
| `micro` | 11.1 cores / 13.0 GiB |

This homelab cluster has three Talos nodes with 2 GiB of RAM each, so a
full MijnBureau installation is not a good fit as-is. Use a larger cluster,
or start with `demo` and reduce the enabled components. The steps below are
still the required installation procedure.

The cluster also needs:

- AMD64 nodes.
- Traefik as the ingress controller (already installed).
- A LoadBalancer for the video-conferencing backend if that feature is
  enabled.
- A DNS name that you control, for example `mijnbureau.example.com`.
- TLS certificates for that name.

---

## 2. Install CloudNativePG

MijnBureau's bundled demo databases use CloudNativePG. Install the operator
once per cluster:

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.4.yaml
kubectl rollout status deployment -n cnpg-system cnpg-controller-manager
```

---

## 3. Add Helmfile support to ArgoCD

The ArgoCD instance in this environment is installed in the `argocd`
namespace by `ansible2/argocd.yml`.

### 3.1 Create the plugin ConfigMap

```bash
kubectl -n argocd apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: helmfile-plugin-config
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: helmfile
    spec:
      version: v1.1
      init:
        command: [sh, -c]
        args: |
          helmfile init
      generate:
        command: [sh, -c]
        args:
          - |
            export MIJNBUREAU_MASTER_PASSWORD=$ARGOCD_ENV_MIJNBUREAU_MASTER_PASSWORD

            if [ -z "$ARGOCD_ENV_ENVIRONMENT" ]; then
              helmfile -e demo template
            else
              helmfile -e $ARGOCD_ENV_ENVIRONMENT template
            fi
      discover:
        fileName: "./helmfile.yaml.gotmpl"
EOF
```

### 3.2 Patch the ArgoCD repo server

The repo server needs the `helmfile` and `helm` binaries and the plugin
configuration. If ArgoCD is managed by Helm, add the volumes, init
container and sidecar to the repo server values. The upstream example uses
the ArgoCD Operator; the same mounts apply to a standard Helm installation:

```yaml
repo:
  volumes:
    - name: helmfile-tools
      emptyDir: {}
    - name: helmfile-plugin-config
      configMap:
        name: helmfile-plugin-config
  initContainers:
    - name: download-helmfile
      image: ghcr.io/helmfile/helmfile:v1.1.7
      command: [sh, -c]
      args:
        - cp /usr/local/bin/helmfile /helmfile-tools/helmfile &&
          cp /usr/local/bin/helm /helmfile-tools/helm &&
          cp -r /helm/.local/share/helm/plugins/ /helmfile-tools/plugins/
      volumeMounts:
        - mountPath: /helmfile-tools
          name: helmfile-tools
  sidecarContainers:
    - name: cmp
      command: [/var/run/argocd/argocd-cmp-server]
      image: ghcr.io/helmfile/helmfile:v1.1.7
      volumeMounts:
        - mountPath: /var/run/argocd
          name: var-files
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
        - mountPath: /home/argocd/cmp-server/config/plugin.yaml
          subPath: plugin.yaml
          name: helmfile-plugin-config
  volumeMounts:
    - mountPath: /usr/local/bin/helmfile
      name: helmfile-tools
      subPath: helmfile
    - mountPath: /usr/local/sbin/helm
      name: helmfile-tools
      subPath: helm
    - mountPath: /.local/share/helm/plugins/
      name: helmfile-tools
      subPath: plugins
```

Restart the repo server after changing it:

```bash
kubectl -n argocd rollout restart deployment argocd-repo-server
```

---

## 4. Create the master password Secret

Do not put the master password directly in the Application manifest. Create
a Secret in the `argocd` namespace:

```bash
kubectl -n argocd create secret generic mijnbureau-master-password \
  --from-literal=password='your-very-secure-password'
```

---

## 5. Create the ArgoCD Application

Use the upstream repository directly. The plugin discovers
`helmfile.yaml.gotmpl` at the repository root.

```bash
kubectl -n argocd apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mijn-bureau
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/MinBZK/mijn-bureau-infra.git
    path: .
    targetRevision: main
    plugin:
      env:
        - name: ENVIRONMENT
          value: demo
        - name: MIJNBUREAU_MASTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mijnbureau-master-password
              key: password
  destination:
    server: https://kubernetes.default.svc
    namespace: mijnbureau
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

Change `ENVIRONMENT` to `production` when deploying a production
environment.

---

## 6. Configure DNS and ingress

Point the chosen domain at the cluster entry point and ensure Traefik can
route it. For this environment, add the hostname to `/etc/hosts` or DNS
alongside the other `*.kubernetes.local` names, for example:

```bash
sudo sh -c 'echo "192.168.0.192  mijnbureau.kubernetes.local" >> /etc/hosts'
```

MijnBureau components create their own Ingress objects through Traefik.

---

## 7. Sync and verify

Force a sync if needed:

```bash
kubectl -n argocd patch application mijn-bureau \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'
```

Or use the ArgoCD CLI/UI. Then check:

```bash
kubectl -n argocd get application mijn-bureau
kubectl -n mijnbureau get pods
kubectl -n mijnbureau get ingress
```

Wait until all pods are ready. The first sync can take several minutes
because it installs many components.

---

## 8. Day-2 operations

- To change the environment, update `ENVIRONMENT` in the Application and
  sync again.
- To change the master password, update the Secret and re-sync. The master
  password generates most application secrets, so changing it affects
  existing deployments.
- Use `helmfile -e demo template` locally or through the plugin to inspect
  rendered manifests before syncing.

---

## 9. Troubleshooting

### Plugin is not discovered

Confirm that `helmfile.yaml.gotmpl` exists at the repository root and that
the repo server has the plugin ConfigMap mounted. Check repo-server logs:

```bash
kubectl -n argocd logs deploy/argocd-repo-server -c cmp --tail=100
```

### Helmfile init fails

Run `helmfile init` manually in a test pod or locally to see whether a
plugin dependency is missing.

### Pods stay Pending

This cluster is small. Check node capacity and reduce the MijnBureau size
or disable components. The `none` size sets no resource requests/limits, but
it is not recommended for production.

### Ingress returns 404

Check Traefik and the generated Ingress objects:

```bash
kubectl -n mijnbureau get ingress
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik
```

### Secrets are wrong

Verify the Secret exists and that the Application references the correct
key:

```bash
kubectl -n argocd get secret mijnbureau-master-password
```

---

## 10. References

- Upstream installation guide:
  https://minbzk.github.io/mijn-bureau-infra/docs/getting_started/install
- Upstream GitOps guide:
  https://minbzk.github.io/mijn-bureau-infra/docs/gitops
- Upstream prerequisites:
  https://minbzk.github.io/mijn-bureau-infra/docs/getting_started/prerequisites