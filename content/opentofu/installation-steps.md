# Installation steps — Euro-Office Docs and Nextcloud

Date: 2026-10-28
Working directory: `content/opentofu`
Target cluster: the Talos/Kubernetes cluster described in
[`access-sites.md`](access-sites.md) (3 control-plane nodes, Kubernetes v1.31.1,
Traefik ingress, `local-path` storage).

This document records how Euro-Office Docs and Nextcloud were installed with
Argo CD, including every deviation from
[`install-euro-office.md`](install-euro-office.md) that was needed for this
cluster.

> **Result:** installed and verified. Both Argo CD Applications are
> `Synced`/`Healthy`, and the Nextcloud connector reports
> `Document server http://euro-office.kubernetes.local/ version 9.3.1.37 is
> successfully connected`. See [section 12](#12-verification).

---

## 1. Environment and pre-flight checks

| Item | Value |
| --- | --- |
| Nodes | `talos-node-1` / `talos-node-2` / `talos-node-3` |
| Node capacity | 2 vCPU, 4 GiB RAM, 20 GB system disk each |
| Allocatable per node | ~1950m CPU, ~3.2 GiB RAM, ~17.8 GB ephemeral storage |
| Ingress controller | Traefik (`IngressClass` `traefik`, NodePort 30080/30443) |
| Default StorageClass | `local-path` (`rancher.io/local-path`, RWO) |
| Argo CD | `argocd` namespace, app-of-apps root Application `root` |
| GitOps repository | Forgejo `gitea_admin/gitops`, path `apps` |

Checks performed:

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory
kubectl get sc
kubectl get ingressclass
kubectl get applications -n argocd
```

The cluster had roughly 2.2 GiB of free memory per node. Euro-Office is a
memory-hungry workload, so all resource requests/limits were reduced (see
[section 5](#5-helm-values-adaptations)) and the Euro-Office pods were pinned to
one node.

### 1.1 Upstream chart availability

The chart URL used by the guide,
`https://euro-office.github.io/Kubernetes-Docs/`, returns **404**. The
documented Helm repository `https://download.euro-office.com/charts/stable` is
now a parked domain: HTTP returns an HTML landing page and HTTPS fails with
`tlsv1 unrecognized name`.

The chart source is still published in the official repository:

* <https://github.com/Euro-Office/Kubernetes-Docs>
* `Chart.yaml`: `name: docs`, `version: 6.0.0`, `appVersion: 9.3.1`
* pinned commit: `0fc3d8403f51432fd12829a9b83ff98de19efe78` (2026-10-13)

The chart was therefore **vendored** into the GitOps repository instead of
being fetched from a Helm repository. The Nextcloud chart
(`nextcloud/nextcloud` 8.3.0, app 32.0.0) was vendored the same way.

The Euro-Office chart defaults to image tag `9.3.1-1`, which is **not
published** on GHCR. The published tag is `v9.3.1`, so that value is
overridden.

---

## 2. Namespaces

```bash
kubectl create namespace euro-office
kubectl create namespace nextcloud

kubectl create namespace nfs-server
kubectl label namespace nfs-server \
  pod-security.kubernetes.io/enforce=privileged --overwrite
```

`nfs-server` needs the privileged Pod Security label because the NFS
provisioner adds the `DAC_READ_SEARCH` and `SYS_RESOURCE` capabilities, which
are not allowed by the default `baseline` profile.

---

## 3. ReadWriteMany storage for Euro-Office

The Euro-Office chart hardcodes `ReadWriteMany` for its three PVCs
(`ds-files`, `ds-runtime-config`, `ds-buffer`). `local-path` only supports
`ReadWriteOnce`, so an NFS provisioner was installed, exactly as the upstream
guide recommends.

```bash
helm repo add nfs-server-provisioner \
  https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm repo update

helm upgrade --install nfs-server \
  nfs-server-provisioner/nfs-server-provisioner \
  --namespace nfs-server \
  --set persistence.enabled=true \
  --set persistence.storageClass=local-path \
  --set persistence.size=8Gi \
  --set storageClass.name=nfs \
  --set storageClass.defaultClass=false \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.memory=256Mi \
  --wait --timeout 6m
```

Result:

```
pod/nfs-server-nfs-server-provisioner-0   1/1   Running
persistentvolumeclaim/data-nfs-server-nfs-server-provisioner-0   Bound   8Gi   RWO   local-path
StorageClass nfs   kubernetes.io/nfs-server-provisioner   Delete   Immediate
```

The chart's PVC sizes were reduced to fit the 8 GiB backing volume:
`ds-files` 4 GiB + `ds-runtime-config` 1 GiB (+ optional `ds-buffer` 2 GiB).

---

## 4. Prerequisite services

The Euro-Office chart expects three external services. Instead of the Bitnami
charts used by the upstream README (whose legacy images are being retired), the
services were deployed as small plain manifests with the official upstream
images. This keeps the image set small and avoids Bitnami catalog changes.

All three run in the `euro-office` namespace. The manifests and the setup
script are stored in `ansible2/files/gitops/prereqs/` (they are applied
manually; Argo CD does not manage them).

### 4.1 PostgreSQL

* image: `postgres:16-alpine`
* PVC: `postgres-data`, 2 GiB, `local-path`
* Service: `postgresql:5432`
* databases/users created on first start:
  * `eurooffice` / `eurooffice` — used by Euro-Office Docs
  * `nextcloud` / `nextcloud` — used by Nextcloud
* the initialisation script is a `ConfigMap` (`postgres-init`) mounted at
  `/docker-entrypoint-initdb.d`
* passwords come from the `postgres-credentials` Secret

```bash
kubectl -n euro-office get deploy,svc,pvc
kubectl -n euro-office exec deploy/postgres -- psql -U postgres -l
```

### 4.2 Redis

* image: `redis:7-alpine`
* Service: `redis-master:6379` (the name the Euro-Office chart expects)
* password from the `redis` Secret, key `redis-password`
* persistence disabled (cache only)

### 4.3 RabbitMQ

* image: `rabbitmq:3.13-management-alpine`
* Service: `rabbitmq:5672` (management on `15672`)
* user `user`, password from the `rabbitmq` Secret, key `rabbitmq-password`
* storage is an `emptyDir` (message broker, not a data store)

The readiness probe initially used the default 1-second timeout and always
failed with `rabbitmq-diagnostics -q ping` (the command takes longer than one
second even on a healthy node). It was corrected to:

```yaml
readinessProbe:
  exec:
    command: ["rabbitmq-diagnostics", "-q", "ping"]
  initialDelaySeconds: 20
  periodSeconds: 10
  timeoutSeconds: 15
  failureThreshold: 6
```

### 4.4 Secrets

Secrets are created out of band; no passwords are stored in this document or
in the GitOps repository:

| Secret | Namespace | Keys |
| --- | --- | --- |
| `postgres-credentials` | `euro-office` | `POSTGRES_PASSWORD`, `EUROOFFICE_DB_PASSWORD`, `NEXTCLOUD_DB_PASSWORD` |
| `eurooffice-db` | `euro-office` | `password` |
| `redis` | `euro-office` | `redis-password` |
| `rabbitmq` | `euro-office` | `rabbitmq-password` |
| `euro-office-jwt` | `euro-office` | `JWT_SECRET` |
| `nextcloud-db` | `nextcloud` | `username`, `password` |
| `nextcloud-admin` | `nextcloud` | `username`, `password` |

They were generated with `openssl rand -hex …` and applied with
`kubectl create secret generic --dry-run=client -o yaml | kubectl apply -f -`.
The temporary credentials file used during the run lived only on the
management container and was deleted afterwards.

---

## 5. Helm values adaptations

Both charts are vendored under `ansible2/files/gitops/charts/`:

```
charts/
├── euro-office-docs/      # upstream Kubernetes-Docs 6.0.0
│   └── values-k8s.yaml
└── nextcloud/             # upstream nextcloud 8.3.0
    └── values-k8s.yaml
```

### 5.1 Euro-Office Docs

`charts/euro-office-docs/values-k8s.yaml` differs from the upstream defaults
as follows:

| Setting | Value | Reason |
| --- | --- | --- |
| `images.tag` | `v9.3.1` | `9.3.1-1` is not published on GHCR |
| `nodeSelector` | `kubernetes.io/hostname: talos-node-1` | pull the 1.4 GB image once; keep memory-heavy pods together |
| `ingress.enabled` | `true` | expose the service |
| `ingress.ingressClassName` | `traefik` | cluster uses Traefik, not NGINX |
| `ingress.host` | `euro-office.kubernetes.local` | homelab DNS name |
| `ingress.ssl.enabled` | `false` | no cert-manager in this cluster |
| `jwt.existingSecret` | `euro-office-jwt` | JWT secret is not committed |
| `connections.dbExistingSecret` | `eurooffice-db` | DB password is not committed |
| `connections.dbName` | `eurooffice` | dedicated database |
| `connections.redisHost` | `redis-master` | matches the Redis Service |
| `connections.amqpHost` | `rabbitmq` | matches the RabbitMQ Service |
| `persistence.storageClass` | `nfs` | chart requires ReadWriteMany |
| `persistence.size` | `4Gi` | fit the 8 GiB NFS backing volume |
| `persistence.runtimeConfig.size` | `1Gi` | same |
| `persistence.customResources.enabled` | `false` | not needed; saves a PVC and job |
| `docservice.replicas` | `1` | small cluster |
| `converter.replicas` | `1` | small cluster |
| `docservice.resources` | requests 250m/512Mi, limits 2 CPU/2Gi | fit node |
| `converter.resources` | requests 200m/256Mi, limits 1 CPU/1Gi | fit node |
| `proxy.resources` | requests 100m/128Mi, limits 500m/512Mi | fit node |
| `metrics.enabled` | `false` | not required |
| `adminpanel.enabled` | `false` | not required |
| `example.enabled` | `true` | deploy the chart's example/test page at `/example/` |
| `tests.enabled` | `false` | no Helm test pods |
| `upgrade.job.enabled` | `false` | Argo CD also runs `pre-upgrade` hooks on install |
| `rollback.job.enabled` | `false` | same |
| `sqlScripts.branchName` | `main` | schema lives on the Euro-Office fork |
| `requestFilteringAgent.allowPrivateIPAddress` | `true` | the document server must download files from Nextcloud's private ClusterIP |

Two templates in the vendored chart were patched as well:

* the schema URLs were changed from
  `raw.githubusercontent.com/ONLYOFFICE/server/…` to
  `raw.githubusercontent.com/Euro-Office/server/…`; the old URL returns
  **404** for `schema/postgresql/createdb.sql`;
* `COMPANY_NAME` was added to
  `templates/configmaps/documentserver.yaml` next to `APPLICATION_NAME`. The
  `cluster-docs:v9.3.1` entrypoint scripts build paths such as
  `/etc/$COMPANY_NAME/documentserver` and
  `/var/www/$COMPANY_NAME/documentserver-example`; without the variable they
  become `/etc//…` and `/var/www//…`, and every container exits with code 2
  (see [section 7.8](#78-missing-company_name-makes-all-containers-exit)).

### 5.2 Nextcloud

`charts/nextcloud/values-k8s.yaml` uses:

| Setting | Value | Reason |
| --- | --- | --- |
| `ingress.enabled` | `true` | expose the service |
| `ingress.className` | `traefik` | Traefik |
| `nextcloud.host` | `nextcloud.kubernetes.local` | homelab DNS name |
| `nextcloud.existingSecret` | `nextcloud-admin` | admin password is not committed |
| `persistence.storageClass` | `local-path` | RWO is sufficient for the Nextcloud data volume |
| `persistence.size` | `5Gi` | fit the node disks |
| `internalDatabase.enabled` | `false` | no SQLite |
| `externalDatabase` | PostgreSQL at `postgresql.euro-office.svc.cluster.local` | reuse the Euro-Office database server |
| `externalDatabase.existingSecret` | `nextcloud-db` | DB password is not committed |
| `mariadb.enabled` | `false` | no bundled MariaDB |
| `postgresql.enabled` | `false` | no bundled PostgreSQL |
| `redis.enabled` | `false` | no bundled Redis |
| `collabora.enabled` | `false` | Euro-Office is the document server |
| `resources` | requests 200m/256Mi, limits 1 CPU/1Gi | fit node |
| probes | longer initial delays | first start initialises the database |

### 5.3 Example application

`example.enabled: true` deploys the chart's example application: a
`StatefulSet` named `example`, a `Service` named `example` on port `3000`, and
a `ConfigMap` with `DS_URL`. The document server's proxy routes `/example/` to
`example:3000`; the main `documentserver` ConfigMap gets
`EXAMPLE_HOST_PORT=example:3000`.

Values added to `values-k8s.yaml`:

```yaml
example:
  enabled: true
  # The example entrypoint defaults JWT_ENABLED to false. The document server
  # requires JWT, so without this the editor config has no token.
  extraEnvVars:
    - name: JWT_ENABLED
      value: "true"
    - name: JWT_HEADER
      value: Authorization
    # Server-to-server URL used by the document server to download the file
    # and post callbacks. The public /example/ prefix is stripped by the
    # documentserver proxy, so use the example Service root here.
    - name: EXAMPLE_URL
      value: http://example:3000
  # Avoid the chart's random `rollme` annotation, which would make Argo CD
  # see a diff on every render and restart the StatefulSet.
  podAnnotations: {}
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

`JWT_SECRET` already comes from the `euro-office-jwt` secret via `envFrom`.
The example image's `docker-entrypoint.sh` defaults `JWT_ENABLED` to `false`,
so the two extra vars above are required; otherwise the editor config has an
empty token and the document server logs `jwt must be provided`.

The image also defaults `EXAMPLE_URL` to `http://localhost/example/`. That is
not reachable from the document server pod. Setting it to
`http://example:3000` (no trailing slash) points at the example Service root;
the app appends `/download` and `/track`, so a trailing slash would produce
`//download` and return 404. The `/example/` prefix is the browser-facing route
handled by the documentserver proxy (which strips it before forwarding).

The example image is `ghcr.io/euro-office/cluster-example:v9.3.1` (about
117 MB compressed) and is pinned to `talos-node-1` by the global
`nodeSelector`. After Argo CD updates the ConfigMap, restart the `docservice`
Deployment so the proxy picks up the new `EXAMPLE_HOST_PORT`:

```bash
kubectl -n euro-office rollout restart deploy/docservice
```

This is the equivalent of the upstream command:

```bash
helm install documentserver onlyoffice/docs --set example.enabled=true
```

The chart is already managed by Argo CD, so the value is changed in
`values-k8s.yaml` instead of running a second `helm install` (which would
collide with the existing release/resources).

---

## 6. Argo CD Applications

Two Application manifests were added at the top level of `apps/`:

* `apps/euro-office.yaml`
* `apps/nextcloud.yaml`

The root Application syncs `path: apps`, but Argo CD's directory source does
**not** recurse by default. The manifests were therefore placed directly in
`apps/`, not in `apps/office/`.

Both Applications use the vendored chart from the in-cluster Forgejo
repository:

```yaml
source:
  repoURL: http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git
  targetRevision: HEAD
  path: charts/euro-office-docs        # or charts/nextcloud
  helm:
    releaseName: documentserver        # or nextcloud
    valueFiles:
      - values-k8s.yaml
destination:
  namespace: euro-office               # or nextcloud
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

The manifests explicitly set `metadata.namespace: argocd` so the root
Application creates them in the Argo CD namespace.

Git commits pushed to the GitOps repository during this installation:

| Commit | Change |
| --- | --- |
| `50e817b` | add both vendored charts and the initial Application manifests |
| `970b9f0` | move Applications from `apps/office/` to `apps/` (root does not recurse) |
| `2e4b66a` | pin Euro-Office pods to `talos-node-1` |
| `0f5755c` | disable Euro-Office `pre-upgrade`/`pre-rollback` hooks |
| `1046d5c` | point schema downloads at `Euro-Office/server` `main` |
| `89a0b8a` | add the missing `COMPANY_NAME` env var to the Euro-Office ConfigMap |
| `b6f0760` | allow the document server to reach private ClusterIPs |
| `7e946c9` | add the prerequisite manifests and setup script under `prereqs/` |
| `3188ccc` | enable the Euro-Office example application (`/example/`) |
| `57e97de` | enable JWT in the example so the editor token is accepted |
| `f4e593b` | use the example Service root for document-server downloads/callbacks |

After each push, the root Application was refreshed with:

```bash
kubectl -n argocd annotate application root \
  argocd.argoproj.io/refresh=normal --overwrite
```

---

## 7. Problems found and corrections

### 7.1 The guide's chart repository no longer exists

* `https://euro-office.github.io/Kubernetes-Docs/` → 404
* `https://download.euro-office.com/charts/stable` → parked domain
* **fix:** vendor the chart from the official GitHub repository at commit
  `0fc3d84`.

### 7.2 Image tag `9.3.1-1` does not exist

GHCR publishes `v9.3.1`, not `9.3.1-1`. The pod would otherwise stay in
`ImagePullBackOff`.
**fix:** `images.tag: v9.3.1`.

### 7.3 Root Application does not recurse

The Applications were first placed in `apps/office/`, but the root Application
only syncs files directly under `apps/`.
**fix:** move them to `apps/euro-office.yaml` and `apps/nextcloud.yaml`.

### 7.4 `pre-upgrade` hook runs on a fresh install

Argo CD maps both `pre-install` and `pre-upgrade` Helm hooks to `PreSync`. The
pre-upgrade hook tries to disable the `docservice` service, which does not
exist yet, and fails with:

```
* Could not resolve host: docservice
The server could not be disabled
```

**fix:** set `upgrade.job.enabled: false` and `rollback.job.enabled: false` in
`values-k8s.yaml`. On upgrades, run those hooks manually if needed.

### 7.5 Database schema download returns 404

The chart's `pre-install` job downloads
`schema/postgresql/createdb.sql` from `ONLYOFFICE/server/master`. That path no
longer exists. The job logged:

```
HTTP request sent, awaiting response... 404 Not Found
work done
```

…but the `eurooffice` database stayed empty.

**fix (one-time):** apply the schema from the Euro-Office fork manually:

```bash
curl -fsSL https://raw.githubusercontent.com/Euro-Office/server/main/schema/postgresql/createdb.sql \
  -o /tmp/createdb.sql
{ echo "SET ROLE eurooffice;"; cat /tmp/createdb.sql; } \
  | kubectl -n euro-office exec -i deploy/postgres -- \
      psql -U postgres -d eurooffice -v ON_ERROR_STOP=1
```

**fix (reproducible):** the vendored chart templates now point at
`https://raw.githubusercontent.com/Euro-Office/server/{{ branch }}/…` and
`sqlScripts.branchName: main`.

Verify:

```bash
kubectl -n euro-office exec deploy/postgres -- \
  psql -U postgres -d eurooffice -c '\dt'
```

Expected: `doc_changes` and `task_result`, both owned by `eurooffice`.

### 7.6 Very slow image pulls

The cluster's uplink delivered roughly 0.3–1 MB/s during the installation.
The Euro-Office main image (`cluster-docs`) is about 1.4 GB and the utilities
image (`cluster-utils`) about 361 MB; the Nextcloud image is about 519 MB.

Mitigations:

* pinned all Euro-Office pods to `talos-node-1` so `cluster-docs` is pulled
  once instead of once per node;
* deleted a stale Nextcloud pod once to restart a stalled pull (cached layers
  are reused);
* let the pulls run in the background.

This is an environment limitation, not a chart problem.

### 7.7 RabbitMQ readiness probe timeout

See [section 4.3](#43-rabbitmq). The default 1-second probe timeout is too
short for `rabbitmq-diagnostics -q ping`.

### 7.8 Missing `COMPANY_NAME` makes all containers exit

After the images were finally cached, both Euro-Office Deployments went into
`CrashLoopBackOff` with exit code **2** and only these log lines:

```
sed: can't read /etc//documentserver/log4js/production.json: No such file or directory
sed: can't read /var/www//documentserver-example/welcome/admin-disabled.html: No such file or directory
```

The double slash is the clue. The `cluster-docs:v9.3.1` entrypoints use
`$COMPANY_NAME`:

```bash
WELCOME_PATH="/var/www/$COMPANY_NAME/documentserver-example/welcome"
sed ... /etc/$COMPANY_NAME/documentserver/log4js/production.json
```

The image provides `COMPANY_NAME_LOW=euro-office`, and the chart sets
`APPLICATION_NAME=euro-office`, but neither sets `COMPANY_NAME`. With an empty
variable the paths become `/var/www//…` and `/etc//…`, `sed` returns 2, and
`set -e` terminates the entrypoint.

**fix:** add `COMPANY_NAME: {{ .Values.product.name }}` to
`templates/configmaps/documentserver.yaml` (commit `89a0b8a`), then restart the
Deployments so the new environment is injected:

```bash
kubectl -n euro-office patch cm documentserver --type merge \
  -p '{"data":{"COMPANY_NAME":"euro-office"}}'
kubectl -n euro-office rollout restart deploy/docservice deploy/converter
```

Result: `docservice` `2/2` and `converter` `1/1` Running.

### 7.9 Connector cannot download the test document

With the document server up, the Nextcloud connector check still failed:

```
Error connection: Error occurred in the document service:
Error while downloading the document file to be converted.
```

Three separate problems were involved:

1. **Wrong port.** The Nextcloud chart's Service exposes `http` on port
   **8080** (`targetPort: 80`). `StorageUrl` had been set to
   `http://nextcloud.nextcloud.svc.cluster.local/` (port 80), so the request
   was refused:
   `curl: (7) Failed to connect ... port 80`.
2. **Private-IP filter.** `requestFilteringAgent.allowPrivateIPAddress`
   defaults to `false`, so the document server refuses to fetch files from a
   `10.x` ClusterIP.
3. **Untrusted hostname.** Nextcloud only accepts `localhost` and
   `nextcloud.kubernetes.local`. A request with
   `Host: nextcloud.nextcloud.svc.cluster.local` returns HTTP **400**.

**fix:**

```bash
# 1. allow private ClusterIPs (chart value, commit b6f0760)
#    requestFilteringAgent.allowPrivateIPAddress: true

# 2. use the Service port
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:app:set onlyoffice StorageUrl \
    --value="http://nextcloud.nextcloud.svc.cluster.local:8080/"

# 3. trust the internal DNS name
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:system:set trusted_domains 2 \
    --value=nextcloud.nextcloud.svc.cluster.local

kubectl -n euro-office patch cm documentserver --type merge \
  -p '{"data":{"ALLOW_PRIVATE_IP_ADDRESS":"true"}}'
kubectl -n euro-office rollout restart deploy/docservice deploy/converter
```

Verification from the document server pod:

```bash
kubectl -n euro-office exec deploy/docservice -c docservice -- \
  curl -sS -o /dev/null -w '%{http_code}\n' \
  http://nextcloud.nextcloud.svc.cluster.local:8080/status.php
# 200
```

### 7.10 Connector tarball has no `vendor/` directory

The Euro-Office connector tarball from GitHub does not contain Composer
dependencies. Enabling it manually produced:

```
Error: Class "Firebase\JWT\JWT" not found
  in .../custom_apps/onlyoffice/lib/DocumentService.php:330
```

The Nextcloud app store package includes `vendor/autoload.php`. Installing the
packaged app fixes it:

```bash
kubectl -n nextcloud exec deploy/nextcloud -- php occ app:install onlyoffice
```

This installed `onlyoffice` **9.15.1** (the app-store release compatible with
Nextcloud 32) and kept the settings that were already stored in the database.
See [section 10](#10-nextcloud--euro-office-integration) for the full
version discussion.

### 7.11 Example editor: "The document security token is not correctly formed"

Opening a document from `/example/` showed the browser error **"The document
security token is not correctly formed"**. The document server logged:

```
[WARN] ... checkJwt error: name = JsonWebTokenError message = jwt must be provided token =
```

The example image's `docker-entrypoint.sh` sets:

```sh
"enable": ${JWT_ENABLED:-false}
```

`JWT_SECRET` is already injected from the `euro-office-jwt` secret, but
`JWT_ENABLED` defaults to `false`. The example therefore rendered the editor
config with `token: ""`, while the document server has JWT enabled and rejected
the empty token.

Fix: add the env vars to `example.extraEnvVars` (see section 5.3) and let the
`example` StatefulSet roll:

```yaml
example:
  extraEnvVars:
    - name: JWT_ENABLED
      value: "true"
    - name: JWT_HEADER
      value: Authorization
    - name: EXAMPLE_URL
      value: http://example:3000
```

The same rollout sets `EXAMPLE_URL=http://example:3000` (no trailing slash).
Without it the signed token's `document.url` is
`http://localhost/example//download`, which the document server cannot reach;
with a trailing slash it is `http://example:3000//download` and returns 404.

After the rollout the editor page contains a signed JWT (verified against
`JWT_SECRET`), and a `CommandService.ashx` request with that token is accepted
by the document server. The example keeps documents inside the pod, so files
created before the rollout are gone; create a new document after the restart.
This was fixed in GitOps commits `57e97de` (JWT) and `f4e593b`
(`EXAMPLE_URL`).

### 7.12 Example app restarts and "File not found: new.docx"

The example stores documents in the container filesystem, not on a PVC. On
2026-10-29 the `example` container restarted after an unhandled error in
`POST /create` (`app.js:386`): `urllib` failed to fetch a sample/external URL
and `data.length` was read on `undefined`. The restart wiped the files, so an
editor URL that was open before the restart returned:

```
Server error: File not found: new.docx
```

The pod restarted automatically and is healthy. Recreate the document with
**Create new → Blank**; the blank route does not use `/create`. Avoid
**With sample content** until the upstream `/create` handler is patched to
check the `urllib` error. This is an example-app issue, not a document-server
or Nextcloud issue.

---

## 8. Current resource usage

The final scheduling and resource requests are:

| Namespace | Workload | CPU request | Memory request | Storage |
| --- | --- | --- | --- | --- |
| `nfs-server` | provisioner | 50m | 64Mi | 8Gi (local-path) |
| `euro-office` | PostgreSQL | 100m | 128Mi | 2Gi (local-path) |
| `euro-office` | Redis | 50m | 64Mi | — |
| `euro-office` | RabbitMQ | 100m | 128Mi | — |
| `euro-office` | docservice | 250m | 512Mi | 4Gi + 1Gi (NFS) |
| `euro-office` | converter | 200m | 256Mi | shares NFS volumes |
| `euro-office` | proxy (sidecar) | 100m | 128Mi | — |
| `nextcloud` | Nextcloud | 200m | 256Mi | 5Gi (local-path) |

Placement:

| Node | Workloads |
| --- | --- |
| `talos-node-1` | `docservice`, `converter`, `redis` |
| `talos-node-2` | `nextcloud` |
| `talos-node-3` | `postgres`, `rabbitmq` |

The Euro-Office node selector is intentional: the 1.4 GB `cluster-docs` image
is pulled once, and the proxy/docservice/converter share the NFS volumes.

---

## 9. Accessing the services

> The management container's DHCP address was `192.168.0.201` at install time.
> It changed to `192.168.0.192` on 2026-10-29. Replace `.201` in the commands
> below with the current address; see [`access-sites.md`](access-sites.md) for
> the current values and the socket/Ansible update procedure.

Add both hostnames to the **client machine** that runs the browser (not to the
Proxmox host):

```
192.168.0.201  euro-office.kubernetes.local nextcloud.kubernetes.local
```

`192.168.0.201` is the management container, which proxies ports 80/443 to the
Traefik NodePorts. Then open:

| Service | URL |
| --- | --- |
| Euro-Office Docs | <http://euro-office.kubernetes.local/> |
| Nextcloud | <http://nextcloud.kubernetes.local/> |

Verify from the management container without changing `/etc/hosts`:

```bash
# 302 -> http://euro-office.kubernetes.local/welcome/
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: euro-office.kubernetes.local' http://192.168.0.201/
# 302 -> http://nextcloud.kubernetes.local/login
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: nextcloud.kubernetes.local' http://192.168.0.201/
```

Follow the redirects with `curl --resolve` (section 12.3) to check the final
pages.

### 9.1 Credentials

Retrieve them from the cluster; they are not stored in Git:

```bash
# Nextcloud admin
ssh root@192.168.0.201 \
  "kubectl -n nextcloud get secret nextcloud-admin \
     -o jsonpath='{.data.username}' | base64 -d; echo"
ssh root@192.168.0.201 \
  "kubectl -n nextcloud get secret nextcloud-admin \
     -o jsonpath='{.data.password}' | base64 -d; echo"

# Euro-Office JWT secret
ssh root@192.168.0.201 \
  "kubectl -n euro-office get secret euro-office-jwt \
     -o jsonpath='{.data.JWT_SECRET}' | base64 -d; echo"
```

---

## 10. Nextcloud ↔ Euro-Office integration

The connector is <https://github.com/Euro-Office/eurooffice-nextcloud>.

### 10.1 Version compatibility

The chart deployed Nextcloud **32.0.0**. The current connector release
(`v11.x`) requires Nextcloud **33–36**, and the current app is published as
`eurooffice`, which is **not** in the Nextcloud app store:

```
Error: Could not download app eurooffice, it was not found on the appstore
```

The Euro-Office fork still has a v9.13.0 tag that supports Nextcloud 31–32. In
that tag the internal app ID is still **`onlyoffice`** (the rename to
`eurooffice` happened in v10, together with the Nextcloud 33 requirement).

The v9.13.0 tarball was installed manually first, but it **does not contain
`vendor/`**, so the connector failed with `Class "Firebase\JWT\JWT" not found`.
The app store package for `onlyoffice` does bundle `vendor/` and is available
for Nextcloud 32. Installing that package fixed the missing dependency and
kept the settings already stored in the database:

```bash
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ app:install onlyoffice
```

Result: `onlyoffice` **9.15.1** enabled. This is the upstream ONLYOFFICE
connector (the app store does not carry the Euro-Office fork); it speaks the
same API and JWT protocol as Euro-Office Docs. The document server itself is
Euro-Office `9.3.1.37`.

> If Euro-Office branding inside Nextcloud is required, use the fork's
> `v9.13.0` tarball plus the `vendor/` directory from the app-store package.
> The functionality is the same; only the app name/branding differs.

### 10.2 Settings

```bash
POD=$(kubectl -n nextcloud get pod -l app.kubernetes.io/name=nextcloud \
  -o jsonpath='{.items[0].metadata.name}')

kubectl -n nextcloud exec "$POD" -- \
  php occ config:app:set onlyoffice DocumentServerUrl \
    --value="http://euro-office.kubernetes.local/"
kubectl -n nextcloud exec "$POD" -- \
  php occ config:app:set onlyoffice DocumentServerInternalUrl \
    --value="http://documentserver.euro-office.svc.cluster.local:8888/"
kubectl -n nextcloud exec "$POD" -- \
  php occ config:app:set onlyoffice StorageUrl \
    --value="http://nextcloud.nextcloud.svc.cluster.local:8080/"

JWT=$(kubectl -n euro-office get secret euro-office-jwt \
  -o jsonpath='{.data.JWT_SECRET}' | base64 -d)
kubectl -n nextcloud exec "$POD" -- \
  php occ config:app:set onlyoffice jwt_secret --value="$JWT"
```

`DocumentServerUrl` is what the browser uses; `DocumentServerInternalUrl` is
what the Nextcloud server uses inside the cluster; `StorageUrl` is what the
document server uses to fetch files from Nextcloud. Note the **`:8080`** on
`StorageUrl`: the Nextcloud chart's Service exposes port 8080 and forwards to
container port 80.

Nextcloud must also trust the internal DNS name used for those downloads:

```bash
kubectl -n nextcloud exec "$POD" -- \
  php occ config:system:set trusted_domains 2 \
    --value=nextcloud.nextcloud.svc.cluster.local
```

The connector writes the JWT in the `Authorization` header by default, which
matches the chart's `jwt.header: Authorization` default. No `jwt_header`
override is needed.

Verify:

```bash
kubectl -n nextcloud exec "$POD" -- \
  php occ onlyoffice:documentserver --check
```

Expected:

```
Document server http://euro-office.kubernetes.local/ version 9.3.1.37 is successfully connected
```

> `occ config:app:set` prints the value it stores, including `jwt_secret`.
> Do not paste that terminal output into a ticket or commit.

### 10.3 Upgrading later

When Nextcloud is upgraded to 33 or newer, replace the connector with the
current `eurooffice` app (v11.x) and use `eurooffice` instead of `onlyoffice`
in every `occ config:app:set` command. The setting keys are unchanged.

---

## 11. Deviations from `install-euro-office.md`

| Guide step | What was done instead | Why |
| --- | --- | --- |
| Helm repo `euro-office.github.io` / `download.euro-office.com` | vendored chart from GitHub | repositories are gone / parked |
| NGINX Ingress | Traefik | cluster already uses Traefik |
| cert-manager / Let's Encrypt | HTTP only | no cert-manager; homelab |
| NFS server provisioner | installed as described | chart requires RWX |
| Bitnami PostgreSQL/Redis/RabbitMQ | small manifests with official images | avoid retired Bitnami images, reduce footprint |
| Nextcloud + bundled MariaDB | Nextcloud + external PostgreSQL | one database server, less memory/disk |
| `apps/office/` subdirectory | top-level `apps/` | Argo CD directory source does not recurse |
| Helm `pre-upgrade` hook | disabled | Argo CD runs it on install; it fails |
| upstream schema URL | patched to `Euro-Office/server/main` | old URL returns 404 |

---

## 12. Verification

Verified on 2026-10-28 from the management container.

### 12.1 Argo CD

```bash
kubectl -n argocd get applications
```

```
NAME          SYNC STATUS   HEALTH STATUS
euro-office   Synced        Healthy
nextcloud     Synced        Healthy
nginx-demo    Synced        Healthy
root          Synced        Healthy
```

### 12.2 Workloads and storage

```bash
kubectl -n euro-office get pods,pvc
kubectl -n nextcloud get pods,pvc
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

* `docservice` — `2/2` Running (proxy + docservice)
* `converter` — `1/1` Running
* `postgres`, `redis`, `rabbitmq` — `1/1` Running
* `nextcloud` — `1/1` Running
* no pods outside `Running`/`Succeeded`

| PVC | Capacity | Access mode | StorageClass |
| --- | --- | --- | --- |
| `euro-office/ds-files` | 4Gi | RWX | `nfs` |
| `euro-office/ds-runtime-config` | 1Gi | RWX | `nfs` |
| `euro-office/postgres-data` | 2Gi | RWO | `local-path` |
| `nextcloud/nextcloud-nextcloud` | 5Gi | RWO | `local-path` |
| `nfs-server/data-nfs-server-nfs-server-provisioner-0` | 8Gi | RWO | `local-path` |

### 12.3 HTTP endpoints

The management container does not resolve the `*.kubernetes.local` names, so
`curl --resolve` is used to follow the redirects. These commands were recorded
with the DHCP address of the time (`.201`); the current lease is `.192` (see
section 12.6):

```bash
curl -sSL --resolve euro-office.kubernetes.local:80:192.168.0.201 \
  -o /dev/null -w '%{http_code} %{url_effective}\n' \
  http://euro-office.kubernetes.local/
# 200 http://euro-office.kubernetes.local/welcome/

curl -sS --resolve euro-office.kubernetes.local:80:192.168.0.201 \
  -o /dev/null -w '%{http_code}\n' \
  http://euro-office.kubernetes.local/healthcheck
# 200

curl -sSL --resolve nextcloud.kubernetes.local:80:192.168.0.201 \
  -o /dev/null -w '%{http_code} %{url_effective}\n' \
  http://nextcloud.kubernetes.local/
# 200 http://nextcloud.kubernetes.local/login
```

The Euro-Office welcome page title is:

```html
<title>Euro-Office Docs Community Edition</title>
```

### 12.4 Nextcloud ↔ Euro-Office

```bash
POD=$(kubectl -n nextcloud get pod -l app.kubernetes.io/name=nextcloud \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n nextcloud exec "$POD" -- php occ onlyoffice:documentserver --check
```

```
Document server http://euro-office.kubernetes.local/ version 9.3.1.37 is successfully connected
```

The document server can also fetch `status.php` from Nextcloud over the
internal Service:

```bash
kubectl -n euro-office exec deploy/docservice -c docservice -- \
  curl -sS -o /dev/null -w '%{http_code}\n' \
  http://nextcloud.nextcloud.svc.cluster.local:8080/status.php
# 200
```

### 12.5 Clean-up performed

* temporary debug pod `euro-office/ds-debug` deleted;
* `euro-office` Application finalizer restored to
  `resources-finalizer.argocd.argoproj.io` after the early re-install;
* the credentials file and connector tarball on the management container
  removed (the secrets live in Kubernetes only).

### 12.6 Example application

The chart's example was enabled with `example.enabled: true` (commit
`3188ccc`) and is the homelab equivalent of:

```bash
helm install documentserver onlyoffice/docs --set example.enabled=true
```

```bash
kubectl -n euro-office get statefulset example
kubectl -n euro-office get pod example-0 -o wide
# example   1/1   Running   talos-node-1
```

The public page returns HTTP **200**:

```bash
curl -sSL --resolve euro-office.kubernetes.local:80:192.168.0.192 \
  -o /tmp/example.html -w '%{http_code} %{url_effective}\n' \
  http://euro-office.kubernetes.local/example/
# 200 http://euro-office.kubernetes.local/example/
grep -o '<title>[^<]*</title>' /tmp/example.html
# <title>Euro-Office Document editors</title>
```

The "Create new → Document" flow creates a document and redirects to the
editor page:

```bash
# creates a document and redirects to the editor page
curl -sS -D - -o /dev/null \
  -H 'Host: euro-office.kubernetes.local' \
  'http://10.10.50.22:30080/example/editor?fileExt=docx'
# HTTP/1.1 302 Found
# Location: http://euro-office.kubernetes.local/example/editor?mode=edit&fileName=new%20(1).docx

curl -sSL --resolve euro-office.kubernetes.local:80:192.168.0.192 \
  -o /tmp/editor.html -w '%{http_code}\n' \
  'http://euro-office.kubernetes.local/example/editor?mode=edit&fileName=new%20(1).docx'
# 200
grep -o '<title>[^<]*</title>' /tmp/editor.html
# <title>new (1).docx - Euro-Office</title>
```

The example now runs with `JWT_ENABLED=true` and
`EXAMPLE_URL=http://example:3000`. The editor page contains a signed JWT whose
`document.url` is `http://example:3000/download?...`; a fetch from the
docservice with `Authorization: Bearer <token>` returns **200**. A
`CommandService.ashx` request with the token returns **200** (the command-level
`error:6` is not a JWT error), and `docservice` logs no `checkJwt` error. See
section 7.11.

> The management container's DHCP lease changed from `192.168.0.201` to
> `192.168.0.192` during verification. The `traefik-ingress-http.socket` /
> `traefik-ingress-https.socket` units were still bound to `.201`, so the
> public hostname refused connections while the Traefik NodePort at
> `10.10.50.22:30080` worked. The socket units and `ansible2/hosts.yml` were
> updated to `.192` and the sockets restarted.

---

## 13. Backup target and Velero

Implemented on 2026-10-30. The full design, status, and limitations are in
[`backup.md`](backup.md); the operational runbook is
[`backup-restore-howto.md`](backup-restore-howto.md). No credentials are
recorded here.

### 13.1 Proxmox LXC and external volume

Root SSH to the Proxmox host is denied, so Garage was installed in a dedicated
privileged LXC rather than on the host:

| Item | Value |
| --- | --- |
| VMID / hostname | `107` / `garage-backup` |
| Addresses | `192.168.0.224/24` on `vmbr0`, `10.10.50.2/24` on `vmbr1` |
| Root filesystem | 4 GiB on `local-lvm` |
| Memory | 1 GiB |
| Data volume | 500 GiB from `externe-disk`, mounted at `/mnt/garage` |
| Boot | `onboot=1` |
| Entrypoint | `/usr/local/sbin/garage-net-init` |

`externe-disk` had to gain `rootdir` content so the LXC volume could be
created; its content is now `backup,rootdir,images`. The LXC uses
`externe-disk:107/vm-107-disk-0.raw` rather than a bind mount because the API
token cannot create bind mounts.

The network entrypoint configures both interfaces, writes a resolver, and
then execs `/sbin/init`. A container reboot was tested; both addresses,
`/mnt/garage`, `garage.service`, and the metadata timer came back.

The LXC's systemd reports `degraded` because host-style units such as
`apparmor`, `systemd-journald`, `systemd-tmpfiles`, and `nftables` cannot run
in this container. Do not add systemd namespace hardening to the Garage unit;
it caused `status=226/NAMESPACE`. The minimal unit and the network script are
stored in `ansible2/files/backup/`.

### 13.2 Garage

Garage v2.5.0 is installed at `/usr/local/bin/garage`; its configuration is
`/etc/garage.toml`, with data on `/mnt/garage/data` and metadata in
`/var/lib/garage/meta`. The service uses
`--single-node --default-bucket`, which creates the `velero` bucket. The
`restic` bucket was created explicitly and the default key was granted
read/write/owner access. The internal S3 endpoint is
`http://10.10.50.2:3900` with path-style addressing.

A daily timer snapshots the metadata with SQLite's online backup API into
`/mnt/garage/meta-snapshots` and keeps 30 days. The Garage status was healthy
(491.1 GiB capacity, 466.0 GiB available), both buckets were listed, and an
unauthenticated `curl` to `:3900` returned `403`.

### 13.3 Velero

Velero chart 12.2.2 / server v1.18.2 is installed in the `velero` namespace
with the AWS plugin v1.14.4 and CLI v1.18.4. The credentials are in the
`velero-credentials` Secret; the values are in
`ansible2/files/backup/values-velero.yaml`. The BackupStorageLocation
`default` points at `http://10.10.50.2:3900/velero` and is `Available`.

The chart creates `schedule/velero-daily` at 02:00 UTC. It includes the
application namespaces and `backup`, excludes the Kubernetes system
namespaces and `velero`, and uses object-only backups
(`defaultVolumesToFsBackup: false`, `snapshotsEnabled: false`).

Verification:

* `smoke-test` completed; it had one expected `hostPath` warning while volume
  backup was temporarily enabled.
* `velero-daily-20261030151045` completed with no errors or warnings.
* `smoke-restore` completed by restoring `nginx-demo` objects into
  `nginx-restore`; the test namespace was deleted.

### 13.4 The `local-path` correction: restic

The smoke test exposed a design error: Velero/Kopia does **not** back up PVs
whose source is `hostPath`, and the `local-path` provisioner uses `hostPath`
PVs. A separate restic 0.18.1 DaemonSet was therefore added:

* namespace `backup`
* one pod per node
* hostPath `/var/local-path-provisioner` mounted read-only at `/data`
* repository `s3:http://10.10.50.2:3900/restic`
* daily per-node snapshots with 30 daily / 8 weekly / 6 monthly retention

The NFS server's backing store is a local-path volume, so backing up the NFS
server node also covers the `ds-files` and `ds-runtime-config` client data.
Snapshots were produced for `talos-node-2` and `talos-node-3` (and an empty
snapshot for node 1), and a restore to a temporary hostPath directory restored
2386 files/dirs. The first automatic DaemonSet snapshots completed on
2026-10-30.

The restic password and AWS keys are in `backup/restic-credentials`; the
password is required for restore and should be kept in a password manager.

### 13.5 PostgreSQL logical dump

The `euro-office/postgres-dump` CronJob runs daily at 01:30 UTC and writes
`pg_dumpall --clean --if-exists` output to the 10 GiB local-path PVC
`euro-office/postgres-dumps`. It keeps 14 days. A manual run completed with a
295 KiB dump, and the updated node-3 tree was captured in restic snapshot
`d612308f`. The dump is included in restic because the PVC lives under
`/var/local-path-provisioner`.

Forgejo still uses SQLite without a separate logical dump; Nextcloud and the
database are not quiesced together. These are documented gaps.

### 13.6 Current status and gaps

Working: object backups, object restore, local-path snapshots, local-path
restore test, PostgreSQL dump, Garage metadata snapshot, and LXC reboot
persistence.

Still missing: an off-site copy of the external disk, Garage replication,
Proxmox VM-level backups, application-consistent hooks, scheduled restore
drills, TLS, and backup alerting. The external disk is currently a single
failure domain.

---

## 14. Cluster monitoring (Prometheus and Grafana)

The `monitoring` Argo CD Application installs
`kube-prometheus-stack` 92.17.0 from the public
`prometheus-community` Helm repository. The Application is defined in
`ansible2/files/gitops/apps/monitoring.yaml`; the chart values are inlined in
the Application so the GitOps repository contains the full configuration.

### 14.1 Components and URLs

| Component | Details |
| --- | --- |
| Grafana | `http://grafana.kubernetes.local`; Traefik ingress |
| Prometheus | internal service `monitoring-kube-prometheus-prometheus:9090` |
| Alertmanager | internal service; no receiver configured yet |
| node-exporter | DaemonSet, one pod per Talos node |
| kube-state-metrics | Kubernetes object metrics |
| Prometheus Operator | manages Prometheus, Alertmanager, rules and monitors |

Grafana uses the stable `monitoring-grafana-admin` Secret. It must exist before
the first sync and is not stored in this repository. Create it with a random
password:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n monitoring get secret monitoring-grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic monitoring-grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -hex 24)"
fi
```

Create the Secret only once. Rotating it later does not update the password
hash already stored in Grafana’s database.

Retrieve it with:

```bash
kubectl -n monitoring get secret monitoring-grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

No password is stored in this repository. See
[`monitoring.md`](monitoring.md) for the full runbook and password-reset
caveats.

### 14.2 Values that matter

* Prometheus retains 7 days or 6 GB in an 8 GiB `local-path` PVC.
* Grafana has a 2 GiB `local-path` PVC and a Traefik ingress for
  `grafana.kubernetes.local`.
* Alertmanager has a 1 GiB `local-path` PVC and 120-hour retention.
* Requests and limits are sized for three 2 GiB nodes.
* The etcd, controller-manager, scheduler and kube-proxy ServiceMonitors are
  disabled because Talos does not expose them as ordinary cluster services.
* The API server, kubelet, CoreDNS, kube-state-metrics and node-exporter
  targets remain enabled.
* The namespace is labeled `pod-security.kubernetes.io/enforce=privileged`
  through Argo CD’s `managedNamespaceMetadata`. Node-exporter requires this
  because it uses host namespaces, host paths and host port `9100`.
* Prometheus has a small init container that fixes ownership of the
  `prometheus-db` subPath on `local-path`; `fsGroup` alone does not chown that
  kubelet-created subPath.
* Grafana uses a `Recreate` deployment strategy. Two Grafana pods must not
  migrate the SQLite database on the same ReadWriteOnce volume concurrently.

### 14.3 Verification

```bash
kubectl -n argocd get application monitoring
kubectl -n monitoring get pods,svc,ingress,pvc
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: grafana.kubernetes.local' http://192.168.0.192/login
```

Expected: the Application is `Synced`/`Healthy`, all pods are `Running`, the
three monitoring PVCs are `Bound`, and Grafana returns `200`. The
`monitoring/kube-prometheus-stack` CRDs are installed with
`ServerSideApply=true`; the initial sync therefore takes longer than the
application charts.

Monitoring is intentionally not highly available: Prometheus, Grafana and
Alertmanager each use a node-local `local-path` volume. There is no remote
write, off-site copy, TLS or alert receiver yet.

---

## 15. Clean-up / re-run notes

* The charts and values are stored in `ansible2/files/gitops/` **and** pushed
  to Forgejo. Re-running `from-scratch.sh` does not remove them; the playbook
  only updates the files it knows about.
* The prerequisite manifests (`postgres`, `redis`, `rabbitmq`) and the secrets
  are *not* managed by Argo CD. They must be re-applied when rebuilding the
  cluster. Reference copies live in `ansible2/files/gitops/prereqs/` and in
  the Forgejo repository.
* The NFS provisioner is a Helm release in `nfs-server`, also outside Argo CD.
* The `onlyoffice` connector (9.15.1) is installed from the Nextcloud app
  store and lives on the Nextcloud PVC. A rebuild with a fresh PVC must run
  `occ app:install onlyoffice` and re-apply the settings from section 10.
* The Euro-Office `pre-install` hook is deleted after a successful sync, so
  the `pre-install` ConfigMap is not present in the running namespace. The
  schema was applied once with `createdb.sql`; the patched chart will do it on
  a fresh install.
* Deleting the `euro-office` Application with its finalizer enabled will delete
  the chart-managed resources, including the NFS PVCs. Remove the finalizer
  first if you want to keep the data.
