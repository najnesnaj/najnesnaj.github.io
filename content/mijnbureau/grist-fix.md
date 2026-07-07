# Grist CrashLoopBackOff Fix

## Symptom

```
default   grist-c6f7bdf5d-5xw8b   0/1   CrashLoopBackOff   13 (3m29s ago)   54m
```

## Root Cause

Both pods died repeatedly with:

```
Error: self-signed certificate
    at TLSSocket.onConnectSecure (node:_tls_wrap:1679:34)
    ...
  code: 'DEPTH_ZERO_SELF_SIGNED_CERT'
```

Grist connects to the OIDC provider (Keycloak) at `https://id.192.168.0.215.sslip.io/realms/mijnbureau` over HTTPS.
The demo Kind cluster uses self-signed TLS certificates, which Node.js rejects by default (`NODE_TLS_REJECT_UNAUTHORIZED=1`).

## Fix

Set `NODE_TLS_REJECT_UNAUTHORIZED=0` on the Grist container to allow self-signed certificates.

### Files changed

1. **`helmfile/apps/grist/values.yaml.gotmpl`** — Added `NODE_TLS_REJECT_UNAUTHORIZED=0` to `extraEnvVars` so the fix survives helmfile redeploy.

2. **Live patch** — Applied directly to the deployment:
   ```bash
   kubectl patch deployment grist -p '{"spec":{"template":{"spec":{"containers":[{"name":"grist","env":[{"name":"NODE_TLS_REJECT_UNAUTHORIZED","value":"0"}]}]}}}}'
   ```

### Verification

After the fix, both pods started successfully with 0 restarts:

```
NAME                     READY   STATUS    RESTARTS   AGE
grist-5f9df685d4-mfvgw   1/1     Running   0          27s
grist-5f9df685d4-qbdmd   1/1     Running   0          27s
```

### Note

This is acceptable for the demo/dev environment. For production, the internal PKI should use a trusted CA so this env var can be removed.
