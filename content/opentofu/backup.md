# Garage backup target, Velero, and local-path data

**Status:** implemented and verified on 2026-10-30.

**Scope:** protect the Kubernetes objects and PersistentVolume data of the
Talos cluster with a backup target that lives on the Proxmox external disk.
The operational step-by-step runbook is
[`backup-restore-howto.md`](backup-restore-howto.md).

**Do not reformat `/dev/sdb1`.** The external disk is already the Proxmox
`externe-disk` storage at `/mnt/small`. Garage runs in a dedicated Proxmox LXC,
not on the Proxmox host itself, because root SSH to the host is denied and the
API token cannot create arbitrary bind mounts.

---

## 1. What protects what

| Data | Tool | Target | Schedule / retention |
| --- | --- | --- | --- |
| Kubernetes objects (Deployments, Services, Secrets, PVC objects, CRs, ...) | Velero 1.18.2 + AWS S3 plugin | Garage bucket `velero` | Daily at 02:00 UTC, 30 days |
| `local-path` PV data (`nextcloud`, `forgejo`, PostgreSQL, the NFS server backing store) | restic 0.18.1 DaemonSet | Garage bucket `restic` | Every 24 h per node; 30 daily / 8 weekly / 6 monthly |
| NFS client volumes (`ds-files`, `ds-runtime-config`) | restic (through the NFS server's `local-path` directory) | Garage bucket `restic` | Same as above |
| PostgreSQL logical dump | `postgres-dump` CronJob into PVC `euro-office/postgres-dumps` | Included in the restic snapshot | Daily at 01:30 UTC, 14 dump files |
| Garage metadata | SQLite online backup timer | `/mnt/garage/meta-snapshots` | Daily at 01:15 UTC, 30 days |
| Garage object data | Garage | `/mnt/garage/data` on the external disk | Continuous |
| Talos OS / etcd / VM disks | **not covered here** | — | Add Proxmox VM backups separately |
| Copy of the external disk | **not covered here** | — | No off-site copy yet |

The important correction to the original design:

> **Velero/Kopia cannot back up a PV whose source is `hostPath`.** The
> `local-path` provisioner creates `hostPath` PVs, so Velero logs a warning and
> skips their data even with `--default-volumes-to-fs-backup`. Velero is used
> for Kubernetes objects, and restic is used for the node-local
> `/var/local-path-provisioner` tree. The NFS server's data lives in that tree,
> so backing up the NFS server node also protects the NFS client volume data.

This is why the Velero schedule sets `defaultVolumesToFsBackup: false`; it is
not an omission. See section 7 for the volume layer.

---

## 2. Implemented topology

```text
Proxmox host (API token access; no root SSH)
  externe-disk storage: /mnt/small, backed by /dev/sdb1
    500 GiB raw volume
      -> LXC 107 garage-backup, mounted at /mnt/garage (ext4)

LXC 107 garage-backup (privileged; onboot=1)
  eth0 192.168.0.224/24  vmbr0  (management network)
  eth1 10.10.50.2/24     vmbr1  (Kubernetes network)
  Garage v2.5.0
    S3 API            http://10.10.50.2:3900  (path-style)
    data              /mnt/garage/data
    metadata          /var/lib/garage/meta
    buckets           velero, restic
    metadata copies   /mnt/garage/meta-snapshots
    service           systemd unit garage.service
    network entry     /usr/local/sbin/garage-net-init -> exec /sbin/init

Kubernetes cluster
  Velero 1.18.2 (namespace velero)
    BackupStorageLocation default -> http://10.10.50.2:3900/velero
    schedule velero-daily
  restic DaemonSet local-path-backup (namespace backup)
    hostPath /var/local-path-provisioner on every node
    repository s3:http://10.10.50.2:3900/restic
  postgres-dump CronJob (namespace euro-office)
```

The management LXC is `192.168.0.192` / `10.10.50.5`; the Talos nodes are
`10.10.50.10`, `10.10.50.21`, and `10.10.50.22`. The Garage S3 endpoint is not
published outside the management/Kubernetes networks.

### Why an LXC instead of the Proxmox host

* Root SSH to the Proxmox host is denied; only the API token is available.
* The API token cannot create a bind mount for an unprivileged container.
* A privileged LXC with a normal Proxmox volume works with the available API
  permissions and keeps Garage outside the Kubernetes failure domain.
* `externe-disk` had to gain `rootdir` content so the LXC volume can live
  there. The storage content was changed from `backup,images` to
  `backup,rootdir,images`. Do not remove `rootdir`.

### Capacity and layout

The 500 GiB volume appears inside the LXC as an ext4 filesystem on loop device
`/dev/loop0`, mounted at `/mnt/garage`. At verification time Garage reported:

```text
Capacity   491.1 GiB
DataAvail  466.0 GiB (94.9%)
```

The Garage data and metadata-copy directories are on this volume. The
metadata database itself remains in `/var/lib/garage/meta` in the LXC root
filesystem; the timer makes a consistent copy onto the external disk.

---

## 3. Versions

| Component | Version |
| --- | --- |
| Garage | v2.5.0 (`x86_64-unknown-linux-musl`) |
| garage-webui | 1.1.0 (`garage-webui-v1.1.0-linux-amd64`) |
| Velero Helm chart | 12.2.2 |
| Velero server | v1.18.2 |
| Velero CLI | v1.18.4 |
| Velero AWS plugin | v1.14.4 |
| restic | 0.18.1 |
| PostgreSQL | 16.15 |
| Kubernetes | v1.31.1 (Talos v1.8.1) |
| Proxmox storage | `externe-disk`, `/mnt/small` |

Velero still reports `uploaderType: kopia`; that setting is harmless for the
object-only backups. It is not used for `hostPath` volumes.

---

## 4. Garage LXC implementation

The container was created with the Proxmox API token, not with host SSH.

| Setting | Value |
| --- | --- |
| VMID / hostname | `107` / `garage-backup` |
| Root filesystem | `local-lvm:4` (4 GiB) |
| Memory | 1 GiB |
| Network | `eth0` on `vmbr0`, `eth1` on `vmbr1` |
| Addresses | `192.168.0.224/24`, `10.10.50.2/24` |
| Data mount | `externe-disk:107/vm-107-disk-0.raw`, 500 GiB, `/mnt/garage` |
| Boot | `onboot=1` |
| Entrypoint | `/usr/local/sbin/garage-net-init` |
| Container type | privileged |

### Network entrypoint

The LXC boots with this persistent script, then hands off to systemd:

```sh
#!/bin/sh
set -eu

ip link set eth0 up
ip addr add 192.168.0.224/24 dev eth0 2>/dev/null || true
ip route replace default via 192.168.0.1 dev eth0 2>/dev/null || true

ip link set eth1 up
ip addr add 10.10.50.2/24 dev eth1 2>/dev/null || true

printf 'nameserver 192.168.0.1\nnameserver 1.1.1.1\n' > /etc/resolv.conf

exec /sbin/init
```

The source is in
`ansible2/files/backup/garage-net-init.sh`. It is intentionally idempotent: a
container restart re-adds the addresses with `|| true`.

### systemd state

The LXC's systemd instance reports `degraded` because several host-style units
(`apparmor`, `systemd-journald`, `systemd-tmpfiles`, `nftables`, ...) cannot run
inside this privileged container. SSH, `garage.service`, and the metadata timer
do work. The Garage unit deliberately has **no** `PrivateTmp`,
`ProtectSystem`, `ProtectHome`, or `ReadWritePaths` settings: those caused
systemd to exit the service with `status=226/NAMESPACE`. The current unit is in
`ansible2/files/backup/garage.service`.

A container reboot was tested on 2026-10-30: both addresses returned,
`/mnt/garage` was mounted, `garage.service` was active, and the metadata timer
was active.

---

## 5. Garage configuration and buckets

The binary is `/usr/local/bin/garage`. Configuration is `/etc/garage.toml`;
non-secret settings are:

```toml
metadata_dir = "/var/lib/garage/meta"
data_dir = "/mnt/garage/data"
db_engine = "sqlite"
replication_factor = 1

rpc_bind_addr = "[::]:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "<generated>"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"
public_endpoint = "http://10.10.50.2:3900"
public_endpoint_path_style = true

[admin]
api_bind_addr = "127.0.0.1:3903"
admin_token = "<generated>"
metrics_token = "<generated>"
```

The service unit starts:

```text
/usr/local/bin/garage -c /etc/garage.toml server --single-node --default-bucket
```

`--default-bucket` creates the `velero` bucket and a default access key. The
`restic` bucket was created explicitly and the default key was granted
read/write/owner access:

```bash
garage -c /etc/garage.toml bucket create restic
garage -c /etc/garage.toml bucket allow restic --read --write --owner --key <access-key-id>
```

Verification at implementation time:

```text
garage status              HEALTHY NODES: garage-backup, 491.1 GiB
garage bucket list         velero, restic
curl http://127.0.0.1:3900/   403 without credentials
velero backup-location get Phase: Available
```

The endpoint is deliberately HTTP inside the private network. There is no TLS
termination or Garage node replication; this is a single-node homelab target.

### Garage Web UI

Garage v2.5 itself has no admin UI yet (the official one is still in
development), so the community UI
[`garage-webui`](https://github.com/khairul169/garage-webui) v1.1.0 runs
alongside Garage as a second systemd unit. The full installation steps are in
[`garage-web-installation.md`](garage-web-installation.md).

| Setting | Value |
| --- | --- |
| Binary | `/usr/local/bin/garage-webui` (linux-amd64 release) |
| Service | `garage-webui.service` in `/etc/systemd/system/`, enabled |
| Runs as | user/group `garage` (it only needs to read `/etc/garage.toml`) |
| Env file | `/etc/garage-webui.env` (root-only 0600) |
| Listen | `0.0.0.0:3909` |
| Config | reads admin API and S3 endpoint straight from `/etc/garage.toml` |
| Auth | browser login via `AUTH_USER_PASS` (`/etc/garage-webui.env`) |

The UI is at <http://192.168.0.224:3909> from the management network (user
`admin`; the password lives only in `/etc/garage-webui.env` on the LXC and is
not reproduced in this repository). Unauthenticated admin API requests are
rejected with `401`; the Garage admin API stays bound to `127.0.0.1:3903`.
`apache2-utils` is installed on the LXC to generate new bcrypt hashes; see
`garage-webui.env.example` for the `$2y$` → `$2b$` prefix detail.

```bash
ssh root@192.168.0.224 'systemctl status garage-webui --no-pager'
ssh root@192.168.0.224 'cat /etc/garage-webui.env'
```

### Metadata snapshots

`garage-meta-snapshot.timer` runs daily at 01:15 UTC (with up to 5 minutes of
random delay) and executes `garage-meta-snapshot.sh`:

```text
sqlite3 /var/lib/garage/meta/db.sqlite \
  ".backup '/mnt/garage/meta-snapshots/db-<timestamp>.sqlite'"
```

It keeps 30 days of copies. At verification time one copy existed:
`db-20261030T151036Z.sqlite`. This protects against a bad metadata write; it
does **not** protect against loss of the external disk, because the copy is on
the same disk.

---

## 6. Velero implementation

### Namespace, credentials, and image

The `velero` namespace is labelled `pod-security.kubernetes.io/*=privileged`
for `node-agent`. The S3 credentials are stored in the `velero-credentials`
Secret in the `velero` namespace, under the `cloud` key in AWS credentials
format. The Secret is not reproduced in this repository.

The Helm values file is
`ansible2/files/backup/values-velero.yaml`. It sets:

```yaml
snapshotsEnabled: false
deployNodeAgent: true
configuration:
  uploaderType: kopia
  defaultVolumesToFsBackup: false
  defaultBackupTTL: 720h
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero
      config:
        region: garage
        s3ForcePathStyle: "true"
        s3Url: http://10.10.50.2:3900
```

The AWS plugin is `velero/velero-plugin-for-aws:v1.14.4`; the server image is
`velero/velero:v1.18.2`.

### Installed resources

```text
namespace/velero                       Active
deployment.apps/velero                 1/1 Running
daemonset.apps/node-agent              3/3 Ready (one per node)
backupstoragelocation/default          Available
schedule/velero-daily                  daily at 02:00 UTC
```

`velero-daily` includes `argocd`, `argocd-demo`, `euro-office`, `forgejo`,
`nextcloud`, `nfs-server`, `nginx-demo`, `traefik`, `local-path-storage`, and
`backup`, and excludes the Kubernetes system namespaces and `velero`. The
`backup` namespace is included so the restic credentials/Secret are present in
the object backup.

### Verification results

```text
smoke-test                     Completed   0 errors, 1 warning
velero-daily-20261030151045    Completed   0 errors, 0 warnings
smoke-restore                  Completed   0 errors, 1 warning
```

The one warning on `smoke-test` was the expected
`nextcloud-main ... is a hostPath volume which is not supported` warning. That
backup was created while `defaultVolumesToFsBackup` was still true; it did not
contain the Nextcloud volume data. The later daily backup and the current
schedule use object-only mode.

The restore test used `smoke-test` and restored only `nginx-demo` object
resources into `nginx-restore`:

```bash
velero restore create smoke-restore \
  --from-backup smoke-test \
  --include-namespaces nginx-demo \
  --namespace-mappings nginx-demo:nginx-restore \
  --wait
```

It completed, and the test namespace was deleted afterwards. A full restore
drill that also restores a local-path volume is covered in the how-to.

---

## 7. Volume backup: why restic, and how it is installed

### The `hostPath` problem

The cluster's `local-path` StorageClass (`rancher.io/local-path`) creates PVs
with:

```yaml
hostPath:
  path: /var/local-path-provisioner/pvc-...
```

Velero's pod-volume backupper rejects `hostPath` sources before it starts
Kopia. This is a hard limitation, not a configuration mistake. The NFS PVs
are exported from the `nfs-server` pod, whose backing PV is itself
`local-path`; therefore the NFS client data is also protected by backing up
the NFS server's node directory.

### restic repository

The restic repository is in a separate bucket so that its layout and locks do
not interfere with Velero:

```text
repository: s3:http://10.10.50.2:3900/restic
region: garage
path-style: yes
encryption: restic password held in Kubernetes Secret backup/restic-credentials
```

The restic password is required for restore and is not recoverable if lost.
It is stored in the `restic-credentials` Secret together with
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The Secret is included in the
Velero backup of the `backup` namespace, but the password should also be kept
in a password manager.

The repository was initialized with:

```bash
restic -o s3.bucket-lookup=path init
```

### DaemonSet

`ansible2/files/backup/restic-daemonset.yaml` runs one restic container per
node. It mounts:

```text
hostPath: /var/local-path-provisioner
mount:    /data (read-only)
```

and runs an immediate check, waits 0–5 minutes to spread node uploads, then:

```bash
restic backup /data --host "$NODE_NAME" --tag local-path
restic forget --host "$NODE_NAME" --tag local-path \
  --keep-daily 30 --keep-weekly 8 --keep-monthly 6 --prune
sleep 86400
```

Each node gets its own snapshot host label. The backup includes all PVC
subdirectories on that node, including the NFS server's backing directory and
the `postgres-dumps` PVC.

At verification time the DaemonSet had produced snapshots for
`talos-node-1` (empty `local-path`), `talos-node-2`, and `talos-node-3`, and a
node-3 snapshot containing the PostgreSQL dump:

```text
e3ff0405  talos-node-2  6.782 MiB
22e4944d  talos-node-3  77.336 MiB
089ec1bb  talos-node-1  0 B
649ffde6  talos-node-2  6.782 MiB
f76f7935  talos-node-1  0 B
d612308f  talos-node-3  77.624 MiB (includes postgres-dumps)
```

A restore test into a temporary directory on `talos-node-3` restored 2386
files/dirs and 77.336 MiB, and verified the PVC directory structure. The test
copy was deleted from the hostPath after verification.

### PostgreSQL logical dump

`ansible2/files/backup/postgres-dump.yaml` adds:

* PVC `euro-office/postgres-dumps` (10 GiB, `local-path`)
* CronJob `euro-office/postgres-dump` at 01:30 UTC

The job runs `pg_dumpall --clean --if-exists` with the existing
`postgres-credentials` Secret and writes `/dumps/postgres-<timestamp>.sql.gz`
to the PVC. It keeps 14 days of dumps. The first manual run completed and
produced a 295 KiB dump. The restic DaemonSet backs up the PVC's node-local
directory, so the dump is included in the same restic repository.

The dump is a logical fallback for PostgreSQL. It does not make the Nextcloud
file tree transactionally consistent with the database, and Forgejo still uses
SQLite without a separate logical dump.

---

## 8. Schedules and consistency

| Time (UTC) | Job |
| --- | --- |
| 01:15 | Garage metadata SQLite snapshot |
| 01:30 | `postgres-dump` CronJob |
| 02:00 | Velero `velero-daily` object backup |
| Every 24 h per node, from DaemonSet start | restic local-path backup |

The restic schedule is relative to pod start, not the wall clock. A DaemonSet
restart can therefore move that node's backup window. The first backup after a
pod start can take up to five minutes because of the deliberate jitter. Check
the logs and snapshot list rather than assuming a fixed minute.

The layers are not a transactionally consistent application snapshot:

* Velero objects are captured at 02:00.
* restic captures the physical local-path tree during its own cycle.
* PostgreSQL has a daily logical dump at 01:30.
* Nextcloud files on `local-path` and PostgreSQL data are not quiesced
  together; a restored Nextcloud may need a database consistency check.
* Forgejo SQLite is backed up as files; use its own dump/export if strict
  consistency is required.
* The NFS client volumes are not copied through Velero; their data is in the
  NFS server's local-path tree.

For a stricter application-consistent backup, add pre-backup hooks or a
maintenance window. That is not implemented yet.

---

## 9. Restore model

Use the detailed procedure in
[`backup-restore-howto.md`](backup-restore-howto.md). The essential order is:

1. **Kubernetes objects:** restore with Velero.
2. **local-path data:** stop the workload, restore the matching node's
   `/var/local-path-provisioner` tree from restic, then start the workload.
3. **PostgreSQL:** use the logical dump if the physical files cannot be
   restored consistently; otherwise restore the local-path directory and then
   verify the database.
4. **NFS:** restore the NFS server's local-path directory first; then restore
   the client objects and start the NFS server.
5. **Garage metadata:** stop Garage, copy a `db-*.sqlite` snapshot over
   `/var/lib/garage/meta/db.sqlite`, remove stale WAL/SHM files, fix ownership,
   and start Garage.
6. **Full LXC rebuild:** reinstall Garage, recreate `velero` and `restic`
   buckets, restore the metadata snapshot, restore the data volume, then
   recreate the Kubernetes Secrets and re-run the Velero/restic configuration.

A local-path PVC is node-bound. If the node is lost, the PV's node affinity
must be addressed before the workload can bind again; restoring data to a
different node is not enough by itself.

---

## 10. Verification checklist

### Verified

- [x] Garage v2.5.0 runs as `garage.service` in LXC 107.
- [x] `192.168.0.224/24` and `10.10.50.2/24` survive a container reboot.
- [x] `/mnt/garage` is the 500 GiB ext4 volume; Garage reports healthy.
- [x] `velero` and `restic` buckets exist.
- [x] Unauthenticated S3 request returns `403`.
- [x] Velero BackupStorageLocation is `Available`.
- [x] Velero object backup completes; `velero-daily-20261030151045` is Completed.
- [x] Velero `nginx-demo` restore completes.
- [x] restic repository is initialized; node snapshots exist.
- [x] restic restore to a temporary hostPath succeeds.
- [x] PostgreSQL dump CronJob completes.
- [x] Garage metadata timer is active and produced a snapshot.
- [x] Garage Web UI (`garage-webui`) runs as `garage-webui.service` on LXC 107,
      serves <http://192.168.0.224:3909>, and rejects unauthenticated admin
      API calls with `401` (2026-11-03).

### Not yet covered

- [ ] Off-site copy of the external disk / Garage buckets.
- [ ] Garage replication or a second Garage node.
- [ ] Proxmox VM-level backup of the Talos nodes and their etcd state.
- [ ] Application-consistent hooks for Nextcloud/Forgejo.
- [ ] A full production namespace restore that writes a local-path volume
      back in place and restarts the application.
- [ ] Automated restore verification (a scheduled restore test).
- [ ] TLS on the S3 endpoint.
- [x] Basic backup metrics for Velero and restic are published to Prometheus/Grafana; see [`back_up_statistics.md`](back_up_statistics.md).
- [ ] Alertmanager has no receiver configured, so backup alerts are only visible in the Prometheus/Alertmanager UIs.

---

## 11. Troubleshooting

### Garage is not reachable from Kubernetes

```bash
ssh root@192.168.0.224 'systemctl status garage.service --no-pager'
ssh root@192.168.0.224 'garage -c /etc/garage.toml status'
ssh root@192.168.0.224 'ip -4 addr show eth1'
ssh root@192.168.0.192 'curl -sS -o /dev/null -w "%{http_code}\n" http://10.10.50.2:3900/'
```

A `403` without credentials is expected. If the LXC lost its `vmbr1`
address, check `/usr/local/sbin/garage-net-init` and the LXC entrypoint.

### Velero BackupStorageLocation is Unavailable

```bash
kubectl -n velero get backupstoragelocation default -o yaml
kubectl -n velero logs deploy/velero --tail=100
kubectl -n velero get secret velero-credentials -o jsonpath='{.data.cloud}' | base64 -d
```

The Secret must contain a `[default]` AWS profile, use the Garage key, and use
the path-style endpoint `http://10.10.50.2:3900`.

### restic cannot open the repository

```bash
export RESTIC_REPOSITORY='s3:http://10.10.50.2:3900/restic'
export AWS_DEFAULT_REGION='garage'
restic -o s3.bucket-lookup=path snapshots
```

Check that `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `RESTIC_PASSWORD`
are exported, that the `restic` bucket permissions include read/write, and
that the path-style option is present. Do not initialize a second repository
in the same bucket.

### A restic snapshot is empty

The DaemonSet on a node with no local-path PVC (currently `talos-node-1`)
legitimately creates a 0 B snapshot. Check the actual PV node affinity:

```bash
kubectl get pv -o custom-columns=NAME:.metadata.name,HOSTPATH:.spec.hostPath.path,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]
```

### Velero reports hostPath warnings

That is expected for every `local-path` PVC. It is not a backup failure, but it
means that Velero did not copy the volume. Use restic for that data. Do not
re-enable `defaultVolumesToFsBackup` expecting it to fix `local-path`.

### The LXC systemd is degraded

This is expected in the current container. Check the units that matter:

```bash
ssh root@192.168.0.224 'systemctl is-active garage.service'
ssh root@192.168.0.224 'systemctl is-active garage-meta-snapshot.timer'
ssh root@192.168.0.224 'systemctl list-timers --no-pager'
```

If you add systemd sandboxing options to `garage.service`, expect
`226/NAMESPACE`; keep the unit minimal as shown above.

### The external volume is missing

```bash
ssh root@192.168.0.224 'findmnt /mnt/garage'
ssh root@192.168.0.224 'df -hT /mnt/garage'
```

The volume is `/dev/loop0` ext4; do not reformat it. Reattach the
`externe-disk:107/vm-107-disk-0.raw` volume and mount it at `/mnt/garage`
before starting Garage.

---

## 12. Secret handling

No credential values are stored in this document.

* Garage service secrets: `/etc/garage.env` and `/etc/garage.toml` on the LXC
  (`root:garage`, mode `0640`).
* Garage credential copy for Velero/restic: `/root/garage-velero-credentials.env`
  on the LXC (`0600`).
* Velero S3 profile: `velero/velero-credentials` Secret, key `cloud`.
* restic AWS keys and repository password: `backup/restic-credentials` Secret.
* PostgreSQL password: `euro-office/postgres-credentials` Secret.
* Local scratch copies used during implementation are outside the repository
  and must not be committed.

Retrieve secrets only on a trusted terminal. The commands are in the how-to.
Rotating the Garage key requires updating both the Velero Secret and the
restic Secret and restarting the Velero server / restic DaemonSet.

---

## Appendix A: Velero values (actual, secret-free)

This is the content of
`ansible2/files/backup/values-velero.yaml`. The Secret is created separately.

```yaml
image:
  repository: docker.io/velero/velero
  tag: v1.18.2
  pullPolicy: IfNotPresent

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.14.4
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - mountPath: /target
        name: plugins

namespace:
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged

credentials:
  useSecret: true
  existingSecret: velero-credentials

snapshotsEnabled: false
deployNodeAgent: true

configuration:
  uploaderType: kopia
  defaultVolumesToFsBackup: false
  defaultBackupTTL: 720h

  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero
      default: true
      config:
        region: garage
        s3ForcePathStyle: "true"
        s3Url: http://10.10.50.2:3900

  volumeSnapshotLocation: []

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

tolerations:
  - operator: Exists

nodeAgent:
  tolerations:
    - operator: Exists
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

schedules:
  daily:
    schedule: "0 2 * * *"
    template:
      ttl: "720h"
      storageLocation: default
      snapshotVolumes: false
      defaultVolumesToFsBackup: false
      includedNamespaces:
        - argocd
        - argocd-demo
        - euro-office
        - forgejo
        - nextcloud
        - nfs-server
        - nginx-demo
        - traefik
        - local-path-storage
        - backup
      excludedNamespaces:
        - kube-system
        - kube-public
        - kube-node-lease
        - velero
```

Create the Secret with a file (not with a command line value):

```bash
kubectl -n velero create secret generic velero-credentials \
  --from-file=cloud=./velero-cloud
```

The file must contain:

```ini
[default]
aws_access_key_id=<garage-access-key>
aws_secret_access_key=<garage-secret-key>
```

---

## Appendix B: Component files in this repository

| File | Purpose |
| --- | --- |
| `ansible2/files/backup/values-velero.yaml` | Helm values for Velero |
| `ansible2/files/backup/restic-daemonset.yaml` | Per-node restic volume backup |
| `ansible2/files/backup/postgres-dump.yaml` | PostgreSQL logical dump PVC/CronJob |
| `ansible2/files/backup/garage-net-init.sh` | LXC network entrypoint |
| `ansible2/files/backup/garage.service` | Garage systemd unit |
| `ansible2/files/backup/garage-webui.service` | Garage Web UI systemd unit |
| `ansible2/files/backup/garage-webui.env.example` | Secret-free Web UI environment |
| `ansible2/files/backup/garage-meta-snapshot.sh` | SQLite online snapshot |
| `ansible2/files/backup/garage-meta-snapshot.service` | Snapshot oneshot unit |
| `ansible2/files/backup/garage-meta-snapshot.timer` | Daily snapshot timer |
| `ansible2/files/backup/garage.toml.example` | Secret-free Garage configuration |

The installed copies on the LXC are under `/etc/systemd/system/`,
`/usr/local/sbin/`, and `/etc/garage.toml`.

---

## Appendix C: Quick verification

```bash
# On the management host
export KUBECONFIG=/root/.kube/config

velero backup-location get
velero schedule get
velero backup get
kubectl -n backup get pods
kubectl -n backup logs ds/local-path-backup --tail=20
kubectl -n euro-office get cronjob postgres-dump
kubectl -n euro-office get pvc postgres-dumps

# On the Garage LXC
ssh root@192.168.0.224
garage -c /etc/garage.toml status
garage -c /etc/garage.toml bucket list
garage -c /etc/garage.toml bucket info velero
garage -c /etc/garage.toml bucket info restic
findmnt /mnt/garage
ls -l /mnt/garage/meta-snapshots
systemctl is-active garage.service garage-webui.service
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3909/
```

Do not trust the installation until a fresh object backup and a fresh restic
snapshot both complete, and until the restore procedure in the how-to has been
rehearsed once.
