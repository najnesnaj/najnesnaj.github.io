# Nextcloud OIDC Fixes

## Root Cause

The Nextcloud `user_oidc` app fetches the OIDC provider configuration via `--discoveryuri`. Since the app does not support individual endpoint overrides, it uses the URLs from the discovery response for both the browser redirect (`authorization_endpoint`) and server-side calls (`token_endpoint`, `userinfo_endpoint`, `jwks_uri`).

The old discovery URI was `https://id.127.0.0.1.sslip.io/realms/mijnbureau/.well-known/openid-configuration` which:
1. Resolves (via CoreDNS rewrite) to the ingress controller's ClusterIP — works
2. But the ingress controller's TLS certificate uses a mkcert CA that the Nextcloud pod does not trust — TLS verification fails → "Could not reach the OpenID Connect provider"

## Solution

Leverage Keycloak's `KC_HOSTNAME_BACKCHANNEL_DYNAMIC` to return different URLs in the discovery response for frontchannel vs. backchannel endpoints:

| Endpoint | Type | URL | Purpose |
|---|---|---|---|
| `authorization_endpoint` | frontchannel | `https://id.127.0.0.1.sslip.io/...` | Browser redirect (public) |
| `token_endpoint` | backchannel | `http://keycloak-keycloak/...` | Server-to-server (internal, no TLS) |
| `userinfo_endpoint` | backchannel | `http://keycloak-keycloak/...` | Server-to-server (internal, no TLS) |
| `jwks_uri` | backchannel | `http://keycloak-keycloak/...` | Server-to-server (internal, no TLS) |

This avoids TLS entirely for server-side communication.

## Files Modified

### 1. `helmfile/apps/keycloak/keycloak.yaml.gotmpl` (line 57)

Wired through `extraEnvVars` from the environment config so that `KC_HOSTNAME_BACKCHANNEL_DYNAMIC: true` takes effect.

**Change:**
```yaml
extraEnvVars: {{ .Values.application.keycloak.extraEnvVars | default list | toYaml | nindent 2 }}
```

The existing `application.keycloak.extraEnvVars` in the demo environment already contained:
```yaml
- name: KC_HOSTNAME_BACKCHANNEL_DYNAMIC
  value: "true"
- name: KC_HOSTNAME_STRICT
  value: "false"
```

The Bitnami Keycloak chart already sets `KC_HOSTNAME_URL` to `https://id.127.0.0.1.sslip.io` (via `production: true` + ingress hostname). With `KC_HOSTNAME_BACKCHANNEL_DYNAMIC: true`, Keycloak uses the frontend URL for frontchannel endpoints and the request URL for backchannel endpoints in the discovery response.

### 2. `helmfile/apps/nextcloud/values.yaml.gotmpl` (line 160)

Made `discoveryUri` configurable with a fallback to the old `authentication.oidc.issuer`-based URL.

**Before:**
```yaml
discoveryUri: "{{ .Values.authentication.oidc.issuer }}/.well-known/openid-configuration"
```

**After:**
```yaml
discoveryUri: "{{ .Values.application.nextcloud.oidc.discoveryUri | default (printf "%s/.well-known/openid-configuration" .Values.authentication.oidc.issuer) }}"
```

### 3. `helmfile/environments/demo/mijnbureau.yaml.gotmpl` (lines 63-65, 108-109)

**Added `authentication.client.nextcloud`:**
```yaml
authentication:
  client:
    nextcloud:
      client_id: "nextcloud"
      client_secret: "f57f464dc535fba69c1fea65eb5722e02999da43"
```

**Added `application.nextcloud.oidc.discoveryUri`:**
```yaml
application:
  nextcloud:
    oidc:
      discoveryUri: "http://keycloak-keycloak/realms/mijnbureau/.well-known/openid-configuration"
```

## How It Works

1. Nextcloud pod fetches discovery document from `http://keycloak-keycloak/realms/mijnbureau/.well-known/openid-configuration` (internal HTTP, no TLS)
2. Keycloak (`KC_HOSTNAME_BACKCHANNEL_DYNAMIC: true` + `KC_HOSTNAME_URL` set to public URL) returns:
   - `authorization_endpoint`: `https://id.127.0.0.1.sslip.io/realms/mijnbureau/protocol/openid-connect/auth`
   - `token_endpoint`: `http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/token`
   - `userinfo_endpoint`: `http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/userinfo`
   - `jwks_uri`: `http://keycloak-keycloak/realms/mijnbureau/protocol/openid-connect/certs`
3. User clicks "Login with Keycloak" → browser redirected to public HTTPS authorization URL → Keycloak login page works
4. After login, Nextcloud exchanges auth code via internal HTTP token endpoint → no TLS issues
5. Nextcloud fetches user info via internal HTTP userinfo endpoint → no TLS issues

### 4. `helmfile/apps/nextcloud/values.yaml.gotmpl` (lines 163-180)

Added `lifecycleHooks.postStart` that runs on every container start. The post-install hook (which configures the OIDC provider via `occ user_oidc:provider`) only runs once on first install. On `helm upgrade` or pod restart, the stored provider endpoints would retain old HTTPS URLs. The `postStart` hook deletes and recreates the provider on every start so it always picks up the current discovery URI.

```yaml
lifecycleHooks:
  postStart:
    exec:
      command:
        - /bin/bash
        - -c
        - |
          for ((i=0; i<30; i++)); do
            if php /var/www/html/occ status --output json 2>/dev/null | grep -q '"installed":true'; then
              break
            fi
            sleep 2
          done
          php /var/www/html/occ user_oidc:provider keycloak --delete 2>/dev/null || true
          php /var/www/html/occ user_oidc:provider keycloak \
            --clientid="{{ .Values.authentication.client.nextcloud.client_id }}" \
            --clientsecret="{{ .Values.authentication.client.nextcloud.client_secret }}" \
            --discoveryuri="{{ .Values.application.nextcloud.oidc.discoveryUri | default (printf "%s/.well-known/openid-configuration" .Values.authentication.oidc.issuer) }}"
```

The retry loop waits up to 60 s for Nextcloud to report `"installed":true` before running the OIDC commands.

## Post-Install Provider Registration Does Not Re-Run

The Bitnami entrypoint's `post-installation` hooks run **only once** on first install. On `helm upgrade` or pod restart the `occ user_oidc:provider` command from the post-install script is never re-executed, so even after changing `discoveryUri` the stored provider endpoints keep old URLs.

The `lifecycleHooks.postStart` fix above ensures the provider is always refreshed on pod start.

## Deploy

Run `helmfile apply` to deploy the changes.

After deploy, verify the provider endpoints by checking the Nextcloud database:

```bash
kubectl exec deploy/nextcloud -- php /var/www/html/occ user_oidc:provider keycloak --output=json
```

The `token_endpoint`, `userinfo_endpoint`, and `jwks_uri` should show `http://keycloak-keycloak/...` while `authorization_endpoint` should show `https://id.127.0.0.1.sslip.io/...`.

## Test OIDC Login

1. Open `https://nextcloud.127.0.0.1.sslip.io` in a browser
2. Click "Login with Keycloak"
3. Should redirect to Keycloak login page (HTTPS, works)
4. After login, should redirect back to Nextcloud (auth code exchange via internal HTTP, no TLS error)
