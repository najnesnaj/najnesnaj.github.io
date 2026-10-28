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

> **Result:** see [section 12](#12-verification) for the final verification.

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

All three run in the `euro-office` namespace.

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
| `example.enabled` | `false` | not required |
| `tests.enabled` | `false` | no Helm test pods |
| `upgrade.job.enabled` | `false` | Argo CD also runs `pre-upgrade` hooks on install |
| `rollback.job.enabled` | `false` | same |
| `sqlScripts.branchName` | `main` | schema lives on the Euro-Office fork |

The chart's schema templates were also patched from
`raw.githubusercontent.com/ONLYOFFICE/server/…` to
`raw.githubusercontent.com/Euro-Office/server/…`; the old URL returns **404**
for `schema/postgresql/createdb.sql`.

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

---

## 8. Current resource usage

After the prerequisites were running (before the Euro-Office images finished
pulling):

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

---

## 9. Accessing the services

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
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: euro-office.kubernetes.local' http://192.168.0.201/
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'Host: nextcloud.kubernetes.local' http://192.168.0.201/
```

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

The Nextcloud connector app is `eurooffice`
(<https://github.com/Euro-Office/eurooffice-nextcloud>). Once the Nextcloud pod
is ready:

```bash
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ app:install eurooffice
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ app:enable eurooffice

kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:app:set eurooffice DocumentServerUrl \
    --value="http://euro-office.kubernetes.local/"
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:app:set eurooffice DocumentServerInternalUrl \
    --value="http://documentserver.euro-office.svc.cluster.local:8888/"
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:app:set eurooffice StorageUrl \
    --value="http://nextcloud.nextcloud.svc.cluster.local/"
kubectl -n nextcloud exec deploy/nextcloud -- \
  php occ config:app:set eurooffice jwt_secret \
    --value="$(kubectl -n euro-office get secret euro-office-jwt \
      -o jsonpath='{.data.JWT_SECRET}' | base64 -d)"
```

`DocumentServerUrl` is what the browser uses; `DocumentServerInternalUrl` is
what the Nextcloud server uses inside the cluster; `StorageUrl` is what the
document server uses to fetch files from Nextcloud.

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

> Filled in after the images finished pulling and the pods became ready.

```bash
kubectl -n argocd get applications
kubectl -n euro-office get pods,pvc
kubectl -n nextcloud get pods,pvc
```

Expected:

* `euro-office` and `nextcloud` Applications `Synced` / `Healthy`;
* all pods `Running` and ready;
* PVCs `Bound`;
* HTTP 200 (or a redirect to the login page) for both hostnames.

---

## 13. Clean-up / re-run notes

* The charts and values are stored in `ansible2/files/gitops/` **and** pushed
  to Forgejo. Re-running `from-scratch.sh` does not remove them; the playbook
  only updates the files it knows about.
* The prerequisite manifests (`postgres`, `redis`, `rabbitmq`) and the secrets
  are *not* managed by Argo CD. They must be re-applied when rebuilding the
  cluster.
* The NFS provisioner is a Helm release in `nfs-server`, also outside Argo CD.
* Deleting the `euro-office` Application with its finalizer enabled will delete
  the chart-managed resources, including the NFS PVCs. Remove the finalizer
  first if you want to keep the data.
