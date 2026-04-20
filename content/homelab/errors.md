---
title: 'errors'
weight: 1400
draft: false
---
kubectl get pods -A
NAMESPACE     NAME                                          READY   STATUS             RESTARTS         AGE
default       bureaublad-backend-5d8fd87894-gpxqx           1/1     Running            5 (37m ago)      3h52m
default       bureaublad-frontend-f47f68648-9wqgn           1/1     Running            3 (37m ago)      3h52m
default       bureaublad-redis-master-0                     1/1     Running            3 (37m ago)      3h52m
default       collabora-online-f7b565658-pl6tv              1/1     Running            5 (35m ago)      3h32m
default       docs-minio-78d7fd6cb7-4g987                   1/1     Running            7 (36m ago)      3h53m
default       docs-minio-provisioning-xgdt5                 0/1     Completed          0                3h53m
default       docs-nginx-658b8bc8d-p27m7                    0/1     CrashLoopBackOff   30 (8s ago)      117m
default       docs-postgresql-0                             1/1     Running            4 (37m ago)      3h53m
default       docs-redis-master-0                           1/1     Running            4 (37m ago)      3h53m
default       docs-static-nginx-f65c6fdf-j6225              1/1     Running            4 (37m ago)      3h53m
default       element-cluster-rw-0                          1/1     Running            0                3m25s
default       element-redis-master-0                        1/1     Running            4 (37m ago)      4h19m
default       element-web-cbc6fb6c7-58dq7                   1/1     Running            4 (37m ago)      4h19m
default       grist-minio-6c95f9d67b-t56rs                  1/1     Running            6 (36m ago)      13d
default       grist-minio-console-7fcdd87654-flvp4          1/1     Running            8 (37m ago)      13d
default       grist-minio-provisioning-jv6mh                0/1     Completed          0                4h21m
default       grist-postgresql-0                            1/1     Running            8 (37m ago)      13d
default       grist-redis-master-0                          1/1     Running            8 (37m ago)      13d
default       keycloak-cluster-rw-0                         1/1     Running            0                23m
default       keycloak-keycloak-0                           1/1     Running            1 (6m55s ago)    9m
default       livekit-redis-master-0                        1/1     Running            4 (37m ago)      3h54m
default       livekit-server-29611500-kd7fh                 0/1     Completed          0                51m
default       livekit-server-94cfdbb84-q4f66                1/1     Running            4 (36m ago)      171m
default       livekit-server-job-2nlkn                      0/1     Completed          0                89s
default       meet-backend-56f8565f89-vrvmk                 1/1     Running            0                3m51s
default       meet-cluster-rw-0                             1/1     Running            0                3m54s
default       meet-frontend-55ff9cd986-pzl5n                1/1     Running            4 (37m ago)      4h19m
default       meet-migrate-j4dqz                            0/1     Completed          0                3m51s
default       meet-redis-master-0                           1/1     Running            4 (37m ago)      4h19m
default       meet-static-nginx-759bfbdf95-6d7bc            1/1     Running            4 (37m ago)      4h19m
default       meet-superuser-xjj5j                          0/1     Completed          2                3m51s
default       nextcloud-864d6c9854-9ts7h                    0/1     Error              41 (5m15s ago)   169m
default       nextcloud-cluster-rw-0                        1/1     Running            0                2m35s
default       nextcloud-cronjob-29611550-qcp5x              0/1     CrashLoopBackOff   3 (29s ago)      83s
default       nextcloud-minio-657f9b9999-px6fx              1/1     Running            5 (36m ago)      4h18m
default       nextcloud-minio-console-b99c75845-dzkrw       1/1     Running            4 (37m ago)      4h18m
default       nextcloud-minio-provisioning-sfv4g            0/1     Completed          0                2m35s
default       nextcloud-redis-master-0                      1/1     Running            4 (37m ago)      4h18m
default       synapse-6b4b44fb94-ptk9m                      0/1     CrashLoopBackOff   39 (3m14s ago)   170m
default       synapse-keygen-gv4vb                          0/1     Completed          0                3m21s
kube-system   coredns-67d69c9b5b-bh2pg                      1/1     Running            10 (37m ago)     13d
kube-system   local-path-provisioner-546dfc6456-j44p2       1/1     Running            10 (37m ago)     13d
kube-system   metrics-server-7b9c9c4b9c-jnq8r               1/1     Running            10 (37m ago)     13d
kube-system   svclb-livekit-livekit-server-12f8090a-qcjxv   10/10   Running            30 (37m ago)     3h54m

**Great progress!** Keycloak is now **Running (1/1)** thanks to the PostgreSQL upgrade and (presumably) disabling the config-cli temporarily.

However, several important services are still broken:

### Current Status Summary

| Service          | Status                          | Priority | Notes |
|------------------|----------------------------------|----------|-------|
| **Keycloak**     | 1/1 Running                     | Good     | Main pod is up |
| **docs-nginx**   | 0/1 CrashLoopBackOff (30 restarts) | High     | Still broken (nginx upstream issue) |
| **Nextcloud**    | 0/1 Error (41 restarts)         | High     | Still crashing |
| **Synapse**      | 0/1 CrashLoopBackOff (39 restarts) | High     | Still has OIDC config error |
| Meet / Element / Livekit | Mostly 1/1 Running          | Good     | Some jobs completed |

### 1. Fix docs-nginx (easiest one)

We already know the problem: nginx is looking for upstream **`docs-backend`** which doesn't exist.

The correct service is **`collabora-online`**.

**Action**: Update your docs Helm values and set the upstream to `collabora-online`.

Typical values snippet:

```yaml
nginx:
  serverBlock:
    # or however your chart structures it
    upstream:
      backend: collabora-online
  # Alternative common keys:
  # proxyPass: http://collabora-online:9980
```

Then run your helm upgrade / helmfile sync for the docs part.

After that, `docs-nginx` should go to 1/1.

---

### 2. Fix Synapse (OIDC error)

Synapse is still crashing with the same old error (`authorization_endpoint: None is not of type 'string'`).

Since Keycloak is now running, the best fix is to switch to **automatic discovery**.

Please update your Synapse `values.yaml` (the oidcProviders section) to this:

```yaml
oidcProviders:
  - idp_id: mijnbureau
    idp_name: "MijnBureau authenticatie"
    discover: true                          # ← Important change
    issuer: "http://keycloak-keycloak.default.svc.cluster.local:8080/realms/master"   # ← Adjust realm name if not "master"
    client_id: "synapse"                    # your client ID
    client_secret: "..."                    # from secret
    client_auth_method: client_secret_post
    scopes: ["openid", "profile"]
    backchannel_logout_enabled: true
    # Remove these 4 lines completely when discover: true
    # authorization_endpoint, token_endpoint, userinfo_endpoint, jwks_uri
    user_mapping_provider:
      config:
        # your existing templates...
```

Then upgrade Synapse.

**Quick test for issuer URL**:
```bash
kubectl run curl-test --rm -it --image=curlimages/curl -- curl -I http://keycloak-keycloak.default.svc.cluster.local:8080/realms/master/.well-known/openid-configuration
```

---

### 3. Fix Nextcloud (still in Error state)

Nextcloud has 41 restarts and is in `Error` state.

Please run these logs so we can see the current error:

```bash
kubectl logs nextcloud-864d6c9854-9ts7h -n default --tail=100

kubectl logs nextcloud-864d6c9854-9ts7h -n default --previous --tail=100
```

Also check the cronjob:

```bash
kubectl logs nextcloud-cronjob-29611550-qcp5x -n default
```

Common Nextcloud issues after upgrades:
- `nextcloud.host` / trusted domains mismatch
- Redis or database connection problems
- Object storage (MinIO) config
- Maintenance mode stuck

### Immediate Next Steps for You

1. **Fix docs-nginx** first (change upstream to `collabora-online`) — this is quick.
2. Run the two log commands for **Nextcloud** and paste the output here.
3. Update Synapse to use `discover: true` with the internal Keycloak URL.

Would you like me to give you the exact `values.yaml` snippet for **docs-nginx** once you confirm how the "docs" chart is structured? Or shall we start with the Nextcloud logs?

Also, what is the name of your Keycloak realm (is it `master` or something else like `mijnbureau`)? That will help with the Synapse issuer URL.
