# k8s-management — Ansible configuration

Ansible project that configures the **`k8s-management`** Proxmox LXC container
(ID `105`) over SSH:

| Role | What it does |
| --- | --- |
| `ssh_server` | Installs/enables `openssh-server`, creates the **`jan`** login (member of `sudo`, passwordless sudo), installs the control-node public key for `jan` **and** `root`, and hardens sshd (key-only logins, root restricted to keys) through `/etc/ssh/sshd_config.d/99-k8s-management.conf`. |
| `tools` | Installs the base CLI packages plus **`talosctl`** and **`kubectl`** (latest stable by default) and enables kubectl bash completion. |
| `talos_client` | Writes the managed **talosconfig** (`/root/.talos/config`) for the control plane: the client certs come from the OpenTofu `talosconfig` output, and the **Talos control-plane endpoint/node** are pinned with `talosctl config endpoint` / `config node`. |
| `kubeconfig` | Generates the **admin kubeconfig** (`/root/.kube/config`) with `talosctl kubeconfig` and points its server at the reachable control plane, so `kubectl` works without arguments. |

## Layout

```
ansible/
├── ansible.cfg              # control-node config (inventory, key, become)
├── hosts.yml                # inventory: the container's home-network address
├── requirements.yml         # ansible.posix collection
├── site.yml                 # playbook: ssh_server + tools + talos_client + kubeconfig
├── group_vars/all.yml       # users, keys, sshd + tool settings
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
    └── kubeconfig/
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
ssh jan@<container> 'talosctl version --client --short; kubectl version --client'
ssh root@<container> 'talosctl config info'        # endpoint/node of the control plane
ssh root@<container> 'kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"'
```

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
