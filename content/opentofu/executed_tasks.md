# Executed tasks — `from-scratch.sh` end-to-end run

Date: 2026-10-27
Working directory: `content/opentofu`
Result: **success** — `./from-scratch.sh --yes` exits `0`; the Talos cluster,
Forgejo, Argo CD, Traefik and the nginx demo are all deployed and reachable.

---

## 1. Environment

| Item | Value |
| --- | --- |
| Proxmox API | `https://192.168.0.141:8006/` (node `proxmox`) |
| Router LXC | `106` / `k8s-router` / eth0 `192.168.0.250`, eth1 `10.10.50.1` |
| Management LXC | `105` / `k8s-management` / eth0 `192.168.0.201`, eth1 `10.10.50.5` |
| Talos VMs | `103` `talos-node-1` `10.10.50.10`, `102` `talos-node-2` `10.10.50.21`, `101` `talos-node-3` `10.10.50.22` |
| Talos OS | v1.8.1 (boot ISO + installer image) |
| Kubernetes | v1.31.1 |
| OpenTofu | 1.13.0 |
| Providers | `bpg/proxmox` 0.115.x, `siderolabs/talos` 0.6.1, `hashicorp/helm` 2.x |
| Helm charts | `argo-cd` 10.11.6 (app v3.5.6), `traefik` 42.1.3, `forgejo` 15.0.11 |
| Ansible | core 2.21.5, collection `ansible.posix` |

The physical control host has no route to `10.10.50.0/24`, so all Talos /
Kubernetes work runs **inside the dual-homed management container**. The
Proxmox resources are created from the control host.

---

## 2. Summary

| Stage | Command | Result |
| --- | --- | --- |
| Prerequisites | `tofu`, `ansible-playbook`, `ssh`, `rsync`, `python3`, Proxmox API auth | OK |
| Base infrastructure | `tofu init` + targeted plan/apply (router, management, Talos VMs) | OK, no changes on re-run |
| Management discovery | Proxmox API `lxc/105/interfaces` → `192.168.0.201` | OK |
| Talos config apply | `tofu apply -target=talos_machine_configuration_apply.nodes` (remote) | OK |
| Talos bootstrap | `tofu apply -target=talos_machine_bootstrap.this` (remote) | OK |
| Cluster + Argo CD | `tofu apply -auto-approve` (remote) | OK |
| State sync | remote `terraform.tfstate` → local (serial 32) | OK |
| Management config | `ansible-playbook site.yml` | OK, `failed=0` |
| Forgejo | `ansible-playbook forgejo.yml` | OK, `failed=0` |
| Argo CD + GitOps + demo | `ansible-playbook argocd.yml` | OK, `failed=0` |
| Traefik | `ansible-playbook traefik.yml` | OK, `failed=0` |
| Full script re-run | `./from-scratch.sh --yes` | OK, exit `0`, all playbooks `failed=0` |

State serial progression: `24` (stale local) → `26` (config apply) → `28`
(bootstrap + kubeconfig) → `31` (Argo CD Helm release) → `32` (final re-run,
local and remote in sync).

---

## 3. Problems found and corrections applied

### 3.1 Provider versions did not match the lock file

* **Symptom:** `tofu init`/plan failed because the configured provider
  constraint did not match `.terraform.lock.hcl`.
* **Cause:** the project had been moved between Talos provider versions
  (`0.12.x` vs `0.6.x`); the lock file was stale.
* **Fix:** pinned the providers in `main.tf`:
  * `bpg/proxmox` → `~> 0.115.0`
  * `siderolabs/talos` → `~> 0.6.0` (resolved 0.6.1)
  * `hashicorp/helm` → `>= 2.0.0`
* Talos provider `0.12.0` stalled after config apply (nodes never returned);
  `0.6.1` applies the config and bootstraps correctly with Talos v1.8.1.

### 3.2 Talos nodes stuck in `booting` / bootstrap `connection refused`

* **Symptom:** `talos_machine_bootstrap` failed after 10 min with
  `dial tcp 10.10.50.10:50000: connect: connection refused`.
* **Cause:** the bootstrap step ran while the freshly configured nodes were
  still rebooting/installing. Once they were back, all three APIs listened on
  `:50000` and `talosctl get machinestatus` showed `stage: booting` with
  `etcd is waiting to join the cluster ... run talosctl bootstrap`.
* **Fix:** re-ran the targeted bootstrap from the management container once the
  nodes were reachable:
  `tofu apply -target=talos_machine_bootstrap.this -auto-approve`
  → `1 added`.

### 3.3 Health check timed out during first boot

* **Symptom:** `data.talos_cluster_health.this` failed with
  `context deadline exceeded` while the API server images were still being
  pulled (etcd was already healthy).
* **Fix:** raised the data-source timeout in `talos.tf`:
  ```hcl
  timeouts = {
    read = "30m"
  }
  ```
  The provider schema exposes `timeouts` as an attribute, not a block.

### 3.4 All workloads `Pending` — control-plane taint

* **Symptom:** `helm_release.argocd` failed with
  `failed pre-install: timed out waiting for the condition`. The hook pod
  `argocd-redis-secret-init-*` was `Pending`:
  `0/3 nodes are available: 3 node(s) had untolerated taint
  {node-role.kubernetes.io/control-plane: }`.
* **Cause:** the cluster has three control-plane nodes and no workers, so the
  default `node-role.kubernetes.io/control-plane:NoSchedule` taint left the
  cluster with nowhere to schedule workloads.
* **Fix:** declaratively allowed scheduling on control planes in `talos.tf`:
  ```hcl
  cluster = {
    allowSchedulingOnControlPlanes = true
  }
  ```
  Applied with `tofu apply -target=talos_machine_configuration_apply.nodes`;
  all taints disappeared without a reboot.
* Cleaned up the failed Helm release and the stuck namespace before retrying:
  `helm uninstall argocd -n argocd --no-hooks`,
  forced deletion of the terminating pod, and finalisation of the namespace.

### 3.5 `talos_version` cannot be bumped on a live cluster

* **Observation:** `talos_machine_secrets.this` had `talos_version = "v1.7.0"`,
  while the running nodes are v1.8.1.
* **Important:** the provider folds `talos_version` into the generated
  `machine_secrets`. A plan changing it showed an in-place update of
  `machine_secrets` (new PKI/tokens) — applying it would have broken the live
  cluster. The value was therefore left pinned, with a comment in `talos.tf`.
  The applied machine configuration already uses
  `install.image: ghcr.io/siderolabs/installer:v1.8.1` and
  `kubelet: v1.31.1`, so no functional drift exists.

### 3.6 Tool version pinning had no effect

* **Symptom:** `group_vars/all.yml` pinned `talosctl_version: "1.8.1"`, but the
  management container kept talosctl v1.14.2.
* **Cause:** `ansible.builtin.get_url` defaults to `force: false`, so an
  existing binary is never overwritten even when the version differs.
* **Fix:** added `force: true` to the talosctl `get_url` task in
  `roles/tools/tasks/main.yml`.
* Tool versions are now pinned in `group_vars/all.yml` to match the cluster:
  `talosctl 1.8.1`, `kubectl v1.31.1`, `helm 3.16.3`.

### 3.7 `talosctl kubeconfig` stdout syntax incompatible with v1.8.x

* **Symptom:** after pinning talosctl to 1.8.1, `kubeconfig` role failed:
  `object of type 'NoneType' has no attribute 'clusters'`.
* **Cause:** `talosctl v1.8.x` treats `-` as a file name:
  `kubeconfig file already exists, use --force to overwrite: "-"`, so no
  kubeconfig was written to stdout.
* **Fix:** the role now downloads to a temporary file and reads it back:
  ```yaml
  /usr/local/bin/talosctl kubeconfig --merge=false --force
  {{ kubeconfig_download_path }}
  ```
  followed by `slurp` + `file: state=absent`, then the existing endpoint
  rewrite and CA comparison. Works with 1.8.x and newer.

### 3.8 Hard-coded management IP

* **Symptom:** Traefik/Argo CD output and the systemd socket proxy used
  `192.168.0.137`, but the container's DHCP address is `192.168.0.201`.
* **Fix:** `ansible2/traefik.yml` and `ansible2/argocd.yml` now use
  `{{ ansible_host }}` (and `{{ talos_endpoint_ip }}` for the node). The
  inventory is refreshed by the script from the Proxmox API.

### 3.9 Script robustness (`from-scratch.sh`)

The orchestration script was rewritten to make the run repeatable:

* `--yes` / `-y` for unattended runs and `--skip-ansible` for infra only.
* Always runs `tofu init` (a stale `.terraform` used to break the first plan).
* Base apply is **targeted** at router, management and Talos VMs only.
* The cluster/Talos/Argo CD apply runs inside the management container.
* Management WAN IP is discovered dynamically from the Proxmox API
  (`/nodes/<node>/lxc/<vmid>/interfaces`), not from an output that may be stale.
* Remote state serial is compared with the local one before copying; a newer
  remote state is synced back first, and the final state is copied back after
  the remote apply.
* `ansible_host` in `ansible2/hosts.yml` is rewritten to the discovered IP.
* Summary prints the actual cluster endpoint and node IPs.

---

## 4. Key commands executed

```bash
# Base infrastructure (control host)
cd content/opentofu
tofu init -input=false
tofu plan -input=false -out=tfplan \
  -target=proxmox_virtual_environment_container.router \
  -target=proxmox_virtual_environment_container.management \
  -target=proxmox_virtual_environment_vm.talos_nodes
tofu apply -input=false tfplan

# Cluster work (management container, reachable at 192.168.0.201)
ssh root@192.168.0.201
cd /root/opentofu
tofu init -input=false
tofu apply -target=talos_machine_configuration_apply.nodes -auto-approve
tofu apply -target=talos_machine_bootstrap.this -auto-approve
tofu apply -auto-approve

# Verification
export KUBECONFIG=/root/.kube/config
kubectl get nodes
kubectl get pods -A
kubectl -n argocd get applications
helm list -A

# Ansible (control host, inventory ansible_host=192.168.0.201)
cd ansible2
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml
ansible-playbook forgejo.yml
ansible-playbook argocd.yml
ansible-playbook traefik.yml

# Full orchestration re-run
cd ..
./from-scratch.sh --yes
```

---

## 5. Final verification

```
$ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
talos-node-1   Ready    control-plane   50m   v1.31.1
talos-node-2   Ready    control-plane   50m   v1.31.1
talos-node-3   Ready    control-plane   50m   v1.31.1

$ kubectl -n argocd get applications
NAME         SYNC STATUS   HEALTH STATUS
nginx-demo   Synced        Healthy
root         Synced        Healthy

$ helm list -n argocd
NAME     NAMESPACE   REVISION   STATUS     CHART           APP VERSION
argocd   argocd      1          deployed   argo-cd-10.11.6 v3.5.6

$ curl -H 'Host: nginx-demo.kubernetes.local' http://192.168.0.201/
HTTP 200 — "nginx demo — ArgoCD"
```

No pods outside `Running`/`Completed`. Local and remote state both at
serial `32`; `tofu plan` reports **No changes**.

Access:

* Argo CD UI: `ssh root@192.168.0.201 'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'`
  → `https://192.168.0.201:8080`
* nginx demo: add `192.168.0.201 nginx-demo.kubernetes.local` to `/etc/hosts`,
  then open `http://nginx-demo.kubernetes.local`
* Forgejo (in-cluster): `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git`

---

## 6. Files changed

| File | Change |
| --- | --- |
| `main.tf` | Provider pins: Proxmox `~> 0.115.0`, Talos `~> 0.6.0`, Helm `>= 2.0.0` |
| `talos.tf` | `cluster.allowSchedulingOnControlPlanes`; 30 min health timeout; `talos_nodes`/`cluster_endpoint` outputs; comment on the secrets/PKI pin |
| `from-scratch.sh` | `--yes`/`--skip-ansible`, always init, targeted base apply, remote apply, state serial sync, dynamic management IP, inventory refresh, summary |
| `ansible2/group_vars/all.yml` | Pinned `talosctl 1.8.1`, `kubectl v1.31.1`, `helm 3.16.3` |
| `ansible2/roles/tools/tasks/main.yml` | `force: true` so version pins actually replace existing binaries |
| `ansible2/roles/kubeconfig/tasks/main.yml` | Download kubeconfig to a temp file (`--merge=false --force`), slurp, remove; compatible with talosctl 1.8.x |
| `ansible2/roles/kubeconfig/defaults/main.yml` | `kubeconfig_download_path` |
| `ansible2/hosts.yml` | `ansible_host: 192.168.0.201` (rewritten by the script) |
| `ansible2/traefik.yml` | Dynamic `ansible_host`/`talos_endpoint_ip`, ingress endpoint via `--set-string` |
| `ansible2/argocd.yml` | Dynamic management IP in the final output |
| `terraform.tfstate` / `.backup` / `.terraform.lock.hcl` | Synced with the live cluster (serial 32) |

---

## 7. Known caveats

* **Single control-plane pool:** all three nodes are schedulable control
  planes (`allowSchedulingOnControlPlanes = true`). This is fine for a homelab
  but is not a production HA topology; add workers before removing the taint
  again.
* **`talos_version` pin:** keep `v1.7.0` in `talos_machine_secrets` unless you
  intend to rotate the cluster PKI, rebuild the nodes and re-issue kubeconfigs.
* **Argo CD ownership:** `argocd.tf` (OpenTofu Helm provider) and
  `ansible2/argocd.yml` (`helm upgrade --install`, OCI chart) both target the
  same release. The current values produce no drift (`tofu plan` = no
  changes), but future changes to the chart/values should be made in one place
  only.
* **State is local, not remote:** `terraform.tfstate` is synced between the
  control host and `/root/opentofu/terraform.tfstate` on the management
  container by `from-scratch.sh`. Do not run `tofu apply` from both hosts at
  the same time.
