## Nextcloud Cronjob runs as root instead of uid 33

### Issue

The Nextcloud cronjob pod runs as root (uid 0), but `config/config.php` is owned by uid 33 (`www-data`). When the cronjob runs `php -f /var/www/html/cron.php`, Nextcloud's console check fails with:

```
Console has to be executed with the user that owns the file config/config.php.
Current user id: 0
Owner id of config.php: 33
```

### Root Cause

The cronjob template (`helmfile/apps/nextcloud/charts/nextcloud/templates/cronjob.yaml`) used the top-level `.Values.podSecurityContext` and `.Values.containerSecurityContext` — the same values as the main deployment. The demo environment disables these (`security.default.podSecurityContext.enabled: false`, `security.default.containerSecurityContext.enabled: false`), which means no security context is applied to the cronjob pod, so it defaults to root.

The demo environment config (`helmfile/environments/demo/mijnbureau.yaml.gotmpl`) did define cronjob-specific security context:

```yaml
nextcloud:
  cronjob:
    securityContext:
      runAsUser: 33
      runAsGroup: 33
      readOnlyRootFilesystem: false
    podSecurityContext:
      runAsUser: 33
      runAsGroup: 33
      fsGroup: 33
```

But the cronjob template never referenced `.Values.cronjob.podSecurityContext` or `.Values.cronjob.securityContext`, so these values were ignored.

### Fix

Two changes were made:

1. **`cronjob.yaml` template** — Added support for `.Values.cronjob.podSecurityContext` (pod level) and `.Values.cronjob.securityContext` (container level). The template checks these first, falling back to the top-level `.Values.podSecurityContext` / `.Values.containerSecurityContext`:

   - Line 38: `{{- if .Values.cronjob.podSecurityContext }}` — use cronjob-specific pod security context
   - Line 40: `{{- else if .Values.podSecurityContext.enabled }}` — fall back to top-level pod security context
   - Same pattern for init container (line 50) and main container (line 83) with `cronjob.securityContext`

2. **`values.yaml.gotmpl`** — Added value passthrough to map `.Values.nextcloud.cronjob.podSecurityContext` and `.Values.nextcloud.cronjob.securityContext` from the environment config into the chart's `.Values.cronjob.*`:

   ```yaml
   {{- if or .Values.nextcloud.cronjob.podSecurityContext .Values.nextcloud.cronjob.securityContext }}
   cronjob:
     {{- with .Values.nextcloud.cronjob.podSecurityContext }}
     podSecurityContext: {{ . | toYaml | nindent 4 }}
     {{- end }}
     {{- with .Values.nextcloud.cronjob.securityContext }}
     securityContext: {{ . | toYaml | nindent 4 }}
     {{- end }}
   {{- end }}
   ```

### Verification

After deploying the fix, verify the cronjob pod runs as uid 33:

```bash
kubectl get pods -l app.kubernetes.io/component=nextcloud-cronjob
kubectl exec <pod-name> -- id
# Should show: uid=33(gid=33)
```

The cronjob logs should no longer show the "Console has to be executed with the user" error:

```bash
kubectl logs <pod-name>
```
