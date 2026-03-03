---
title: 'Helm'
weight: 730
draft: false
---

# helm on microk8s

sudo microk8s enable helm3
sudo microk8s status

```bash
microk8s is running
high-availability: no
  datastore master nodes: 192.168.0.103:19001
  datastore standby nodes: none
addons:
  enabled:
    dashboard            # (core) The Kubernetes dashboard
    dns                  # (core) CoreDNS
    ha-cluster           # (core) Configure high availability on the current node
    helm                 # (core) Helm - the package manager for Kubernetes
    helm3                # (core) Helm 3 - the package manager for Kubernetes
    hostpath-storage     # (core) Storage class; allocates storage from host directory
    ingress              # (core) Ingress controller for external access
    metallb              # (core) Loadbalancer for your Kubernetes cluster
    metrics-server       # (core) K8s Metrics Server for API access to service metrics
    minio                # (core) MinIO object storage
    rbac                 # (core) Role-Based Access Control for authorisation
    registry             # (core) Private image registry exposed on localhost:32000
    storage              # (core) Alias to hostpath-storage add-on, deprecated
  disabled:
    cert-manager         # (core) Cloud native certificate management
    cis-hardening        # (core) Apply CIS K8s hardening
    community            # (core) The community addons repository
    gpu                  # (core) Alias to nvidia add-on
    host-access          # (core) Allow Pods connecting to Host services smoothly
    kube-ovn             # (core) An advanced network fabric for Kubernetes
    mayastor             # (core) OpenEBS MayaStor
    nvidia               # (core) NVIDIA hardware (GPU and network) support
    observability        # (core) A lightweight observability stack for logs, traces and metrics
    prometheus           # (core) Prometheus operator for monitoring and logging
    rook-ceph            # (core) Distributed Ceph storage using Rook
```

# Create a new Helm chart
helm create my-application

# This creates a standard Helm chart structure with:
# - Chart.yaml
# - values.yaml
# - templates/ directory
# - You can then manually copy and modify your existing Kubernetes manifests

#### NOTE
you can use helmify or kompose to convert your existing Kubernetes manifests to Helm charts.
This proved to be no walk in the park. Manual intervention was required to fix the generated Helm charts.

## testing the Helm chart

helm template ./my-helm –debug

## Create a package

helm package ./my-helm

## create a helm chart repository

```bash
in de webserver directory : eg /var/www/html
create directory charts
cd charts
cp my-helm-0.1.0.tgz .

helm repo index . (this creates the index.yaml file)

URL=http://IP:80/charts
```

## helm repo

```bash
helm repo add laptop http://192.168.0.103:82/charts
helm repo list
helm search repo my-helm
NAME                CHART VERSION   APP VERSION     DESCRIPTION
laptop/my-helm      0.1.0           1.0.0           A Helm chart for deploying the nosql application
```

## helm repo list

```bash
helm repo list

NAME    URL
bitnami https://charts.bitnami.com/bitnami
runix   https://helm.runix.net
laptop  http://192.168.0.103:82/charts
```

#### NOTE
postgres uses persistent volume, and persistent volume claim
this proved difficult to use off the shelve
Talos did not allow installation under /tmp, so the helm chart was modified to use /var/lib/postgres-data (values.yaml pv: hostPath)

## install postgresql

local helm chart for database : my-postgres-chart

> helm search repo laptop
> NAME                            CHART VERSION   APP VERSION     DESCRIPTION
> laptop/my-helm                  0.1.2           1.0.0           A Helm chart for deploying the nosql applicatio…
> laptop/my-postgres-chart        0.1.0           1.16.0          A Helm chart for Kubernetes

> helm install my-postgres laptop/my-postgres-chart

## install pgadmin

problem with pvc!

```bash
helm repo add runix https://helm.runix.net
helm install pgadmin4 runix/pgadmin4
```

create pv: vi pgadmin-pv.yaml

```bash
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pgadmin-pv
spec:
  capacity:
    storage: 1Gi  # Smaller than PostgreSQL, adjust as needed
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: "/var/lib/pgadmin-data"  # Different from /var/lib/postgres-data
```

```bash
kubectl apply -f pgadmin-pv.yaml
helm uninstall pgadmin4
helm install pgadmin4 runix/pgadmin4\
--set persistence.existingClaim=pgadmin-pvc \
--set persistence.storageClass=manual \
--set tolerations[0].key="node-role.kubernetes.io/control-plane" \
--set tolerations[0].operator="Exists" \
--set tolerations[0].effect="NoSchedule"
```

**PROBLEM PERSIST – CREATE OWN CHART**

helm install pgadmin4 runix/pgadmin4 
: –set persistence.enabled=false –set tolerations[0].key=”node-role.kubernetes.io/control-plane” –set tolerations[0].operator=”Exists” –set tolerations[0].effect=”NoSchedule”

## create pgadmin helm chart

```bash
helm create my-pgadmin-chart
cd my-pgadmin-chart
vi values.yaml ....

dry-run to test :
helm install my-pgadmin . --dry-run --debug
```

```bash
helm package ./my-pgadmin-chart
cp my-pgadmin-chart-0.1.0.tgz /var/www/html/charts/
cd /var/www/html/charts/
helm repo index .
```

on the talos client :

```bash
 helm repo update
 helm repo list
 helm search repo laptop

helm install my-pgadmin laptop/my-pgadmin-chart \
  --set persistence.enabled=true \
  --set persistence.accessMode=ReadWriteOnce \
  --set persistence.size=1Gi \
  --set persistence.storageClass=manual \
  --set pgadmin.securityContext.allowPrivilegeEscalation=false \
  --set pgadmin.securityContext.runAsNonRoot=true \
  --set pgadmin.securityContext.capabilities.drop[0]=ALL \
  --set pgadmin.securityContext.seccompProfile.type=RuntimeDefault
```

## dry run (–debug) to test :

helm install my-pgadmin laptop/my-pgadmin-chart -f pgadmin-values.yaml -n default –dry-run –debug > pgadmin-dry-run.yaml
