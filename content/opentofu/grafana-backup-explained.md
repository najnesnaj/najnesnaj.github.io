# Grafana backup dashboard not visible

If a newly added backup dashboard does not appear in Grafana, use the checks
below.

## ConfigMap method

Verify that the sidecar can see the ConfigMap:

```bash
kubectl -n monitoring get configmap -l grafana_dashboard=1
kubectl -n monitoring get configmap <name> -o jsonpath='{.data}' | head
kubectl -n monitoring logs deploy/monitoring-grafana -c grafana-sc-dashboard --tail=50
```

The ConfigMap must:

- be in a namespace scanned by the sidecar (`searchNamespace: ALL`, so any
  namespace is acceptable),
- have the exact label `grafana_dashboard=1`,
- contain a key ending in `.json`,
- contain valid JSON, not an HTML error page.

After fixing the ConfigMap, wait about a minute or restart Grafana:

```bash
kubectl -n monitoring rollout restart deployment monitoring-grafana
```

## Grafana UI import method

If importing by dashboard ID (for example `23838` for Velero or `17554`
for restic):

- the browser needs internet access to grafana.com,
- check **Dashboards → Browse** and search by dashboard name,
- if the import fails, download the JSON from grafana.com and use
  **Upload JSON file** instead.

## Manual panel method

Make sure to click **Save dashboard**. With
`provider.allowUiUpdates: false`, provisioned dashboards cannot be edited in
place, so create a new dashboard instead of editing a provisioned one.

## Data checks

Also verify that:

- the Prometheus datasource is selected,
- the scrape target is **UP** in Prometheus,
- the metric names in the panels match the exporter output, such as
  `restic_backup_timestamp` and `velero_backup_success_total`.

A dashboard can import successfully but show no data if the target is down.