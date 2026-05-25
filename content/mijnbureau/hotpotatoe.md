**Same issue again** — `hsts-header` is now owned by `docs`.

### Quick Fix (do this now):

```bash
kubectl delete middleware hsts-header -n default
```

Then retry:

```bash
helmfile -e demo apply
```

---

### Why This Keeps Happening

Every time you delete it, the next chart in the helmfile order claims ownership. Right now the ownership chain is getting passed around like a hot potato.

### Do This To End It Permanently

Create a **shared middleware chart** that deploys first.

```bash
# 1. Create the shared chart
mkdir -p charts/traefik-middleware/templates
```

**File: `charts/traefik-middleware/Chart.yaml`**
```yaml
apiVersion: v2
name: traefik-middleware
description: Shared Traefik Middlewares
version: 0.1.0
type: application
```

**File: `charts/traefik-middleware/templates/hsts-header.yaml`**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: hsts-header
  namespace: default
  annotations:
    helm.sh/resource-policy: keep
spec:
  headers:
    stsSeconds: 31536000
    stsIncludeSubDomains: true
    stsPreload: true
    forceSTSHeader: true
```

Then add this release **at the top** of your main `helmfile.yaml` (before any apps):

```yaml
- name: traefik-middleware
  chart: ./charts/traefik-middleware
  namespace: default
```

After that, remove the `hsts-header` definition from all your individual app charts (`bureaublad`, `docs`, `nextcloud`, etc.).

---

Would you like me to give you a ready-to-use full shared middleware chart with a few more useful ones (security headers, compression, etc.)?
