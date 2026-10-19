# talos-control-plane-ansible — talosctl client config for the control plane

Summary of the work that taught the Ansible project in `./ansible` to configure
the **talosctl client** on **`k8s-management`** (Proxmox LXC `105`) so that a
bare `talosctl` command targets the **Talos control plane** — no
`--endpoints`/`--nodes` flags needed.

Example command the role is built around (pinned default):

```
/usr/local/bin/talosctl config endpoint {{ talos_endpoint_ip | default('10.10.50.10') }}
```

## Starting point (what was wrong)

- `/root/.talos/config` (talosctl's default config) held an **empty** config:

  ```yaml
  context: ""
  contexts: {}
  ```

  so every `talosctl` call failed with `no context is set`.

- A hand-generated `/root/talosconfig` (from
  `talosctl gen config k8s-cluster https://10.10.50.10:6443`, see
  `/root/.bash_history`) did exist, but its **CA does not match the running
  cluster**: the live nodes reject it with
  `x509: certificate signed by unknown authority`. It is a *different* PKI.
- No endpoint/node was configured anywhere (`talosctl config info` →
  `Endpoints: not defined`).
- The OpenTofu cluster endpoint is `10.10.50.10` (`node_ips[0]`), but that is
  also the **management container's own `eth1`** (`management_lan_ip`), so the
  Talos API is not reachable there (see *Findings* below).

## Decisions

- **Ansible owns the talosconfig.** The client certificate/key are read from the
  OpenTofu project that owns the cluster PKI (`tofu output -raw talosconfig`) and
  installed at `/root/.talos/config`, so the client can never drift from the
  running cluster (context `talos-cluster`).
- **Pin the control plane with the command from the brief**
  (`talosctl config endpoint …`), plus `talosctl config node …` so bare
  `talosctl health` / `talosctl version` work.
- **Idempotent by design:**
  - the talosconfig is only (re)installed when the installed **CA** differs from
    the OpenTofu one;
  - the endpoint/node commands only run when the current values differ, so a
    second run reports `changed=0`.
- **Endpoint repointed to `10.10.50.22`** (the reachable control plane,
  `talos-node-3`) because `10.10.50.10` collides with the container itself.
  Overridable per run with `-e talos_endpoint_ip=…`.

## Files added / changed

```
ansible/
├── site.yml                        # + talos_client role, asserts, API probe
├── group_vars/all.yml              # + talos_endpoint_ip / node / config / tofu dir
├── README.md                       # + role, variables, verification
└── roles/
    └── talos_client/               # NEW
        ├── defaults/main.yml
        └── tasks/main.yml
```

### `talos_client` role

1. Ensures the config directory (`/root/.talos`, mode `0700`) exists.
2. Reads the cluster talosconfig on the control node
   (`tofu output -raw talosconfig`, `chdir: ../`, `delegate_to: localhost`).
3. Extracts the cluster **CA** from it.
4. Reads the currently installed talosconfig (if any).
5. Installs the managed talosconfig (`/root/.talos/config`, owner root,
   mode `0600`, `no_log`) **only** when the CA is missing/different.
6. Reads the current context (`talosctl config info -o json`).
7. Runs the endpoint command (the example) when `endpoints != [talos_endpoint_ip]`.
8. Runs `talosctl config node` when `nodes != [talos_node_ip]`.
9. Reports the resulting context.

### `site.yml`

- New role order: `ssh_server`, `tools`, `talos_client`.
- New post-task asserts `talos_endpoint_ip` is in both `endpoints` and `nodes`.
- A **non-fatal** API probe (`talosctl -n <endpoint> version`) reports
  reachability without failing the playbook (the cluster is rebuilt
  independently of the client config).
- The final report now shows context, endpoint, node and control-plane
  reachability.

### `group_vars/all.yml` (new keys)

| Variable | Value | Purpose |
| --- | --- | --- |
| `talos_endpoint_ip` | `10.10.50.22` | Control-plane endpoint written to the talosconfig. |
| `talos_node_ip` | `{{ talos_endpoint_ip }}` | Default node(s) for bare `talosctl`. |
| `talos_config_file` | `/root/.talos/config` | Managed talosconfig path. |
| `talos_tofu_dir` | `{{ playbook_dir }}/..` | OpenTofu project providing the PKI. |

## How to run

```sh
cd ansible
ansible-playbook site.yml
```

Override the endpoint for a run (e.g. once the IP conflict is fixed):

```sh
ansible-playbook site.yml -e talos_endpoint_ip=10.10.50.10
```

## Verification (live, on the running container)

```
$ ssh root@192.168.0.137 'talosctl config info'
Current context:     talos-cluster
Nodes:               10.10.50.22
Endpoints:           10.10.50.22
Roles:               os:admin
Certificate expires: 11 months from now (2027-10-06)

$ ssh root@192.168.0.137 'talosctl version --short'
  Tag:         v1.8.1
  Enabled:     RBAC
```

Playbook runs:

```
# first run after the repoint — sets endpoint + node
PLAY RECAP *********************************************************************
k8s-management  : ok=34  changed=2  unreachable=0  failed=0  skipped=4

# second run — idempotent
PLAY RECAP *********************************************************************
k8s-management  : ok=32  changed=0  unreachable=0  failed=0  skipped=6
```

The playbook asserts the endpoint/node and reports:

```
talosctl:  context talos-cluster, endpoint 10.10.50.22, node 10.10.50.22
talosctl:  control plane 10.10.50.22 reachable = True
```

With the certs installed by the role, the managed config authenticates to the
live control plane (`talosctl version --short` returns the server version).

## Findings (important)

1. **IP collision.** The OpenTofu `node_ips[0]` / cluster endpoint is
   `10.10.50.10`, but so is the management container's own `eth1`
   (`management_lan_ip` in `../variables.tf`). Both live on `vmbr1`, so the
   control plane cannot hold `10.10.50.10` while the container is up. Pointing
   talosctl there only reaches the container (`connection refused` on `:50000`).
   The default was therefore set to the reachable control plane **`10.10.50.22`**.
   Real fix: change `management_lan_ip` so the container stops stealing the
   control plane address (needs a container recreate), then revert
   `talos_endpoint_ip` to `10.10.50.10`.
2. **Stale hand-made talosconfig.** `/root/talosconfig` (context `k8s-cluster`)
   belongs to a different PKI than the running cluster and was left untouched;
   the managed config lives at `/root/.talos/config` (context `talos-cluster`).
3. **Cluster health.** `talosctl health` reported `etcd` stuck in `Preparing`
   because the cluster was never bootstrapped — **fixed** by running
   `talosctl bootstrap` (see the last section). `10.10.50.22` is `talos-node-3`
   (control plane, **Talos v1.8.1**, client is v1.14.2) and `10.10.50.21`
   presents yet another CA. Duplicate Talos VMs exist in Proxmox (`102–104` and
   `107–109`). Out of scope here, but worth a cleanup.

## Security / notes

- The managed talosconfig contains the cluster CA plus the client certificate
  **and private key**; it is written `0600`, owned by `root`, and the tasks that
  handle it use `no_log`.
- `tofu output -raw talosconfig` runs on the **control node**
  (`delegate_to: localhost`, `become: false`), so the OpenTofu state must be
  available where the playbook runs.
- The role needs `/usr/local/bin/talosctl` (installed by the `tools` role) and
  `tofu` on the control node.

## Follow-up — admin kubeconfig for `kubectl`

After the talosctl work, `kubectl` was already **installed** by the `tools` role
(`/usr/local/bin/kubectl`, v1.37.1, with bash completion), but it could not talk
to anything: there was **no kubeconfig** (`/root/.kube` did not exist) and the
OpenTofu project has no `kubeconfig` output (`talos_cluster_kubeconfig` was
never applied).

A new `kubeconfig` role (run after `talos_client`) fixes that:

1. Ensures `/root/.kube` exists (`0700`).
2. Downloads the admin kubeconfig with `talosctl kubeconfig -m=false -` (it is
   generated from the Talos machine secrets, so it works even while the API
   server is down).
3. Rewrites the `server:` from the Talos cluster endpoint (`10.10.50.10`, the
   container itself) to the reachable control plane
   `https://{{ kube_api_endpoint }}:6443` (`kube_api_endpoint` defaults to
   `talos_endpoint_ip` = `10.10.50.22`).
4. Installs it at `/root/.kube/config` (`0600`, `root`).

`site.yml` now asserts the effective server equals
`https://<kube_api_endpoint>:6443` and probes `kubectl get nodes` (non-fatal).

**Idempotency caveat:** `talosctl kubeconfig` mints a *new client certificate on
every call*, so its output is never byte-stable. The role therefore only
installs when the installed kubeconfig is missing, its **cluster CA** differs
from the freshly generated one, or its **server** differs from the desired
endpoint. A second run reports `changed=0`.

New variables: `kube_config_dir` (`/root/.kube`), `kubeconfig_file`
(`{{ kube_config_dir }}/config`), `kube_api_endpoint` (`{{ talos_endpoint_ip }}`).

### Verification (live)

```
$ ssh root@192.168.0.137 'kubectl config current-context; \
    kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"'
admin@talos-cluster
https://10.10.50.22:6443
```

```
PLAY RECAP (idempotent)
k8s-management  : ok=42  changed=0  unreachable=0  failed=0  skipped=7
```

> **Resolved:** the API was unreachable because the cluster had never been
> bootstrapped (`etcd` stuck in `Preparing`). See the next section.

## Follow-up — bootstrapping the control plane (fixing `:6443` unreachable)

### Symptom

`kubectl` and the `:6443` probe failed with `connection refused`. On the control
plane (`10.10.50.22`, `talos-node-3`):

```
SERVICE  STATE    EVENTS
etcd     Failed   [Failed]: Failed to run pre stage: failed to build initial
                  etcd cluster: failed to build cluster arguments: 1 error(s)
                  occurred:\x0a\x09timeout
```

`MachineStatus` was stuck at `STAGE=booting READY=false`.

### Root cause

The cluster had **never been bootstrapped**. With
`cluster.discovery.enabled: true`, the first control-plane node waits for the
discovery service to return cluster members; with no existing cluster to join
(and no `bootstrap` run), etcd's `Preparing` phase timed out and etcd never
started. No etcd → no `kube-apiserver` → nothing listening on `:6443`.

This matches the OpenTofu state: the `talos_machine_bootstrap` resource was
never applied.

### Fix

Bootstrap the (single reachable) control plane:

```sh
talosctl -e 10.10.50.22 -n 10.10.50.22 bootstrap
```

etcd formed a single-node cluster and started; the `kube-apiserver`,
`kube-controller-manager` and `kube-scheduler` static pods were then scheduled
and the API came up on `:6443`.

> The installed client (v1.14.2) has **no `--wait` flag** for `bootstrap`; it
> returns once the request is accepted. Watch progress with
> `talosctl -n 10.10.50.22 get machinestatus` and the etcd service.

### Verification (live, after bootstrap)

```
$ kubectl get nodes -o wide
NAME           STATUS   ROLES           AGE    VERSION   INTERNAL-IP   ...
talos-node-3   Ready    control-plane   ...    v1.31.1   10.10.50.22   ...

$ kubectl get pods -A
NAMESPACE     NAME                                   READY   STATUS
kube-system   coredns-68d75fd545-hgd2x               1/1     Running
kube-system   coredns-68d75fd545-lgcrd               1/1     Running
kube-system   kube-apiserver-talos-node-3            1/1     Running
kube-system   kube-controller-manager-talos-node-3   1/1     Running
kube-system   kube-flannel-l48nl                     1/1     Running
kube-system   kube-proxy-mfkdj                       1/1     Running
kube-system   kube-scheduler-talos-node-3            1/1     Running

$ kubectl get --raw=/healthz
ok
```

### Cluster endpoint repointed to `10.10.50.22`

The Talos machine config advertised `cluster.controlPlane.endpoint:
https://10.10.50.10:6443` — the **management container's own IP**, not a
control-plane node — so the last check of cluster-wide `talosctl health` failed
(`Get "https://10.10.50.10:6443/api/v1/nodes": connection refused`). Repointed
to the live control plane:

```sh
talosctl -n 10.10.50.22 patch machineconfig \
  --patch='[{"op":"replace","path":"/cluster/controlPlane/endpoint","value":"https://10.10.50.22:6443"}]'
# patched MachineConfigs.config.talos.dev/v1alpha1 at the node 10.10.50.22
# Applied configuration without a reboot
```

Talos regenerated the apiserver serving certificate and reconciled the control
plane components without a reboot. `talosctl health` now completes:

```
waiting for all k8s nodes to report: OK
waiting for all control plane static pods to be running: OK
waiting for all control plane components to be ready: OK
waiting for kube-proxy to report ready: OK
waiting for coredns to report ready: OK
```

OpenTofu source updated to match: new `cluster_endpoint_ip` variable (default
`10.10.50.22`) in `../variables.tf`, consumed by the controlplane machine config
in `../talos.tf` instead of `node_ips[0]`.

> `node_ips[0]` (`10.10.50.10`) is still used as the **bootstrap node** in
> `talos_machine_bootstrap` / `talos_cluster_kubeconfig`. Those resources are not
> in state and the cluster is already bootstrapped on `10.10.50.22`; if the
> project is ever applied for real, point bootstrap at a reachable control plane
> (or fix the `management_lan_ip` collision first).

Longer term, fix the root cause: change `management_lan_ip` in `../variables.tf`
to a free address and recreate the management container so `10.10.50.10` can be
the control plane again — then set `cluster_endpoint_ip` back to
`10.10.50.10`.

