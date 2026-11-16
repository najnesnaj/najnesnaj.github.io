# MijnBureau installation — remaining issues and follow-up

This document records the remaining issues and recommended follow-up after deploying MijnBureau (`demo`, `nano`-oriented overlay, `OVERLAY_VERSION=7`) to namespace `mijnbureau` on the Talos/Kubernetes homelab cluster via ArgoCD + Helmfile CMP.

**Status snapshot (end of run):** core Deployments/StatefulSets and application workloads are running/ready, wildcard TLS ingresses are in place, Keycloak is reachable, and the `mijnbureau` realm was bootstrapped manually. The ArgoCD Application is **not** in a clean synced/healthy state due to hook/operation failures (see below).

## Remaining issues

### 1. ArgoCD Application sync is not clean
- **Observed:** `argocd/mijn-bureau` ended as `Failed` / `OutOfSync` / `Degraded` with repeated retries (e.g. “one or more synchronization tasks completed unsuccessfully (retried 5 times)”).
- **Impact:** Desired manifests are effectively applied and workloads are healthy, but ArgoCD does not report a reconciled/synced state and may continue retrying operations.
- **Likely causes:** hook Jobs/tasks that failed, were deleted, or became stuck during earlier attempts (notably minio provisioning hooks and keycloak-config-cli image pulls) and/or stale operation state.
- **Notes:** A naive app recreate/full sync can re-run PostSync hooks and stall again if hook images are slow/unavailable.

### 2. `keycloak-config-cli` hook not converged declaratively
- **Observed:** `docker.io/adorsys/keycloak-config-cli:6.5.1-26.5.5` remained stuck in `ContainerCreating` (image pull) on nodes for an extended period, blocking realm bootstrap.
- **Workaround applied:** `mijnbureau` and `master` realm settings were imported manually via `kcadm.sh` in `keycloak-0` using config from `ConfigMap/keycloak-config-cli` and secrets from `Secret/keycloak-config-cli`.
- **Impact:** OIDC discovery/realm exists now, but the declarative config-cli hook path is not proven healthy in-cluster; future config drift may not be reconciled automatically until the hook can run.

### 3. End-to-end application/OIDC validation incomplete
- **Observed checks:** HTTPS reachability via `192.168.0.192:443` with SNI/host resolve returned e.g. `id` 302, `element` 200, `docs/drive/projects/calendars/bureaublad/collabora/conversations` 200, matrix `/_matrix/client/versions` 200; static hosts (`static-docs`, `static-drive`, `static-conversations`) returned 404 on `/`.
- **Not fully validated:** browser login flows, Keycloak client redirect URIs/secrets per app, token exchange, Synapse/OIDC integration behavior, cross-app SSO/logout, and app-specific post-install functionality/data paths.

### 4. Known/tolerated warnings and environment gaps
- **Repeated resource warnings:** duplicate `traefik.io/Middleware/mijnbureau/hsts-header` and `NetworkPolicy/mijnbureau/default-deny-ingress` observed (tolerated).
- **HPAs/metrics:** horizontal autoscaling disabled in overlay because no metrics-server is installed; HPA-related issues were a prior sync blocker and may recur if re-enabled without metrics support.
- **Residual components:** `argocd/helmfile-image-prepull` DaemonSet and other leftover operational artifacts may remain depending on prior state; review and clean up if unnecessary.

### 5. Hook/image reliability on this cluster
- **Observed:** hook Jobs (minio provisioning, keycloak-config-cli) were sensitive to image pull latency/availability on specific nodes despite configured registry mirrors; some provisioning was completed manually (MinIO buckets: `conversations-media-storage`, `docs`, `drive`, `projects`).
- **Impact:** future syncs that (re)create hooks may hang or fail until images are cached/available.

## Follow-up actions

1. **Stabilize ArgoCD sync**
   - Inspect current operation/hook failures: `kubectl -n argocd get app mijn-bureau -o yaml` (operation state, sync result, hook phases/messages) and related Jobs/Pods in `mijnbureau`.
   - Ensure required hook images are pullable/cached on all relevant nodes (or adjust hook job scheduling/image policy as appropriate).
   - Decide on a controlled reconciliation: re-run/repair failed hooks, then perform a fresh sync/app recreate with a forced render (restart repo-server and/or flush Redis / bump overlay env) only when hooks will complete cleanly.
   - Target end state: `Synced` and `Healthy` with no failing hook tasks.

2. **Make Keycloak configuration declarative again**
   - Pre-pull or otherwise make `adorsys/keycloak-config-cli` reliably available, then run the `keycloak-config-cli` Job (or allow ArgoCD to run it) and confirm it completes successfully.
   - Verify realm/clients/users match the rendered config (`ConfigMap/Secret: keycloak-config-cli`) and that manual bootstrap did not diverge from desired state.

3. **Validate application functionality**
   - Add local name resolution for `*.mijnbureau.kubernetes.local` to `192.168.0.192` and test via browser with the self-signed wildcard cert trusted/accepted as needed.
   - Exercise login/SSO for enabled apps (Keycloak, Element/Matrix, Docs, Drive, Projects, Calendars, Bureaublad, Conversations, Collabora) and confirm redirect/callback behavior.
   - Confirm Synapse and OIDC-dependent integrations work with the mixed browser/in-cluster endpoint configuration.

4. **Clean up and harden**
   - Remove or reconcile leftover DaemonSets/Jobs/pods/artifacts no longer needed (e.g. image-prepull helpers, failed historical Jobs) after confirming they are safe to delete.
   - Revisit HPA enablement only after installing/configuring metrics-server and validating ArgoCD sync behavior.
   - Keep and review the CMP overlay/patches in `/tmp/opencode/argocd-helmfile-cmp.yaml` and `/tmp/opencode/application-mijn-bureau.yaml`; persist them in the repo/IaC if this configuration should be reproducible.

5. **Documentation**
   - Keep [`installation-mijnbureau.md`](./installation-mijnbureau.md) aligned with any further fixes (hook handling, image pinning/mirroring, final ArgoCD sync procedure, and validated app-specific steps).

## References
- Installation notes and fixes: [`installation-mijnbureau.md`](./installation-mijnbureau.md)
- Upstream: [MinBZK/mijn-bureau-infra](https://github.com/MinBZK/mijn-bureau-infra), [docs/getting_started/install](https://minbzk.github.io/mijn-bureau-infra/docs/getting_started/install), [docs/gitops](https://minbzk.github.io/mijn-bureau-infra/docs/gitops)
