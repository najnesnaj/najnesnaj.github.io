# Nextcloud OIDC "Could not reach the OpenID Connect provider" Fix

## Problem

When logging in via `https://nextcloud.192.168.0.215.sslip.io/apps/user_oidc/login/1`, Nextcloud shows:

> Could not reach the OpenID Connect provider.

## Root Cause

Nextcloud's `user_oidc` app attempts to fetch the OIDC discovery document from:

```
https://id.192.168.0.215.sslip.io/realms/mijnbureau/.well-known/openid-configuration
```

This is a server-side HTTPS request from the Nextcloud pod to the Kubernetes NGINX ingress controller. The ingress controller presents a self-signed mkcert TLS certificate (for `*.192.168.0.215.sslip.io`), but the Nextcloud PHP container does **not** trust the mkcert Certificate Authority. The PHP/cURL HTTP client therefore rejects the TLS handshake, and user_oidc reports "Could not reach the OpenID Connect provider."

Unlike the Docs app (which configures each OIDC endpoint individually — front-channel over HTTPS via ingress, backchannel over HTTP directly to `keycloak-keycloak`), Nextcloud's `user_oidc` app relies on the discovery document fetched over HTTPS for all endpoints. This means every server-side OIDC call (discovery, token exchange, userinfo, JWKS) fails.

## Fix

**File:** `helmfile/apps/nextcloud/values.yaml.gotmpl`

Added an `extraConfigs` entry that creates a Nextcloud config file enabling the `user_oidc.httpclient.allowselfsigned` option:

```yaml
extraConfigs:
  oidc-selfsigned.config.php: |
    <?php
    $CONFIG = array(
      'user_oidc' => array(
        'httpclient.allowselfsigned' => true,
      ),
    );
```

This config tells the `user_oidc` app to disable SSL certificate verification (`verify => false` in Guzzle) for all its HTTP requests, including:
- Fetching the OIDC discovery document
- Exchanging the authorization code for tokens
- Requesting userinfo
- Fetching JWKS keys

**Reference:** https://github.com/nextcloud/user_oidc#user_oidchttpclientallowselfsigned

## Deployment

After applying the change, run:

```bash
helmfile -e demo apply
```

The post-install hook will re-run the OIDC provider setup. If the existing provider configuration is stale, you can recreate it manually:

```bash
kubectl exec deploy/nextcloud -- php /var/www/html/occ user_oidc:provider:remove keycloak
kubectl exec deploy/nextcloud -- php /var/www/html/occ user_oidc:provider keycloak \
  --clientid="nextcloud" \
  --clientsecret="$(kubectl get secret nextcloud -o jsonpath='{.data.oidc-client-secret}' | base64 -d)" \
  --discoveryuri="https://id.192.168.0.215.sslip.io/realms/mijnbureau/.well-known/openid-configuration" \
  --check-bearer=1 --bearer-provisioning=1
```

## Security Note

This disables TLS certificate verification for the user_oidc app on the **server-side** only. The browser-facing redirect to the Keycloak authorization endpoint still uses HTTPS with full browser-side TLS verification.

> ⚠️ Use with caution in production environments. For production, import the CA certificate into the Nextcloud container's trust store instead.
