# ansible-ssh — SSH login + tooling for k8s-management

Summary of the work that configured a key-based SSH login on **`k8s-management`**
(Proxmox LXC `105`) with Ansible, owning both the SSH **server** and the
**tools** (talosctl/kubectl).

## Starting point (what was wrong)

- The container was reachable over SSH **as `root` only**.
- `management.tf`'s boot script (`k8s-management-setup.sh`) tried to create
  `jan` and `ubuntu` logins, but those users never existed. It only ran
  `mkdir -p /home/jan/.ssh` / `mkdir -p /home/ubuntu/.ssh` **as root**, so the
  authorized keys landed in root-owned home directories of userless accounts.
- An orphan `/home/ubuntu` directory (no matching passwd entry) was left behind.
- `talosctl` and `kubectl` were installed by the same ad-hoc boot script.

## Decisions

- **Login:** create `jan` as a member of `sudo` with passwordless sudo, install
  the control node's public key, and keep root key access.
- **Integration:** a versioned `ansible/` project run over SSH from the control
  node; the container boot script no longer configures sshd, users or tools.

## Files added / changed

```
ansible/
├── ansible.cfg            # inventory, private key, become
├── hosts.yml              # target = container's home-network (vmbr0) address
├── requirements.yml       # ansible.posix collection
├── site.yml               # ssh_server + tools + verification/asserts
├── group_vars/all.yml     # jan, key path, sshd + tool settings
├── README.md
└── roles/
    ├── ssh_server/
    │   ├── defaults/main.yml
    │   ├── handlers/main.yml
    │   ├── tasks/main.yml
    │   └── templates/sshd_config.d/99-k8s-management.conf.j2
    └── tools/
        ├── defaults/main.yml
        └── tasks/main.yml
```

- `management.tf` — boot script reduced to DNS + seeding **root's** authorized
  key (bootstrap access for Ansible); header comment updated.
- `management-changes.md` — Ansible handoff section + live verification.
- `management.md` — Dutch description updated to reflect the Ansible setup.

### `ssh_server` role

- Installs/enables `openssh-server`.
- Creates `jan` (groups `[sudo]`, `/bin/bash`, home created) and registers the
  account so its home path can be used.
- Installs the control-node key for `jan` and `root` (`ansible.posix.authorized_key`).
- **Ensures `jan` owns its home directory contents** (`file: recurse=true`) —
  required because the pre-existing home was root-owned, which sshd rejects for
  key authentication.
- Grants passwordless sudo via `/etc/sudoers.d/90-jan`
  (`jan ALL=(ALL) NOPASSWD:ALL`, validated with `visudo -cf`).
- Deploys `/etc/ssh/sshd_config.d/99-k8s-management.conf` (validated with
  `sshd -t -f %s`) and restarts `ssh`:

  ```
  PubkeyAuthentication yes
  PasswordAuthentication no
  KbdInteractiveAuthentication no
  PermitRootLogin prohibit-password
  PermitEmptyPasswords no
  X11Forwarding no
  AllowUsers root jan
  ```

### `tools` role

- Base CLI packages: `bash-completion`, `ca-certificates`, `curl`, `dnsutils`,
  `git`, `iptables`, `jq`, `unzip`.
- `talosctl` from GitHub releases (latest by default, `talosctl_version` to pin).
- `kubectl` from `dl.k8s.io` (stable by default, `kubectl_version` to pin) with
  a SHA-256 checksum.
- kubectl bash completion in `/etc/bash_completion.d/kubectl`.
- Installs only when missing or when a pinned version differs (idempotent).

## Terraform change (`management.tf`)

`k8s-management-setup.sh` now only:

1. Writes `/etc/resolv.conf` if empty (so Ansible can `apt`).
2. Seeds `/root/.ssh/authorized_keys` with the control-node public key.

Everything else (sshd, `jan`, tools) is owned by Ansible.

> The container `entrypoint` is written only when the container is **created**,
> so this boot-script change needs a recreate to take effect for a fresh
> container:
>
> ```
> tofu apply -refresh=false -auto-approve \
>   -replace=proxmox_virtual_environment_container.management \
>   -target=proxmox_virtual_environment_container.management
> ```
>
> `tofu apply` was intentionally **not** run (it would recreate the running
> container unnecessarily); the live container is already fully configured.

## How to run

```sh
cd ansible
ansible-galaxy collection install -r requirements.yml   # once
ansible-playbook site.yml
```

Target address: `hosts.yml` points at the container's DHCP address on the home
network (`vmbr0`), **not** `10.10.50.10` (that one is only reachable inside
`vmbr1`). If the lease changes:

```sh
ansible-playbook site.yml \
  -e "ansible_host=$(cd .. && tofu output -json management | jq -r .wan_ips.eth0)"
```

## Verification (live, on the running container)

SSH login as `jan` with key-only auth and passwordless sudo:

```
$ ssh jan@192.168.0.137 'whoami; id; sudo -n whoami'
jan
uid=1000(jan) gid=1000(jan) groups=1000(jan),27(sudo)
root
```

Tools available to `jan`:

```
$ ssh jan@192.168.0.137 'talosctl version --client --short; kubectl version --client -o json | grep gitVersion'
Client:
Talos v1.14.2
    "gitVersion": "v1.37.1",
```

Effective sshd policy:

```
$ ssh root@192.168.0.137 '/usr/sbin/sshd -T | grep -Ei "^(passwordauthentication|permitrootlogin|pubkeyauthentication|allowusers)"'
permitrootlogin prohibit-password
pubkeyauthentication yes
passwordauthentication no
allowusers root
allowusers jan
```

Playbook run (idempotent):

```
PLAY RECAP *********************************************************************
k8s-management  : ok=22  changed=0  unreachable=0  failed=0  skipped=2
```

The playbook also asserts, at the end, that `PasswordAuthentication` is disabled
and `PermitRootLogin` is `prohibit-password`.

Drift test: `/home/jan` was reverted to `root:root` on purpose, which broke key
auth as expected; a subsequent `ansible-playbook site.yml` detected and fixed
the ownership (`changed=1`), and `jan` could log in again. A following run was
back to `changed=0`.

OpenTofu checks:

- `tofu validate` → Success.
- `tofu plan -refresh=false -target=proxmox_virtual_environment_container.management`
  → 0 to add, 1 to change (only `initialization.entrypoint`), 0 to destroy.

## Logging in from another server (no local `jan` account)

The remote login name is always **`jan`**; the client does not need a local
`jan` account. It only needs a private key whose public key is authorized for
`jan` on the container.

- **Reuse the key:** copy the control node's `~/.ssh/id_ed25519` to the other
  server and `ssh jan@<container>`.
- **Own key per server (recommended):** generate a key pair on the other server
  (`ssh-keygen -t ed25519`) and authorize only its public key via the playbook:

  ```yaml
  # ansible/group_vars/all.yml
  ssh_extra_authorized_keys:
    - "ssh-ed25519 AAAAC3Nza... ops@other-server"
  ```

  or ad hoc (mind the JSON, a bare `key=value` is coerced to a string):

  ```sh
  ansible-playbook site.yml \
    -e '{"ssh_extra_authorized_keys": ["ssh-ed25519 AAAA... ops@other-server"]}'
  ```

  Set `ssh_authorized_keys_exclusive: true` to make the playbook remove any keys
  not listed above.

Verified end-to-end: a throwaway `ed25519` key added via
`ssh_extra_authorized_keys` logged in as `jan` with passwordless sudo
(`changed=1`); after removing it, the normal run returned to `changed=0`.

Only `root` and `jan` are accepted by `AllowUsers`; a *different* login name
requires creating that user and adding it to `sshd_allow_users`. Password auth
stays disabled, so a key is mandatory. Network path: container eth0 (home
network) or `10.10.50.10` from inside `vmbr1`.

## Environment notes

- Ansible was not installed on the control node, so `ansible-core` and the
  `ansible.posix` collection were installed under `~/.local` (via
  `pip --user --break-system-packages`).
- The orphan `/home/ubuntu` directory on the container was removed.
- `host_key_checking = False` in `ansible.cfg` (containers are recreated with a
  new host key); enable it after populating `known_hosts` for strict
  verification.
- Password auth is disabled only after the `jan` key is installed and root key
  access is preserved, so the playbook cannot lock itself out; the Proxmox web
  console remains a fallback.

## Troubleshooting

### `ssh 192.168.0.137 -l jan` → `Permission denied (publickey)` from the control node

The key lives in the **`jan`** account: `/home/jan/.ssh/id_ed25519` (owner
`jan`, mode `600`). If the ssh client is run as **`root@ubuntu26CT`**, root only
looks in `/root/.ssh/` (and the agent), finds no key, and offers none — the
server then correctly rejects it. The server side is fine (`sshd -T` shows
`pubkeyauthentication yes` and `allowusers ... jan`).

Use one of:

```sh
# run as the account that owns the key
ssh jan@192.168.0.137

# as root, point ssh at jan's key explicitly
ssh -i /home/jan/.ssh/id_ed25519 jan@192.168.0.137

# or give root its own copy (needs root)
install -d -m 700 /root/.ssh
install -m 600 /home/jan/.ssh/id_ed25519 /root/.ssh/id_ed25519
```

The `ED25519 key fingerprint ... continue connecting?` prompt is expected after
a container recreate/reboot (new host key); accepting just adds it to
`known_hosts`.

