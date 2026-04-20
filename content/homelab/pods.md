---
title: 'pods'
weight: 1200
draft: false
---




Here's the current situation after your reboot with more CPUs:

### Progress
- **Keycloak** is now **1/1 Ready** — great, the main app is healthy.
- Most databases (PostgreSQL, Redis) and core services like **Meet**, **Grist**, **Element-web**, **Nextcloud** (minio/redis/postgres) are Running.
- Several provisioning jobs have completed.

### Remaining Blockers

1. **ImagePullBackOff** (biggest current issue)
   - `docs-frontend`, `docs-y-provider`
   - `livekit-server` pods
   - `nextcloud` (Init:ImagePullBackOff)
   - `collabora-online` (one terminating, new one Pending)

   This is common on **k3s + containerd** (especially NixOS) after a reboot or when many images are pulled at once. The images (mostly from `docker.io/bitnami/...` or quay.io) are not cached properly or the pull is failing due to network/registry hiccups.

2. **Pending pods** (Bureaublad full stack, most of **Docs** backend/celery/nginx etc.)
   - Still waiting for scheduling or image pull.

3. **Synapse** in **CrashLoopBackOff** (12 restarts)
   - Matrix Synapse is crashing repeatedly. Common causes: wrong config (homeserver.yaml), database connection issues, missing secrets, or initial migration problems.

4. **collabora-online** is flapping (old pod terminating, new one Pending).

### Quick Actions (Run These Now)

**Fix ImagePullBackOff first** (retry pulls):

```bash
# Delete pods that are failing to pull images (they will be recreated)
kubectl delete pod docs-frontend-d7c8fdf49-p9grz docs-y-provider-5b555b6f56-tdlxn
kubectl delete pod livekit-server-5c8c997b7b-kqf46 livekit-server-7447dfcf8b-mvbf4
kubectl delete pod nextcloud-864d6c9854-dr7rn
kubectl delete pod collabora-online-f7b565658-pl6tv   # the new one

# Force a rollout for safety
kubectl rollout restart deployment/docs-frontend
kubectl rollout restart deployment/livekit-server
```

Wait 2–3 minutes and run `kubectl get pods -A` again.

**Check Keycloak logs** (just to be sure it's fully happy):

```bash
kubectl logs keycloak-keycloak-0 -c keycloak --tail=50
```

**Check Synapse crash reason** (very important):

```bash
kubectl logs synapse-6b4b44fb94-4nztg --previous   # shows the last crash
kubectl logs synapse-6b4b44fb94-4nztg
kubectl describe pod synapse-6b4b44fb94-4nztg | tail -30
```

**Re-run Helmfile** (after cleaning the above):

```bash
helmfile -e demo sync -f helmfile.yaml.gotmpl \
  --values $(pwd)/local-values.yaml \
  --prune --timeout 1800
```

### Recommended Values to Add to `local-values.yaml`

Add this block to make future syncs more reliable:

```yaml
# Disable post-install hooks that cause timeouts
keycloakConfigCli:
  enabled: false

minio:
  provisioning:
    enabled: false

# Help with slow startup / image pull issues
keycloak:
  readinessProbe:
    initialDelaySeconds: 90
    failureThreshold: 30

# Lower resources for Docs and LiveKit (they seem heavy)
docs:
  resources:
    requests:
      cpu: "200m"
      memory: "512Mi"
livekit:
  server:
    resources:
      requests:
        cpu: "300m"
        memory: "1Gi"
```

### Next Steps After Cleaning
1. Run the delete/rollout commands above.
2. Paste the **new** `kubectl get pods -A`.
3. Paste the output of the Synapse logs + describe (this one needs specific fixing).

Once ImagePullBackOff is resolved, most things should stabilize quickly. The extra CPU helped a lot — we're mainly fighting image caching and a few app-specific issues now.

Which apps are your highest priority right now (Keycloak is good, but e.g. Nextcloud, Docs, Synapse, Bureaublad)? I can give more targeted fixes.



============================================================

Here's a clear breakdown of your latest `kubectl get pods -A`:

### Good Progress
- **Keycloak** is stable at **1/1 Running**.
- **LiveKit server** is now Running (one replica succeeded).
- **Meet**, **Element**, **Grist**, and **Docs** core services (DBs, Redis, MinIO, static nginx, celery) are mostly Running.
- **Synapse** pod was recreated (`synapse-6b4b44fb94-d9rxd`) and is now **Pending** — this is better than the previous CrashLoopBackOff.

### Current Main Problems

1. **ImagePullBackOff** (still blocking several apps)
   - `docs-frontend`, `docs-y-provider`
   - `collabora-online` (old pod terminating, new one ContainerCreating)

2. **Pending pods** (resource or dependency issues)
   - Full **Bureaublad** stack (backend, frontend, redis)
   - Most **Docs** backend pods (createsuperuser, migrate, docspec, nginx)

3. **Nextcloud** in **CrashLoopBackOff** (5 restarts on main pod + cronjob)
   - Likely a configuration issue (common with Bitnami Nextcloud Helm chart after changes to hostname, ingress, or admin settings).

4. **ClamAV** re-appeared and is **Pending** (you commented it out earlier — it shouldn't be installing).

### Immediate Recommended Actions

**Step 1: Fix ImagePullBackOff (retry pulls)**

```bash
kubectl delete pod docs-frontend-d7c8fdf49-p9grz docs-y-provider-5b555b6f56-tdlxn collabora-online-f7b565658-pl6tv
```

Wait 1–2 minutes, then check again.

**Step 2: Fix Synapse (OIDC configuration error)**

The previous error was:
> `Error in configuration at 'oidc_providers.<item 0>.authorization_endpoint': None is not of type 'string'`

This usually happens when `discover: true` but Keycloak discovery fails, or the provider config is incomplete.

**Best quick fix** — temporarily disable OIDC in Synapse so it starts:

Add to your `local-values.yaml`:

```yaml
synapse:
  homeserverConfig:
    oidc_providers: []   # disable OIDC for now
```

Then:

```bash
helmfile -e demo sync -f helmfile.yaml.gotmpl --values $(pwd)/local-values.yaml --prune --timeout 1200
kubectl delete pod synapse-6b4b44fb94-d9rxd
```

Once Synapse is Running, we can re-enable OIDC with a correct Keycloak config.

**Step 3: Investigate Nextcloud CrashLoopBackOff**

```bash
kubectl logs nextcloud-864d6c9854-dr7rn --previous
kubectl logs nextcloud-864d6c9854-dr7rn
kubectl describe pod nextcloud-864d6c9854-dr7rn | tail -40
```

Paste the output — common causes are wrong `nextcloud.host` value, missing admin password, or Redis/DB connection issues.

**Step 4: Clean up ClamAV (again)**

```bash
helm uninstall clamav
```

### General Advice
Your cluster is getting much better with the extra CPU, but you still have **too many apps** trying to start simultaneously on a single node. Consider temporarily disabling heavy ones (Bureaublad, Docs, Collabora) in your helmfile until the core ones (Keycloak, Nextcloud, Meet, Synapse) are stable.

Would you like:
- A ready-to-paste block to disable OIDC in Synapse + lowered resources for Docs/Nextcloud?
- Or should I help debug Nextcloud once you paste the logs?

Run the ImagePullBackOff cleanup + the Synapse OIDC disable, then share the new `kubectl get pods -A` and the Nextcloud logs. We'll keep knocking these down one by one.
