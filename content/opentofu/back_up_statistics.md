# Backup statistics in Grafana

This document describes how to publish backup statistics for **Velero** and
**restic** into the existing Prometheus/Grafana stack. It does not change the
backup design itself; see [`backup.md`](backup.md) and
[`backup-restore-howto.md`](backup-restore-howto.md) for that.

The monitoring stack is the one described in
[`monitoring.md`](monitoring.md): Prometheus Operator, Prometheus, Grafana and
Alertmanager in the `monitoring` namespace. Prometheus already picks up every
`ServiceMonitor` in the cluster because the monitoring Application sets
`serviceMonitorSelectorNilUsesHelmValues: false`.

---

## 1. What gets published

| Backup tool | Metrics source | What it shows |
| --- | --- | --- |
| Velero | Velero server `/metrics` on port `8085` | backup/restore attempts, successes, failures, duration, storage location status, volume snapshots |
| restic | `ngosang/restic-exporter` in the `backup` namespace | repository size, blob/file counts, snapshot count, last backup timestamp per host/tag, `restic check` result |

Velero’s own server metrics are enabled by default in the chart; only the
Service and ServiceMonitor have to be turned on. restic has no metrics
endpoint, so a small exporter Deployment reads the same Garage repository and
exposes Prometheus metrics on port `8001`.

---

## 2. Velero

### 2.1 Enable the metrics ServiceMonitor

`ansible2/files/backup/values-velero.yaml` now contains:

```yaml
metrics:
  enabled: true
  scrapeInterval: 30s
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: monitoring
  prometheusRule:
    enabled: true
    additionalLabels:
      release: monitoring
```

`metrics.enabled` was already true in the chart; the important change is
`metrics.serviceMonitor.enabled: true`. The `release: monitoring` label keeps
the object selectable even if the Prometheus CRD is later changed to a
label-based selector.

Apply the change with the same Helm release that was used for the original
installation (release name `velero` is assumed here):

```bash
helm repo update
helm upgrade velero vmware-tanzu/velero \
  -n velero \
  -f ansible2/files/backup/values-velero.yaml
```

The chart creates a Service named `velero-metrics` (port `8085`) and a
`ServiceMonitor` named `velero` in the `velero` namespace.

### 2.2 Verify

```bash
kubectl -n velero get svc, servicemonitor | grep -i velero
kubectl -n velero port-forward deploy/velero 8085:8085
curl -s http://127.0.0.1:8085/metrics | head
```

In Prometheus (`http://localhost:9090/targets` after port-forwarding
Prometheus) the `velero` target should be **UP**.

### 2.3 Useful PromQL

```promql
# Successful backups in the last 24 hours
increase(velero_backup_success_total[24h])

# Failed backups in the last 24 hours
increase(velero_backup_failure_total[24h])

# Success rate over the last hour
rate(velero_backup_success_total[1h])
/ (rate(velero_backup_success_total[1h]) + rate(velero_backup_failure_total[1h]))

# 95th percentile backup duration by schedule
histogram_quantile(
  0.95,
  sum by (schedule, le) (rate(velero_backup_duration_seconds_bucket[1h]))
)

# Storage location availability
velero_backup_location_status_gauge

# Velero server health
up{job="velero"}
```

---

## 3. restic

### 3.1 Deploy the exporter

The manifest is
`ansible2/files/backup/restic-exporter.yaml`. It creates:

* a `Deployment` `restic-exporter` in the `backup` namespace,
* a `Service` on port `8001`,
* a `ServiceMonitor` with the `release: monitoring` label,
* a `PrometheusRule` with two alerts.

The exporter reuses the existing `backup/restic-credentials` Secret, so no
new credentials are required. `RESTIC_REPOSITORY` points at the same Garage
bucket as the DaemonSet.

Apply it:

```bash
kubectl apply -f ansible2/files/backup/restic-exporter.yaml
kubectl -n backup get deploy,svc,servicemonitor,prometheusrule
```

The exporter runs `restic check` and `restic stats` against the repository
every `REFRESH_INTERVAL` seconds (one hour by default). Set
`REFRESH_INTERVAL` higher (for example `86400`) if Garage traffic costs
become a concern; the repository in this installation is small, so one hour
is fine.

### 3.2 Verify

```bash
kubectl -n backup port-forward deploy/restic-exporter 8001:8001
curl -s http://127.0.0.1:8001/metrics | head
```

Look for `restic_check_success`, `restic_snapshots_total` and
`restic_backup_timestamp`.

### 3.3 Useful PromQL

```promql
# Repository health
restic_check_success

# Number of snapshots in the repository
restic_snapshots_total

# Repository size
restic_size_total
restic_uncompressed_size_total

# Age of the newest snapshot per backup host
time() - max by (client_hostname) (restic_backup_timestamp)

# Snapshot count per host
count by (client_hostname) (restic_backup_timestamp)

# Last backup size per host
max by (client_hostname) (restic_backup_size_total)
```

Because the restic DaemonSet labels each snapshot with
`--host "$NODE_NAME"` and `--tag local-path`, the `client_hostname` label
identifies the node that produced the snapshot.

---

## 4. Grafana dashboards

The existing Grafana instance is the one provisioned by
`kube-prometheus-stack`. Add the backup statistics in one of these ways.

### 4.1 Import community dashboards

In Grafana, go to **Dashboards → Import** and use:

| Tool | Dashboard | ID |
| --- | --- | --- |
| Velero | Velero Overview | `23838` |
| restic | Restic Exporter | `17554` |

Select the Prometheus datasource when prompted. These dashboards use the
standard metric names shown above.

### 4.2 Provision dashboards as ConfigMaps

If the dashboards should be recreated automatically, store each dashboard
JSON as a ConfigMap in the `monitoring` namespace with the label
`grafana_dashboard: "1"` (the sidecar that ships with the chart watches for
that label):

```bash
kubectl -n monitoring create configmap grafana-dashboard-velero \
  --from-file=velero.json=./velero-dashboard.json
kubectl -n monitoring label configmap grafana-dashboard-velero \
  grafana_dashboard=1

kubectl -n monitoring create configmap grafana-dashboard-restic \
  --from-file=restic.json=./restic-dashboard.json
kubectl -n monitoring label configmap grafana-dashboard-restic \
  grafana_dashboard=1
```

### 4.3 Build a small combined panel

A single “Backup health” dashboard can be built from:

| Panel | Type | Query |
| --- | --- | --- |
| Velero server up | Stat | `up{job="velero"}` |
| Velero successes (24h) | Stat | `increase(velero_backup_success_total[24h])` |
| Velero failures (24h) | Stat | `increase(velero_backup_failure_total[24h])` |
| Velero backup duration p95 | Time series | `histogram_quantile(0.95, sum by (schedule, le) (rate(velero_backup_duration_seconds_bucket[1h])))` |
| restic check | Stat | `restic_check_success` |
| restic snapshots | Stat | `restic_snapshots_total` |
| restic repository size | Stat | `restic_size_total` |
| restic newest snapshot age | Time series | `time() - max by (client_hostname) (restic_backup_timestamp)` |

---

## 5. Alert rules

Velero rules are created by the chart because
`metrics.prometheusRule.enabled: true` is set in `values-velero.yaml`. restic
rules are created by `restic-exporter.yaml`. Both use the `release: monitoring`
label so Alertmanager/Prometheus picks them up.

Current rules:

* `VeleroBackupFailed` — `velero_backup_last_status{schedule!=""} != 1` for
  15 minutes.
* `VeleroNoSuccessfulBackup` — no successful Velero backup for 25 hours.
* `ResticCheckFailed` — `restic_check_success == 0` for 5 minutes.
* `ResticBackupOutdated` — newest restic snapshot older than 48 hours.

Alertmanager has no receiver configured yet (see `monitoring.md`), so these
alerts are visible in the Prometheus and Alertmanager UIs only.

---

## 6. Verification checklist

- [ ] `velero` target is **UP** in Prometheus.
- [ ] `restic-exporter` target is **UP** in Prometheus.
- [ ] Velero dashboard shows the `velero-daily` schedule.
- [ ] restic dashboard shows one snapshot series per cluster node.
- [ ] `restic_check_success` is `1`.
- [ ] `time() - max(restic_backup_timestamp)` is below 48 hours after the
      next backup cycle.

---

## 7. Troubleshooting

### Velero target is missing

Check that the Application was resynced after editing `values-velero.yaml`:

```bash
ssh root@192.168.0.192 \
  'KUBECONFIG=/root/.kube/config kubectl -n argocd get application monitoring'
```

Then verify the ServiceMonitor exists and has the expected labels:

```bash
kubectl -n velero get servicemonitor velero -o yaml
```

If Prometheus does not select it, add the `release: monitoring` label (already
done in the values) or check `serviceMonitorSelector` in the Prometheus CRD.

### Velero metrics endpoint returns 404

The endpoint is `/metrics` on port `8085`. Confirm the pod exposes it:

```bash
kubectl -n velero get pod -l app.kubernetes.io/name=velero -o jsonpath='{.items[0].spec.containers[0].ports}'
kubectl -n velero port-forward deploy/velero 8085:8085
curl -I http://127.0.0.1:8085/metrics
```

### restic-exporter CrashLoopBackOff

The most common cause is an authentication or path-style problem with Garage.
Check the logs:

```bash
kubectl -n backup logs deploy/restic-exporter --tail=50
```

Then test the repository manually from a temporary pod or from the
management host with the same environment:

```bash
export RESTIC_REPOSITORY='s3:http://10.10.50.2:3900/restic'
export AWS_DEFAULT_REGION='garage'
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export RESTIC_PASSWORD=...
restic snapshots
```

Garage requires path-style access. Restic defaults to path-style for
non-AWS endpoints, so no `-o s3.bucket-lookup=path` is needed in the
exporter. If the test above works but the exporter fails, compare the
environment variables in the Secret with the ones used in the manual test.

### restic metrics are stale

`REFRESH_INTERVAL=3600` means the exporter recomputes at most once per hour.
`restic check` and `restic stats` are expensive; do not set the interval
below a few minutes. A pod restart resets the timer, so a freshly started
exporter has no metrics until the first refresh completes.

### Dashboard shows “No data”

1. Confirm the Prometheus datasource URL is
   `http://monitoring-kube-prometheus-prometheus:9090`.
2. Confirm the target is **UP** in Prometheus.
3. Confirm the metric name in the panel matches the exporter output
   (`restic_backup_timestamp`, not `restic_last_backup_timestamp`).
4. For Velero, confirm that at least one backup has completed; some
   `velero_backup_*` counters are zero until the first run.

---

## 8. Secret handling

No new secrets are introduced. The exporter reads the existing
`backup/restic-credentials` Secret (`AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `RESTIC_PASSWORD`). The metrics endpoints are
cluster-internal Services; they are not exposed through Traefik. Do not
publish port `8001` or `8085` on the LAN.

---

## 9. Files touched

| File | Change |
| --- | --- |
| `ansible2/files/backup/values-velero.yaml` | Enable Velero ServiceMonitor and PrometheusRule |
| `ansible2/files/backup/restic-exporter.yaml` | New restic exporter Deployment, Service, ServiceMonitor and PrometheusRule |
| `ansible2/files/backup/README.md` | List the new manifest |
