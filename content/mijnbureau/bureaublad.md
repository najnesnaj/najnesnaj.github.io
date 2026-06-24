# Bureaublad Fixes

## Changes made to fix bureaublad OIDC login (`authentication_failed` error)

### Root Causes
1. **Missing `REDIS_URL` env var** in backend — the OIDC callback handler stores auth sessions in Redis but the backend had no Redis connection configured
2. **Missing Redis egress rule** in backend network policy — port 6379 blocked
3. **Missing Keycloak egress rule** in backend network policy — port 8080 blocked (token exchange, userinfo, etc.)

### `helmfile/apps/bureaublad/values.yaml.gotmpl`

#### Backend env vars
- Added `REDIS_URL: {{ $redisUrl | quote }}` to `backend.envVars` (was only present in frontend)

#### Backend network policy `extraEgress`
- Added Keycloak rule: port 8080 to pods with `app.kubernetes.io/name: keycloak`
- Added Redis rule: port 6379 to pods with `app.kubernetes.io/name: redis`, `app.kubernetes.io/component: master`

### Live cluster patches
- `kubectl patch networkpolicy bureaublad-backend` — added egress rules for ports 6379 (Redis) and 8080 (Keycloak)
- `kubectl rollout restart deployment bureaublad-backend` — picked up new `REDIS_URL` env var
