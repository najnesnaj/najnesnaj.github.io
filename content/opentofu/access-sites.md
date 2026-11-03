# Access sites — Argo CD, Forgejo, Nextcloud, Euro-Office and Grafana

This guide describes how to reach the services after the installation in
[`installation-steps.md`](installation-steps.md) has completed.

The cluster lives on the isolated `10.10.50.0/24` network. Only the
**management container** is dual-homed, so it is the single entry point from the
home network:

| Service | URL on the home network | How it is exposed |
| --- | --- | --- |
| Argo CD | `https://192.168.0.192:8080` | `kubectl port-forward` on the management container |
| Forgejo | `http://192.168.0.192:3000` | `kubectl port-forward` on the management container |
| nginx demo | `http://nginx-demo.kubernetes.local` | Traefik NodePort + systemd socket proxy on the management container |
| Nextcloud | `http://nextcloud.kubernetes.local` | Traefik ingress + the same socket proxy |
| Euro-Office Docs | `http://euro-office.kubernetes.local` | Traefik ingress + the same socket proxy |
| Grafana | `http://grafana.kubernetes.local` | Traefik ingress + the same socket proxy |
| Talos / Kubernetes API | `https://10.10.50.22:6443` | only from the management container (or its LAN side) |
| Forgejo Git (for Argo CD) | `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git` | in-cluster DNS, not resolvable from the home network |

> `192.168.0.192` is the management container's **DHCP** address on the home
> network. It was `192.168.0.201` during the initial installation; the lease
> changed on 2026-10-29. If it changes again, look it up in the Proxmox UI
> (LXC `105` → Network) or on the container with
> `ip -4 -o addr show eth0`. The OpenTofu state can be stale after a DHCP
> change; the Proxmox UI is authoritative.
>
> When the address changes, also update `ansible2/hosts.yml` and the
> `traefik-ingress-http.socket` / `traefik-ingress-https.socket` units (or
> re-run `ansible2/traefik.yml`), otherwise port 80/443 stays bound to the old
> address.

---

## 1. Argo CD

Argo CD's service is `ClusterIP`, so it is not directly reachable from the home
network. Forward its HTTPS port from the management container:

```bash
ssh root@192.168.0.192 \
  'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
```

Keep that SSH session open and browse to:

```
https://192.168.0.192:8080
```

* The certificate is self-signed; accept the browser warning.
* Username: `admin`
* Password:

```bash
ssh root@192.168.0.192 \
  "kubectl -n argocd get secret argocd-initial-admin-secret \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

The password is stored in the cluster, not in this repository.

**Alternative without exposing the port on the LAN** — bind the forward to
localhost on the management container and tunnel it over SSH:

```bash
# terminal 1
ssh root@192.168.0.192 'kubectl -n argocd port-forward svc/argocd-server 8080:443'

# terminal 2
ssh -L 8080:127.0.0.1:8080 root@192.168.0.192
```

Then open `https://localhost:8080`.

The port-forward stops when the SSH session ends. For a long-lived setup, run it
inside `tmux`/`screen`, or add a small systemd unit on the management container.

---

## 2. Forgejo

Forgejo is also a `ClusterIP` service (`forgejo-http`, port `3000`), so use a
port-forward as well:

```bash
ssh root@192.168.0.192 \
  'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
```

Browse to:

```
http://192.168.0.192:3000
```

Admin credentials (the chart generates them once, in the `forgejo-admin`
secret):

```bash
ssh root@192.168.0.192 \
  "kubectl -n forgejo get secret forgejo-admin \
   -o jsonpath='{.data.username}' | base64 -d; echo"

ssh root@192.168.0.192 \
  "kubectl -n forgejo get secret forgejo-admin \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

The GitOps repository Argo CD reads is:

```
http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git
```

That hostname only resolves **inside** the cluster (Argo CD's repo-server uses
it). From your workstation, use the Forgejo web UI above.

**Git over SSH (optional).** Forward the SSH service to a high port and use it:

```bash
ssh root@192.168.0.192 \
  'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-ssh 2222:22'

git clone ssh://git@192.168.0.192:2222/gitea_admin/gitops.git
```

Forgejo is deliberately **not** published through Traefik in this setup; only
the four application hostnames in section 3 use the ingress path.

---

## 3. Kubernetes ingresses (`*.kubernetes.local`)

Four hostnames are served through Traefik on the management container:

| Hostname | Application |
| --- | --- |
| `nginx-demo.kubernetes.local` | nginx demo |
| `nextcloud.kubernetes.local` | Nextcloud 32 |
| `euro-office.kubernetes.local` | Euro-Office Docs |
| `grafana.kubernetes.local` | Grafana |

### Where does the `/etc/hosts` entry go?

**On the machine where the browser (or `curl`) runs — not on the Proxmox host.**

`/etc/hosts` is a per-machine file. It is consulted by the operating system that
makes the request. Your laptop asks "what is the IP of
`nextcloud.kubernetes.local`?", so the entry must exist on your laptop.
Adding it to `192.168.0.141` (the Proxmox host) only affects commands executed
**on the Proxmox host itself**; it does not change name resolution for your
laptop, phone, or any other device.

| Where you browse from | Where to add the entry |
| --- | --- |
| Your laptop/desktop (normal case) | `/etc/hosts` on that laptop/desktop |
| The Proxmox host shell (`curl` there) | `/etc/hosts` on the Proxmox host |
| A phone/tablet | Not possible without root; use the `Host` header trick below or local DNS |
| Whole home network | Add a DNS record on your router (better than per-device hosts files) |

### Linux / macOS

Add all four names on one line:

```bash
sudo sh -c 'echo "192.168.0.192  nginx-demo.kubernetes.local nextcloud.kubernetes.local euro-office.kubernetes.local grafana.kubernetes.local" >> /etc/hosts'
```

Verify:

```bash
getent hosts nginx-demo.kubernetes.local nextcloud.kubernetes.local euro-office.kubernetes.local grafana.kubernetes.local    # Linux
dscacheutil -q host -a name grafana.kubernetes.local   # macOS (repeat per name)
```

### Windows

Edit `C:\Windows\System32\drivers\etc\hosts` **as Administrator** and add:

```
192.168.0.192  nginx-demo.kubernetes.local nextcloud.kubernetes.local euro-office.kubernetes.local grafana.kubernetes.local
```

Then flush the DNS cache in an Administrator prompt:

```powershell
ipconfig /flushdns
```

### Browse

| URL | Expected |
| --- | --- |
| `http://nginx-demo.kubernetes.local` | the "nginx demo — ArgoCD" page |
| `http://nextcloud.kubernetes.local` | Nextcloud login page (`/login`) |
| `http://euro-office.kubernetes.local` | redirect to `/welcome/`, title "Euro-Office Docs Community Edition" |
| `http://euro-office.kubernetes.local/example/` | example/test page, title "Euro-Office Document editors" |
| `http://grafana.kubernetes.local` | Grafana login page |

Nextcloud admin credentials:

```bash
ssh root@192.168.0.192 \
  "kubectl -n nextcloud get secret nextcloud-admin \
   -o jsonpath='{.data.username}' | base64 -d; echo"
ssh root@192.168.0.192 \
  "kubectl -n nextcloud get secret nextcloud-admin \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

The username is normally `admin`. Euro-Office itself has no web login; the
`/welcome/` page is just the document server landing page. Documents are opened
from Nextcloud, which authenticates the user and signs the document-server
request.

Grafana admin credentials are in the stable `monitoring-grafana-admin` Secret,
not in Git:

```bash
ssh root@192.168.0.192 \
  "kubectl -n monitoring get secret monitoring-grafana-admin \
   -o jsonpath='{.data.admin-user}' | base64 -d; echo"
ssh root@192.168.0.192 \
  "kubectl -n monitoring get secret monitoring-grafana-admin \
   -o jsonpath='{.data.admin-password}' | base64 -d; echo"
```

See [`monitoring.md`](monitoring.md) for the Prometheus/Grafana architecture,
retention and verification commands.

### Without editing `/etc/hosts`

Send the `Host` header manually:

```bash
curl -H 'Host: nginx-demo.kubernetes.local' http://192.168.0.192/
curl -I -H 'Host: nextcloud.kubernetes.local' http://192.168.0.192/
curl -I -H 'Host: euro-office.kubernetes.local' http://192.168.0.192/
curl -I -H 'Host: grafana.kubernetes.local' http://192.168.0.192/
```

or let `curl` resolve the name for one request. Add `-L` when the application
redirects, otherwise the second request tries to resolve the hostname normally:

```bash
curl -sSL --resolve nginx-demo.kubernetes.local:80:192.168.0.192 \
  http://nginx-demo.kubernetes.local/
curl -sSL --resolve nextcloud.kubernetes.local:80:192.168.0.192 \
  -o /dev/null -w '%{http_code} %{url_effective}\n' \
  http://nextcloud.kubernetes.local/
curl -sSL --resolve euro-office.kubernetes.local:80:192.168.0.192 \
  -o /dev/null -w '%{http_code} %{url_effective}\n' \
  http://euro-office.kubernetes.local/
curl -sSL --resolve grafana.kubernetes.local:80:192.168.0.192 \
  -o /dev/null -w '%{http_code} %{url_effective}\n' \
  http://grafana.kubernetes.local/login
```

### How the request flows

```
browser on your laptop
  │  DNS: <hostname> -> 192.168.0.192  (/etc/hosts)
  ▼
192.168.0.192:80            management container, systemd socket
  │  systemd-socket-proxyd (traefik-ingress-http.service)
  ▼
10.10.50.22:30080           Traefik NodePort on talos-node-3
  │  Traefik routes on the Host header
  ▼
<namespace>/<service>       Ingress -> Service -> Pod
```

| Hostname | Ingress | Service |
| --- | --- | --- |
| `nginx-demo.kubernetes.local` | `nginx-demo/nginx` | `nginx-demo/nginx` |
| `nextcloud.kubernetes.local` | `nextcloud/nextcloud` | `nextcloud/nextcloud:8080` |
| `euro-office.kubernetes.local` | `euro-office/documentserver` | `euro-office/documentserver:8888` |
| `grafana.kubernetes.local` | `monitoring/monitoring-grafana` | `monitoring/monitoring-grafana:80` |

The HTTPS equivalent is `192.168.0.192:443` → `10.10.50.22:30443`. The socket
proxy is managed by `ansible2/traefik.yml` and runs as
`traefik-ingress-http.socket` / `traefik-ingress-https.socket` on the
management container.

### Verify from the management container

```bash
ssh root@192.168.0.192 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: nginx-demo.kubernetes.local' http://192.168.0.192/"
ssh root@192.168.0.192 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: nextcloud.kubernetes.local' http://192.168.0.192/"
ssh root@192.168.0.192 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: euro-office.kubernetes.local' http://192.168.0.192/"
ssh root@192.168.0.192 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: euro-office.kubernetes.local' \
   http://192.168.0.192/healthcheck"
ssh root@192.168.0.192 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: grafana.kubernetes.local' \
   http://192.168.0.192/login"
```

Use `192.168.0.192`, not `127.0.0.1`: the systemd socket binds specifically to
the container's LAN address, so localhost refuses the connection. Expected:
`200`, `302`, `302`, `200`, `200`.

---

## 4. Quick reference

```bash
# Management container IP (run on the control host)
tofu output -json management \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["wan_ips"]["eth0"])'

# Argo CD
ssh root@192.168.0.192 'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
# -> https://192.168.0.192:8080  (admin / secret argocd-initial-admin-secret)

# Forgejo
ssh root@192.168.0.192 'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
# -> http://192.168.0.192:3000   (secret forgejo-admin)

# nginx demo (after the /etc/hosts entry on the client)
# browse to http://nginx-demo.kubernetes.local

# Nextcloud
# browse to http://nextcloud.kubernetes.local (admin / secret nextcloud-admin)

# Euro-Office Docs
# browse to http://euro-office.kubernetes.local
# example/test page: http://euro-office.kubernetes.local/example/
# documents are opened from Nextcloud; there is no separate login

# Grafana
# browse to http://grafana.kubernetes.local
# admin / secret monitoring-grafana-admin; see monitoring.md

# Garage S3 backup target (internal only; not a browser UI)
# from the management container:
# curl -sS -o /dev/null -w '%{http_code}\n' http://10.10.50.2:3900/
# expected: 403 without credentials; see backup.md and backup-restore-howto.md
```

---

## 5. Troubleshooting

| Symptom | Check |
| --- | --- |
| `bind: address already in use` | Another port-forward is still running; kill it or pick another local port (`8081:443`, `3001:3000`). |
| Argo CD/Forgejo page does not load | Confirm the SSH session running `kubectl port-forward` is still open, and `kubectl -n <ns> get pods` is healthy on the management container. |
| `*.kubernetes.local` does not resolve | The `/etc/hosts` entry is missing **on the client**; re-check with `getent hosts` / `ping`. |
| `502`/`503` from Traefik | Check the pods and Ingress in the matching namespace (`nginx-demo`, `nextcloud`, `euro-office`, `monitoring`). |
| Grafana shows a login page but dashboards are empty | Check the Argo CD `monitoring` Application, the Prometheus targets, and the Prometheus datasource in Grafana; see `monitoring.md`. |
| Nextcloud returns `400` with "Trusted domain error" | Add the hostname to `trusted_domains`; see `installation-steps.md` section 7.9. |
| Connector: "Error while downloading the document file" | Check `StorageUrl` uses port `8080`, `ALLOW_PRIVATE_IP_ADDRESS=true`, and the internal Nextcloud hostname is trusted (section 7.9). |
| Example editor: "The document security token is not correctly formed" | `JWT_ENABLED=true` or `EXAMPLE_URL=http://example:3000` is missing; see `installation-steps.md` section 7.11. After the rollout, hard-refresh and create a new document. |
| Example: "File not found: new.docx" after a pod restart | Example files are ephemeral; create a new **Blank** document. Avoid **With sample content** until the `/create` handler is patched; see section 7.12. |
| Connection refused on `192.168.0.192:80` | The socket proxy is not active: `systemctl status traefik-ingress-http.socket` on the management container. |
| Wrong management IP | The address is DHCP; refresh it from the Proxmox API or the Proxmox UI and update `/etc/hosts` (and `ansible2/hosts.yml`). |

> Security note: the only **application** ports permanently exposed to the home
> network are `80`/`443` (nginx demo, Nextcloud, Euro-Office and Grafana). Argo CD and
> Forgejo stay on `ClusterIP` and are only reachable while a `kubectl
> port-forward` started over SSH is running. SSH (22) remains open for
> administration.
