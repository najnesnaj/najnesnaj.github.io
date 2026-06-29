# Docs Backend Fixes (Applied 2026-06-29)

## Problems Fixed

### 1. Liveness probe killed backend before workers initialized (CrashLoopBackOff)

The docs-backend pod ran 4 uvicorn workers (`WEB_CONCURRENCY=4`, implicit default) under 500m CPU limit. Worker initialization took ~20-60s, but the liveness probe (`initialDelaySeconds: 10`, `failureThreshold: 3`) killed the pod after ~30s — before workers finished starting. This caused infinite CrashLoopBackOff.

**Fix:** Added a `startupProbe` with 60s initial delay and 6 failure threshold (~120s startup window) in `helmfile/apps/docs/values.yaml.gotmpl`:

```yaml
startupProbe:
  enabled: true
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 6
  successThreshold: 1
```

Applied to live deployment via `kubectl patch`.

### 2. Database credential mismatch (password authentication failed for user "docs")

The PostgreSQL chart upgrade (Bitnami postgresql) regenerated the `docs-cluster-rw` secret with new passwords, but the actual database retained the old passwords. The `/__heartbeat__` endpoint returned 500 because it could not connect to the database.

**Fix:** Reset the `postgres` and `docs` database user passwords to match the current Kubernetes secret:
- Temporarily switched `pg_hba.conf` to `trust` authentication
- Ran `ALTER USER postgres WITH PASSWORD '...'` and `ALTER USER docs WITH PASSWORD '...'`  
- Restored `md5` authentication and reloaded PostgreSQL

### 3. Network policy blocked Keycloak backchannel on port 80

The docs backend's NetworkPolicy blocked egress on port 80. The OIDC backchannel endpoints (`token_endpoint`, `userinfo_endpoint`, `jwks_uri`) used HTTP (`http://keycloak-keycloak/...`) which connects on port 80. When `mozilla-django-oidc` tried to exchange the auth code for tokens, the connection was silently dropped by the network policy.

**Fix:** Added an egress rule for port 80 to Keycloak pods in the `docs-backend` NetworkPolicy:

```yaml
- ports:
    - port: 80
  to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: keycloak
```

Applied both to `helmfile/apps/docs/values.yaml.gotmpl` (under `backend.networkPolicy.extraEgress`) and to the live NetworkPolicy via `kubectl patch`.

## Pre-existing Conditions (Not Changed)

- **OIDC front-channel URLs** (`authorization_endpoint`, `end_session_endpoint`, `issuer`) already use `id.192.168.0.215.sslip.io` (fix applied earlier). No change needed.
- **Celery worker memory** already set to 720Mi limit (fix applied earlier). No change needed.
