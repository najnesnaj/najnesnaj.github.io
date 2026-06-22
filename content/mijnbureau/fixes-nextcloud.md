# Nextcloud Fixes

## 1. Traefik Middleware Conflict

**Symptom**: Helm sync fails with `middleware "default-hsts-header@kubernetescrd" does not exist`, intermittent routing errors.

**Root cause**: Both keycloak and nextcloud charts ship a `treafik-middleware.yaml` template that creates `hsts-header` Middleware CRD. Helm ownership conflicts cause intermittent failures.

**Fix**: Removed the duplicate template from the nextcloud chart:

```bash
rm helmfile/apps/nextcloud/charts/nextcloud/templates/treafik-middleware.yaml
```

The HSTS middleware is created globally via `kubectl` instead (documented in installation-history.md).

---

## 2. Traefik Readiness Probe Failing

**Symptom**: Traefik pod stays in `0/1 Running` (readiness probe failing).

**Root cause**: The custom Helm values override the default entrypoint args and omit `--ping=true`. The Traefik readiness probe requires the ping endpoint.

**Fix**: Restored original entrypoint ports (`:8000`/`:8443` instead of `:80`/`:443`) and re-added `--ping=true`:

```bash
helm upgrade traefik traefik/traefik \
  --namespace traefik --reuse-values \
  --set ports.web.port=8000 \
  --set ports.web.hostPort=80 \
  --set ports.websecure.port=8443 \
  --set ports.websecure.hostPort=443 \
  --set additionalArguments[0]="--ping=true" \
  --set additionalArguments[1]="--providers.kubernetescrd" \
  --set additionalArguments[2]="--providers.kubernetesingress"
```

---

## 3. OIDC hostAliases — Nextcloud Cannot Resolve Keycloak

**Symptom**: Nextcloud cannot reach `id.kubernetes.local` — DNS resolves to external IP or fails.

**Root cause**: `id.kubernetes.local` is a vanity hostname not in public DNS. Need to point it to Traefik's ClusterIP so requests are routed through the ingress.

**Fix**: Patched the Nextcloud deployment to add `hostAliases`:

```bash
# Find Traefik ClusterIP
TRAEFIK_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.spec.clusterIP}')

kubectl patch deployment nextcloud --namespace default -p '{
  "spec": {
    "template": {
      "spec": {
        "hostAliases": [{
          "ip": "'$TRAEFIK_IP'",
          "hostnames": ["id.kubernetes.local"]
        }]
      }
    }
  }
}'
```

---

## 4. Traefik Default Certificate — SSL Verify Fail

**Symptom**: SSL certificate verification fails when Nextcloud connects to Keycloak via HTTPS.

**Root cause**: Traefik uses a self-signed certificate by default. The mkcert CA is trusted on the host but not inside the cluster.

**Fix**: Created a TLS secret with the mkcert certificate and configured a Traefik TLSStore to use it as the default certificate:

```bash
# Create TLS secret from mkcert cert
kubectl create secret tls mkcert-tls \
  --namespace default \
  --cert=/tmp/traefik-cert.pem \
  --key=/tmp/traefik-key.pem

# Configure TLSStore CRD
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: default
spec:
  defaultCertificate:
    secretName: mkcert-tls
EOF
```

---

## 5. mkcert CA Not Trusted Inside Nextcloud Container

**Symptom**: `curl https://id.kubernetes.local` inside the Nextcloud pod returns `SSL certificate verify failed`.

**Root cause**: The Nextcloud container does not have the mkcert CA in its trust store.

**Fix**: Mounted CA as ConfigMap and run `update-ca-certificates` at container startup (see `installation-nextcloud.md`).

---

## 6. Keycloak OIDC Endpoints Return HTTPS URLs

**Symptom**: Nextcloud OIDC discovery document returns `https://id.kubernetes.local/...` but Traefik HTTPS routing returns 404.

**Root cause**: Keycloak generates issuer/auth/token/userinfo endpoints with `https://` scheme. Traefik's `websecure` entrypoint has no matching routers for these ingresses.

**Fix**: Changed Keycloak realm's `frontendUrl` to use HTTP:

```bash
kubectl exec keycloak-keycloak-0 -- \
  kcadm.sh update realms/mijnbureau \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password <pass> \
    -s 'attributes.frontendUrl="http://id.kubernetes.local"'
```

---

## 7. Nextcloud OVERWRITEPROTOCOL Forcing HTTPS URLs

**Symptom**: Nextcloud generates redirect URLs with `https://` scheme even when accessed via HTTP.

**Root cause**: The `OVERWRITEPROTOCOL` env var defaults to `https` in the ConfigMap.

**Fix**: Changed the ConfigMap value from `https` to `http`:

```bash
kubectl patch configmap nextcloud-env-vars --namespace default \
  -p '{"data":{"OVERWRITEPROTOCOL":"http"}}'
```

Then restart Nextcloud:
```bash
kubectl rollout restart deployment nextcloud --namespace default
```

---

## 8. Nextcloud Blocks Local HTTP Connections (SSRF Protection)

**Symptom**: OIDC token exchange fails — Nextcloud refuses to connect to `http://id.kubernetes.local` (private ClusterIP).

**Root cause**: Nextcloud's `allow_local_remote_servers` defaults to `false`, blocking HTTP connections to private/reserved IP ranges.

**Fix**:
```bash
kubectl exec deploy/nextcloud -- \
  php occ config:system:set allow_local_remote_servers --value=true
```

---

## 9. user_oidc App Enforces HTTPS (isSecure check)

**Symptom**: Visiting `/apps/user_oidc/login/1` returns HTTP 404 with message `You must access Nextcloud with HTTPS to use OpenID Connect.`

**Root cause**: The `user_oidc` app's `LoginController::isSecure()` method in `/var/www/html/custom_apps/user_oidc/lib/Controller/LoginController.php` checks:

```php
private function isSecure(): bool {
    return $this->isDebugModeEnabled()
        || $this->appConfig->getValueBool(Application::APP_ID, 'allow_insecure_http', false, lazy: true)
        || $this->request->getServerProtocol() === 'https';
}
```

The request arrives as HTTP, debug mode is off, and `allow_insecure_http` is unset — so `isSecure()` returns false.

**Fix**: Set the `allow_insecure_http` app config flag:

```bash
kubectl exec deploy/nextcloud -- \
  php occ config:app:set user_oidc allow_insecure_http --value=1
```

---

## 10. Traefik HTTPS Routing Returns 404 (Unresolved)

**Symptom**: HTTPS access to any ingress (`https://nextcloud.kubernetes.local`, `https://id.kubernetes.local`) returns HTTP 404. SSL handshake succeeds (mkcert cert served) but Traefik access log shows `"-" "-"` frontend/backend with `0ms` duration.

**Root cause**: Not fully determined. The `kubernetesingress` provider does not create routers on the `websecure` entrypoint for TLS ingresses. The `kubernetescrd` provider may handle TLS differently when the TLSStore approach is used.

**Workaround**: All OIDC traffic uses plain HTTP (fixes 6, 7, 8, 9). HTTPS routing fix is not required for functional OIDC login.
