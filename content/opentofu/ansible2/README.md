# k8s-management — Ansible configuration

Ansible project that configures the **`k8s-management`** Proxmox LXC container
(ID `105`) over SSH:

| Role | What it does |
| --- | --- |
| `ssh_server` | Installs/enables `openssh-server`, creates the **`jan`** login (member of `sudo`, passwordless sudo), installs the control-node public key for `jan` **and** `root`, and hardens sshd (key-only logins, root restricted to keys) through `/etc/ssh/sshd_config.d/99-k8s-management.conf`. |
| `tools` | Installs the base CLI packages plus **`talosctl`**, **`kubectl`** and **`helm`** (latest stable by default) and enables kubectl/helm bash completion. |
| `talos_client` | Writes the managed **talosconfig** (`/root/.talos/config`) for the control plane: the client certs come from the OpenTofu `talosconfig` output, and the **Talos control-plane endpoint/node** are pinned with `talosctl config endpoint` / `config node`. |
| `kubeconfig` | Generates the **admin kubeconfig** (`/root/.kube/config`) with `talosctl kubeconfig` and points its server at the reachable control plane, so `kubectl` works without arguments. |
| `local_path_storage` | Installs **Rancher local-path-provisioner** and the `local-path` StorageClass (dynamic 10Gi-style PVCs on the single node), pointed at `/var/local-path-provisioner`. |

## Layout

```
ansible/
├── ansible.cfg              # control-node config (inventory, key, become)
├── hosts.yml                # inventory: the container's home-network address
├── requirements.yml         # ansible.posix collection
├── site.yml                 # playbook: ssh_server + tools + talos_client + kubeconfig
├── forgejo.yml              # playbook: Forgejo on Kubernetes via Helm (includes tools)
├── forgejo-playbook-wijzigingen.md  # changelog van de Forgejo-wijzigingen
├── forgejo-controle.md      # controleer of Forgejo draait
├── argocd.yml               # playbook: ArgoCD met Forgejo als Git-bron
├── argocd-forgejo.md        # hoe ArgoCD Forgejo gebruikt + controle
├── nginx-demo-argocd.md     # nginx-demo via ArgoCD (GitOps) + controle
├── traefik.yml              # playbook: Traefik ingress + bridge op de managementcontainer
├── traefik.md               # ingress, /etc/hosts, verificatie en beheer
├── group_vars/all.yml       # users, keys, sshd + tool settings
├── files/gitops/            # manifests die in de Forgejo-repo worden gezet
│   └── apps/
│       ├── demo.yaml
│       └── nginx-demo/
│           └── app.yaml
├── files/traefik-values.yaml # Helm-waarden voor Traefik
├── tasks/
│   └── forgejo_file.yml     # zet één bestand idempotent in Forgejo
└── roles/
    ├── ssh_server/
    │   ├── defaults/main.yml
    │   ├── handlers/main.yml
    │   ├── tasks/main.yml
    │   └── templates/sshd_config.d/99-k8s-management.conf.j2
    ├── tools/
    │   ├── defaults/main.yml
    │   └── tasks/main.yml
    ├── talos_client/
    │   ├── defaults/main.yml
    │   └── tasks/main.yml
    ├── kubeconfig/
    │   ├── defaults/main.yml
    │   └── tasks/main.yml
    └── local_path_storage/
        ├── defaults/main.yml
        └── tasks/main.yml
```

## Prerequisites

- `ansible-core` ≥ 2.15 on the control node.
- The `ansible.posix` collection:

  ```sh
  ansible-galaxy collection install -r requirements.yml
  ```

- An SSH key pair at `~/.ssh/id_ed25519` / `~/.ssh/id_ed25519.pub`. Override with
  `ssh_public_key_path` (group vars) and `private_key_file` (ansible.cfg).
- The container reachable on its **eth0** address (home network / `vmbr0`).

## Usage

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml   # once
ansible-playbook site.yml
```

## Deploying Forgejo

`forgejo.yml` installs (or upgrades) Forgejo on the Talos cluster with Helm,
into the `forgejo` namespace, with a 10Gi persistent volume:

```sh
ansible-playbook forgejo.yml
```

The chart is published as an OCI artifact
(`oci://code.forgejo.org/forgejo-helm/forgejo`), so there is no `helm repo add`
step. The play includes the `tools` role, so `helm` is installed on the
container when it is missing — no separate `site.yml` run is required, though the
admin kubeconfig (`/root/.kube/config`, created by `site.yml`) must exist.

The play also includes the `local_path_storage` role, which installs
local-path-provisioner because the cluster ships without a StorageClass. Two
environment-specific details are handled there:

- The only node is a control-plane with a `NoSchedule` taint, so the provisioner
  and the Forgejo pod get matching tolerations.
- Talos enforces PodSecurity `baseline`, while local-path's helper pods need a
  `hostPath` volume; the `local-path-storage` namespace is therefore labelled
  `pod-security.kubernetes.io/enforce=privileged`.

Volume data lives in `/var/local-path-provisioner` on the node's Talos
`EPHEMERAL` partition: it survives reboots but **not** a Talos upgrade or
reinstall. To keep repositories and the SQLite database on the data disk, mount
`scsi1` at `/var/mnt/storage` and set
`local_path_provisioner_data_dir: /var/mnt/storage/local-path-provisioner`.

Override the chart version or volume size per run:

```sh
ansible-playbook forgejo.yml \
  -e forgejo_chart_version=17.3.1 -e forgejo_storage_size=20Gi
```

## Deploying ArgoCD with Forgejo

`argocd.yml` installs (or upgrades) ArgoCD with Helm into the `argocd`
namespace and wires it to Forgejo as its Git source:

```sh
ansible-playbook argocd.yml
```

What it sets up:

- ArgoCD (OCI chart `oci://ghcr.io/argoproj/argo-helm/argo-cd`) with
  `global.tolerations`, so every component runs on the tainted control-plane
  node.
- A private Forgejo repository `gitea_admin/gitops` containing the demo manifest
  `apps/demo.yaml` (Namespace + ConfigMap `argocd-demo`) and the nginx demo in
  `apps/nginx-demo/app.yaml`.
- A read-only (`read:repository`) Forgejo token, stored in the ArgoCD
  repository secret `argocd/repo-forgejo`.
- The root Application `argocd/root`, which syncs `apps/` from
  `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git`.
- The Application `argocd/nginx-demo`, which syncs `apps/nginx-demo/` and
  deploys nginx with a `welcome.html` from a ConfigMap.

The play reuses the chart-managed admin credentials (`forgejo-admin` secret);
repo and file writes use that admin login, while ArgoCD only gets read access.
`forgejo.yml` must have run first. The play refreshes both Applications and
waits until they are on the latest commit.

The UI is ClusterIP-only; use a port-forward:

```sh
ssh root@192.168.0.137 \
  'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
# https://192.168.0.137:8080 — user admin
ssh root@192.168.0.137 \
  "kubectl -n argocd get secret argocd-initial-admin-secret \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

The nginx demo is exposed through **Traefik**, not a `kubectl port-forward`;
the Ingress in `apps/nginx-demo/app.yaml` routes its hostname to the
`ClusterIP` Service. See [Deploying the Traefik ingress](#deploying-the-traefik-ingress)
below for the install command and the `/etc/hosts` entry.

See `argocd-forgejo.md` for the ArgoCD/Forgejo setup and
`nginx-demo-argocd.md` for the nginx demo, the GitOps change flow and
troubleshooting.

## Deploying the Traefik ingress

`traefik.yml` installs (or upgrades) Traefik with the OCI chart
`oci://ghcr.io/traefik/helm/traefik` into the `traefik` namespace and makes it
the default IngressClass:

```sh
ansible-playbook traefik.yml
```

It uses `files/traefik-values.yaml` for:

- Service type `NodePort`, ports `30080` (HTTP) and `30443` (HTTPS);
- tolerations for the control-plane taint;
- `ingressEndpoint.ip: 192.168.0.137`, so the Ingress status matches the
  address clients use and ArgoCD reports the Ingress as healthy;
- conservative resource requests/limits and the chart's restricted-compatible
  security defaults (non-root, read-only root filesystem, all capabilities
  dropped).

Because the Talos node is only on `10.10.50.0/24`, the play also installs a
small `systemd-socket-proxyd` bridge on `k8s-management`:

```text
192.168.0.137:80  -> 10.10.50.22:30080
192.168.0.137:443 -> 10.10.50.22:30443
```

The bridge is L4 only; Traefik still performs all host-based routing. Add one
`/etc/hosts` entry per hostname on the workstation, for example:

```text
192.168.0.137  nginx-demo.kubernetes.local
```

`traefik.yml` must run after `argocd.yml`, because it checks that the nginx
Ingress already exists. A second run is idempotent (only the Helm task reports
`changed`). See `traefik.md` for the full design, `/etc/hosts` instructions for
Linux/macOS/Windows, TLS options and troubleshooting.

## Logging in from another server

The **remote login name is always `jan`** (the account that exists on the
container). The client machine does *not* need a local `jan` account — it only
needs a private key whose public key is authorized on the container:

- **Reuse the existing key:** copy `~/.ssh/id_ed25519` (and `.pub`) from the
  control node to the other server, then `ssh jan@<container>`.
- **Recommended — own key per server:** generate a key pair on the other server
  (`ssh-keygen -t ed25519`) and add its **public** key to
  `ssh_extra_authorized_keys` in `group_vars/all.yml`, then re-run the playbook:

  ```yaml
  ssh_extra_authorized_keys:
    - "ssh-ed25519 AAAAC3Nza... ops@other-server"
  ```

  It can also be supplied ad hoc:

  ```sh
  ansible-playbook site.yml \
    -e '{"ssh_extra_authorized_keys": ["ssh-ed25519 AAAA... ops@other-server"]}'
  ```

Notes:

- Only `root` and `jan` may log in (`AllowUsers`). To use a *different* login
  name, create that user and add it to `sshd_allow_users`.
- Password logins are disabled, so a key is mandatory.
- Reachability: use the container's eth0 address (home network / `vmbr0`). Servers
  inside the isolated `vmbr1` network can use `10.10.50.10`.

## Inventory and the container address

`hosts.yml` points at the container's **DHCP** address on the home network
(`vmbr0`). This is deliberately *not* `10.10.50.10`: that address lives on the
isolated `vmbr1` bridge and is only reachable from inside the Talos subnet.

If the DHCP lease changes, override it for a run:

```sh
ansible-playbook site.yml \
  -e "ansible_host=$(cd .. && tofu output -json management | jq -r .wan_ips.eth0)"
```

## Variables

All defaults live in `group_vars/all.yml`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `admin_user` | `jan` | Login created on the container. |
| `admin_groups` | `[sudo]` | Supplementary groups for the login. |
| `ssh_public_key_path` | `~/.ssh/id_ed25519.pub` | Key installed for `jan` and `root`. |
| `ssh_extra_authorized_keys` | `[]` | Extra public keys authorized for `jan` (other servers/operators). |
| `ssh_authorized_keys_exclusive` | `false` | When true, remove any keys not listed above. |
| `sshd_password_authentication` | `false` | Interactive password logins. |
| `sshd_permit_root_login` | `prohibit-password` | Root may log in with a key only. |
| `sshd_allow_users` | `root jan` | Accounts sshd accepts. |
| `talosctl_version` | `""` (latest) | Pin a talosctl release. |
| `kubectl_version` | `""` (stable) | Pin a kubectl release. |
| `helm_version` | `""` (latest) | Pin a Helm release. |
| `tools_packages` | see file | Base CLI packages. |
| `talos_endpoint_ip` | `10.10.50.22` | Talos control-plane endpoint written to the talosconfig (also used as the default node). |
| `talos_node_ip` | `{{ talos_endpoint_ip }}` | Node(s) bare `talosctl` commands target. |
| `talos_config_file` | `/root/.talos/config` | Path of the managed talosconfig. |
| `talos_tofu_dir` | `{{ playbook_dir }}/..` | OpenTofu project providing the `talosconfig` output (client certs). |
| `kube_config_dir` | `/root/.kube` | Directory of the managed admin kubeconfig. |
| `kubeconfig_file` | `{{ kube_config_dir }}/config` | Path of the managed kubeconfig. |
| `kube_api_endpoint` | `{{ talos_endpoint_ip }}` | Control plane host written into the kubeconfig (`:6443`). |

## Verification

The playbook finishes by asserting the effective sshd configuration is
key-only, asserting the talosconfig targets the Talos control plane, asserting
the kubeconfig points at the control plane, probing both APIs (non-fatal) and
reporting the installed versions. You can also check by hand:

```sh
ssh jan@<container> 'whoami; id; sudo -n whoami'
ssh jan@<container> 'talosctl version --client --short; kubectl version --client; helm version --short'
ssh root@<container> 'talosctl config info'        # endpoint/node of the control plane
ssh root@<container> 'kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"'
```

### ArgoCD

```sh
ssh root@<container> 'kubectl -n argocd get application root \
  -o jsonpath="{.status.sync.status}/{.status.health.status}"; echo'
ssh root@<container> 'kubectl -n argocd get application nginx-demo \
  -o jsonpath="{.status.sync.status}/{.status.health.status}"; echo'
ssh root@<container> 'kubectl -n argocd-demo get configmap argocd-demo'
ssh root@<container> 'kubectl -n nginx-demo get deploy,pods,svc'
ssh root@<container> 'kubectl -n argocd get secret repo-forgejo'
ssh root@<container> 'kubectl get ingressclass'
ssh root@<container> 'kubectl -n nginx-demo get ingress nginx'
```

Expected: both Applications `Synced/Healthy`, the demo ConfigMap managed by
ArgoCD, the nginx pod `1/1 Running`, IngressClass `traefik`, and Ingress
`nginx` with host `nginx-demo.kubernetes.local`. See `nginx-demo-argocd.md` for
the GitOps change flow and `traefik.md` for the ingress and `/etc/hosts`
setup.

Set the control-plane endpoint with the same command the role uses:

```sh
ssh root@<container> '/usr/local/bin/talosctl config endpoint 10.10.50.22'
```

> **Note:** the client certificate/key in the managed talosconfig come from the
> OpenTofu `talosconfig` output. If you generate a talosconfig by hand
> (`talosctl gen config`) it belongs to a *different* PKI and cannot talk to the
> cluster — re-run this playbook to restore the matching one.
>
> **Note:** the OpenTofu `node_ips[0]` / cluster endpoint is `10.10.50.10`, but
> that address is also the management container's own `eth1`
> (`management_lan_ip`), so it is *not* reachable as a Talos API from the
> container. The default `talos_endpoint_ip` therefore points at the reachable
> control plane `10.10.50.22` (`talos-node-3`); override it with
> `-e talos_endpoint_ip=...` once the IP conflict is resolved.

## Relationship to the OpenTofu bootstrap

`management.tf` only bootstraps the container: it brings the interfaces up and
seeds **root's** authorized key so Ansible can connect. Everything else — the
SSH server, the `jan` login and the tooling — is owned by this project, so the
container's boot script no longer installs anything.

The container `entrypoint` is written at creation time, so a change to the boot
script only takes effect after a recreate:

```sh
tofu apply -refresh=false -auto-approve \
  -replace=proxmox_virtual_environment_container.management \
  -target=proxmox_virtual_environment_container.management
```

## Security notes

- `host_key_checking = False` in `ansible.cfg` because the container is
  recreated with a new host key. Populate `~/.ssh/known_hosts` and set it to
  `True` if you prefer strict verification.
- Password authentication is disabled by `ssh_server`, but the `jan` key is
  installed *before* that happens, and root keeps key access, so the playbook
  cannot lock itself out.
- The Proxmox web console (xterm/noVNC) always remains available as a fallback.
