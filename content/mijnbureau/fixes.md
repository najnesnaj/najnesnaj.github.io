# Fixes Applied

## 1. Backend CrashLoopBackOff — ASGI startup too slow for liveness probe

**Symptom**: `docs-backend` pods in `CrashLoopBackOff` — uvicorn starts but gets killed by liveness probe before the Django ASGI app finishes loading.

**Root cause**: The ASGI app import (`impress.asgi:application` → `django.setup()`) takes >40 seconds (database checks, app configs, etc.). The default liveness probe killed the container after 3 failures × 10 s = 40 s (`initialDelaySeconds=10`, `periodSeconds=10`, `failureThreshold=3`).

**Fix**: Added a `startupProbe` with `failureThreshold=12` (120 s window) and raised `livenessProbe.initialDelaySeconds` to 90.

```bash
kubectl patch deployment -n default docs-backend -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "docs-backend",
            "livenessProbe": {
              "httpGet": {
                "path": "/__heartbeat__",
                "port": 8000,
                "scheme": "HTTP"
              },
              "initialDelaySeconds": 90,
              "periodSeconds": 10,
              "timeoutSeconds": 5,
              "failureThreshold": 3
            },
            "startupProbe": {
              "httpGet": {
                "path": "/__heartbeat__",
                "port": 8000,
                "scheme": "HTTP"
              },
              "initialDelaySeconds": 10,
              "periodSeconds": 10,
              "failureThreshold": 12
            }
          }
        ]
      }
    }
  }
}'
```

---

## 2. OIDC callback returns 500 — backend cannot reach Keycloak via external URL

**Symptom**: `GET /api/v1.0/callback/?state=...` returns HTTP 500.  
Backend log: `HTTPSConnectionPool(host='id.127.0.0.1.sslip.io', port=443): Failed to establish a new connection: [Errno 111] Connection refused`

**Root cause**: The OIDC backend endpoints (token, userinfo, jwks, logout) were configured as `https://id.127.0.0.1.sslip.io/...`. From inside the pod, `127.0.0.1` resolves to the pod's own loopback interface, not the host where Traefik listens.

**Fix**: Changed the backend-facing OIDC endpoints to use the internal Keycloak ClusterIP service with plain HTTP. The authorization endpoint stays external (the browser redirects there).

```bash
kubectl set env deployment -n default docs-backend \
  OIDC_OP_TOKEN_ENDPOINT=http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/token \
  OIDC_OP_USER_ENDPOINT=http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/userinfo \
  OIDC_OP_JWKS_ENDPOINT=http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/certs \
  OIDC_OP_LOGOUT_ENDPOINT=http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/logout \
  OIDC_VERIFY_SSL=false
```
