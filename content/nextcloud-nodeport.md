# Expose Nextcloud via NodePort 30030

## Context

Nextcloud is deployed on the Talos cluster by ArgoCD from the GitOps repository in Forgejo:

- **ArgoCD Application:** `argocd/nextcloud` → repo `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git`, path `charts/nextcloud`, values `values-k8s.yaml`, release `nextcloud`, namespace `nextcloud`.
- Before the change, the `nextcloud` Service was `ClusterIP` on port 8080 (targetPort 80), so the UI was reachable only inside the cluster (or through the `nextcloud.kubernetes.local` Ingress via Traefik).

## Modification (source of truth: Forgejo GitOps repo)

Because ArgoCD uses `selfHeal: true`, the change was made in the GitOps source. The upstream Nextcloud chart already supports `service.type` / `service.nodePort` and `nextcloud.trustedDomains` / `nextcloud.configs`, so only `charts/nextcloud/values-k8s.yaml` needed editing (locally under `content/opentofu/ansible2/files/gitops/charts/nextcloud/`, then pushed to Forgejo via the contents API as the Forgejo admin user).

### `charts/nextcloud/values-k8s.yaml`

Added a fixed NodePort:

```yaml
# Expose Nextcloud through a fixed NodePort so the UI is reachable from outside
# the cluster via any Talos node IP (e.g. http://10.10.50.10:30030).
service:
  type: NodePort
  nodePort: 30030
```

Also had to address Nextcloud's host check — accessing the node IP as the HTTP Host otherwise returns **HTTP 400 "Access through untrusted domain"**. Two changes under `nextcloud:`:

Also had to address Nextcloud's host check. Any HTTP `Host` that is not in `trusted_domains` is rejected with **HTTP 400 "Access through untrusted domain"**. Initially only the node IPs were listed, but the same error reappeared when accessing via the LAN/management address (`192.168.0.192`) and the Ingress address (`192.168.0.201`). The final list covers every way this homelab reaches Nextcloud:

```yaml
nextcloud:
  host: nextcloud.kubernetes.local
  # Nextcloud rejects any HTTP Host not listed here with "Access through
  # untrusted domain" (HTTP 400). Cover every way this homelab reaches it:
  # the Ingress vhost, Talos node IPs/hostnames, and LAN/forwarded addresses.
  trustedDomains:
    - nextcloud.kubernetes.local
    - 10.10.50.10
    - 10.10.50.21
    - 10.10.50.22
    - talos-node-1
    - talos-node-2
    - talos-node-3
    - 192.168.0.192
    - 192.168.0.201
    - 192.168.0.250
    - nextcloud.gridzig.com
  # NEXTCLOUD_TRUSTED_DOMAINS is only applied on first install. A later-loaded
  # config file keeps these hosts trusted after every pod recreation.
  configs:
    zz-trusted-domains.config.php: |-
      <?php
      $CONFIG = array (
        'trusted_domains' =>
        array (
          0 => 'nextcloud.kubernetes.local',
          1 => '10.10.50.10',
          2 => '10.10.50.21',
          3 => '10.10.50.22',
          4 => 'talos-node-1',
          5 => 'talos-node-2',
          6 => 'talos-node-3',
          7 => '192.168.0.192',
          8 => '192.168.0.201',
          9 => '192.168.0.250',
          10 => 'nextcloud.gridzig.com',
        ),
      );
```

Why both:
- `trustedDomains` → sets the `NEXTCLOUD_TRUSTED_DOMAINS` env var in the Deployment (correct desired state), but the Nextcloud Docker entrypoint only applies it on **first install**, so existing deployments keep the old value.
- `configs.zz-trusted-domains.config.php` → the chart writes this into a ConfigMap mounted at `/var/www/html/config/zz-trusted-domains.config.php`. The `zz-` prefix makes it load after the default config, so it reliably overrides `trusted_domains` on every pod start.

If you access Nextcloud through yet another hostname or IP (e.g. a router WAN/DNS name), add it to **both** lists in `values-k8s.yaml`, push to Forgejo and let ArgoCD re-sync.

### Force HTTPS

Traffic is forced to HTTPS by a second later-loaded config file, `nextcloud.configs.zz-https.config.php` (mounted at `/var/www/html/config/zz-https.config.php`). This keeps the settings durable across pod recreations rather than editing `config/config.php` by hand inside the pod:

```yaml
  configs:
    zz-https.config.php: |-
      <?php
      $CONFIG = array (
        'overwriteprotocol' => 'https',
        'overwrite.cli.url' => 'https://nextcloud.gridzig.com',
      );
```

- `overwriteprotocol => https` — Nextcloud generates absolute URLs with the `https` scheme and redirects plain HTTP requests to HTTPS (TLS is terminated upstream at Traefik / the public reverse proxy for `nextcloud.gridzig.com`).
- `overwrite.cli.url => https://nextcloud.gridzig.com` — the canonical base URL used for CLI-generated links (cron jobs, notifications, etc.).

### Render validation

```bash
cd content/opentofu/ansible2/files/gitops/charts/nextcloud
/tmp/opencode/bin/helm template nextcloud . -n nextcloud -f values-k8s.yaml \
  --show-only templates/service.yaml
```

Rendered Service:

```yaml
kind: Service
metadata:
  name: nextcloud
spec:
  type: NodePort
  ports:
    - port: 8080
      targetPort: 80
      protocol: TCP
      name: http
      nodePort: 30030
  selector:
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/component: app
```

### Pushed to Forgejo

`charts/nextcloud/values-k8s.yaml` was pushed to `gitea_admin/gitops`, branch `main`, via the Forgejo contents API (`PUT` with the current blob SHA, commit message `Expose Nextcloud via NodePort 30030`). Verified via the API that the file in Forgejo contains the NodePort and trusted-domain settings.

## Applied to the cluster

```bash
ssh root@192.168.0.192 \
  'kubectl -n argocd annotate application nextcloud argocd.argoproj.io/refresh=hard --overwrite'
```

ArgoCD synced successfully (`successfully synced (all tasks run)`). The Deployment rolled out (the config-hash change triggered a pod restart). Because the chart's `strategy` is `Recreate` and the first rollout didn't recover on its own, a `kubectl -n nextcloud rollout restart deploy/nextcloud` was issued; the new pod came up healthy.

## Verification

Service:

```text
$ kubectl -n nextcloud get svc nextcloud -o wide
NAME        TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE   SELECTOR
nextcloud   NodePort   10.111.155.173   <none>        8080:30030/TCP   19d   app.kubernetes.io/component=app,app.kubernetes.io/instance=nextcloud,app.kubernetes.io/name=nextcloud
```

Trusted domains in the running pod:

```text
$ kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get trusted_domains
nextcloud.kubernetes.local
10.10.50.10
10.10.50.21
10.10.50.22
talos-node-1
talos-node-2
talos-node-3
192.168.0.192
192.168.0.201
192.168.0.250
nextcloud.gridzig.com
```

HTTPS enforcement in the running pod:

```text
$ kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get overwriteprotocol
https
$ kubectl -n nextcloud exec deploy/nextcloud -- php occ config:system:get overwrite.cli.url
https://nextcloud.gridzig.com
```

An HTTP request now redirects to HTTPS:

```text
$ curl -H 'Host: nextcloud.gridzig.com' http://10.10.50.10:30030/
302  https://nextcloud.gridzig.com/login
```

HTTP checks against the NodePort, sending each candidate `Host` header (302 → `/login` is the expected response for an unauthenticated browser; 400 means "Access through untrusted domain"):

```text
nextcloud.kubernetes.local -> 302
10.10.50.10               -> 302
10.10.50.21               -> 302
10.10.50.22               -> 302
talos-node-1              -> 302
talos-node-2              -> 302
talos-node-3              -> 302
192.168.0.192             -> 302
192.168.0.201             -> 302
192.168.0.250             -> 302
nextcloud.gridzig.com     -> 302
localhost                 -> 302
127.0.0.1                 -> 302
```

ArgoCD Application: `Synced`, `Healthy`.

## Access

- Inside the Talos subnet / from a host that can route to it: `http://<talos-node-ip>:30030/` (e.g. `http://10.10.50.10:30030/`).
- From a LAN client that cannot route to `10.10.50.0/24`: add a router/gateway or management-host forward to `<any-talos-node>:30030` (same pattern as documented for Forgejo in [`opentofu/ansible2/nodeport-modification-router.md`](./opentofu/ansible2/nodeport-modification-router.md)).
- The existing Ingress (`nextcloud.kubernetes.local` via Traefik) remains in place; NodePort is an additional access path.
- If you later change the node IPs, update both `trustedDomains` and `configs.zz-trusted-domains.config.php` in `values-k8s.yaml` and push to Forgejo.

## Related

- [GitOps setup with Forgejo](./opentofu/ansible2/argocd-forgejo.md)
- [Euro-Office demo NodePort change](./euro-office-nodeport.md)
- [Forgejo NodePort change](./opentofu/ansible2/forgejo-update.md)
- [Router/management-host forwarding notes](./opentofu/ansible2/nodeport-modification-router.md)
