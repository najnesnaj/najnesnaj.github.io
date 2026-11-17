# Pushing the Nextcloud changes manually

This document explains exactly how the Nextcloud configuration changes were pushed, so you can repeat the process yourself. ArgoCD does **not** read from your local checkout — it watches the GitOps repository hosted in Forgejo. Editing a file locally is only half the job; the file must also be committed in Forgejo.

## Overview of the flow

```
edit local values-k8s.yaml
        |
        v
helm template  (render check, no cluster contact)
        |
        v
scp file to management host 192.168.0.192
        |
        v
Forgejo contents API: GET file -> PUT with sha (or POST if new)
        |
        v
hard-refresh ArgoCD Application
        |
        v
wait for pod rollout -> verify with kubectl/curl
```

## Access and paths

| Item | Value |
|---|---|
| Local checkout | `/usr/src/najnesnaj.github.io/content/opentofu/ansible2/files/gitops/` |
| Chart | `charts/nextcloud/` |
| Values file | `charts/nextcloud/values-k8s.yaml` |
| Management host | `192.168.0.192` (SSH as root) |
| Forgejo repo | `gitea_admin/gitops`, branch `main` |
| Forgejo API (inside cluster) | `http://127.0.0.1:3000/api/v1` |
| ArgoCD Application | `argocd/nextcloud` |
| Helm binary (local) | `/tmp/opencode/bin/helm` |

Forgejo's HTTP service (`forgejo-http.forgejo.svc.cluster.local`) is only reachable from inside the cluster, so the contents API calls are run **from inside the Forgejo pod** via `kubectl exec`.

## Step 1 — Edit the values file locally

Make your changes in:

```bash
/usr/src/najnesnaj.github.io/content/opentofu/ansible2/files/gitops/charts/nextcloud/values-k8s.yaml
```

For the work done so far this meant:

- `service.type: NodePort` / `service.nodePort: 30030`
- `nextcloud.trustedDomains` (Ingress vhost, Talos node IPs + hostnames, LAN/forwarded addresses)
- `nextcloud.configs.zz-trusted-domains.config.php` (same hosts, durable across pod restarts)
- `nextcloud.configs.zz-https.config.php` (`overwriteprotocol` and `overwrite.cli.url`)

Keep `trustedDomains` and the `zz-trusted-domains.config.php` file in sync — the env var only applies on first install, the config file is what actually takes effect on every pod start.

## Step 2 — Render-check the chart (optional but recommended)

This catches YAML/syntax errors before you push:

```bash
cd /usr/src/najnesnaj.github.io/content/opentofu/ansible2/files/gitops/charts/nextcloud

/tmp/opencode/bin/helm template nextcloud . -n nextcloud -f values-k8s.yaml \
  --show-only templates/service.yaml

# To check the generated config files:
/tmp/opencode/bin/helm template nextcloud . -n nextcloud -f values-k8s.yaml \
  | grep -A12 'zz-trusted-domains.config.php:'
/tmp/opencode/bin/helm template nextcloud . -n nextcloud -f values-k8s.yaml \
  | grep -A8  'zz-https.config.php:'
```

## Step 3 — Copy the file to the management host

```bash
cp /usr/src/najnesnaj.github.io/content/opentofu/ansible2/files/gitops/charts/nextcloud/values-k8s.yaml \
   /tmp/opencode/nextcloud-values-k8s.yaml

scp /tmp/opencode/nextcloud-values-k8s.yaml \
    root@192.168.0.192:/tmp/nextcloud-values-k8s.yaml
```

## Step 4 — Push the file into Forgejo via the contents API

Save the following script locally as `/tmp/opencode/push-forgejo-nextcloud.sh`, then run it over SSH:

```bash
cat > /tmp/opencode/push-forgejo-nextcloud.sh << 'REMOTE'
set -e
KP=$(kubectl -n forgejo get secret forgejo-admin -o jsonpath="{.data.password}" | base64 -d)
API=http://127.0.0.1:3000/api/v1/repos/gitea_admin/gitops/contents
BASE=charts/nextcloud
path=values-k8s.yaml
localfile=/tmp/nextcloud-values-k8s.yaml
content=$(base64 -w0 "$localfile")

# Check whether the file already exists (200) and grab its blob sha.
out=$(kubectl -n forgejo exec deploy/forgejo -- curl -s -w '\n%{http_code}' \
      -u gitea_admin:$KP "$API/$BASE/$path?ref=main")
status=$(echo "$out" | tail -1)

if [ "$status" = "200" ]; then
  sha=$(echo "$out" | head -n -1 | python3 -c 'import sys,json; print(json.load(sys.stdin)["sha"])')
  body=$(python3 -c 'import json,sys; print(json.dumps({"content":sys.argv[1],"sha":sys.argv[2],"message":"Expose Nextcloud via NodePort 30030","branch":"main"}))' "$content" "$sha")
  method=PUT
else
  body=$(python3 -c 'import json,sys; print(json.dumps({"content":sys.argv[1],"message":"Expose Nextcloud via NodePort 30030","branch":"main"}))' "$content")
  method=POST
fi

echo "Pushing $BASE/$path ($method, status=$status, sha=${sha:-none})"
kubectl -n forgejo exec deploy/forgejo -- curl -s -o /dev/null -w '%{http_code}\n' \
  -X "$method" -u gitea_admin:$KP -H 'Content-Type: application/json' \
  -d "$body" "$API/$BASE/$path"
REMOTE

ssh root@192.168.0.192 'bash -s' < /tmp/opencode/push-forgejo-nextcloud.sh
```

Expected output (the `Defaulted container "forgejo" out of: ...` warning from `kubectl exec` is harmless):

```text
Pushing charts/nextcloud/values-k8s.yaml (PUT, status=200, sha=<old-sha>)
200
```

### What the script does

1. Reads the Forgejo admin password from the `forgejo/forgejo-admin` Kubernetes Secret.
2. Base64-encodes the full local file (`content` must be base64 for the Forgejo contents API).
3. `GET`s the current file from branch `main`:
   - **HTTP 200** → the file exists; extract its `sha` and use **PUT** (an update requires the sha, otherwise Forgejo returns `422 "[SHA]: Required"`).
   - anything else → use **POST** to create the file.
4. Sends the JSON body with `content`, `message`, `branch` (and `sha` for updates).

**Before running it, update the commit message** in the script — it is currently hardcoded to `"Expose Nextcloud via NodePort 30030"`. Change it to describe your actual change, e.g. `"Add nextcloud.gridzig.com to trusted domains"`.

### Alternative: native git

If you have network access to Forgejo's HTTP/SSH endpoint from your own machine, you can use normal git instead of the API:

```bash
git clone http://<forgejo-address>/gitea_admin/gitops.git
cd gitops
# edit charts/nextcloud/values-k8s.yaml
git add charts/nextcloud/values-k8s.yaml
git commit -m "Describe the change"
git push origin main
```

The API approach above is used because the Forgejo service address is only resolvable inside the cluster.

## Step 5 — Make ArgoCD pick up the change

ArgoCD polls, but a hard refresh makes it immediate:

```bash
ssh root@192.168.0.192 \
  'kubectl -n argocd annotate application nextcloud argocd.argoproj.io/refresh=hard --overwrite'
```

Then check the result:

```bash
ssh root@192.168.0.192 \
  'kubectl -n argocd get app nextcloud -o json | jq "{sync:.status.sync.status, health:.status.health.status, revision:.status.sync.revision}"'
```

Wait until it reports `"sync": "Synced"` and `"health": "Healthy"`.

## Step 6 — Verify in the running pod

```bash
ssh root@192.168.0.192 '
echo "=== service ==="
kubectl -n nextcloud get svc nextcloud -o wide

echo "=== trusted domains ==="
kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get trusted_domains

echo "=== https settings ==="
kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get overwriteprotocol
kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get overwrite.cli.url

echo "=== host check ==="
curl -sS -o /dev/null -w "%{http_code} %{redirect_url}\n" \
  --max-time 8 -H "Host: nextcloud.gridzig.com" http://10.10.50.10:30030/
'
```

`302 https://nextcloud.gridzig.com/login` is the expected result. A `400` means "Access through untrusted domain" — the Host you used is missing from the trusted-domain config files (go back to Step 1).

## Troubleshooting

### The pod rollout stalls (0 replicas, only old Completed pods)

This chart uses `strategy: Recreate`. On several occasions the config-hash change killed the old pod but the new one never came up, leaving the deployment at 0/1 and ArgoCD `Progressing`. Recovery:

```bash
ssh root@192.168.0.192 'kubectl -n nextcloud rollout restart deploy/nextcloud'
```

Wait about 90–120 seconds and re-check with the verification commands above. This is a known quirk of this chart's Recreate strategy — it is not caused by the values change itself.

### The API call returns 422

An update (`PUT`) without the current blob sha causes `422 "[SHA]: Required"`. Make sure the `GET ...?ref=main` succeeded (status 200) and that the `sha` was extracted before building the PUT body. For a genuinely new file, use POST.

### ArgoCD still shows the old revision

The repo-server caches manifests. Do another hard refresh, and if needed restart it:

```bash
ssh root@192.168.0.192 '
kubectl -n argocd rollout restart deploy/argocd-repo-server
kubectl -n argocd annotate application nextcloud argocd.argoproj.io/refresh=hard --overwrite
'
```

## Summary of the files involved

| Location | Role |
|---|---|
| `content/opentofu/ansible2/files/gitops/charts/nextcloud/values-k8s.yaml` | Local source of truth you edit |
| Forgejo `gitea_admin/gitops`, `main`, `charts/nextcloud/values-k8s.yaml` | Remote source ArgoCD watches |
| `content/nextcloud-nodeport.md` | Documentation of all Nextcloud changes |
| `content/opentofu/ansible2/tasks/forgejo_file.yml` | Ansible task implementing the same PUT/POST pattern |
| `content/opentofu/ansible2/argocd.yml` | ArgoCD + Forgejo GitOps setup |
