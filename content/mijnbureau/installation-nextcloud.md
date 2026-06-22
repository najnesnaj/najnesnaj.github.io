# Nextcloud Installation

## Prerequisites

- KIND cluster `mijnbureau` running with Traefik ingress controller
- Keycloak deployed and accessible
- `mkcert` installed on host for local TLS certificates

## Deployment

Deployed via helmfile from `mijn-bureau-deploy-demo`:

```bash
export KIND_EXPERIMENTAL_PROVIDER=docker
export MIJNBUREAU_MASTER_PASSWORD="test123"
export MIJNBUREAU_CREATE_NAMESPACES=true

helmfile -e demo --skip-refresh sync
```

## StorageClass Fix

The demo environment used `local-path` StorageClass, but the cluster only has `standard` (from `local-path-provisioner`).

**Edit**: `helmfile/environments/demo/mijnbureau.yaml.gotmpl` — changed all `storageClass: local-path` to `storageClass: standard`.

## Docker Hub Authentication

Nextcloud image `nextcloud:33.0.5-apache` is pulled from Docker Hub, which rate-limits anonymous pulls.

```bash
kubectl create secret docker-registry docker-hub-pull \
  --docker-server=https://registry-1.docker.io \
  --docker-username=<user> \
  --docker-password=<token> \
  --namespace default

kubectl patch serviceaccount default \
  --namespace default \
  -p '{"imagePullSecrets": [{"name": "docker-hub-pull"}]}'
```

Also patched the cronjob service account:
```bash
kubectl patch serviceaccount nextcloud-cron \
  --namespace default \
  -p '{"imagePullSecrets": [{"name": "docker-hub-pull"}]}'
```

## Ingress Configuration

The ingress uses hostname `nextcloud.127.0.0.1.sslip.io` (also kept `nextcloud.kubernetes.local`).

## Trusted Domains

Configured via `occ` after first deploy:

```bash
kubectl exec deploy/nextcloud -- \
  php occ config:system:set trusted_domains 2 --value="nextcloud.127.0.0.1.sslip.io"
kubectl exec deploy/nextcloud -- \
  php occ config:system:set trusted_domains 3 --value="nextcloud.kubernetes.local"
```

## mkcert CA Trust

Mounted the host mkcert CA into the Nextcloud container and runs `update-ca-certificates` at startup.

```bash
# Create ConfigMap from mkcert CA on host
kubectl create configmap mkcert-ca \
  --namespace default \
  --from-file=mkcert.crt=/home/naj/.local/share/mkcert/rootCA.pem

# Mount the CA and run update-ca-certificates in the container
kubectl patch deployment nextcloud --namespace default -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nextcloud",
          "command": [
            "bash", "-c",
            "cp /usr/local/share/ca-certificates/mkcert.crt /usr/local/share/ca-certificates/ 2>/dev/null; update-ca-certificates; exec /entrypoint.sh apache2-foreground"
          ],
          "volumeMounts": [{
            "name": "mkcert-ca",
            "mountPath": "/usr/local/share/ca-certificates/mkcert.crt",
            "subPath": "mkcert.crt"
          }]
        }],
        "volumes": [{
          "name": "mkcert-ca",
          "configMap": {
            "name": "mkcert-ca"
          }
        }]
      }
    }
  }
}'
```

## OIDC Provider Configuration

Configured in Nextcloud via `occ`:

```bash
kubectl exec deploy/nextcloud -- \
  php occ user_oidc:provider Keycloak \
    --clientid="nextcloud" \
    --clientsecret="273fa96b5b2c59ae622cbcb39922e42d5e717d47" \
    --discoveryuri="http://id.kubernetes.local/realms/mijnbureau/.well-known/openid-configuration" \
    --check-bearer=1 \
    --enabled=1
```

## Verify OIDC Login

```bash
kubectl exec deploy/nextcloud -- \
  curl -sS -D- -o /dev/null \
  http://nextcloud.kubernetes.local/apps/user_oidc/login/1
```

Expected: `HTTP/1.1 303 See Other` with `Location: http://id.kubernetes.local/realms/mijnbureau/protocol/openid-connect/auth?...`
