# Bureaublad Local Fixes

## Issue: 404 Not Found on `bureaublad.192.168.0.215.sslip.io`

### Root Cause
Ingress hostname was `bureaublad.127.0.0.1.sslip.io` (from an old deployment), but the environment domain was updated to `192.168.0.215.sslip.io` without redeploying.

### Changes applied

#### Ingress (`kubectl patch ingress bureaublad`)
- Changed `spec.rules[0].host` from `bureaublad.127.0.0.1.sslip.io` to `bureaublad.192.168.0.215.sslip.io`

#### Backend deployment env vars (`kubectl set env deployment/bureaublad-backend`)
- `CORS_ALLOW_ORIGINS`: updated to include `https://bureaublad.192.168.0.215.sslip.io` (kept old domain too for transition)
- `TRUSTED_HOSTS`: updated to include `bureaublad.192.168.0.215.sslip.io` (kept old domain too because liveness/readiness probes still send the old `Host` header)
- `OIDC_POST_LOGIN_REDIRECT_URI`: updated to `https://bureaublad.192.168.0.215.sslip.io`
- `OIDC_POST_LOGOUT_REDIRECT_URI`: updated to `https://bureaublad.192.168.0.215.sslip.io`
