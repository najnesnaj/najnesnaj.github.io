<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Euro-Office + Nextcloud on an air-gapped Kubernetes cluster (Helm)

This document provides **detailed, offline-capable installation instructions** for running the **Nextcloud + Euro-Office** office stack on a **Kubernetes cluster that has no internet connection** (air-gapped). It combines:

- the original [kubernetes-proposal.md](./kubernetes-proposal.md) (the two-helm-chart deployment idea),
- the upstream documentation of the [Nextcloud Helm Chart](https://github.com/nextcloud/helm/tree/main/charts/nextcloud) and the [Euro-Office Kubernetes-Docs Helm Chart](https://github.com/Euro-Office/Kubernetes-Docs),
- the fixes and modifications that were recorded for the **Podman** installation in this directory ([overview.md](./overview.md), [installation-steps.md](./installation-steps.md), [local-nextcloud-fixes.md](./local-nextcloud-fixes.md), [nextcloud-euro-office-integration.md](./nextcloud-euro-office-integration.md), [final-install.md](./final-install.md), [kubernetes.md](./kubernetes.md)),
- and translates every one of those Podman-only fixes into native Kubernetes/Helm configuration (self-signed TLS, the document-**saving** fix, shared JWT, local domains, cache/database wiring).

> [!WARNING]
> **Artificial-intelligence notice.** Like [kubernetes.md](./kubernetes.md), this document was created with the assistance of **artificial intelligence**. It is based on the recorded Podman installation and on the upstream chart documentation referenced above. It has **not** been validated against a real air-gapped cluster. Treat all commands, manifests and values as a thorough starting point; plan for rework, validation and troubleshooting time on your actual cluster (see [section 15](#15-estimated-time-and-risk)).

| Document | Content |
| --- | --- |
| [kubernetes-proposal.md](./kubernetes-proposal.md) | The original two-chart proposal this document turns into a full guide |
| [kubernetes.md](./kubernetes.md) | Manifest-based Kubernetes translation of the Podman install |
| [overview.md](./overview.md) | Overview of the local (air-gapped) Podman installation |
| [installation-steps.md](./installation-steps.md) | Full AIO install log under Podman |
| [local-nextcloud-fixes.md](./local-nextcloud-fixes.md) | The Podman / local-only fixes in detail |
| [nextcloud-euro-office-integration.md](./nextcloud-euro-office-integration.md) | Euro-Office integration and the document-saving fix |
| [euro-office-github.md](./euro-office-github.md) | Euro-Office upstream install guide (GitHub-based) |
| [final-install.md](./final-install.md) | The concrete Podman containers and credentials used |

## Table of contents

- [1. Goal and scope](#1-goal-and-scope)
- [2. Architecture](#2-architecture)
- [3. What changes compared to the Podman installation](#3-what-changes-compared-to-the-podman-installation)
- [4. Air-gapped prerequisites](#4-air-gapped-prerequisites)
- [5. Preparing offline artifacts on a connected machine](#5-preparing-offline-artifacts-on-a-connected-machine)
  - [5.1 Container images](#51-container-images)
  - [5.2 Helm charts](#52-helm-charts)
  - [5.3 SQL scripts for the Euro-Office install/upgrade/delete jobs](#53-sql-scripts-for-the-euro-office-installupgradedelete-jobs)
  - [5.4 The custom Nextcloud image with the Euro-Office app](#54-the-custom-nextcloud-image-with-the-euro-office-app)
- [6. Base cluster setup (done once)](#6-base-cluster-setup-done-once)
  - [6.1 Ingress controller](#61-ingress-controller)
  - [6.2 RWX storage (NFS server provisioner)](#62-rwx-storage-nfs-server-provisioner)
  - [6.3 DNS / name resolution for the local domains](#63-dns--name-resolution-for-the-local-domains)
  - [6.4 TLS certificates and registry pull secret](#64-tls-certificates-and-registry-pull-secret)
- [7. Namespace and secrets](#7-namespace-and-secrets)
- [8. Stateful dependencies: RabbitMQ, Redis, PostgreSQL](#8-stateful-dependencies-rabbitmq-redis-postgresql)
- [9. Euro-Office Docs (Helm)](#9-euro-office-docs-helm)
  - [9.1 `local.json` ConfigMap (the document-saving fix)](#91-localjson-configmap-the-document-saving-fix)
  - [9.2 `values-eurooffice.yaml`](#92-values-euroofficeyaml)
  - [9.3 Install / uninstall / upgrade in a private cluster](#93-install--uninstall--upgrade-in-a-private-cluster)
- [10. Nextcloud (Helm)](#10-nextcloud-helm)
  - [10.1 `values-nextcloud.yaml`](#101-values-nextcloudyaml)
  - [10.2 Install](#102-install)
  - [10.3 Post-install occ configuration](#103-post-install-occ-configuration)
- [11. Connecting Nextcloud to Euro-Office](#11-connecting-nextcloud-to-euro-office)
- [12. Verification](#12-verification)
- [13. How the Podman fixes translate to Kubernetes](#13-how-the-podman-fixes-translate-to-kubernetes)
- [14. Management, backups and upgrades (offline)](#14-management-backups-and-upgrades-offline)
- [15. Estimated time and risk](#15-estimated-time-and-risk)
- [16. Troubleshooting](#16-troubleshooting)
- [17. References](#17-references)

---

## 1. Goal and scope

The Podman installation in this directory runs Nextcloud and the Euro-Office document server on a **single local host** under a **local-only domain** (`nextcloud.local` → `192.168.0.114`), with **no internet link** and with several manual runtime fixes (self-signed TLS, document-saving callback fix, `containers.json` patching).

The goal here is the **same workload on a real Kubernetes cluster** that is **not connected to the internet**:

- a **Nextcloud** instance (PostgreSQL-backed, Redis-cached) reached at `https://nextcloud.local`,
- the **Euro-Office document server** reached at `https://office.local`,
- integrated so documents can be opened **and saved**,
- using the two official **Helm charts** from [kubernetes-proposal.md](./kubernetes-proposal.md),
- with **everything required to run offline** (images, charts, SQL scripts, app sources) staged beforehand on a connected machine and carried over.

The default credentials below match the Podman record ([final-install.md](./final-install.md)) so that this document is directly comparable. **Change all secrets before a real deployment.**

## 2. Architecture

Everything runs in the namespace `nextcloud` (or `eurooffice` if you prefer to separate the document server; the values below use a single `nextcloud` namespace like [kubernetes.md](./kubernetes.md)).

```
                    (air-gapped LAN clients)
                     +----------------------+
                     |  /etc/hosts:          |
                     |  nextcloud.local      |
                     |  office.local         |
                     +----------+-----------+
                                | 80/443
                     +----------v-----------+
                     | Ingress (ingress-nginx)   |
                     |  TLS: self-signed secrets  |
                     +-----+----------------+-----+
                           |                    |
                    +------v------+      +------v--------+
                    | nextcloud   |      | office.local  |
                    | Deployment  |      | Euro-Office   |
                    | nginx+PHP   |      | Docs          |
                    | (custom img)|      | (docservice + |
                    +------+------+      |  converter +  |
                           |             |  proxy)       |
                           |             +-------^-------+
        +------------------+---------------+      |
        |                  |               |      |
  +-----v-----+      +-----v-----+   +-----v-----v----+
  | postgres  |      | redis     |   | rabbitmq       |
  | (Stateful |      | (master)  |   | (Stateful)     |
  |  by bitnami)     |  by bitnami)  |  by bitnami)   |
  +-----------+      +-----------+   +----------------+
```

The Euro-Office chart needs three state stores (it does **not** bundle them, unlike the Nextcloud chart):

| Service | Bitnami release | Image (legacy tags, see [5.1](#51-container-images)) |
| --- | --- | --- |
| PostgreSQL (shared by Nextcloud and Euro-Office) | `postgresql` | `bitnamilegacy/postgresql:17.6.0-debian-12-r2` |
| Redis (shared) | `redis` | `bitnamilegacy/redis:8.2.1-debian-12-r0` |
| RabbitMQ (Euro-Office message queue) | `rabbitmq` | `bitnamilegacy/rabbitmq:4.1.3-debian-12-r1` |

> The **Nextcloud Helm chart** optionally packages its own Bitnami PostgreSQL/Redis/MariaDB sub-charts. Because we already run a PostgreSQL and Redis for Euro-Office, this guide disables those sub-charts (`postgresql.enabled: false`, `redis.enabled: false`) and points Nextcloud at the shared services via `externalDatabase` / `externalRedis`. This saves memory and image staging effort on the air-gapped cluster.

## 3. What changes compared to the Podman installation

| Podman / AIO concept | Kubernetes / Helm equivalent |
| --- | --- |
| AIO mastercontainer + `containers.json` patching | Helm values files (the fixes become *values*, never runtime patches) |
| AIO interface on `:8080`, password login | `helm install` / `helm upgrade` + `kubectl` |
| `nextcloud-aio-apache` (Caddy TLS) | ingress-nginx + self-signed TLS secrets |
| `nextcloud-aio-redis` | shared Bitnami Redis service |
| AIO-managed PostgreSQL | shared Bitnami PostgreSQL service |
| AIO-managed `nextcloud-aio-eurooffice` | `euro-office/docs` Helm chart (docservice/converter/proxy) |
| App installed by `git clone` + npm + composer at runtime | **custom Nextcloud image** with the app baked in (required, see [5.4](#54-the-custom-nextcloud-image-with-the-euro-office-app)) |
| `podman restart` after apache recreation (stale `listen.allowed_clients`) | **Not applicable** - nginx and PHP live in one pod |
| Caddy `tls { issuer internal }` (self-signed) | TLS secret with a self-signed certificate, or an internal CA (cert-manager) |
| `USE_UNAUTHORIZED_STORAGE=true`, `ALLOW_PRIVATE_IP_ADDRESS=true` | `local.json` ConfigMap (`rejectUnauthorized: false`) + `requestFilteringAgent.allowPrivateIPAddress`, see [9.1](#91-localjson-configmap-the-document-saving-fix) |
| `--restart always` / systemd user units | Deployments / StatefulSets + cluster scheduler |

The three *new* offline concerns on Kubernetes (none existed under Podman) are:

1. **Images** must already be in a registry the cluster can reach (section [5.1](#51-container-images)).
2. **Helm charts** must be packaged and carried over, because `helm repo add` needs the internet (section [5.2](#52-helm-charts)).
3. The **Euro-Office install/upgrade/delete hooks** download SQL scripts from the internet; they must be switched to `privateCluster=true` with pre-created ConfigMaps (section [5.3](#53-sql-scripts-for-the-euro-office-installupgradedelete-jobs)).

## 4. Air-gapped prerequisites

On the cluster side:

- Kubernetes **1.24+** (Nextcloud chart requirement; the Euro-Office chart requires 1.19+). The Euro-Office upstream docs recommend at least **two worker nodes** and **4 CPU / 8 GB RAM minimum** per host for the document server.
- **Helm v3** (the Euro-Office chart requires **3.15+**; install Helm v3 from the packaged `.deb`/`.tar.gz` beforehand - the official installer script needs internet).
- `kubectl` configured for the cluster.
- A **local container registry** reachable by all nodes (e.g. Harbor, GitLab registry, or a simple `registry:2`). All image `pull`/`push` below assume `registry.local:5000`.
- An **ingress controller** (ingress-nginx) that will terminate TLS on ports 80/443.
- A **`ReadWriteMany` storage class** (needed by the Euro-Office docserver PVCs, see [6.2](#62-rwx-storage-nfs-server-provisioner)).
- **No outbound internet** from the cluster is used at any point.

> [!IMPORTANT]
> Everything in sections 5.1-5.4 is done on a **separate, connected machine** (the "staging host"). Only the resulting artifacts (`.tar.gz` image bundles, `.tgz` chart files, `.sql` files, the custom image tarball) are carried into the air-gapped environment (USB stick / disconnected transfer), then loaded and pushed into the local registry.

## 5. Preparing offline artifacts on a connected machine

### 5.1 Container images

All images must be mirrored into the local registry. On the staging host, use `skopeo` (or `docker/podman save` + `load` if no direct registry connection exists).

```sh
# On the connected machine: copy each image into the air-gapped registry.
# Replace <VERSION> with the exact tag you use (keep them in lockstep with the chart versions).
skopeo copy --dest-tls-verify=false docker://docker.io/library/nextcloud:29.0 \
  docker://registry.local:5000/nextcloud:29.0

skopeo copy --dest-tls-verify=false docker://docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r2 \
  docker://registry.local:5000/bitnamilegacy/postgresql:17.6.0-debian-12-r2
skopeo copy --dest-tls-verify=false docker://docker.io/bitnamilegacy/redis:8.2.1-debian-12-r0 \
  docker://registry.local:5000/bitnamilegacy/redis:8.2.1-debian-12-r0
skopeo copy --dest-tls-verify=false docker://docker.io/bitnamilegacy/rabbitmq:4.1.3-debian-12-r1 \
  docker://registry.local:5000/bitnamilegacy/rabbitmq:4.1.3-debian-12-r1

skopeo copy --dest-tls-verify=false docker://ghcr.io/euro-office/cluster-docs:9.3.1-1 \
  docker://registry.local:5000/euro-office/cluster-docs:9.3.1-1
skopeo copy --dest-tls-verify=false docker://ghcr.io/euro-office/cluster-utils:9.3.1-1 \
  docker://registry.local:5000/euro-office/cluster-utils:9.3.1-1

# ingress controller + NFS provisioner (tags depend on the chart versions you stage, see 5.2)
skopeo copy --dest-tls-verify=false docker://registry.k8s.io/ingress-nginx/controller:v1.12.0 \
  docker://registry.local:5000/ingress-nginx/controller:v1.12.0
skopeo copy --dest-tls-verify=false docker://quay.io/kubernetes_incubator/nfs-provisioner:v2.2.2-k8s1.12 \
  docker://registry.local:5000/kubernetes_incubator/nfs-provisioner:v2.2.2-k8s1.12
```

> [!NOTE]
> If the staging host **cannot** reach the cluster's registry directly (true air gap), do: `skopeo copy docker://... docker-archive:image.tar` on the connected host, carry the tar, then `skopeo copy docker-archive:image.tar docker://registry.local:5000/...` on a host inside the air-gapped network. Also verify the exact image tags a chart wants with `helm show values ./chart.tgz | grep -A3 image` (see next section) so the mirrored tags match.

The **custom Nextcloud image** (with the Euro-Office app baked in) is built and mirrored separately - section [5.4](#54-the-custom-nextcloud-image-with-the-euro-office-app).

### 5.2 Helm charts

Package every chart on the connected machine and transfer the `.tgz` files. Do **not** run `helm repo add` on the air-gapped cluster.

```sh
# 1. add the repos on the CONNECTED machine
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add nfs-server-provisioner https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo add euro-office https://download.euro-office.com/charts/stable
helm repo update

# 2. pull each chart as a self-contained .tgz (pin versions for reproducibility)
helm pull bitnami/rabbitmq --version 16.0.14
helm pull bitnami/redis --version 22.0.7
helm pull bitnami/postgresql --version 16.7.27
helm pull ingress-nginx/ingress-nginx
helm pull nfs-server-provisioner/nfs-server-provisioner
helm pull euro-office/docs
helm pull nextcloud/nextcloud

# 3. the nextcloud chart ships Bitnami sub-charts (postgresql/redis/mariadb).
#    Even though we disable them at install time, the packaged tgz must contain them.
helm pull nextcloud/nextcloud --untar
cd nextcloud
helm dependency update   # downloads the sub-charts into ./charts/
helm package . -d ../offline-charts
cd ..
```

Copy the `offline-charts/*.tgz` directory onto the air-gapped admin workstation. From now on, **all `helm install` commands in this document use `./offline-charts/<chart>.tgz`** instead of `repo/chart`.

> If you want to serve them from a mini chart-repository on the cluster network, a single static HTTP server over the directory is enough (`helm install` accepts `https://charts.local/...`), but the `.tgz` form below works everywhere.

### 5.3 SQL scripts for the Euro-Office install/upgrade/delete jobs

The Euro-Office chart runs a `Job` during `install`, `upgrade`, `rollback` and `delete` that **downloads the database schema scripts from the internet**. In an air-gapped cluster this is impossible, so the chart provides `privateCluster=true` and expects two ConfigMaps with the SQL scripts instead.

On the connected machine, fetch the two PostgreSQL scripts (this matches the `postgres` DB type used below; substitute `mysql` for MySQL):

```sh
wget -O removetbl.sql https://raw.githubusercontent.com/Euro-Office/server/master/schema/postgresql/removetbl.sql
wget -O createdb.sql https://raw.githubusercontent.com/Euro-Office/server/master/schema/postgresql/createdb.sql
```

Carry both files into the cluster (they become `ConfigMap`s in section [9.3](#93-install--uninstall--upgrade-in-a-private-cluster)).

### 5.4 The custom Nextcloud image with the Euro-Office app

Under Podman the `eurooffice` app was installed **at runtime** (`git clone` + `npm run build` + `composer install`, see [final-install.md](./final-install.md) steps 12-13). On Kubernetes that is not acceptable: packages added inside a running pod are **lost on every pod recreation**. The app must be **baked into the image**.

Build it on the connected machine, then push to the local registry:

```dockerfile
# Dockerfile.nextcloud-eurooffice
FROM node:20 AS eurooffice-build
WORKDIR /build
RUN git clone --recursive https://github.com/Euro-Office/eurooffice-nextcloud.git eurooffice
WORKDIR /build/eurooffice
RUN npm install && npm run build

FROM docker.io/library/nextcloud:29.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends git composer unzip \
 && rm -rf /var/lib/apt/lists/*
COPY --from=eurooffice-build /build/eurooffice /usr/src/nextcloud/apps/eurooffice
WORKDIR /usr/src/nextcloud/apps/eurooffice
RUN composer install --no-dev --no-interaction \
 && chown -R www-data:www-data /usr/src/nextcloud/apps/eurooffice
```

```sh
docker build -f Dockerfile.nextcloud-eurooffice -t registry.local:5000/nextcloud-eurooffice:29.0 .
docker push registry.local:5000/nextcloud-eurooffice:29.0
# or, if no direct registry access from the staging host:
#   docker save registry.local:5000/nextcloud-eurooffice:29.0 | gzip > nextcloud-eurooffice.tar.gz
#   (load it on a host inside the air-gapped network and docker/podman push it)
```

> [!NOTE]
> - The official `nextcloud` image (Debian-based, apache flavor) already ships the PHP extensions the Euro-Office app needs (intl, zip, gd, xml, mbstring, curl, ...). If the app reports a missing extension at runtime, add the corresponding `docker-php-ext-install`/apt package in the `FROM` stage.
> - `composer install` needs internet **during the build** (which runs on the connected host), so the air-gapped cluster itself never touches the network.
> - On the first boot the Nextcloud entrypoint copies `/usr/src/nextcloud` (including `apps/eurooffice`) into the persistent volume; the app therefore survives pod recreation. The chart also places `custom_apps` on its own volume subpath (see [10](#10-nextcloud-helm)).

## 6. Base cluster setup (done once)

These steps are identical for an online cluster but must be run from the **packaged charts** offline.

### 6.1 Ingress controller

```sh
helm install ingress-nginx ./offline-charts/ingress-nginx.tgz \
  --namespace ingress-nginx --create-namespace \
  --set controller.image.registry=registry.local:5000 \
  --set controller.image.image=ingress-nginx/controller \
  --set controller.image.tag=v1.12.0 \
  --set controller.publishService.enabled=true \
  --set controller.replicaCount=2
```

> Set the `controller.image.*` values to your locally mirrored image and tag. Find the ingress address afterwards:
> ```sh
> kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide   # LoadBalancer / node IP
> ```
> On bare metal use `--set controller.service.type=NodePort` (or MetalLB if available) and use one node IP as the ingress address.

### 6.2 RWX storage (NFS server provisioner)

The Euro-Office docserver PVCs require `ReadWriteMany` storage (2 docservice + 2 converter pods share them). The upstream docs install the NFS Server Provisioner, which creates a storage class named `nfs`:

```sh
helm install nfs-server ./offline-charts/nfs-server-provisioner.tgz \
  --set image.repository=registry.local:5000/kubernetes_incubator/nfs-provisioner \
  --set image.tag=v2.2.2-k8s1.12 \
  --set persistence.enabled=true \
  --set persistence.storageClass=<existing-RWO-storage-class> \
  --set persistence.size=200Gi \
  --set storageClass.defaultClass=true
```

Afterwards `kubectl get storageclass` must list an `nfs` class (default). If your cluster already provides an RWX class (e.g. CephFS, Longhorn RWX), you can skip this and set `storageClass` accordingly in the chart values below.

### 6.3 DNS / name resolution for the local domains

Two things must resolve the local domains to the ingress address:

1. **On every client browser** (the equivalent of the `/etc/hosts` entry in the Podman setup):
   ```sh
   # /etc/hosts on every client and on the cluster admin workstation
   192.168.0.114   nextcloud.local office.local
   ```

2. **Inside the cluster pods** (the document server's converter/docservice background services must reach Nextcloud at `https://nextcloud.local` to save documents). This is the Kubernetes equivalent of the Podman `hostAliases`/Caddy-DNS problem. The cleanest air-gapped solution is a `hosts` block in the **CoreDNS** Corefile:

   ```sh
   kubectl -n kube-system get configmap coredns -o yaml > coredns-cm.yaml
   # edit the Corefile so it contains:
   #   hosts {
   #       192.168.0.114 nextcloud.local office.local
   #       fallthrough
   #   }
   kubectl apply -f coredns-cm.yaml
   kubectl -n kube-system rollout restart deployment/coredns
   ```

   > If you cannot or do not want to edit CoreDNS, the Euro-Office chart supports per-pod entries instead (`docservice.hostAliases` / `converter.hostAliases`, used in [section 9.2](#92-values-euroofficeyaml)). The Nextcloud chart has no `hostAliases` option, so for Nextcloud's own outbound calls to `office.local`/`nextcloud.local` the CoreDNS route (or `nextcloud.extraEnv` pointing at the ingress) is the supported path.

### 6.4 TLS certificates and registry pull secret

**Self-signed TLS** (the exact counterpart of the Caddy `tls { issuer internal }` fix from [local-nextcloud-fixes.md](./local-nextcloud-fixes.md)). Generate one certificate valid for both hostnames and create the two secrets the ingresses below use:

```sh
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=nextcloud.local" \
  -addext "subjectAltName=DNS:nextcloud.local,DNS:*.nextcloud.local,DNS:office.local,DNS:*.office.local"

kubectl -n nextcloud create secret tls nextcloud-tls --key tls.key --cert tls.crt
kubectl -n nextcloud create secret tls office-tls    --key tls.key --cert tls.crt
```

> Every browser will show the usual "connection not private" warning - exactly as under Podman. For a trusted internal CA install **cert-manager** (offline: `helm pull jetstack/cert-manager` + stage its images) with a `ClusterIssuer` of type `SelfSigned` or an internal CA and remove the static secrets. Do **not** use Let's Encrypt for `.local` domains - it can never issue certificates for them (this is the Podman `SSL_ERROR_INTERNAL_ERROR_ALERT` problem).

**Registry pull secret** so the cluster can pull from `registry.local:5000` (adjust credentials/host):

```sh
kubectl -n nextcloud create secret docker-registry regcred \
  --docker-server=registry.local:5000 \
  --docker-username=<user> --docker-password=<pass>
```

## 7. Namespace and secrets

```sh
kubectl create namespace nextcloud
```

Shared secrets (values match [final-install.md](./final-install.md) and [kubernetes.md](./kubernetes.md) so the records stay comparable):

```sh
kubectl -n nextcloud create secret generic nextcloud-secrets \
  --from-literal=NEXTCLOUD_DB_PASS=nextcloud-secret \
  --from-literal=NEXTCLOUD_ADMIN_PASS=nextcloud-admin-pw \
  --from-literal=EUROOFFICE_JWT_SECRET=euro-office-jwt-secret-at-least-32-chars \
  --from-literal=REDIS_PASSWORD=nextcloud-redis-secret \
  --from-literal=DB_ROOT_PASSWORD=eurooffice-db-pass
```

> Generate strong random values (`openssl rand -base64 32`) in a real deployment; the JWT secret must be **at least 32 characters** (HS256).

## 8. Stateful dependencies: RabbitMQ, Redis, PostgreSQL

Install the three Bitnami charts from the packaged tarballs. All images point at the local mirror. Values are given as `--set` for brevity; for a repeatable setup put them in `values-deps.yaml`.

**RabbitMQ** (Euro-Office message queue):

```sh
helm install rabbitmq ./offline-charts/rabbitmq.tgz \
  --set auth.username=user \
  --set auth.password=eurooffice-rabbit-pass \
  --set image.repository=registry.local:5000/bitnamilegacy/rabbitmq \
  --set image.tag=4.1.3-debian-12-r1 \
  --set global.security.allowInsecureImages=true \
  --set persistence.storageClass=nfs \
  --set resourcesPreset=none \
  --set metrics.enabled=false
```

**Redis** (shared by Nextcloud and Euro-Office):

```sh
helm install redis ./offline-charts/redis.tgz \
  --set architecture=standalone \
  --set auth.enabled=true \
  --set auth.password=eurooffice-redis-pass \
  --set image.repository=registry.local:5000/bitnamilegacy/redis \
  --set image.tag=8.2.1-debian-12-r0 \
  --set global.security.allowInsecureImages=true \
  --set master.persistence.storageClass=nfs \
  --set master.resourcesPreset=none \
  --set metrics.enabled=false
```

> The Bitnami Redis chart exposes its master at the service name **`redis-master`** - this is the host the Euro-Office chart and Nextcloud both use.

**PostgreSQL** (shared). The Euro-Office chart connects as the `postgres` superuser to a database `euro-office`; Nextcloud gets its own database/user `nextcloud`. Both are created on first initialisation with an init script:

```sh
cat > postgres-init.sql <<'EOF'
CREATE USER nextcloud WITH PASSWORD 'nextcloud-secret';
CREATE DATABASE nextcloud OWNER nextcloud;
CREATE DATABASE "euro-office" OWNER postgres;
EOF
kubectl -n nextcloud create configmap postgres-init --from-file=init.sql=postgres-init.sql
```

```sh
helm install postgresql ./offline-charts/postgresql.tgz \
  --set auth.postgresPassword=eurooffice-db-pass \
  --set auth.database=postgres \
  --set image.repository=registry.local:5000/bitnamilegacy/postgresql \
  --set image.tag=17.6.0-debian-12-r2 \
  --set global.security.allowInsecureImages=true \
  --set primary.persistence.storageClass=nfs \
  --set primary.persistence.size=50Gi \
  --set primary.resourcesPreset=none \
  --set initdbScriptsConfigMap=postgres-init \
  --set metrics.enabled=false
```

> The upstream Euro-Office README configures `auth.database=postgres` and the chart defaults to the `postgres` user - keep that. If you use a separate PostgreSQL instance, just set `connections.*` in [9.2](#92-values-euroofficeyaml) accordingly.

Verify everything is ready before continuing:

```sh
kubectl -n nextcloud get pods
kubectl -n nextcloud get svc   # expect: postgresql, redis-master, rabbitmq
```

## 9. Euro-Office Docs (Helm)

### 9.1 `local.json` ConfigMap (the document-saving fix)

This is the Kubernetes translation of the Podman **document-saving fix** from [nextcloud-euro-office-integration.md](./nextcloud-euro-office-integration.md). Under Podman, two environment variables were patched into `containers.json`:

| Podman env var | local.json effect | Helm equivalent |
| --- | --- | --- |
| `USE_UNAUTHORIZED_STORAGE=true` | `.services.CoAuthoring.requestDefaults.rejectUnauthorized = false` (accept the self-signed cert on callbacks) | `extraConf.configMap` → `local.json` |
| `ALLOW_PRIVATE_IP_ADDRESS=true` | `.services.CoAuthoring["request-filtering-agent"].allowPrivateIPAddress = true` (private IP as callback target) | `extraConf.configMap` → `local.json` (+ `requestFilteringAgent.allowPrivateIPAddress`) |

In Kubernetes these are **plain values** - they survive every pod recreation automatically, so the "re-run the fix script after a mastercontainer recreate" step of the Podman install disappears entirely.

```json
{
  "services": {
    "CoAuthoring": {
      "requestDefaults": {
        "rejectUnauthorized": false
      },
      "request-filtering-agent": {
        "allowPrivateIPAddress": true,
        "allowMetaIPAddress": true
      }
    }
  }
}
```

```sh
kubectl -n nextcloud create configmap local-config --from-file=local.json
```

> [!IMPORTANT]
> **Security note:** disabling `rejectUnauthorized` is acceptable only because this is an air-gapped setup with a self-signed certificate (same trade-off as the Podman install). If the instance is ever exposed on a public domain with a real certificate, remove this ConfigMap again (set `extraConf.configMap` to empty) and delete the `request-filtering-agent` overrides so TLS verification stays enabled.

### 9.2 `values-eurooffice.yaml`

```yaml
# values-eurooffice.yaml - Euro-Office Docs on the air-gapped cluster
imagePullSecrets:
  - name: regcred

images:
  tag: 9.3.1-1

# shared JWT between Nextcloud and the document server
jwt:
  enabled: true
  secret: "euro-office-jwt-secret-at-least-32-chars"
  header: "Authorization"

# --- connections (state stores deployed in section 8) ----------------------
connections:
  dbType: postgres
  dbHost: postgresql
  dbPort: "5432"
  dbName: euro-office
  dbUser: postgres
  dbPassword: eurooffice-db-pass

  redisHost: redis-master
  redisPort: "6379"
  redisPassword: eurooffice-redis-pass

  amqpHost: rabbitmq
  amqpPort: "5672"
  amqpUser: user
  amqpPassword: eurooffice-rabbit-pass

# --- storage ----------------------------------------------------------------
persistence:
  storageClass: nfs
  size: 8Gi

# --- document-saving fix (see 9.1) ------------------------------------------
extraConf:
  configMap: local-config
  filename: local.json
requestFilteringAgent:
  allowPrivateIPAddress: true
  allowMetaIPAddress: true

# --- air-gapped: no internet for install/upgrade/delete jobs ----------------
privateCluster: true

# --- resolve nextcloud.local inside the docserver pods ----------------------
# Only needed if you did NOT add the hosts block to CoreDNS (section 6.3).
docservice:
  replicas: 2
  # hostAliases:
  #   - ip: "192.168.0.114"        # ingress controller address
  #     hostnames: ["nextcloud.local"]
converter:
  # hostAliases:
  #   - ip: "192.168.0.114"
  #     hostnames: ["nextcloud.local"]

# --- ingress ----------------------------------------------------------------
ingress:
  enabled: true
  ingressClassName: nginx
  host: office.local
  path: /
  pathType: ImplementationSpecific
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  ssl:
    enabled: true
    secret: office-tls

# --- optional: admin panel (the Podman test-admin.md record used it) --------
# adminpanel:
#   enabled: true
```

> [!NOTE]
> - **Images:** the chart pulls `ghcr.io/euro-office/cluster-docs:9.3.1-1` for docservice/converter/proxy and `ghcr.io/euro-office/cluster-utils:9.3.1-1` for the hooks. If your registry is not set up to pull from `ghcr.io` (air gap), override the repositories with `--set docservice.image.repository=registry.local:5000/euro-office/cluster-docs` (and the same for `converter.image.repository`, `proxy.image.repository`, `adminpanel.image.repository`, `example.image.repository`, and the job images under `install.job.image.repository`, `upgrade.job.image.repository`, `clearCache.image.repository`, ...) - or better, run `helm show values ./offline-charts/docs.tgz | grep -B2 repository` to enumerate every image reference and mirror/override all of them. Keep `images.tag` in sync with the mirrored tag.
> - **Commercial license:** if you have a license file, `kubectl -n nextcloud create secret generic euro-office-license --from-file=license.lic` and add `--set license.existingSecret=euro-office-license` (or `license.existingSecret` in the values file). Without one the chart creates an empty license secret and runs in trial mode.
> - **DB schema:** the install job creates the `euro-office` schema in PostgreSQL using `createdb.sql`. In a *connected* cluster the chart downloads it; in our air-gapped setup it comes from the ConfigMaps prepared in [5.3](#53-sql-scripts-for-the-euro-office-installupgradedelete-jobs).

### 9.3 Install / uninstall / upgrade in a private cluster

Create the SQL-script ConfigMaps first (from the files fetched in [5.3](#53-sql-scripts-for-the-euro-office-installupgradedelete-jobs)):

```sh
kubectl -n nextcloud create configmap init-db-scripts   --from-file=createdb.sql
kubectl -n nextcloud create configmap remove-db-scripts --from-file=removetbl.sql
```

Install (run from the directory holding `values-eurooffice.yaml`):

```sh
helm install documentserver ./offline-charts/docs.tgz \
  --namespace nextcloud \
  -f values-eurooffice.yaml \
  --timeout 20m
```

Watch it come up:

```sh
kubectl -n nextcloud get pods -w     # docservice-* and converter-* deployments (the proxy runs inside the docservice pod)
kubectl -n nextcloud get svc,ingress
curl -sk -o /dev/null -w '%{http_code}\n' https://office.local/healthcheck   # expect 200 / "true"
```

Uninstall (the delete hook also needs the `remove-db-scripts` ConfigMap and `privateCluster`):

```sh
helm uninstall documentserver -f values-eurooffice.yaml --timeout 20m
# or, to skip the cleanup job entirely:
helm uninstall documentserver --no-hooks
```

Upgrade (any upgrade that changes the version runs the pre-upgrade hook - it needs the same ConfigMaps; both are passed via the values file):

```sh
helm upgrade documentserver -f values-eurooffice.yaml ./offline-charts/docs.tgz \
  --set images.tag=<new-version> --timeout 20m
```

> If your cluster has a Web proxy the pods can use, an alternative to the ConfigMaps is `webProxy.enabled=true` with `webProxy.http` / `webProxy.https` / `webProxy.noProxy` - the hooks then download the scripts through the proxy and `privateCluster` stays `false`.

## 10. Nextcloud (Helm)

### 10.1 `values-nextcloud.yaml`

```yaml
# values-nextcloud.yaml - Nextcloud on the air-gapped cluster
image:
  repository: registry.local:5000/nextcloud-eurooffice   # custom image, see 5.4
  tag: "29.0"
  pullPolicy: IfNotPresent
  pullSecrets:
    - name: regcred

replicaCount: 1

nextcloud:
  host: nextcloud.local
  username: admin
  password: nextcloud-admin-pw
  trustedDomains:
    - nextcloud.local
    - office.local
    - 192.168.0.114
  defaultApps:
    - eurooffice
  # - air-gapped: never contact the Nextcloud App Store
  # - allow the document server to reach the private IP (part of the saving fix)
  configs:
    offline.config.php: |-
      <?php
      $CONFIG = array (
        'appstoreenabled' => false,
        'allow_local_remote_servers' => true,
      );
    proxy.config.php: |-
      <?php
      $CONFIG = array (
        'trusted_proxies' => array(
          0 => '10.0.0.0/8',
          1 => '192.168.0.0/16',
        ),
      );
  phpConfigs:
    zz-memory_limit.ini: |-
      memory_limit=512M

# --- database: use the shared PostgreSQL, not SQLite -------------------------
internalDatabase:
  enabled: false
externalDatabase:
  enabled: true
  type: postgresql
  host: postgresql:5432
  database: nextcloud
  user: nextcloud
  password: nextcloud-secret

# --- cache: use the shared Redis ---------------------------------------------
externalRedis:
  enabled: true
  host: redis-master
  port: "6379"
  password: nextcloud-redis-secret

# disable the chart's bundled Bitnami sub-charts (we run our own)
redis:
  enabled: false
postgresql:
  enabled: false
mariadb:
  enabled: false

# --- persistence --------------------------------------------------------------
persistence:
  enabled: true
  storageClass: nfs
  size: 100Gi
  nextcloudData:
    enabled: true
    storageClass: nfs
    size: 100Gi

# --- ingress ------------------------------------------------------------------
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "10g"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
  tls:
    - hosts:
        - nextcloud.local
      secretName: nextcloud-tls

# fix from the Podman record: force https in generated URLs behind the proxy
phpClientHttpsFix:
  enabled: true
```

> [!NOTE]
> - **`trusted_domains` / `overwriteprotocol`:** these are the Kubernetes equivalent of the `occ config:system:set` calls recorded in [final-install.md](./final-install.md) steps 14. `nextcloud.host` + `trustedDomains` configure `trusted_domains`, and `phpClientHttpsFix` sets `overwriteprotocol=https` (the Podman install used `overwritehost=host.docker.internal` / `overwriteprotocol=http`; behind the ingress we use the real hostname and https).
> - The chart's config files (written into `/var/www/html/config/*.config.php`) persist in the `config` subpath of the Nextcloud PVC, so they survive restarts without `occ`.
> - The Nextcloud image first-boot entrypoint copies the baked-in `apps/eurooffice` into the persistent volume, so the app is present after every recreation without any runtime `git clone`.

### 10.2 Install

```sh
helm install nextcloud ./offline-charts/nextcloud.tgz \
  --namespace nextcloud \
  -f values-nextcloud.yaml \
  --timeout 20m

kubectl -n nextcloud get pods -w     # nextcloud-*
kubectl -n nextcloud get svc,ingress
curl -sk -o /dev/null -w '%{http_code}\n' https://nextcloud.local/login    # expect 200
```

### 10.3 Post-install occ configuration

Verify Redis is wired as cache and locking backend (the Kubernetes equivalent of the AIO `nextcloud-aio-redis` config from [kubernetes.md](./kubernetes.md) section 7):

```sh
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set redis host --value=redis-master"
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set redis port --value=6379"
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set redis password --value=nextcloud-redis-secret"
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set memcache.local --value='\OC\Memcache\Redis'"
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'"
kubectl -n nextcloud exec deploy/nextcloud -- su -s /bin/sh www-data -c "php occ config:system:set memcache.locking --value='\OC\Memcache\Redis'"
```

## 11. Connecting Nextcloud to Euro-Office

Configure the `eurooffice` app. The values file already ships the app in the image and `defaultApps: [eurooffice]`; now point it at the document server with the shared JWT.

**Via occ** (equivalent of [kubernetes-proposal.md](./kubernetes-proposal.md) Step 3 Method A and [final-install.md](./final-install.md) step 13):

```sh
POD=$(kubectl -n nextcloud get pod -l app.kubernetes.io/name=nextcloud -o jsonpath='{.items[0].metadata.name}')
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c "php occ app:enable eurooffice"

kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ config:app:set eurooffice DocumentServerUrl --value='https://office.local/'"
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ config:app:set eurooffice jwt_secret --value='euro-office-jwt-secret-at-least-32-chars'"
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ config:app:set eurooffice sameTab --value=false"
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ config:app:set eurooffice enableSharing --value=true"
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ config:app:set eurooffice preview --value=true"
```

**Declarative alternative** (applies on every deploy; add to `nextcloud.configs` in `values-nextcloud.yaml`):

```php
// eurooffice.config.php
<?php
$CONFIG = array (
  'eurooffice' => array (
    'DocumentServerUrl' => 'https://office.local/',
    'jwt_secret' => 'euro-office-jwt-secret-at-least-32-chars',
    'sameTab' => false,
    'enableSharing' => true,
    'preview' => true,
  ),
);
```

> The `jwt_secret` must match the `jwt.secret` of the document server ([9.2](#92-values-euroofficeyaml)) and the `JWT_SECRET` from [section 7](#7-namespace-and-secrets).

**Via the web UI** (same as the proposal's Method B): Administration settings → **Euro-Office** → Document Server Address `https://office.local/` + Secret key.

## 12. Verification

```sh
# 1. all workloads ready
kubectl -n nextcloud get pods,svc,ingress,pvc

# 2. document server healthcheck
curl -sk https://office.local/healthcheck            # expect "true"
kubectl -n nextcloud logs deploy/docservice | tail

# 3. Nextcloud reachable through the ingress
curl -sk -o /dev/null -w '%{http_code}\n' https://nextcloud.local/login   # expect 200

# 4. Euro-Office connection check (mirrors final-install.md verification)
kubectl -n nextcloud exec "$POD" -- su -s /bin/sh www-data -c \
  "php occ eurooffice:documentserver --check"
#   expect: Document server https://office.local/ ... is successfully connected

# 5. final check: open a document in Euro-Office from Nextcloud AND SAVE it
```

If step 5 fails with "The document cannot be saved", go to [section 16](#16-troubleshooting) - it is the Podman saving fix all over again, now controlled by `local.json` (section 9.1) and name resolution (section 6.3).

## 13. How the Podman fixes translate to Kubernetes

| # | Podman problem | Podman fix | Kubernetes / Helm equivalent |
| --- | --- | --- | --- |
| 1 | Non-root containers cannot bind host port 443 (`CAP_NET_BIND_SERVICE`) | Patch `containers.json` | **Not needed.** ingress-nginx owns ports 80/443; workloads bind only container ports. |
| 2 | Caddy cannot get a Let's Encrypt cert for `.local` (`SSL_ERROR_INTERNAL_ERROR_ALERT`) | Caddy `tls { issuer internal }` | **Ingress + self-signed TLS secret** (or cert-manager internal CA), section [6.4](#64-tls-certificates-and-registry-pull-secret). |
| 3 | Stale php-fpm `listen.allowed_clients` after apache recreation (HTTP 503) | `podman restart nextcloud-aio-nextcloud` | **Not applicable.** nginx and PHP run in the same pod. |
| 4 | Euro-Office cannot save: `UNABLE_TO_GET_ISSUER_CERT_LOCALLY` on the callback to self-signed `https://nextcloud.local` | `USE_UNAUTHORIZED_STORAGE=true` + `ALLOW_PRIVATE_IP_ADDRESS=true` in `containers.json`/`local.json` | **`local.json` ConfigMap** (`extraConf`) + `requestFilteringAgent` values, section [9.1](#91-localjson-configmap-the-document-saving-fix). Survives every recreate. |
| 5 | Docker API version mismatch (`v1.44` vs `v1.41`) | `DOCKER_API_VERSION=1.41` | **Not applicable.** No Docker-compatible API; the cluster API is the orchestrator. |
| 6 | Podman socket permissions (`0600` vs `0660`) | `systemctl --user restart podman.socket` | **Not applicable.** No container engine socket in the cluster. |
| 7 | `containers.json` patches lost on mastercontainer recreate | Re-run `nextcloud-aio-podman-fix.sh` / systemd unit | **Not applicable.** Helm values are the source of truth; nothing is patched at runtime. |
| 8 | Euro-Office app installed at runtime (`git clone`+npm+composer), lost on recreate | Re-clone + rebuild | **Custom image** with the app baked in, section [5.4](#54-the-custom-nextcloud-image-with-the-euro-office-app). |
| 9 | *(new, air-gapped)* Helm/images/SQL scripts require internet | - | Offline staging: sections [5.1](#51-container-images)-[5.3](#53-sql-scripts-for-the-euro-office-installupgradedelete-jobs); `privateCluster=true`; App Store disabled. |

## 14. Management, backups and upgrades (offline)

```sh
# status / logs
kubectl -n nextcloud get all
kubectl -n nextcloud logs deploy/nextcloud
kubectl -n nextcloud logs deploy/docservice deploy/converter

# restart a workload
kubectl -n nextcloud rollout restart deploy/nextcloud
kubectl -n nextcloud rollout status deploy/nextcloud

# update an image / values, then re-apply
helm upgrade nextcloud -f values-nextcloud.yaml ./offline-charts/nextcloud.tgz --timeout 20m
```

**Backups** (all offline): the data lives in the PVCs (`nextcloud` nextcloud-config/data, `ds-files`, `ds-runtime-config`, `postgresql-data`, `rabbitmq`, `redis`). Back up the **PostgreSQL dump**, the **`nextcloud` PVCs** and the **secrets** (the JWT secret must stay identical across restores or the document server rejects callbacks). Under Podman the AIO Borg backup did not work; on Kubernetes use `kubectl` + `velero`/`k8up` (both offline-installable) or a plain `pg_dump`/`tar` cron.

**Upgrading the Euro-Office chart offline:** bump `images.tag`, stage the new `cluster-docs`/`cluster-utils` images into the local registry, and re-run `helm upgrade ... --set images.tag=<new>` with the `remove-db-scripts`/`init-db-scripts` ConfigMaps still present (the pre-upgrade hook needs them - see [9.3](#93-install--uninstall--upgrade-in-a-private-cluster)). Nextcloud upgrades go **one major version at a time** (image tag in [5.4](#54-the-custom-nextcloud-image-with-the-euro-office-app) + values), exactly as the chart README warns.

## 15. Estimated time and risk

| Activity | Estimated time |
| --- | --- |
| Offline staging (images, charts, SQL scripts, custom image) on a connected host | 2 - 4 hours |
| Base cluster setup: ingress, storage, DNS, TLS (sections 6-7) | 0.5 - 2 hours |
| Dependencies: RabbitMQ, Redis, PostgreSQL (section 8) | 0.5 - 1 hour |
| Euro-Office Docs chart + private-cluster hooks (section 9) | 1 - 2 hours |
| Nextcloud chart + integration + saving fix verification (sections 10-12) | 1 - 3 hours |
| **Total for an experienced admin on an existing cluster** | **about 6 - 12 hours** |

> [!WARNING]
> These figures are **estimates produced by artificial intelligence** and are **not** based on a real Kubernetes validation. Air-gapped deployments add real risk: image-tag mismatches between the local registry and the chart values, the Euro-Office `privateCluster` hook ConfigMaps, RWX storage behaviour, Nextcloud app compatibility, and the document-saving integration are all places where substantial rework is likely. Budget accordingly.

## 16. Troubleshooting

- **Pods stay `ImagePullBackOff`**: the image tag in `values*.yaml` / `--set` does not exist in `registry.local:5000`. List what is mirrored (`curl http://registry.local:5000/v2/_catalog`), align every `image.repository`/`image.tag`/`images.tag` to it (see the note in [9.2](#92-values-euroofficeyaml)).
- **Euro-Office install hangs or fails on the hooks**: the install/upgrade/delete `Job` cannot reach the internet. Verify `privateCluster=true` is set and the `init-db-scripts` / `remove-db-scripts` ConfigMaps exist (`kubectl -n nextcloud get cm init-db-scripts remove-db-scripts`). Check the job pod: `kubectl -n nextcloud get jobs; kubectl -n nextcloud logs job/<hook-job>`.
- **Ingress returns 502/503**: check `kubectl -n nextcloud get endpoints` - the Services must select the pods. The Euro-Office chart exposes its proxy on service port `8888`; the Nextcloud chart on port `80` (TLS terminates at the ingress).
- **Browser shows "connection not private"**: expected - the certificates are self-signed. Install cert-manager with an internal CA if this must disappear.
- **"The document cannot be saved"** (the classic saving fix): the docserver's converter/docservice cannot call back to `https://nextcloud.local`. Check, in order:
  1. `kubectl -n nextcloud get cm local-config` exists and is referenced (`extraConf.configMap: local-config`) - the values in [9.1](#91-localjson-configmap-the-document-saving-fix).
  2. `nextcloud.local` resolves inside the pods: `kubectl -n nextcloud exec deploy/docservice -- getent hosts nextcloud.local` (CoreDNS hosts block, section [6.3](#63-dns--name-resolution-for-the-local-domains)) or the `docservice.hostAliases`/`converter.hostAliases` in [9.2](#92-values-euroofficeyaml).
  3. `allow_local_remote_servers` and the app's `DocumentServerUrl`/`jwt_secret` match (sections [10.1](#101-values-nextcloudyaml), [11](#11-connecting-nextcloud-to-euro-office)).
  4. The converter log (same paths as under Podman): `kubectl -n nextcloud exec deploy/converter -- cat /var/log/euro-office/documentserver/converter/out.log` - expect to see `UNABLE_TO_GET_ISSUER_CERT_LOCALLY` gone after the fix.
- **Nextcloud returns 400 / "not trusted domain"**: complete `trusted_domains` and `trusted_proxies` in `values-nextcloud.yaml` (section [10.1](#101-values-nextcloudyaml)) and re-apply.
- **Persistent volumes not writable / `Operation not permitted`**: the Nextcloud image runs as `www-data` (uid 33); the chart sets `fsGroup: 33` for the apache flavor. If you use the `fpm` flavor the nginx container uses `fsGroup: 82` (the chart handles this via `nginx.enabled`). For the Euro-Office PVCs ensure ownership `101:101` (`podSecurityContext.docs.fsGroup` etc., see `helm show values ./offline-charts/docs.tgz | grep -A3 fsGroup`), the upstream requirement for the NFS class.
- **App Store / update errors in the Nextcloud log**: `appstoreenabled => false` (offline.config.php) prevents the image from trying to reach the Nextcloud App Store on boot. Without it the failures are harmless but noisy.
- **Helm `install`/`upgrade` asks for internet**: you used `repo/chart` instead of the packaged `./offline-charts/...tgz`, or the Nextcloud tgz was packaged without its dependencies (`helm dependency update` in [5.2](#52-helm-charts)).

## 17. References

- [nextcloud/helm - charts/nextcloud](https://github.com/nextcloud/helm/tree/main/charts/nextcloud) - the Nextcloud chart used in section [10](#10-nextcloud-helm)
- [Euro-Office/Kubernetes-Docs](https://github.com/Euro-Office/Kubernetes-Docs) - the Euro-Office Docs chart used in section [9](#9-euro-office-docs-helm) (prerequisites, `privateCluster`, ingress, parameters)
- [kubernetes-proposal.md](./kubernetes-proposal.md) - the original proposal this document turns into a full guide
- [kubernetes.md](./kubernetes.md) - the manifest-based (non-Helm) alternative translation of the Podman install
- [nextcloud-euro-office-integration.md](./nextcloud-euro-office-integration.md) - the document-saving fix (section [9.1](#91-localjson-configmap-the-document-saving-fix))
- [local-nextcloud-fixes.md](./local-nextcloud-fixes.md) - self-signed TLS and Podman port-443 fixes
- [final-install.md](./final-install.md) - the concrete Podman containers and credentials used here as defaults
- [euro-office-github.md](./euro-office-github.md) - upstream install guide for the document server and Nextcloud app
- [ingress-nginx](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), [nfs-server-provisioner](https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner)
- [Bitnami charts](https://github.com/bitnami/charts) - rabbitmq, redis, postgresql used in section [8](#8-stateful-dependencies-rabbitmq-redis-postgresql)
