# Docs 500 Error Fix

## Problems

### 1. OIDC authorization endpoint uses unresolvable hostname

The OIDC front-channel endpoints (`authorization_endpoint`, `end_session_endpoint`, `issuer`) used `id.kubernetes.local` which doesn't resolve in the browser. The browser was redirected to `https://id.kubernetes.local/...` and couldn't reach Keycloak.

### 2. Network policy blocks Keycloak backchannel on port 80

After fixing #1, the callback returned a 500 error. The docs backend's Kubernetes `NetworkPolicy` blocked egress on port 80. The OIDC backchannel endpoints (`token_endpoint`, `userinfo_endpoint`, `jwks_uri`) were configured as HTTP (`http://keycloak-keycloak/...`) which uses port 80. When the `mozilla-django-oidc` callback handler tried to exchange the auth code for tokens via `POST` to the token endpoint, the connection was silently dropped by the network policy, causing a `ConnectionError` → 500.

The network policy only allowed egress on:
- Database, Redis, MinIO ports
- Port 443 (HTTPS) — used for external AI and Keycloak front-channel
- Port 4444 (yProvider)
- Port 4000 (docspec)

Port 80 was missing.

## Fixes

### Fix 1: Use publicly resolvable hostname for OIDC front-channel endpoints

**File:** `helmfile/environments/demo/mijnbureau.yaml.gotmpl`

Changed `id.kubernetes.local` → `id.127.0.0.1.sslip.io` (resolves to 127.0.0.1 via sslip.io) for browser-facing endpoints:

```yaml
issuer: "https://id.127.0.0.1.sslip.io/realms/mijnbureau"
authorization_endpoint: "https://id.127.0.0.1.sslip.io/realms/mijnbureau/protocol/openid-connect/auth"
end_session_endpoint: "https://id.127.0.0.1.sslip.io/realms/mijnbureau/protocol/openid-connect/logout"
```

The backchannel endpoints (`token_endpoint`, `userinfo_endpoint`, `jwks_uri`, `introspection_endpoint`) remain as internal `http://keycloak-keycloak/...` since those are called from within the cluster.

### Fix 2: Allow HTTP egress to Keycloak in network policy

**File:** `helmfile/apps/docs/values.yaml.gotmpl`

Added a network policy egress rule allowing HTTP (port 80) specifically to Keycloak pods:

```yaml
# Allow http egress for keycloak backchannel (token, userinfo, jwks)
- ports:
    - port: 80
  to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: keycloak
```

## Additional Issues Found & Fixed

### 3. Database credential mismatch (docs backend CrashLoopBackOff)

The docs PostgreSQL pod's `docs` user password in the database didn't match the Kubernetes secret after helm upgrades. The `helmfile sync` triggered a PostgreSQL chart upgrade that rotated the secret values, but the actual database retained the old password. This caused authentication failures (`password authentication failed for user "docs"`).

**Fix:** Reset database user passwords to match the current secret values:
```sql
ALTER USER postgres WITH PASSWORD '<current-postgres-password>';
ALTER USER docs WITH PASSWORD '<current-docs-password>';
```

### 4. Liveness probe kills backend before workers initialize

4 uvicorn workers (`WEB_CONCURRENCY=4`) initialize simultaneously under 500m CPU limit, taking ~20-60s to start. The liveness probe (`initialDelaySeconds: 10`, `failureThreshold: 3`) killed the pod after 30s — before workers could finish initialization. This caused infinite CrashLoopBackOff.

**Fix:** Enabled a `startupProbe` in `helmfile/apps/docs/values.yaml.gotmpl` with 60s initial delay and 6 failure threshold (total ~120s startup window):

```yaml
startupProbe:
  enabled: true
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6
  successThreshold: 1
```

### 5. Celery worker OOMKilled (pre-existing)

The docs celery worker was OOMKilled (exit 137) with 384Mi memory limit due to Celery prefork autoscaling (min=3, max=9).

**Fix:** Increased celery worker memory limit to 720Mi in `helmfile/environments/demo/mijnbureau.yaml.gotmpl`.

### 6. Database password rotated by helmfile sync

Each `helmfile sync` upgrades the PostgreSQL chart, which can regenerate the `docs-cluster-rw` secret with a new password. The database retains the previous password, causing authentication failures.

**Workaround:** After each `helmfile sync`, run `ALTER USER` to sync the database with the current secret. A proper fix would pin the PostgreSQL password in the chart values.
