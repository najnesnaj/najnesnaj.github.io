# Cluster monitoring — Prometheus and Grafana

This document describes the monitoring stack added to the Talos cluster:

| Component | Purpose |
| --- | --- |
| Prometheus | metrics collection and short-term storage |
| Alertmanager | alert routing; a receiver is not configured yet |
| Grafana | dashboards and ad-hoc metric queries |
| kube-state-metrics | Kubernetes object state |
| node-exporter | per-node CPU, memory, disk and network metrics |
| Prometheus Operator | manages Prometheus, Alertmanager, ServiceMonitors and rules |

The stack is installed from the
[`prometheus-community/kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
Helm chart through Argo CD. The chart version is pinned in
`ansible2/files/gitops/apps/monitoring.yaml`; the values are stored inline in
that Application so the GitOps repository contains the complete configuration.

---

## 1. URLs and access

Grafana is exposed through Traefik:

```
http://grafana.kubernetes.local
```

Add the name to the machine that runs the browser, next to the other
`*.kubernetes.local` names:

```bash
sudo sh -c 'echo "192.168.0.192  nginx-demo.kubernetes.local nextcloud.kubernetes.local euro-office.kubernetes.local grafana.kubernetes.local" >> /etc/hosts'
```

Browser checks:

```bash
curl -I http://grafana.kubernetes.local/
```

Without an `/etc/hosts` entry, use the `Host` header against the management
container:

```bash
curl -I -H 'Host: grafana.kubernetes.local' http://192.168.0.192/
```

Prometheus and Alertmanager are **not** exposed through an ingress. They are
reachable only inside the cluster, and through Grafana’s Prometheus datasource.
For temporary local access:

```bash
ssh root@192.168.0.192 \
  'kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090'
```

Then open `http://localhost:9090`. Do not expose this port on the LAN.

### Grafana login

Grafana uses a stable Kubernetes Secret named `monitoring-grafana-admin`
instead of the chart-generated `monitoring-grafana` Secret. The chart-generated
password can change on a Helm re-render, leaving the Secret and Grafana’s
SQLite database out of sync.

The Secret is deliberately not stored in Git. Create it once before the first
sync (or whenever rebuilding the cluster):

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n monitoring get secret monitoring-grafana-admin >/dev/null 2>&1; then
  kubectl -n monitoring create secret generic monitoring-grafana-admin \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$(openssl rand -hex 24)"
fi
```

Run the Secret creation only once, or check for an existing Secret first. Re-applying
a newly generated password would rotate the Secret without changing the password
already stored in Grafana’s SQLite database, causing login failures.

Retrieve the credentials when needed:

```bash
ssh root@192.168.0.192 \
  "kubectl -n monitoring get secret monitoring-grafana-admin \
   -o jsonpath='{.data.admin-user}' | base64 -d; echo"

ssh root@192.168.0.192 \
  "kubectl -n monitoring get secret monitoring-grafana-admin \
   -o jsonpath='{.data.admin-password}' | base64 -d; echo"
```

The default user is `admin`. If the password is lost, use Grafana’s admin
password-reset procedure; changing the Secret alone does not update the hash
already stored in Grafana’s database. For a disposable monitoring database the
simplest reset is to scale Grafana to zero, delete its PVC, and start one pod
again so the database is recreated from the current Secret.

---

## 2. Argo CD application

The Application is defined in
`ansible2/files/gitops/apps/monitoring.yaml` and is also seeded by
`ansible2/argocd.yml` on a fresh installation. The relevant source is:

```yaml
source:
  repoURL: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  targetRevision: 92.17.0
  helm:
    releaseName: monitoring
    values: |
      # values-k8s inlined in the Application
```

The Application creates the `monitoring` namespace and uses automated sync
with pruning and self-healing. `ServerSideApply=true` is required because the
chart contains large CRDs.

The Application also sets `managedNamespaceMetadata` to label the namespace
`pod-security.kubernetes.io/enforce=privileged` (plus matching audit and warn
labels). This is required by the node-exporter DaemonSet, which uses
`hostNetwork`, `hostPID`, host paths and host port `9100`. Do not remove that
label; on a cluster with a default Pod Security Admission policy the
node-exporter pods will otherwise be rejected.

Check the application:

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl -n argocd get application monitoring'
```

If a manual refresh is needed after changing the Application in Forgejo:

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config \
   kubectl -n argocd annotate application monitoring \
   argocd.argoproj.io/refresh=hard --overwrite'
```

Do not edit the generated `monitoring` resources directly; Argo CD will revert
them. Change the Application values in the GitOps repository instead.

---

## 3. What is installed

The stack creates, among other objects:

| Namespace | Workloads and storage |
| --- | --- |
| `monitoring` | Prometheus StatefulSet with an 8 GiB `local-path` PVC, 7-day retention |
| `monitoring` | Grafana Deployment with a 2 GiB `local-path` PVC and Traefik Ingress |
| `monitoring` | Alertmanager with a 1 GiB `local-path` PVC and 120-hour retention |
| `monitoring` | Prometheus Operator, kube-state-metrics, node-exporter DaemonSet |
| cluster-wide | Prometheus Operator CRDs, ServiceMonitors, PrometheusRules and admission webhooks |

The values intentionally disable the etcd, controller-manager, scheduler and
kube-proxy ServiceMonitors. Talos does not run those as ordinary Kubernetes
pods, so the upstream defaults would produce permanently missing targets.
The API server, kubelet, CoreDNS, kube-state-metrics and node-exporter are
scraped.

Prometheus uses a small `init-chown-data` container because `local-path`
mounts the database below a kubelet-created `prometheus-db` subPath that
`fsGroup` does not change. The init container makes that directory writable by
the Prometheus UID before the server starts. Grafana already has its own
`init-chown-data` container from the upstream chart.

Grafana uses the `Recreate` deployment strategy. Its SQLite database is on a
ReadWriteOnce volume; running old and new pods concurrently during a rolling
update can start two schema migrations at once and corrupt the database.

Resource requests are deliberately small for this three-node, 2 GiB-per-node
cluster:

| Component | Request | Limit |
| --- | --- | --- |
| Prometheus | 200m CPU / 512Mi | 1 CPU / 1Gi |
| Grafana | 100m CPU / 128Mi | 500m / 512Mi |
| Alertmanager | 50m CPU / 64Mi | 200m / 128Mi |
| Prometheus Operator | 100m CPU / 128Mi | 500m / 256Mi |
| kube-state-metrics | 50m CPU / 64Mi | 200m / 256Mi |
| node-exporter | 20m CPU / 32Mi per node | 100m / 64Mi |

Prometheus keeps at most 7 days or 6 GB of metrics in an 8 GiB PVC. Grafana
and Alertmanager also use `local-path`; their data is node-local and not
replicated. This is adequate for a homelab monitoring stack but is not a
high-availability or long-term-retention design.

---

## 4. Verification

### Pods and storage

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl -n monitoring get pods,svc,ingress,pvc'
```

Expected:

* all `monitoring-*` pods are `Running` (node-exporter has one pod per node),
* the Grafana ingress has host `grafana.kubernetes.local`,
* the Prometheus, Grafana and Alertmanager PVCs are `Bound`.

### Prometheus targets

```bash
ssh root@192.168.0.192 \
  "KUBECONFIG=/root/.kube/config kubectl -n monitoring \
   port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090"
```

Open `http://localhost:9090/targets` and check the `kubernetes-*`, `node-exporter`
and `kube-state-metrics` targets.

### Grafana

Open `http://grafana.kubernetes.local`, log in with the credentials from the
Secret, and open a built-in dashboard such as:

* **Kubernetes / Compute Resources / Cluster**
* **Kubernetes / Compute Resources / Node**
* **Node Exporter / Nodes**

The Prometheus datasource is provisioned automatically.

### Quick API checks

```bash
ssh root@192.168.0.192 \
  "KUBECONFIG=/root/.kube/config kubectl -n monitoring \
   get --raw /api/v1/namespaces/monitoring/services/monitoring-kube-prometheus-prometheus:9090/proxy/-/ready"
```

A healthy Prometheus returns `Prometheus Server is Ready.`

---

## 5. Changing retention or resources

Edit the `helm.values` block in
`ansible2/files/gitops/apps/monitoring.yaml`, then commit it to the Forgejo
GitOps repository. The root Application will update the `monitoring`
Application, and Argo CD will reconcile it.

To change the chart version, update `targetRevision` in the same Application.
Review the upstream chart’s upgrade notes before crossing major versions; CRD
changes may require `ServerSideApply=true` (already configured).

If Prometheus runs out of disk, reduce `retention` or `retentionSize` before
increasing the PVC. `local-path` volumes cannot be expanded in place.

---

## 6. Known limitations

* Single Prometheus and Alertmanager replicas; a node failure makes monitoring
  unavailable until the pod is rescheduled.
* Metrics are stored on one node’s `local-path` volume. There is no
  replication, remote write, Thanos or off-site copy.
* Grafana and Alertmanager persistence are also node-local.
* Alertmanager has no receiver configured, so alerts are only visible in the
  Alertmanager and Prometheus UIs.
* Grafana and Alertmanager have no TLS and no SSO; access is controlled by the
  cluster network and the admin password.
* The control-plane components etcd, controller-manager, scheduler and
  kube-proxy are not scraped because Talos does not expose them as cluster
  services in this installation.
* The restic DaemonSet backs up `/var/local-path-provisioner`, so the
  monitoring PVC directories are included in its snapshots. There is no
  monitoring-specific restore rehearsal yet, and a cluster rebuild should treat
  the metric history as disposable.

These are acceptable for the current homelab setup but should be revisited
before treating monitoring as production infrastructure.

---

## 7. Troubleshooting

### Grafana ingress returns 404

Check that Traefik is running and that the ingress class is `traefik`:

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl get ingress -A'
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl -n monitoring describe ingress monitoring-grafana'
```

Verify the request with an explicit `Host` header. If that works, the client’s
`/etc/hosts` or DNS entry is missing or points at the wrong address.

### Prometheus pod is Pending

The `local-path` provisioner is WaitForFirstConsumer. Check the PVC events:

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl -n monitoring describe pvc'
```

Check node allocatable memory and whether the requests fit. The Prometheus
request is 512Mi; lower it only if the node is genuinely memory-constrained.

### Grafana shows “No data”

Check the Prometheus datasource and targets. The datasource URL should be the
in-cluster service:

```
http://monitoring-kube-prometheus-prometheus:9090
```

If Prometheus is running but targets are empty, inspect the `monitoring`
Application sync status and the Prometheus Operator logs.

### Grafana crashes with a SQLite migration error

Symptoms include `no such column: uid` or `no such column: last_seen_at` in the
Grafana container logs. This usually means two Grafana pods ran SQLite
migrations against the same ReadWriteOnce PVC during a rollout. The
Application sets `grafana.deploymentStrategy.type=Recreate` to prevent this.
If the database is already damaged and there is no data worth keeping:

```bash
kubectl -n monitoring scale deployment monitoring-grafana --replicas=0
kubectl -n monitoring delete pvc monitoring-grafana
kubectl -n monitoring scale deployment monitoring-grafana --replicas=1
```

### Operator webhook errors during first sync

The chart’s CRDs and webhook certificates take a moment to become ready. The
Application has retry/backoff configured. Re-check after a few minutes.

---

## 8. Secret handling

No Grafana password, Prometheus token, webhook certificate or alert receiver
credential is stored in this repository. The Grafana credentials are in the
`monitoring/monitoring-grafana-admin` Secret, which must be created outside
Git as shown in section 1. Retrieve them with the commands there and store them
in the team password manager if they need to be shared.

Velero backs up Kubernetes objects, but skips `local-path` PVs. The restic
DaemonSet does back up `/var/local-path-provisioner`, which contains the
`local-path` directories for the monitoring PVCs as well as the other
application volumes. That gives the monitoring data a restic snapshot, but
there is no monitoring-specific restore rehearsal; metric history remains
disposable. See [`backup.md`](backup.md) for the exact restic layout.

See [`backup.md`](backup.md) and
[`backup-restore-howto.md`](backup-restore-howto.md) for the backup design.
