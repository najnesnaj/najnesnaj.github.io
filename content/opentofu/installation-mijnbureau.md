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

The repo server needs the `helmfile` and `helm` binaries, Helm plugins, and
the CMP plugin configuration. For ArgoCD v3.x the CMP sidecar must run the
ArgoCD CMP server image (`quay.io/argoproj/argocd:v<version>`) and the plugin
socket; copy `helmfile`/`helm` and Helm plugins into a shared volume with an
init container.

Key points that were required on this cluster:

- Use `quay.io/argoproj/argocd:v3.5.6` for the `cmp` sidecar (same version as
  ArgoCD) so it can serve `/home/argocd/cmp-server/plugins/*.sock`.
- Copy tools/plugins from `ghcr.io/helmfile/helmfile:v1.1.7` in an init
  container (e.g. `helmfile`, `helm`, and `/helm/.local/share/helm/plugins/`).
- Mount the plugin `plugin.yaml` under `/home/argocd/cmp-server/config/`.
- Pass `MIJNBUREAU_MASTER_PASSWORD` into the sidecar via a Secret-backed env
  var (do not put it in the Application manifest). The plugin should fail fast
  if the variable is unset.
- ArgoCD caches rendered manifests in Redis. After changing plugin/config,
  restart the repo-server and flush Redis or bump a plugin env var (e.g.
  `OVERLAY_VERSION`) and recreate the Application to force a fresh render.

Example (adapt to your Helm values schema):

```yaml
repoServer:
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
  extraContainers:
    - name: cmp
      image: quay.io/argoproj/argocd:v3.5.6
      command: [/var/run/argocd/argocd-cmp-server]
      env:
        - name: MIJNBUREAU_MASTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mijnbureau-master-password
              key: password
      volumeMounts:
        - mountPath: /var/run/argocd
          name: var-files
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
        - mountPath: /home/argocd/cmp-server/config
          name: helmfile-plugin-config
        - mountPath: /usr/local/bin/helmfile
          name: helmfile-tools
          subPath: helmfile
        - mountPath: /usr/local/bin/helm
          name: helmfile-tools
          subPath: helm
        - mountPath: /helm/.local/share/helm/plugins
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

---

## 11. Homelab-specific fixes (tested on this cluster)

These notes capture the adjustments required to deploy MijnBureau on this
3×control-plane Talos v1.8.1 / Kubernetes v1.31.1 cluster (6 vCPU / 8 GiB per
node, `local-path` storage, Traefik NodePorts 30080/30443 exposed on
`192.168.0.192`) using the `demo` environment with a `nano` resource preset.

### 11.1 Sizing and feature selection

- `global.resourcesPreset: nano` is not sufficient by itself for some
  workloads; keep upstream per-app presets/floors where needed and add explicit
  overrides.
- Disable heavy/unsupported components for a small cluster, e.g.
  `application.ollama/livekit/meet/clamav/messages.enabled: false` (and keep
  `nextcloud`/`dictaphone` disabled if not required).
- Disable horizontal autoscalers (`autoscaling.horizontal.*.enabled: false`) if
  no metrics-server is installed; otherwise ArgoCD sync can fail on HPA handling
  in this environment.
- Upstream `element` now enables Matrix Authentication Service (MAS) and Element
  Call by default. If LiveKit is disabled and/or the MAS image
  (`oci.element.io/matrix-authentication-service`) is not pullable, set
  `application.element.mas.enabled: false` and
  `application.element.call.enabled: false` and use direct Synapse OIDC.

### 11.2 Namespace and overlay injection

- Deploy app resources into a dedicated namespace (e.g. `mijnbureau`) by
  setting `application.<app>.namespace` for enabled apps and
  `destination.namespace: mijnbureau` in the ArgoCD Application.
- Inject a `--state-values-file` overlay from the CMP plugin
  (`helmfile -e demo --state-values-file <overlay> template`) to set domain,
  ingress/storage classes, TLS, OIDC, resource overrides, and feature toggles
  without forking upstream.

### 11.3 TLS (self-signed wildcard)

- Apps and OIDC redirect URIs expect HTTPS. Without cert-manager, create a
  self-signed wildcard certificate for `*.mijnbureau.kubernetes.local` and
  store it as a Secret in the app namespace (e.g. `mijnbureau-wildcard-tls`).
- Set `global.tls.enabled: true` and configure per-app `tls.<app>` entries
  / `extraTls` where supported.
- Some static-nginx ingresses (docs/conversations/drive, depending on upstream
  revision) do not render `spec.tls` from values alone. A post-render patch in
  the CMP `generate` step (e.g. via `awk`) was used to add `spec.tls` with the
  wildcard secret. Verify after sync: `kubectl -n mijnbureau get ingress`.
- Do not set global `cluster.ingress.annotations` blindly: upstream
  static-nginx templates can have fragile indentation for Traefik middleware
  annotations, producing invalid YAML when annotations are non-empty.

### 11.4 OIDC / Keycloak endpoints

- Use mixed endpoints so browser redirects work over HTTPS while in-cluster
  traffic avoids TLS trust issues with the self-signed cert:
  - browser-facing (`issuer`, `authorization_endpoint`, `end_session_endpoint`):
    `https://id.<domain>/realms/mijnbureau/...`
  - in-cluster (`token_endpoint`, `introspection_endpoint`, `userinfo_endpoint`,
    `jwks_uri`): `http://keycloak-http/realms/mijnbureau/...`
- Keycloak (Quarkus image, uid 1000) may need writable runtime paths on startup.
  If it crashes with `AccessDeniedException` on
  `/opt/keycloak/lib/quarkus/transformed-bytecode.jar`, override the container
  security context (e.g. `runAsUser: 1000`, `runAsGroup: 0`,
  `readOnlyRootFilesystem: false`) via environment values.
- The `mijnbureau` realm is created by the `keycloak-config-cli` PostSync hook.
  If sync hooks do not complete, run the hook Job manually and verify:
  `curl -sk --resolve id.mijnbureau.kubernetes.local:443:<host> https://id.mijnbureau.kubernetes.local/realms/mijnbureau/.well-known/openid-configuration`.

### 11.5 Resources, probes, and scheduling

- Several Python/Django/Celery components OOMKilled at very small limits; raise
  limits (e.g. to 1Gi) while keeping modest requests where needed for docs,
  conversations, drive backends/celery, calendars backend/worker, projects, and
  bureaublad backend.
- Docs backend may need a longer liveness `initialDelaySeconds` to avoid
  premature kills during startup/migrations.
- Celery `inspect ping` liveness/readiness probes can time out and kill healthy
  workers under load/startup; increase `timeoutSeconds`/`failureThreshold`
  (and for drive celery, `initialDelaySeconds`) as needed.
- Synapse's `large` preset requests can be too high for a 3×8GiB cluster (and a
  local-path PVC pins it to a node). Lower Synapse requests (including init
  containers such as `volume-permissions`) and cap limits appropriately.
- Talos nodes may need extra CPU/RAM; this cluster was increased to 6 vCPU /
  8192 MB per node. Configure registry mirrors for Docker Hub if pulls are
  slow/blocked (e.g. `mirror.gcr.io`, `dockerproxy.net`).

### 11.6 ArgoCD / sync behavior

- ArgoCD Helmfile CMP renders can take time; ensure repo-server/cmp timeouts and
  resources are sufficient.
- Manifest caching: after plugin/ConfigMap changes, restart repo-server and
  force a fresh render (flush Redis if possible, or bump a plugin env such as
  `OVERLAY_VERSION` and recreate the Application). A hard refresh alone may not
  invalidate cached manifests.
- Sync can be blocked by failing hook/prune tasks (e.g. HPA discovery issues in
  this environment) or by hook Jobs stuck on image pulls. All core Deployments/
  StatefulSets/Ingresses may be healthy even if the Application reports
  `OutOfSync|Degraded` due to hooks; inspect `operationState` and hook Jobs.
- `RepeatedResourceWarning` for duplicated `hsts-header` Middleware /
  `default-deny-ingress` NetworkPolicy resources was observed and tolerated.
- MinIO provisioning hooks are idempotent; if they are stuck, buckets can be
  created manually in the running MinIO pods and hook Jobs cleaned up.

#### 11.6.1 Resolving a stuck/failed sync (`one or more synchronization tasks completed unsuccessfully`)

A reproducible cause of this error was traced and fixed in the CMP post-render
script (`patch-render.sh`). All fixes are applied in the **GitOps/CMP source**, not
with live `kubectl edit`, so ArgoCD `selfHeal` will not revert them. Bump
`OVERLAY_VERSION` (and hard-refresh the Application) after each CMP change so the
repo-server re-renders instead of using cached manifests.

1. **Do not change `imagePullPolicy` on Job/CronJob pod templates.** A patch that
   rewrote `imagePullPolicy: Always` → `IfNotPresent` on *all* rendered workloads
   changed Job `spec.template`, which is immutable. ArgoCD's in-place patch then
   failed with `Job.batch "<name>" is invalid: spec.template: Invalid value: ...
   field is immutable` (e.g. `synapse-keygen`). Scope such patches to workloads
   that are safe to update in place:
   ```awk
   doc_kind!="Job" && doc_kind!="CronJob" && /^[[:space:]]*imagePullPolicy: Always[[:space:]]*$/ {
     sub(/Always/, "IfNotPresent"); print; next
   }
   ```
   The Docker Hub registry mirrors on the Talos nodes are sufficient for hook
   image pulls; leaving hook Jobs untouched avoids the immutability failure.

2. **Drop null-valued ConfigMap data keys in the post-render script.** Some
   charts render `FRONTEND_JS_URL: ` (empty value = YAML `null`) in ConfigMaps.
   Kubernetes cannot store `null` in ConfigMap `data`, so ArgoCD normalises it
   away and the two ConfigMaps (`conversations`, `drive`) stayed permanently
   `OutOfSync`. With `selfHeal: true` this triggered continuous re-syncs (tens of
   operations in minutes) that re-ran all PostSync hooks and could fail on slow
   image pulls. Drop those keys during rendering so desired == live:
   ```awk
   doc_kind=="ConfigMap" && /^  FRONTEND_JS_URL:[[:space:]]*(null)?[[:space:]]*$/ { next }
   ```
   Scope this to the exact key (a broad "empty 2-space value" rule also deletes
   structural keys such as `annotations:` and produces invalid YAML).

3. **Beware shell quoting in `patch-render.sh`.** The awk program is wrapped in
   single quotes inside the CMP `generate` command. A comment containing an
   apostrophe (e.g. `ArgoCD's`) terminates the string and the CMP fails with
   errors like `awk: cannot open "in-place" (No such file or directory)` or
   `did not find expected key`. Never use apostrophes anywhere inside the awk
   program, including comments.

4. **Clearing a stale/orphaned operation.** If the controller is stuck in a
   retry loop using an old render, disable `syncPolicy.automated`, terminate the
   operation (ArgoCD API / `argocd app terminate-op`), restart the
   `argocd-application-controller`, re-enable automated sync, then hard-refresh
   with a new `OVERLAY_VERSION`. All workloads may already be healthy while the
   operation is stuck; verify per-resource health before intervening.

**Verified end state:** with these fixes (`OVERLAY_VERSION=13`) the Application
reports `Synced` / `Healthy`, `operationState.phase: Succeeded`, no `SyncError`
or `ComparisonError` conditions, and zero automatic re-syncs in a 5-minute
window. Only the two tolerated `RepeatedResourceWarning` conditions remain.

### 11.7 Current state (this run)

- Core MijnBureau workloads in namespace `mijnbureau` are running with
  `nano`-oriented overrides, wildcard TLS on ingresses, Traefik ingress, and
  Keycloak running with the adjusted security context.
- Synapse is running with reduced requests so it can schedule on its local-path
  node.
- `keycloak-config-cli` (realm bootstrap) may take time if its image pull is
  slow; until the `mijnbureau` realm exists, OIDC-dependent app logins will not
  work. Verify realm creation and re-run/configure if needed.
- ArgoCD Application sync may remain retrying if hook Jobs (e.g. minio
  provisioning or keycloak-config-cli) are stuck; resolve hook image pulls or
  complete their actions manually, then re-sync.