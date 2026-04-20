---
title: 'services2'
weight: 1350
draft: false
---
kubectl get svc -n default
NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)                                                                                                                                                           AGE
bureaublad-backend           ClusterIP      10.43.186.230   <none>          80/TCP                                                                                                                                                            3h56m
bureaublad-frontend          ClusterIP      10.43.108.163   <none>          80/TCP                                                                                                                                                            3h56m
bureaublad-redis-headless    ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h56m
bureaublad-redis-master      ClusterIP      10.43.81.217    <none>          6379/TCP                                                                                                                                                          3h56m
collabora-online             ClusterIP      10.43.242.247   <none>          9980/TCP                                                                                                                                                          4h23m
docs-minio                   ClusterIP      10.43.23.14     <none>          9000/TCP                                                                                                                                                          3h58m
docs-nginx                   ClusterIP      10.43.49.244    <none>          80/TCP,443/TCP                                                                                                                                                    3h57m
docs-postgresql              ClusterIP      10.43.218.63    <none>          5432/TCP                                                                                                                                                          3h58m
docs-postgresql-hl           ClusterIP      None            <none>          5432/TCP                                                                                                                                                          3h58m
docs-redis-headless          ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h58m
docs-redis-master            ClusterIP      10.43.67.8      <none>          6379/TCP                                                                                                                                                          3h58m
docs-static-nginx            ClusterIP      10.43.25.75     <none>          80/TCP,443/TCP                                                                                                                                                    3h58m
element-cluster-rw           ClusterIP      10.43.149.87    <none>          5432/TCP                                                                                                                                                          7m43s
element-cluster-rw-hl        ClusterIP      None            <none>          5432/TCP                                                                                                                                                          7m43s
element-redis-headless       ClusterIP      None            <none>          6379/TCP                                                                                                                                                          4h23m
element-redis-master         ClusterIP      10.43.153.12    <none>          6379/TCP                                                                                                                                                          4h23m
element-web                  ClusterIP      10.43.86.254    <none>          8080/TCP                                                                                                                                                          4h23m
grist-minio                  ClusterIP      10.43.241.202   <none>          9000/TCP                                                                                                                                                          13d
grist-minio-console          ClusterIP      10.43.145.71    <none>          9090/TCP                                                                                                                                                          13d
grist-postgresql             ClusterIP      10.43.206.72    <none>          5432/TCP                                                                                                                                                          13d
grist-postgresql-hl          ClusterIP      None            <none>          5432/TCP                                                                                                                                                          13d
grist-redis-headless         ClusterIP      None            <none>          6379/TCP                                                                                                                                                          13d
grist-redis-master           ClusterIP      10.43.46.27     <none>          6379/TCP                                                                                                                                                          13d
keycloak-cluster-rw          ClusterIP      10.43.157.123   <none>          5432/TCP                                                                                                                                                          27m
keycloak-cluster-rw-hl       ClusterIP      None            <none>          5432/TCP                                                                                                                                                          27m
keycloak-keycloak            ClusterIP      10.43.131.39    <none>          80/TCP                                                                                                                                                            13d
keycloak-keycloak-headless   ClusterIP      None            <none>          8080/TCP                                                                                                                                                          13d
kubernetes                   ClusterIP      10.43.0.1       <none>          443/TCP                                                                                                                                                           13d
livekit-livekit-server       LoadBalancer   10.43.120.54    192.168.0.216   30001:30001/UDP,30002:30002/UDP,30003:30003/UDP,30004:30004/UDP,30005:30005/UDP,30006:30006/UDP,30007:30007/UDP,30008:30008/UDP,30009:30009/UDP,32669:32669/TCP   3h59m
livekit-redis-headless       ClusterIP      None            <none>          6379/TCP                                                                                                                                                          3h59m
livekit-redis-master         ClusterIP      10.43.16.191    <none>          6379/TCP                                                                                                                                                          3h59m
livekit-server               ClusterIP      10.43.74.104    <none>          80/TCP                                                                                                                                                            3h59m
meet-backend                 ClusterIP      10.43.123.54    <none>          80/TCP                                                                                                                                                            4h23m
meet-cluster-rw              ClusterIP      10.43.250.114   <none>          5432/TCP                                                                                                                                                          8m12s
meet-cluster-rw-hl           ClusterIP      None            <none>          5432/TCP                                                                                                                                                          8m12s
meet-frontend                ClusterIP      10.43.230.94    <none>          80/TCP                                                                                                                                                            4h23m
meet-redis-headless          ClusterIP      None            <none>          6379/TCP                                                                                                                                                          4h23m
meet-redis-master            ClusterIP      10.43.254.166   <none>          6379/TCP                                                                                                                                                          4h23m
meet-static-nginx            ClusterIP      10.43.188.143   <none>          80/TCP,443/TCP                                                                                                                                                    4h23m
nextcloud                    ClusterIP      10.43.134.233   <none>          8080/TCP                                                                                                                                                          3h59m
nextcloud-cluster-rw         ClusterIP      10.43.73.242    <none>          5432/TCP                                                                                                                                                          6m53s
nextcloud-cluster-rw-hl      ClusterIP      None            <none>          5432/TCP                                                                                                                                                          6m53s
nextcloud-minio              ClusterIP      10.43.176.97    <none>          9000/TCP                                                                                                                                                          4h22m
nextcloud-minio-console      ClusterIP      10.43.159.253   <none>          9090/TCP                                                                                                                                                          4h22m
nextcloud-redis-headless     ClusterIP      None            <none>          6379/TCP                                                                                                                                                          4h22m
nextcloud-redis-master       ClusterIP      10.43.21.144    <none>          6379/TCP                                                                                                                                                          4h22m
synapse                      ClusterIP      10.43.222.1     <none>          8448/TCP                                                                                                                                                          4h23m
synapse-replication          ClusterIP      10.43.141.53    <none>          9093/TCP                                                                                                                                                          4h23m
Here's the updated status based on your latest `kubectl get pods -A` and `get svc`.

### Good News
- **Keycloak** is now **1/1 Running** (`keycloak-keycloak-0`).
- PostgreSQL instances for Keycloak, Nextcloud, Meet, and Element are healthy (`*-cluster-rw-0` pods are Running).
- Collabora (`collabora-online`), most frontends, Redis, and MinIO are stable.
- Many services restarted ~35-37m ago (likely from recent Helm upgrades).

### Still Broken (Priority Order)
1. **docs-nginx** → `0/1 CrashLoopBackOff` (30 restarts)  
   This is the reverse proxy in front of Collabora. It is still failing with the same error we saw earlier:  
   `host not found in upstream "docs-backend"`

2. **Nextcloud** → `0/1 Error` (41 restarts) + cronjob crashing  
   Needs fresh logs to diagnose the current error.

3. **Synapse** → `0/1 CrashLoopBackOff` (39 restarts)  
   Still blocked by the OIDC configuration error (`authorization_endpoint: None`).

### Fix for docs-nginx (Do this first – it's quick)

From the service list, the correct backend is **`collabora-online`** (port 9980).

In your **docs** Helm values (the chart that deploys `docs-nginx`), change the upstream/backend setting to:

```yaml
# Most common locations in Bitnami-style or custom "docs" charts:
nginx:
  serverBlock: |-
    upstream backend {
      server collabora-online:9980;
    }
  # OR
  proxy:
    upstream: collabora-online:9980

# Alternative common keys:
# backendService: collabora-online
# collabora:
#   serviceName: collabora-online
```

After updating the values, re-apply with:

```bash
helmfile sync   # or your usual helm upgrade / helmfile apply for the docs part
```

Once `docs-nginx` becomes **1/1 Running**, Collabora integration (used by Nextcloud) should start working.

### Next Steps for the Other Two

**For Synapse (OIDC fix)**  
Since Keycloak is now running, switch to discovery mode. Use this corrected block (replace in your Synapse values):

```yaml
oidcProviders:
  - idp_id: mijnbureau
    idp_name: "MijnBureau authenticatie"
    discover: true
    issuer: "http://keycloak-keycloak-headless.default.svc.cluster.local:8080/realms/master"   # change realm if not "master"
    client_id: "..."
    client_secret: "..."
    client_auth_method: client_secret_post
    scopes: ["openid", "profile"]
    backchannel_logout_enabled: true
    # Remove the manual *_endpoint lines
```

Then upgrade Synapse.

**For Nextcloud**  
Please run these commands and paste the output:

```bash
kubectl logs nextcloud-864d6c9854-9ts7h --tail=150
kubectl logs nextcloud-864d6c9854-9ts7h --previous --tail=100
kubectl logs nextcloud-cronjob-29611550-qcp5x
```

This will show whether it's a trusted domains issue, Redis/Postgres connection, MinIO problem, or maintenance mode.

### Quick Checks You Can Run Now
```bash
# Check if Keycloak is reachable internally
kubectl run test-curl --rm -it --image=curlimages/curl -- curl -I http://keycloak-keycloak-headless:8080/realms/master/.well-known/openid-configuration

# Check docs-nginx logs again after any changes
kubectl logs docs-nginx-658b8bc8d-p27m7 --tail=50
```

Would you like the exact values snippet for **docs-nginx** once you tell me the structure of your docs chart (e.g., is it a custom chart or Bitnami nginx + Collabora)? Or shall we focus on the Nextcloud logs first?

Let me know the output of the Nextcloud logs or which one you want to tackle next!
