# Drive Backend Celery CrashLoopBackOff Fix

## Symptom

```
default   drive-backend-celery-6c4d9d75d8-rhzz5   0/1   CrashLoopBackOff   27 (2m ago)   93m
```

## Root Cause

Two issues caused the `drive-backend-celery` pod to crash-loop:

### 1. Liveness/Readiness probe timeout too short (2s)

Both probes ran `celery -A drive.celery_app inspect ping -d drive@$HOSTNAME` which connects to the Redis broker and waits for neighbor discovery — taking longer than the 2-second probe timeout.

Pod events confirmed:
```
Warning  Unhealthy  Readiness probe failed: command timed out: "celery ... inspect ping" timed out after 2s
Warning  Unhealthy  Liveness probe failed: command timed out: "celery ... inspect ping" timed out after 2s
Normal   Killing    Container drive failed liveness probe, will be restarted
```

The default chart values (`helmfile/apps/drive/charts/drive/values.yaml:605`) set:
```yaml
livenessProbe:
  timeoutSeconds: 2
readinessProbe:
  timeoutSeconds: 2
```

These are too aggressive for the `celery inspect ping` command.

### 2. Insufficient memory (micro preset)

The celery worker (`--autoscale=9,3`) was using the `micro` resource preset (256Mi request / 384Mi limit) because:
- `global.resourcesPresetPerApp.drive.backend` defaults to `"micro"` in `helmfile/environments/default/global.yaml.gotmpl:35`
- No `resource.drive.celery` was defined in the demo config, so `drive.celery.resources` resolved to `null`
- The template fell back to `drive.resourcesPreset` = `"micro"`

With 3+ worker processes at ~80MiB each plus the Python parent process, the 384Mi limit was very tight.

## Fix Applied

### Live patch (immediate)

Increased probe timeout to 15s and resources to "small" level (512Mi/768Mi) on the deployment:

```bash
kubectl patch deployment drive-backend-celery -p '{"spec":{"template":{"spec":{"containers":[{"name":"drive","livenessProbe":{"timeoutSeconds":15},"readinessProbe":{"timeoutSeconds":15},"resources":{"requests":{"cpu":"250m","memory":"512Mi","ephemeral-storage":"50Mi"},"limits":{"cpu":"750m","memory":"768Mi","ephemeral-storage":"2Gi"}}}]}}}}'
```

### Permanent config changes

#### 1. Probe timeout overrides in `helmfile/apps/drive/values.yaml.gotmpl`

Added probe timeout values that deep-merge with chart defaults (harmless for the main backend which uses fast httpGet probes):

```yaml
drive:
  livenessProbe:
    timeoutSeconds: 15
  readinessProbe:
    timeoutSeconds: 15
```

#### 2. Celery resource config in `helmfile/environments/demo/mijnbureau.yaml.gotmpl`

Added explicit celery worker resources under `resource.drive.celery`:

```yaml
resource:
  drive:
    celery:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 750m
        memory: 768Mi
```

## Verification

After the fix, both celery pods are running with 0 restarts:

```
NAME                                         READY   STATUS    RESTARTS   AGE
drive-backend-celery-5d48d8db5d-b7nln        1/1     Running   0          2m
drive-backend-celery-5d48d8db5d-xbd88        1/1     Running   0          43s
```

Probe configuration now shows `timeout=15s` and resources are 512Mi/768Mi.

## Redeploy

After applying the config file changes, redeploy the drive app:

```bash
helmfile -e demo -l name=drive apply
```
