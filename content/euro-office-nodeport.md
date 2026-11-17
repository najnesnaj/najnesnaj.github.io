# Euro-Office: NodePort 30020 and public HTTPS access

## Context

Euro-Office is deployed on the Talos cluster by ArgoCD from the GitOps repository in Forgejo:

- **ArgoCD Application:** `argocd/euro-office` → repo `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git`, path `charts/euro-office-docs`, values `values-k8s.yaml`, release `documentserver`, namespace `euro-office`.
- **Services:**
  - `docservice` → docservice pod, port **8000** (backend API, e.g. `api.js`)
  - `documentserver` → docservice pod, port **8888** (nginx proxy, full UI)
  - `example` → `example-0` demo pod, port **3000**, exposed as NodePort **30020**
- **Public hostname:** `euro-office.gridzig.com` (Cloudflare) → `k8s-router` → Talos NodePort **30080** (Traefik).

## Change 1 — expose the local demo via NodePort 30020

The upstream chart hardcodes `type: ClusterIP` for the `example` Service and has no NodePort support. `charts/euro-office-docs/templates/services/example.yaml` was made configurable (`service.type`, `service.nodePort`, and optionally `service.targetPort` / `service.selector`, with the original behaviour as defaults), and `values-k8s.yaml` sets:

```yaml
example:
  enabled: true
  service:
    type: NodePort
    nodePort: 30020
```

## Change 2 — fix the public `api.js` error via a Traefik Ingress

### Problem

`https://euro-office.gridzig.com/web-apps/apps/api/documents/api.js` returned *"An error occurred while processing your request."* The public hostname was tunneled to the `example` NodePort (30020), where the demo app returns **404** for that path. The document server serves it correctly on ports 8000/8888.

An intermediate attempt repointed `svc example` to `docservice:8000`. That made `api.js` work but removed the demo UI from port 30020 and left no UI at `/`. The final solution uses Traefik instead, restoring the demo and serving the full document-server UI.

### Solution

Add the public hostname to the existing Ingress using the chart's `ingress.tenants` feature. In `values-k8s.yaml`:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  host: euro-office.kubernetes.local
  # Also serve the public hostname through Traefik (NodePort 30080). The router
  # forwards euro-office.gridzig.com to port 30080; this host routes it to the
  # document server proxy (documentserver:8888), which serves the full UI and
  # /web-apps/apps/api/documents/api.js.
  tenants:
    - euro-office.kubernetes.local
    - euro-office.gridzig.com
  path: /
  pathType: Prefix
```

Rendered Ingress hosts:

```text
$ helm template euro-office . -n euro-office -f values-k8s.yaml --show-only templates/ingresses/documentserver.yaml | grep 'host:'
  - host: euro-office.kubernetes.local
  - host: euro-office.gridzig.com
```

Both rules route to Service `documentserver` port **8888**.

### Pushed to Forgejo

Files were `PUT` to `gitea_admin/gitops`, branch `main`, via the Forgejo contents API (admin credentials from Secret `forgejo/forgejo-admin`). ArgoCD was hard-refreshed and reported `Synced`/`Healthy` at revision `d3801cb5...`.

## Required router change (on k8s-router)

The `k8s-euro-office-proxy.service` must listen on **8888** (the Cloudflare tunnel target) and forward to the **Traefik NodePort 30080** on a Talos node — **not** to port 8888 (nothing listens on 8888 on the Talos nodes; only NodePorts 30020/30080 are exposed).

```ini
# /etc/systemd/system/k8s-euro-office-proxy.service
[Unit]
Description=Euro-Office public proxy to K8s Traefik NodePort

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:8888,fork,reuseaddr TCP:10.10.50.10:30080
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart k8s-euro-office-proxy.service
sudo systemctl status k8s-euro-office-proxy.service
```

> **Note:** while the target was still wrong, `https://euro-office.gridzig.com/web-apps/apps/api/documents/api.js` appeared to return 200 — that was a stale Cloudflare cache hit (`cf-cache-status: HIT`). A cache-busted request (`?nocache=<timestamp>`) returned **502**, confirming the origin was broken. Always cache-bust when verifying after an origin change.

## Verification

### In-cluster via Traefik (works now)

```text
$ curl -H 'Host: euro-office.gridzig.com' http://10.10.50.10:30080/
302  http://euro-office.gridzig.com/welcome/

$ curl -H 'Host: euro-office.gridzig.com' http://10.10.50.10:30080/web-apps/apps/api/documents/api.js
200
```

### Local demo (restored)

```text
$ curl http://10.10.50.10:30020/
200
```

Service:

```text
$ kubectl -n euro-office get svc example -o custom-columns=...
SELECTOR                                          TARGET  NODEPORT
map[statefulset.kubernetes.io/pod-name:example-0]  3000    30020
```

### Public (after the router fix)

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://euro-office.gridzig.com/web-apps/apps/api/documents/api.js?nocache=$(date +%s)"
# expected: 200
```

## Related

- [GitOps setup with Forgejo](./opentofu/ansible2/argocd.yml)
- [Pushing changes manually](./pushing_changes_manually.md)
- [Forgejo NodePort change](./opentofu/ansible2/forgejo-update.md)
- [Router/management-host forwarding notes](./opentofu/ansible2/nodeport-modification-router.md)
