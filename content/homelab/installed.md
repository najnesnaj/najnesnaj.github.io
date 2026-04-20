---
title: 'installed'
weight: 1300
draft: false
---
Your `kubectl get pods -A` output shows a mostly healthy cluster with many self-hosted services (Nextcloud, Synapse/Matrix, "docs" which looks like OnlyOffice/Collabora-related, Meet, Element, Grist, etc.). However, there are a few problematic pods in **CrashLoopBackOff**:

- **docs-nginx-658b8bc8d-9pwzl** (namespace: default) — 0/1, CrashLoopBackOff, 7 restarts
- **nextcloud-864d6c9854-9ts7h** — 0/1, CrashLoopBackOff, 6 restarts
- **nextcloud-cronjob-29611390-j45x5** — 0/1, CrashLoopBackOff, 4 restarts
- **synapse-6b4b44fb94-ptk9m** — 0/1, CrashLoopBackOff, 6 restarts

All other pods (including most databases like PostgreSQL/Redis/MinIO, frontends, and system pods) are Running fine.

### Quick Diagnosis Steps
**CrashLoopBackOff** means the container starts but exits with a non-zero code (crash or error), so Kubernetes keeps restarting it with increasing backoff delays. Common root causes include:
- Application misconfiguration (wrong env vars, missing secrets/config, DB connection failure, etc.)
- Resource issues (OOMKilled — out of memory)
- Volume/PV mount problems
- Init container failures
- Bugs or startup script errors in the app

To find the exact cause, run these commands (replace `<pod-name>` with the full name, e.g. `nextcloud-864d6c9854-9ts7h`):

1. **Check detailed events and state** (most important first step):
   ```
   kubectl describe pod <pod-name> -n default
   ```
   - Look under **Events** at the bottom for clues (e.g., "Error", "Back-off restarting", OOMKilled, probe failures, volume mount issues).
   - Check the **Last State** or **State** section for the container — it often shows the exit code (e.g., 137 = OOMKilled, 1 = general error).

2. **View logs** (this usually reveals the real error):
   ```
   kubectl logs <pod-name> -n default
   ```
   - For previous (crashed) instance: `kubectl logs <pod-name> -n default --previous`
   - For the cronjob one: same, but it might be a short-lived job.

3. **Check recent events cluster-wide** (helpful context):
   ```
   kubectl get events -n default --sort-by=.metadata.creationTimestamp
   ```

### Likely Specific Issues Based on Your Setup
- **Nextcloud pods** (main + cronjob): Common causes are database connection problems (PostgreSQL not ready or wrong creds), Redis issues, missing MinIO config, or incorrect `NEXTCLOUD_*` environment variables / admin user setup. The cronjob often fails if the main app can't initialize properly. Also check if persistent volumes for data/config are mounted correctly.
- **Synapse** (Matrix homeserver): Frequently fails due to PostgreSQL connection issues, missing signing key (there's a `synapse-keygen` job that completed — did it succeed?), config file problems (homeserver.yaml), or database migration errors.
- **docs-nginx**: This looks like the Nginx frontend/proxy for OnlyOffice/Collabora ("docs" namespace services). It could be a config error in nginx.conf, inability to reach the backend (Collabora Online pod), or port binding issues.

Most of your other services (Element, Meet, Grist, LiveKit, etc.) look stable, so this seems isolated to recent changes or a shared dependency (e.g., DB/network hiccup during deployment).

### Next Steps / Fixes
- Run the `describe` and `logs` commands above and share the output if you want more targeted help.
- If logs show a connection error to PostgreSQL/Redis/MinIO → check those pods' logs and ensure services are reachable (`kubectl get svc -n default`).
- If OOMKilled → increase resource limits/requests in the Deployment/StatefulSet.
- Temporary workaround: Delete the crashing pod to let the controller recreate it (sometimes clears transient issues):
  ```
  kubectl delete pod <pod-name> -n default
  ```
- Check Helm values or manifests if you installed via Helm (common for these apps) — recent changes to hostnames, domains, or secrets often cause this.

Once you paste the output from `kubectl describe pod` + `kubectl logs` for the crashing ones, I can help pinpoint the exact fix. In the meantime, start with those two commands on the affected pods!
