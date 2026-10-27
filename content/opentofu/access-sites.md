# Access sites — Argo CD, Forgejo and the nginx demo

This guide describes how to reach the services after `from-scratch.sh` has run.

The cluster lives on the isolated `10.10.50.0/24` network. Only the
**management container** is dual-homed, so it is the single entry point from the
home network:

| Service | URL on the home network | How it is exposed |
| --- | --- | --- |
| Argo CD | `https://192.168.0.201:8080` | `kubectl port-forward` on the management container |
| Forgejo | `http://192.168.0.201:3000` | `kubectl port-forward` on the management container |
| nginx demo | `http://nginx-demo.kubernetes.local` | Traefik NodePort + systemd socket proxy on the management container |
| Talos / Kubernetes API | `https://10.10.50.22:6443` | only from the management container (or its LAN side) |
| Forgejo Git (for Argo CD) | `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git` | in-cluster DNS, not resolvable from the home network |

> `192.168.0.201` is the management container's **DHCP** address on the home
> network. If it changes, look it up on the control host with
> `tofu output -json management | python3 -c 'import json,sys; print(json.load(sys.stdin)["wan_ips"]["eth0"])'`
> or in the Proxmox UI (LXC `105` → Network).

---

## 1. Argo CD

Argo CD's service is `ClusterIP`, so it is not directly reachable from the home
network. Forward its HTTPS port from the management container:

```bash
ssh root@192.168.0.201 \
  'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
```

Keep that SSH session open and browse to:

```
https://192.168.0.201:8080
```

* The certificate is self-signed; accept the browser warning.
* Username: `admin`
* Password:

```bash
ssh root@192.168.0.201 \
  "kubectl -n argocd get secret argocd-initial-admin-secret \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

The password is stored in the cluster, not in this repository.

**Alternative without exposing the port on the LAN** — bind the forward to
localhost on the management container and tunnel it over SSH:

```bash
# terminal 1
ssh root@192.168.0.201 'kubectl -n argocd port-forward svc/argocd-server 8080:443'

# terminal 2
ssh -L 8080:127.0.0.1:8080 root@192.168.0.201
```

Then open `https://localhost:8080`.

The port-forward stops when the SSH session ends. For a long-lived setup, run it
inside `tmux`/`screen`, or add a small systemd unit on the management container.

---

## 2. Forgejo

Forgejo is also a `ClusterIP` service (`forgejo-http`, port `3000`), so use a
port-forward as well:

```bash
ssh root@192.168.0.201 \
  'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
```

Browse to:

```
http://192.168.0.201:3000
```

Admin credentials (the chart generates them once, in the `forgejo-admin`
secret):

```bash
ssh root@192.168.0.201 \
  "kubectl -n forgejo get secret forgejo-admin \
   -o jsonpath='{.data.username}' | base64 -d; echo"

ssh root@192.168.0.201 \
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
ssh root@192.168.0.201 \
  'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-ssh 2222:22'

git clone ssh://git@192.168.0.201:2222/gitea_admin/gitops.git
```

Forgejo is deliberately **not** published through Traefik in this setup; only
the nginx demo uses the ingress path.

---

## 3. `nginx-demo.kubernetes.local`

### Where does the `/etc/hosts` entry go?

**On the machine where the browser (or `curl`) runs — not on the Proxmox host.**

`/etc/hosts` is a per-machine file. It is consulted by the operating system that
makes the request. Your laptop asks "what is the IP of
`nginx-demo.kubernetes.local`?", so the entry must exist on your laptop.
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

```bash
sudo sh -c 'echo "192.168.0.201  nginx-demo.kubernetes.local" >> /etc/hosts'
```

Verify:

```bash
getent hosts nginx-demo.kubernetes.local    # Linux
dscacheutil -q host -a name nginx-demo.kubernetes.local   # macOS
```

### Windows

Edit `C:\Windows\System32\drivers\etc\hosts` **as Administrator** and add:

```
192.168.0.201  nginx-demo.kubernetes.local
```

Then flush the DNS cache in an Administrator prompt:

```powershell
ipconfig /flushdns
```

### Browse

```
http://nginx-demo.kubernetes.local
```

You should see the "nginx demo — ArgoCD" page.

### Without editing `/etc/hosts`

Send the `Host` header manually:

```bash
curl -H 'Host: nginx-demo.kubernetes.local' http://192.168.0.201/
```

or let `curl` resolve the name for one request:

```bash
curl --resolve nginx-demo.kubernetes.local:80:192.168.0.201 \
  http://nginx-demo.kubernetes.local/
```

### How the request flows

```
browser on your laptop
  │  DNS: nginx-demo.kubernetes.local -> 192.168.0.201  (/etc/hosts)
  ▼
192.168.0.201:80            management container, systemd socket
  │  systemd-socket-proxyd (traefik-ingress-http.service)
  ▼
10.10.50.22:30080           Traefik NodePort on talos-node-3
  │  Traefik routes on the Host header
  ▼
nginx-demo/nginx            Ingress -> Service -> Pod
```

The HTTPS equivalent is `192.168.0.201:443` → `10.10.50.22:30443`. The socket
proxy is managed by `ansible2/traefik.yml` and runs as
`traefik-ingress-http.socket` / `traefik-ingress-https.socket` on the
management container.

### Verify from the management container

```bash
ssh root@192.168.0.201 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: nginx-demo.kubernetes.local' http://192.168.0.201/"
```

Use `192.168.0.201`, not `127.0.0.1`: the systemd socket binds specifically to
the container's LAN address, so localhost refuses the connection. Expected:
`200`.

---

## 4. Quick reference

```bash
# Management container IP (run on the control host)
tofu output -json management \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["wan_ips"]["eth0"])'

# Argo CD
ssh root@192.168.0.201 'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
# -> https://192.168.0.201:8080  (admin / secret argocd-initial-admin-secret)

# Forgejo
ssh root@192.168.0.201 'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
# -> http://192.168.0.201:3000   (secret forgejo-admin)

# nginx demo (after the /etc/hosts entry on the client)
# browse to http://nginx-demo.kubernetes.local
```

---

## 5. Troubleshooting

| Symptom | Check |
| --- | --- |
| `bind: address already in use` | Another port-forward is still running; kill it or pick another local port (`8081:443`, `3001:3000`). |
| Argo CD/Forgejo page does not load | Confirm the SSH session running `kubectl port-forward` is still open, and `kubectl -n <ns> get pods` is healthy on the management container. |
| `nginx-demo.kubernetes.local` does not resolve | The `/etc/hosts` entry is missing **on the client**; re-check with `getent hosts` / `ping`. |
| `502`/`503` from Traefik | Check `kubectl -n nginx-demo get pods` and the Ingress: `kubectl -n nginx-demo get ingress`. |
| Connection refused on `192.168.0.201:80` | The socket proxy is not active: `systemctl status traefik-ingress-http.socket` on the management container. |
| Wrong management IP | The address is DHCP; refresh it from the Proxmox API or the Proxmox UI and update `/etc/hosts` (and `ansible2/hosts.yml`). |

> Security note: the only **application** ports permanently exposed to the home
> network are `80`/`443` (nginx demo). Argo CD and Forgejo stay on `ClusterIP`
> and are only reachable while a `kubectl port-forward` started over SSH is
> running. SSH (22) remains open for administration.
