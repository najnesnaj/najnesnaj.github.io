# MijnBureau installation — remaining issues and follow-up

This document records the remaining issues and recommended follow-up after deploying MijnBureau (`demo`, `nano`-oriented overlay, current `OVERLAY_VERSION=13`) to namespace `mijnbureau` on the Talos/Kubernetes homelab cluster via ArgoCD + Helmfile CMP.

**Status snapshot (end of run):** core Deployments/StatefulSets and application workloads are running/ready, wildcard TLS ingresses are in place, Keycloak is reachable, the `mijnbureau` realm was bootstrapped manually, and the ArgoCD Application is **`Synced` / `Healthy`** with a clean `Succeeded` operation and no `SyncError`/`ComparisonError`. See [`installation-mijnbureau.md`](./installation-mijnbureau.md#1161-resolving-a-stuckfailed-sync-one-or-more-synchronization-tasks-completed-unsuccessfully) for the CMP fixes that stabilised it.

## Resolved issues

### 1. ArgoCD Application sync is not clean — RESOLVED
- **Was:** `argocd/mijn-bureau` ended as `Failed` / `OutOfSync` / `Degraded` with repeated retries ("one or more synchronization tasks completed unsuccessfully (retried 5 times)").
- **Root causes fixed in the CMP post-render script:**
  - `imagePullPolicy: Always` → `IfNotPresent` was applied to all workloads including Jobs, whose `spec.template` is immutable — ArgoCD patch failed on `synapse-keygen`. The patch is now scoped to non-Job/CronJob workloads.
  - Null-valued ConfigMap data (`FRONTEND_JS_URL: `) caused a permanent `OutOfSync` on `conversations`/`drive` and a `selfHeal` re-sync loop; those keys are now dropped during render.
  - An apostrophe in an awk comment broke the single-quoted CMP script; removed.
- **Verified:** `Synced` / `Healthy`, `Succeeded`, no error conditions, 0 automatic re-syncs in 5 minutes (only tolerated `RepeatedResourceWarning`s remain). Hook image pulls can still be slow; see section 5.

## Remaining issues

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

1. **ArgoCD sync — DONE** (see resolved issue 1 and installation guide section 11.6.1). Application is `Synced`/`Healthy` with no failing hook tasks and no `selfHeal` loop. Keep hook Jobs untouched by workload-template patches, and keep the null-ConfigMap-key drop in the CMP render. If hook image pulls stall again, warm the images on the nodes rather than changing Job templates.

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
