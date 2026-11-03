# Installing Prometheus and Grafana

This is the repeatable installation and verification procedure for the cluster
monitoring stack. It records the implementation used in this environment:

| Item | Value |
| --- | --- |
| Argo CD Application | `argocd/monitoring` |
| Helm repository | `https://prometheus-community.github.io/helm-charts` |
| Chart | `kube-prometheus-stack` |
| Chart version | `92.17.0` |
| Prometheus Operator app version | `v0.94.2` |
| Grafana version | `13.3.0` |
| Namespace | `monitoring` |
| Grafana host | `http://grafana.kubernetes.local` |
| Grafana admin Secret | `monitoring/monitoring-grafana-admin` |

The stack installs Prometheus, Alertmanager, Grafana, the Prometheus Operator,
kube-state-metrics and a node-exporter DaemonSet. The Application manifest is
stored in the working tree at
`ansible2/files/gitops/apps/monitoring.yaml` and, after being pushed, in the
Forgejo GitOps repository at `apps/monitoring.yaml`.

The chart values are embedded in the Argo CD Application. The important
non-default settings are:

* Grafana persistence: 2 GiB `local-path` PVC.
* Grafana ingress: Traefik, host `grafana.kubernetes.local`.
* Prometheus: 7-day/6 GB retention, 8 GiB `local-path` PVC.
* Alertmanager: 120-hour retention, 1 GiB `local-path` PVC.
* Prometheus Operator, kube-state-metrics and node-exporter resource limits
  sized for three 2 GiB Talos nodes.
* etcd, controller-manager, scheduler and kube-proxy ServiceMonitors disabled
  because Talos does not expose them as ordinary cluster services.
* `monitoring` namespace labelled `pod-security.kubernetes.io/enforce=privileged`
  for the host-networked node-exporter DaemonSet.
* A Prometheus init container fixes ownership of the `prometheus-db` subPath.
* Grafana uses the `Recreate` deployment strategy to prevent concurrent SQLite
  migrations.

For the operational reference, see [`monitoring.md`](monitoring.md). For the
combined installation log, see
[`installation-steps.md`](installation-steps.md).

---

## 1. Prerequisites

Run these commands on the management container:

```bash
ssh root@192.168.0.192
export KUBECONFIG=/root/.kube/config
```

Confirm the cluster and Argo CD are ready:

```bash
kubectl get nodes
kubectl -n argocd get application root
```

Argo CD's root Application must be using the Forgejo GitOps repository:

```text
http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git
```

with path `apps`, branch `main`, and automated sync enabled.

The cluster needs egress to the public `prometheus-community` Helm repository
and to the container registries used by the chart images. The Argo CD
repo-server must be able to reach `https://prometheus-community.github.io/helm-charts`.

---

## 2. Create the Grafana admin Secret first

Grafana deliberately uses a stable Kubernetes Secret instead of the
chart-generated password. The chart-generated password can change during Helm
re-renders and then no longer match the password hash stored in Grafana's
SQLite database.

Create the namespace and Secret **before** the monitoring Application first
syncs:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl -n monitoring get secret monitoring-grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic monitoring-grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -hex 24)"
fi
```

Do not store the resulting password in this repository. Retrieve it when
needed:

```bash
kubectl -n monitoring get secret monitoring-grafana-admin \
  -o jsonpath='{.data.admin-user}' | base64 -d; echo
kubectl -n monitoring get secret monitoring-grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Create the Secret only once. Re-applying a newly generated password would
rotate the Secret but leave the old password in Grafana's database, causing
authentication failures.

---

## 3. Put the Argo CD Application in the GitOps repository

The complete Application is in:

```text
ansible2/files/gitops/apps/monitoring.yaml
```

It uses the public Helm chart directly:

```yaml
source:
  repoURL: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  targetRevision: 92.17.0
  helm:
    releaseName: monitoring
    values: |
      # Full values are in the Application manifest.
```

Copy that file to the GitOps repository as `apps/monitoring.yaml`, commit it,
and push it:

```bash
cp ansible2/files/gitops/apps/monitoring.yaml /path/to/gitops/apps/monitoring.yaml
cd /path/to/gitops
git add apps/monitoring.yaml
git commit -m "monitoring: add Prometheus and Grafana"
git push
```

On a fresh installation, `ansible2/argocd.yml` can seed the file instead. It
already lists:

```yaml
argocd_gitops_files:
  - path: apps/demo.yaml
  - path: apps/nginx-demo/app.yaml
  - path: apps/monitoring.yaml
```

The root Application watches the `apps` directory and will create the
`monitoring` Application automatically. To trigger an immediate refresh:

```bash
kubectl -n argocd annotate application root \
  argocd.argoproj.io/refresh=hard --overwrite
```

Wait for the Application to appear and sync:

```bash
kubectl -n argocd get application monitoring
kubectl -n argocd get application monitoring \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
```

Expected result:

```text
Synced Healthy
```

If automated sync is disabled, sync it explicitly:

```bash
argocd app sync monitoring
```

If the Application is already present but the embedded values changed, refresh
it:

```bash
kubectl -n argocd annotate application monitoring \
  argocd.argoproj.io/refresh=hard --overwrite
```

Do not edit generated resources directly. Change the values in the GitOps file
and let Argo CD reconcile them.

---

## 4. What the Application creates

The first sync installs the Prometheus Operator CRDs and then the workload
objects. This can take several minutes, especially while images are pulled.

Check the namespace:

```bash
kubectl -n monitoring get pods
kubectl -n monitoring get pvc
kubectl -n monitoring get ingress
kubectl -n monitoring get svc
```

Expected workloads:

| Workload | Expected state |
| --- | --- |
| `prometheus-monitoring-kube-prometheus-prometheus-0` | `Running`, 2/2 |
| `alertmanager-monitoring-kube-prometheus-alertmanager-0` | `Running`, 2/2 |
| `monitoring-grafana-*` | `Running`, 3/3 |
| `monitoring-kube-prometheus-operator-*` | `Running`, 1/1 |
| `monitoring-kube-state-metrics-*` | `Running`, 1/1 |
| `monitoring-prometheus-node-exporter-*` | one `Running` pod per node |

Expected PVCs:

| PVC | Size | Class |
| --- | --- | --- |
| `prometheus-monitoring-kube-prometheus-prometheus-db-...` | 8 GiB | `local-path` |
| `monitoring-grafana` | 2 GiB | `local-path` |
| `alertmanager-monitoring-kube-prometheus-alertmanager-db-...` | 1 GiB | `local-path` |

The Grafana ingress should be:

```text
monitoring-grafana   traefik   grafana.kubernetes.local
```

The namespace must have the privileged Pod Security labels:

```bash
kubectl get namespace monitoring --show-labels
```

They are set by the Application's `managedNamespaceMetadata`. The
node-exporter DaemonSet uses host networking, host PID, host paths and port
`9100`, so it will be rejected without the privileged label.

---

## 5. Add the local hostname and test Grafana

Add the hostname on the machine running the browser:

```bash
sudo sh -c 'echo "192.168.0.192  nginx-demo.kubernetes.local nextcloud.kubernetes.local euro-office.kubernetes.local grafana.kubernetes.local" >> /etc/hosts'
```

Verify name resolution:

```bash
getent hosts grafana.kubernetes.local
```

Without an `/etc/hosts` entry, test with the Host header against the management
container:

```bash
curl -I -H 'Host: grafana.kubernetes.local' http://192.168.0.192/
curl -I -H 'Host: grafana.kubernetes.local' http://192.168.0.192/login
```

Expected: HTTP `200` for `/login`. A `404` means the ingress host or Traefik
routing is wrong; a `502`/`503` means Grafana is not ready.

Open:

```text
http://grafana.kubernetes.local
```

Log in with `admin` and the password from the
`monitoring-grafana-admin` Secret.

Quick API checks:

```bash
PASS=$(kubectl -n monitoring get secret monitoring-grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 -d)

curl -sS -u "admin:$PASS" \
  -H 'Host: grafana.kubernetes.local' \
  http://192.168.0.192/api/user \
  -o /dev/null -w 'grafana auth: %{http_code}\n'
```

Expected: `200`.

Grafana should have two provisioned datasources:

* `Prometheus` → `http://monitoring-kube-prometheus-prometheus.monitoring:9090/`
* `Alertmanager` → `http://monitoring-kube-prometheus-alertmanager.monitoring:9093/`

Built-in Kubernetes dashboards are installed by the chart's dashboard sidecar.
Useful starting dashboards include:

* Kubernetes / Compute Resources / Cluster
* Kubernetes / Compute Resources / Node
* Kubernetes / Compute Resources / Namespace (Pods)
* Kubernetes / Compute Resources / Workload
* Node Exporter / Nodes

---

## 6. Verify Prometheus

Prometheus is not exposed through an ingress. Check its readiness through the
Kubernetes API:

```bash
kubectl -n monitoring get --raw \
  /api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/-/ready
```

Expected:

```text
Prometheus Server is Ready.
```

Check target health:

```bash
kubectl -n monitoring get --raw \
  /api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/targets \
  | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]["activeTargets"]; print("active",len(d),"down",sum(x["health"] != "up" for x in d)); print(sorted({x["labels"].get("job") for x in d}))'
```

At the time of installation the result was:

```text
active 24 down 0
['apiserver', 'coredns', 'kube-state-metrics', 'kubelet', 'monitoring-grafana', 'monitoring-kube-prometheus-alertmanager', 'monitoring-kube-prometheus-operator', 'monitoring-kube-prometheus-prometheus', 'node-exporter']
```

For temporary local access to the Prometheus UI:

```bash
kubectl -n monitoring port-forward \
  svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Then open `http://localhost:9090`. Do not expose this port on the LAN.

---

## 7. Retention, storage and resource footprint

The current values keep monitoring within the small cluster's resources:

| Component | Request | Limit |
| --- | --- | --- |
| Prometheus | 200m CPU / 512Mi | 1 CPU / 1Gi |
| Grafana | 100m CPU / 128Mi | 500m / 512Mi |
| Alertmanager | 50m CPU / 64Mi | 200m / 128Mi |
| Prometheus Operator | 100m CPU / 128Mi | 500m / 256Mi |
| kube-state-metrics | 50m CPU / 64Mi | 200m / 256Mi |
| node-exporter | 20m CPU / 32Mi per node | 100m / 64Mi |

Prometheus keeps up to 7 days or 6 GB of metrics in an 8 GiB volume. If disk
usage is a problem, reduce `retention` or `retentionSize` in the Application.
A `local-path` volume cannot be expanded in place, so increasing its size
requires a new PVC and a data migration or a fresh start.

Grafana and Alertmanager also use node-local `local-path` volumes. This is a
single-node failure domain for monitoring data and is not a high-availability
design.

To change values, edit the embedded `helm.values` block in
`ansible2/files/gitops/apps/monitoring.yaml`, push the change to Forgejo, and
let Argo CD reconcile it.

To change the chart version, update `targetRevision` and review the upstream
chart's upgrade notes before syncing.

---

## 8. Troubleshooting

### Node-exporter pods are rejected by Pod Security

Check the namespace labels:

```bash
kubectl get namespace monitoring --show-labels
```

The Application should set all of:

```text
pod-security.kubernetes.io/enforce=privileged
pod-security.kubernetes.io/audit=privileged
pod-security.kubernetes.io/warn=privileged
```

The labels are managed by the Application's `managedNamespaceMetadata`; do not
remove them.

### Prometheus crashes with `permission denied` under `/prometheus`

`local-path` mounts the Prometheus database below the `prometheus-db` subPath,
which the kubelet creates as root. `fsGroup` does not reliably change that
subPath. The Application includes an `init-chown-data` container:

```yaml
initContainers:
  - name: init-chown-data
    image: docker.io/library/busybox:1.38.0
    command: ["sh", "-c", "chown -R 1000:2000 /prometheus"]
    securityContext:
      runAsUser: 0
      runAsGroup: 0
      runAsNonRoot: false
    volumeMounts:
      - name: prometheus-monitoring-kube-prometheus-prometheus-db
        mountPath: /prometheus
        subPath: prometheus-db
```

Keep it in the Application. Do not replace it by running Prometheus as root.

### Grafana is `CreateContainerConfigError`

The stable admin Secret is missing:

```bash
kubectl -n monitoring get secret monitoring-grafana-admin
```

Create it using section 2 and refresh the Application.

### Grafana returns `401 Invalid username or password`

Check that the running Grafana pod references the stable Secret and that the
Secret was not rotated after the database was created:

```bash
kubectl -n monitoring get deployment monitoring-grafana \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="grafana")].env}' | head
kubectl -n monitoring get secret monitoring-grafana-admin
```

If the Secret was rotated, changing it alone does not update the hash already
stored in Grafana's database. Restart Grafana after restoring the original
Secret, or recreate the Grafana PVC if the dashboard/database contents are
disposable.

### Grafana crashes with a SQLite migration error

Errors such as `no such column: uid` or `no such column: last_seen_at` usually
mean two Grafana pods ran migrations against the same ReadWriteOnce PVC during
a rollout. The Application sets:

```yaml
deploymentStrategy:
  type: Recreate
```

If the database is damaged and contains no data worth keeping:

```bash
kubectl -n monitoring scale deployment monitoring-grafana --replicas=0
kubectl -n monitoring delete pvc monitoring-grafana
kubectl -n monitoring scale deployment monitoring-grafana --replicas=1
```

### Argo CD reports `rollingUpdate may not be specified` for the Grafana deployment

This can happen when converting an existing Deployment from `RollingUpdate`
to `Recreate`. Patch the existing strategy once, then refresh Argo CD:

```bash
kubectl -n monitoring patch deployment monitoring-grafana \
  --type=json \
  -p '[{"op":"replace","path":"/spec/strategy","value":{"type":"Recreate"}}]'
```

### Argo CD waits for hook deletion

The chart's admission-certificate hooks are normal Helm hooks. If an operation
is stuck waiting for deletion of `monitoring-kube-prometheus-admission` hook
resources after the jobs completed, verify the jobs completed and remove the
stale hook resources:

```bash
kubectl -n monitoring get jobs
kubectl -n monitoring delete serviceaccount monitoring-kube-prometheus-admission
kubectl -n monitoring delete role monitoring-kube-prometheus-admission
kubectl -n monitoring delete rolebinding monitoring-kube-prometheus-admission
kubectl delete clusterrole monitoring-kube-prometheus-admission
kubectl delete clusterrolebinding monitoring-kube-prometheus-admission
```

Then refresh the Application. These hook resources are recreated when the
chart runs its admission-certificate job again.

### Prometheus pod remains Pending

Check PVC events and node memory:

```bash
kubectl -n monitoring describe pvc
kubectl get nodes -o wide
kubectl -n monitoring describe pod prometheus-monitoring-kube-prometheus-prometheus-0
```

The `local-path` provisioner uses `WaitForFirstConsumer`; ensure the pod is
scheduled and that the node has a free `local-path` volume. The Prometheus
request is 512Mi, so do not lower it aggressively.

---

## 9. Security and limitations

* Grafana is exposed over HTTP only. There is no TLS or SSO; access is limited
  by the home network and the admin password.
* Alertmanager has no receiver configured, so alerts are visible only in the
  Prometheus/Alertmanager/Grafana interfaces.
* Prometheus, Grafana and Alertmanager each have a single replica. A node
  failure makes monitoring unavailable until Kubernetes reschedules the pod.
* Monitoring data is stored on node-local `local-path` volumes; there is no
  remote write, Thanos, replication or off-site copy.
* The etcd, controller-manager, scheduler and kube-proxy targets are not
  scraped because Talos does not expose them as ordinary cluster services.
* Velero backs up Kubernetes objects but skips `local-path` PVs. The restic
  DaemonSet covers `/var/local-path-provisioner`, so monitoring PVC data is
  included in its snapshots, but there is no monitoring-specific restore
  rehearsal yet.
* The Grafana admin Secret is created outside Git. Rebuilds must recreate it
  before the Application syncs.

---

## 10. Current verification checklist

After a fresh installation, all of these should be true:

```bash
kubectl -n argocd get application monitoring
kubectl -n monitoring get pods,pvc,ingress
kubectl -n monitoring get --raw \
  /api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/-/ready
curl -sS -o /dev/null -w '%{http_code}\n' \
  -H 'Host: grafana.kubernetes.local' http://192.168.0.192/login
```

Expected summary:

* `monitoring` is `Synced` and `Healthy`.
* All monitoring pods are `Running`.
* The three PVCs are `Bound`.
* The ingress host is `grafana.kubernetes.local`.
* Prometheus returns `Prometheus Server is Ready.`
* Grafana `/login` returns `200`.
* Grafana has the Prometheus and Alertmanager datasources.
* Prometheus has no down targets.

The installation was last verified with the `monitoring` Application in
`Synced`/`Healthy` state, Grafana authentication returning `200`, and
Prometheus reporting 24 active targets with 0 down.
