---
title: 'services'
weight: 1300
draft: false
---



kubectl get svc -n default
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                                                           AGE
bureaublad-backend           ClusterIP      10.43.186.230   <none>          80/TCP                                                                                                                                                            3h3m
bureaublad-frontend          ClusterIP      10.43.108.163   <none>          80/TCP                                                                                                                                                            3h3m
bureaublad-redis-headless    ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h3m
bureaublad-redis-master      ClusterIP      10.43.81.217    <none>          6379/TCP                                                                                                                                                          3h3m
collabora-online             ClusterIP      10.43.242.247   <none>          9980/TCP                                                                                                                                                          3h30m
docs-minio                   ClusterIP      10.43.23.14     <none>          9000/TCP                                                                                                                                                          3h5m
docs-nginx                   ClusterIP      10.43.49.244    <none>          80/TCP,443/TCP                                                                                                                                                    3h4m
docs-postgresql              ClusterIP      10.43.218.63    <none>          5432/TCP                                                                                                                                                          3h5m
docs-postgresql-hl           ClusterIP      None            <none>          5432/TCP                                                                                                                                                          3h5m
docs-redis-headless          ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h5m
docs-redis-master            ClusterIP      10.43.67.8      <none>          6379/TCP                                                                                                                                                          3h5m
docs-static-nginx            ClusterIP      10.43.25.75     <none>          80/TCP,443/TCP                                                                                                                                                    3h5m
element-postgresql           ClusterIP      10.43.132.149   <none>          5432/TCP                                                                                                                                                          3h30m
element-postgresql-hl        ClusterIP      None            <none>          5432/TCP                                                                                                                                                          3h30m
element-redis-headless       ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h30m
element-redis-master         ClusterIP      10.43.153.12    <none>          6379/TCP                                                                                                                                                          3h30m
element-web                  ClusterIP      10.43.86.254    <none>          8080/TCP                                                                                                                                                          3h30m
grist-minio                  ClusterIP      10.43.241.202   <none>          9000/TCP                                                                                                                                                          12d
grist-minio-console          ClusterIP      10.43.145.71    <none>          9090/TCP                                                                                                                                                          12d
grist-postgresql             ClusterIP      10.43.206.72    <none>          5432/TCP                                                                                                                                                          12d
grist-postgresql-hl          ClusterIP      None            <none>          5432/TCP                                                                                                                                                          12d
grist-redis-headless         ClusterIP      None            <none>          6379/TCP                                                                                                                                                          12d
grist-redis-master           ClusterIP      10.43.46.27     <none>          6379/TCP                                                                                                                                                          12d
keycloak-keycloak            ClusterIP      10.43.131.39    <none>          80/TCP                                                                                                                                                            13d
keycloak-keycloak-headless   ClusterIP      None            <none>          8080/TCP                                                                                                                                                          13d
keycloak-postgresql          ClusterIP      10.43.159.226   <none>          5432/TCP                                                                                                                                                          13d
keycloak-postgresql-hl       ClusterIP      None            <none>          5432/TCP                                                                                                                                                          13d
kubernetes                   ClusterIP      10.43.0.1       <none>          443/TCP                                                                                                                                                           13d
livekit-livekit-server       LoadBalancer   10.43.120.54    192.168.0.216   30001:30001/UDP,30002:30002/UDP,30003:30003/UDP,30004:30004/UDP,30005:30005/UDP,30006:30006/UDP,30007:30007/UDP,30008:30008/UDP,30009:30009/UDP,32669:32669/TCP   3h6m
livekit-redis-headless       ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h6m
livekit-redis-master         ClusterIP      10.43.16.191    <none>          6379/TCP                                                                                                                                                          3h6m
livekit-server               ClusterIP      10.43.74.104    <none>          80/TCP                                                                                                                                                            3h6m
meet-backend                 ClusterIP      10.43.123.54    <none>          80/TCP                                                                                                                                                            3h30m
meet-frontend                ClusterIP      10.43.230.94    <none>          80/TCP                                                                                                                                                            3h30m
meet-postgresql              ClusterIP      10.43.42.238    <none>          5432/TCP                                                                                                                                                          3h30m
meet-postgresql-hl           ClusterIP      None            <none>          5432/TCP                                                                                                                                                          3h30m
meet-redis-headless          ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h30m
meet-redis-master            ClusterIP      10.43.254.166   <none>          6379/TCP                                                                                                                                                          3h30m
meet-static-nginx            ClusterIP      10.43.188.143   <none>          80/TCP,443/TCP                                                                                                                                                    3h30m
nextcloud                    ClusterIP      10.43.134.233   <none>          8080/TCP                                                                                                                                                          3h6m
nextcloud-minio              ClusterIP      10.43.176.97    <none>          9000/TCP                                                                                                                                                          3h29m
nextcloud-minio-console      ClusterIP      10.43.159.253   <none>          9090/TCP                                                                                                                                                          3h29m
nextcloud-postgresql         ClusterIP      10.43.177.65    <none>          5432/TCP                                                                                                                                                          3h29m
nextcloud-postgresql-hl      ClusterIP      None            <none>          5432/TCP                                                                                                                                                          3h29m
nextcloud-redis-headless     ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h29m
nextcloud-redis-master       ClusterIP      10.43.21.144    <none>          6379/TCP                                                                                                                                                          3h29m
synapse                      ClusterIP      10.43.222.1     <none>          8448/TCP                                                                                                                                                          3h30m
synapse-replication          ClusterIP      10.43.141.53    <none>          9093/TCP                                                                                                                                                          3h30m

**Perfect — we now have the exact cause and the fix.**

### Root Cause
The nginx config contains:

```nginx
upstream ... "docs-backend" ...
```

But there is **no service named `docs-backend`** in your cluster.

Looking at `kubectl get svc`, the correct backend for your "docs" service (Collabora Online) is:

→ **`collabora-online`** (ClusterIP 10.43.242.247, port 9980)

The Bitnami nginx chart / your "docs" Helm chart is hardcoded (or configured) to proxy to a non-existent service called `docs-backend`.

This is why nginx fails with `[emerg] host not found in upstream "docs-backend"`.

### Fix (Do this now)

You need to tell the nginx chart what the real upstream/backend is.

In your Helm `values.yaml` for the **docs** release, add or change this section:

```yaml
nginx:
  serverBlock:
    upstream:
      backend: collabora-online   # ← Change this line
  # or depending on the exact chart structure, it might be:
  # backend:
  #   serviceName: collabora-online
  #   servicePort: 9980
```

If the chart uses a more specific key (common in Bitnami or custom "docs" charts), try one of these patterns:

```yaml
# Option 1 (most common)
collabora:
  enabled: true
  service:
    name: collabora-online

# Option 2
nginx:
  proxy:
    upstream: collabora-online:9980

# Option 3
extraEnvVars:
  - name: NGINX_UPSTREAM_BACKEND
    value: collabora-online
```

**After updating the values**, upgrade the chart:

```bash
helm upgrade docs <chart-name> -n default -f values.yaml
```

(or whatever your release name and chart reference is — e.g. `helm upgrade docs bitnami/nginx ...` if it's a plain nginx chart).

### Quick & Dirty Temporary Workaround (if you want nginx up immediately)
You can patch the ConfigMap or the deployment to replace the upstream name, but it's better to fix it properly via Helm so it survives restarts.

### Next Steps After Fixing docs-nginx
Once `docs-nginx` becomes 1/1 Running, the Collabora integration for Nextcloud should start working (or at least show the next error).

Then we can tackle the remaining two crashing pods:
- **Nextcloud** (still CrashLoopBackOff)
- **Synapse** (OIDC config still broken)

For **Nextcloud**, please now run these two log commands and paste the output:

```bash
kubectl logs nextcloud-864d6c9854-9ts7h -n default --tail=150
kubectl logs nextcloud-864d6c9854-9ts7h -n default --previous --tail=100
```

Also run the cronjob log if you want:

```bash
kubectl logs nextcloud-cronjob-29611495-hpj6l -n default
```

### For Synapse (quick reminder)
While we're waiting, the fastest way to bring Matrix back is to set `discover: true` and a correct `issuer` in the OIDC block (remove the four manual endpoint lines), or temporarily set `oidcProviders: []`.


First, let's get **docs-nginx** fixed — update the upstream to `collabora-online` and run the helm upgrade. Then paste the Nextcloud logs. We're very close to a fully green cluster!
