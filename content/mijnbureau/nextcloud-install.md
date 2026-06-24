# Nextcloud Installation Modifications

## Summary of changes made to fix OIDC authentication, MinIO, Redis, and Keycloak issues

### 1. Keycloak Configuration

#### `helmfile/apps/keycloak/keycloak.yaml.gotmpl`
- Changed `proxyHeaders` from `"forwarded"` back to `"xforwarded"` (Bitnami entrypoint converts `xforwarded` → `--proxy-headers=xforwarded`, which is valid for Keycloak 26+)
- Added `extraEnvVars` wiring from `.Values.application.keycloak.extraEnvVars` to allow environment-specific overrides

#### `helmfile/environments/demo/mijnbureau.yaml.gotmpl`
- Added `extraEnvVars` block in `application.keycloak`:
  - `KC_PROXY_HEADERS: xforwarded` (was incorrectly `x-forwarded` with hyphen, which Keycloak rejects)
  - `KC_HOSTNAME_STRICT: false` (allows mixed frontchannel/backchannel URLs)
  - `KC_HOSTNAME_BACKCHANNEL_DYNAMIC: true` (Keycloak returns internal HTTP URLs for backchannel endpoints based on incoming Host header)
  - `KC_HTTP_ENABLED: true` (enables HTTP listener for internal traffic)
- Added `authentication.client.nextcloud` credentials block
- Added `application.nextcloud.oidc.discoveryUri: "http://keycloak-keycloak/realms/mijnbureau/.well-known/openid-configuration"`

### 2. Nextcloud OIDC Configuration

#### `helmfile/apps/nextcloud/values.yaml.gotmpl`
- Added `discoveryUri` with fallback to `http://keycloak-keycloak/realms/mijnbureau/.well-known/openid-configuration`
- Added `checkBearer: true` and `bearerProvisioning: true` to OIDC provider config
- Changed `externalRedis.existingSecret: "nextcloud-redis"` and `existingSecretPasswordKey: "redis-password"` (instead of `externalRedis.password` which helm would recompute on every sync)

### 3. Pre-start Hook for Nextcloud OIDC Provider

#### `helmfile/apps/nextcloud/values.yaml.gotmpl`
- Added `extraDeploy` ConfigMap (`nextcloud-oidc-pre-start`) with script `oidc-provider-update.sh`
- Mount path: `/docker-entrypoint-hooks.d/before-starting/` (Bitnami convention, NOT `pre-start/`)
- Script permissions: `defaultMode: 493` (octal `0755`)
- Script actions:
  - Run `occ config:system:set allow_local_remote_servers --value true --type boolean` (system-level, required by `RemoteHostValidator`)
  - Run `occ user_oidc:provider keycloak` with `--check-bearer=1`, `--bearer-provisioning=1`, `--unique-uid=1` to update the existing provider in-place (keeps stable numeric ID)

### 4. Redis Password Fix

#### `helmfile/apps/nextcloud/charts/nextcloud/templates/_helpers.tpl`
- Fixed typo: `ExistingSecretSecretPasswordKey` → `existingSecretPasswordKey` in `nextcloud.redis.secretPasswordKey` helper
- This bug caused the chart to always look for key `password` in the secret instead of respecting the configured `existingSecretPasswordKey` value

### 5. Network Policy for Docs

#### `helmfile/environments/demo/mijnbureau.yaml.gotmpl`
- Changed `docs.backend.networkPolicy.extraEgress` port from `80` to `8080`
- Kubernetes NetworkPolicy egress rules are evaluated after DNAT, so the destination port is the container port (8080), not the service port (80)

### 6. Bureaublad Backend Fix (Redis + Network Policy)

#### `helmfile/apps/bureaublad/values.yaml.gotmpl`
- Added `REDIS_URL` env var to backend section (was missing, causing OIDC callback to fail when storing auth session)
- Added Redis egress rule (port 6379) to backend `networkPolicy.extraEgress`
- Added Keycloak OIDC egress rule (port 8080) to backend `networkPolicy.extraEgress`

#### `helmfile/apps/bureaublad/values.yaml.gotmpl`
- Added Keycloak egress rule to backend `networkPolicy.extraEgress`:
  - Port `8080` (Keycloak container port, post-DNAT)
  - Targets pods with `app.kubernetes.io/name: keycloak`
- This is needed because the bureaublad backend exchanges OIDC authorization codes for tokens via `http://keycloak-keycloak/.../token` (HTTPS to the public endpoint works for auth redirect, but the token exchange uses internal HTTP)

### 7. MinIO Credentials Fix

- `nextcloud-externalminio` secret had a different password than `nextcloud-minio` root password
- Root cause: the initial helm deploy generated different SHA1 hashes from the derived password
- Fix: patched `nextcloud-externalminio` secret to match `nextcloud-minio` root password
- This resolved the "Error while writing stream to object store" / `SignatureDoesNotMatch` errors

### 7. Files Modified

| File | Change |
|---|---|
| `helmfile/environments/demo/mijnbureau.yaml.gotmpl` | Keycloak extraEnvVars, egress port fix, OIDC discovery URI, Nextcloud client credentials |
| `helmfile/apps/keycloak/keycloak.yaml.gotmpl` | proxyHeaders reverted to xforwarded, extraEnvVars wiring |
| `helmfile/apps/nextcloud/values.yaml.gotmpl` | OIDC config, pre-start hook, externalRedis with existingSecret |
| `helmfile/apps/nextcloud/charts/nextcloud/templates/_helpers.tpl` | Fixed existingSecretPasswordKey typo |
| `helmfile/apps/docs/values.yaml.gotmpl` | Reads extraEgress from environment config |
