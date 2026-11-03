# Backup and restore how-to

This is the operational runbook for the Garage/Velero/restic backup target
described in [`backup.md`](backup.md). Commands are run from the management LXC
unless a step says otherwise.

**Last verified:** 2026-10-30. The implemented system is not the same as the
first draft in the Git history: Velero cannot copy `local-path` (`hostPath`) PV
data, so restic provides the volume layer. See section 2.

---

## 1. Access and credentials

### 1.1 Hosts

| Purpose | Address | Login |
| --- | --- | --- |
| Management / kubectl | `192.168.0.192` | `root`, key `~/.ssh/id_ed25519` |
| Garage LXC | `192.168.0.224` / `10.10.50.2` | `root`, key `~/.ssh/id_ed25519` |
| Kubernetes API VIP | `10.10.50.5` | via management `KUBECONFIG` |
| Talos nodes | `10.10.50.10`, `.21`, `.22` | no direct SSH in this runbook |
| Proxmox API | `PVE_HOST` from `export-proxmox-api-token` | API token, no root SSH |

Start with:

```bash
ssh root@192.168.0.192
export KUBECONFIG=/root/.kube/config
```

The Proxmox host is never used for Garage commands; use the LXC:

```bash
ssh root@192.168.0.224
```

### 1.2 Credentials — retrieve, do not paste

All commands below print or export secrets. Run them only on a trusted
terminal, and do not put the output in tickets, chat, Git, or shell history.

**Velero S3 profile** (the `cloud` key is an AWS-style profile):

```bash
kubectl -n velero get secret velero-credentials \
  -o jsonpath='{.data.cloud}' | base64 -d
```

**restic AWS keys and repository password:**

```bash
export AWS_ACCESS_KEY_ID="$(
  kubectl -n backup get secret restic-credentials \
    -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
)"
export AWS_SECRET_ACCESS_KEY="$(
  kubectl -n backup get secret restic-credentials \
    -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d
)"
export RESTIC_PASSWORD="$(
  kubectl -n backup get secret restic-credentials \
    -o jsonpath='{.data.RESTIC_PASSWORD}' | base64 -d
)"
```

**Garage service credentials (on the LXC only):**

```bash
ssh root@192.168.0.224 'cat /etc/garage.env'
ssh root@192.168.0.224 'cat /root/garage-velero-credentials.env'
```

The second file contains the access key and secret used by Velero and restic.
The restic repository password is **not** in that file; it is only in the
Kubernetes Secret. Keep a copy in a password manager before relying on restic.

**PostgreSQL password:**

```bash
kubectl -n euro-office get secret postgres-credentials \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

### 1.3 Set a restic shell

```bash
export RESTIC_REPOSITORY='s3:http://10.10.50.2:3900/restic'
export AWS_DEFAULT_REGION='garage'
restic() { command restic -o s3.bucket-lookup=path "$@"; }
restic snapshots --compact
```

The `-o s3.bucket-lookup=path` option is required for Garage. The management
host has restic installed; Kubernetes pods use `restic/restic:0.18.1`.

---

## 2. What is backed up, and the `hostPath` limitation

| Layer | What it contains | Where |
| --- | --- | --- |
| Velero object backups | Kubernetes objects, including Secrets, PVC objects, CronJobs, and CRs | Garage `velero` bucket |
| restic local-path | `/var/local-path-provisioner` from each node, including `nextcloud`, `forgejo`, PostgreSQL, the NFS server backing store, and `postgres-dumps` | Garage `restic` bucket |
| PostgreSQL logical dump | `pg_dumpall` output on `euro-office/postgres-dumps` | Included in the restic bucket |
| Garage metadata | SQLite online copy of Garage's database | `/mnt/garage/meta-snapshots` |
| Garage object data | Objects in the `velero` and `restic` buckets | `/mnt/garage/data` |

**Do not expect Velero to copy a `local-path` volume.** The provisioner makes
a `hostPath` PV, and Velero's pod-volume backupper rejects that source. This is
why the Velero schedule has `defaultVolumesToFsBackup: false`, and why restic
runs as a DaemonSet. A `PartiallyFailed` Velero backup is not caused by this
when volumes are disabled; check errors rather than the warning text.

The NFS client PVs (`ds-files`, `ds-runtime-config`) are not separately
copied. Their data is on the NFS server's local-path volume, which restic
copies. If the NFS server itself is lost, restore its data before starting the
NFS clients.

---

## 3. What runs automatically

| Time (UTC) | Job | Evidence |
| --- | --- | --- |
| 01:15 | Garage metadata snapshot | `systemctl list-timers` on the LXC |
| 01:30 | `postgres-dump` CronJob | `kubectl -n euro-office get jobs` |
| 02:00 | Velero `velero-daily` object backup | `velero backup get` |
| 24 h from each restic pod start | restic local-path backup | `kubectl -n backup logs ds/local-path-backup` |

The restic DaemonSet has a deliberate 0–5 minute initial jitter and then
sleeps 24 hours. A pod restart moves that node's window; verify by the snapshot
list, not only by the clock.

### 3.1 Daily check

```bash
# Velero
velero backup-location get
velero schedule get
velero backup get
LATEST=$(kubectl -n velero get backups.velero.io \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)
LATEST=${LATEST#*/}
velero backup describe "$LATEST" --details
velero backup logs "$LATEST" | tail -50

# restic
kubectl -n backup get pods -o wide
kubectl -n backup logs ds/local-path-backup --tail=30 --prefix
restic snapshots --compact

# PostgreSQL dump
kubectl -n euro-office get cronjob postgres-dump
kubectl -n euro-office get jobs --sort-by=.metadata.creationTimestamp
kubectl -n euro-office get pvc postgres-dumps

# Garage metadata and service
ssh root@192.168.0.224 'systemctl is-active garage.service'
ssh root@192.168.0.224 'systemctl is-active garage-meta-snapshot.timer'
ssh root@192.168.0.224 'systemctl list-timers --no-pager'
ssh root@192.168.0.224 'garage -c /etc/garage.toml status'
ssh root@192.168.0.224 'garage -c /etc/garage.toml bucket list'
ssh root@192.168.0.224 'ls -l /mnt/garage/meta-snapshots'
```

Expected:

* Velero `backup-location` is `Available`.
* The latest backup is `Completed`, with no errors. Warnings about `hostPath`
  should not appear when volumes are disabled.
* restic lists one snapshot per node that has local-path data.
* The PostgreSQL CronJob's last job is `Complete`.
* Garage lists a recent `db-*.sqlite` metadata copy.

### 3.2 If a backup did not run

```bash
kubectl -n velero logs deploy/velero --tail=100
kubectl -n velero describe backup <name>
velero backup logs <name> | tail -100

kubectl -n backup describe ds local-path-backup
kubectl -n backup logs ds/local-path-backup --tail=100
```

For Garage, see section 8.

---

## 4. Manual backups

### 4.1 Velero object backup

```bash
NAME="manual-$(date -u +%Y%m%dT%H%M%SZ)"
velero backup create "$NAME" \
  --include-namespaces nextcloud,euro-office,forgejo,nginx-demo,backup \
  --wait

velero backup describe "$NAME" --details
velero backup logs "$NAME" | tail -80
```

This is object-only because the schedule and the server default have
`defaultVolumesToFsBackup: false`. To exercise the production schedule without
waiting for 02:00:

```bash
velero backup create --from-schedule velero-daily --wait
velero backup get
```

### 4.2 restic local-path backup

Pick the pod on the node whose volume you want to capture. `NODE_NAME` is
already set in the DaemonSet pod, and the Secret supplies the restic password
and AWS keys:

```bash
NODE=talos-node-3
POD=$(kubectl -n backup get pods -o wide | awk -v n="$NODE" '$7==n {print $1; exit}')
echo "$POD"

kubectl -n backup exec "$POD" -- sh -ec '
  export RESTIC_REPOSITORY="s3:http://10.10.50.2:3900/restic"
  export AWS_DEFAULT_REGION="garage"
  restic -o s3.bucket-lookup=path backup /data \
    --host "$NODE_NAME" \
    --tag local-path \
    --exclude "*/lost+found" \
    --exclude "*/restic-cache"
'
```

Run this on each node that has local-path data (`talos-node-2` and
`talos-node-3` in this cluster). The pod's `/data` mount is read-only, so this
cannot modify live PVC data.

After a manual backup, confirm the snapshot exists:

```bash
restic snapshots --compact
restic check --read-data-subset=5%
```

`restic check` is optional and can be slow on a large repository.

### 4.3 PostgreSQL dump now

```bash
kubectl -n euro-office delete job postgres-dump-manual --ignore-not-found
kubectl -n euro-office create job postgres-dump-manual --from=cronjob/postgres-dump
kubectl -n euro-office wait --for=condition=complete \
  job/postgres-dump-manual --timeout=180s
kubectl -n euro-office logs job/postgres-dump-manual --tail=20
```

To include that new dump in restic immediately, find the `postgres-dumps` PV's
node and run section 4.2 on that node:

```bash
PV=$(kubectl -n euro-office get pvc postgres-dumps -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}{"\n"}'
```

### 4.4 Garage metadata snapshot now

```bash
ssh root@192.168.0.224 'systemctl start garage-meta-snapshot.service'
ssh root@192.168.0.224 'ls -lt /mnt/garage/meta-snapshots | head'
```

---

## 5. Restore drill: objects only (safe)

This restores the stateless `nginx-demo` namespace into `nginx-restore` and
does not touch live data.

```bash
velero backup get

# Choose a Completed backup, or select the newest by creation time:
BACKUP=$(kubectl -n velero get backups.velero.io \
  --sort-by=.metadata.creationTimestamp -o name | tail -1)
BACKUP=${BACKUP#*/}
echo "$BACKUP"

velero restore create "restore-nginx-$(date -u +%Y%m%dT%H%M%SZ)" \
  --from-backup "$BACKUP" \
  --include-namespaces nginx-demo \
  --namespace-mappings nginx-demo:nginx-restore \
  --wait

velero restore get
kubectl -n nginx-restore get pods,svc
kubectl -n nginx-restore get pods -w
```

The restore should report `Completed` (a warning about a missing resource is
acceptable if it is understood). Delete the test namespace:

```bash
kubectl delete namespace nginx-restore
```

The implementation test `smoke-restore` completed this way on 2026-10-30.

---

## 6. Restore local-path data safely

A local-path PV is node-local. You cannot copy a snapshot to a different node
and expect the old PV to bind there without changing the PV's node affinity.
The safest normal restore is in place, on the same node, with the application
stopped.

### 6.1 Identify the snapshot and path

```bash
# All snapshots; note the host and time you want.
restic snapshots --compact

# List the saved tree. The path starts with /data because the DaemonSet
# mounts hostPath at /data.
restic ls latest --host talos-node-3 | head -50

# Map a PVC to its local-path directory and node.
kubectl get pv -o custom-columns=NAME:.metadata.name,HOSTPATH:.spec.hostPath.path,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]
```

Example directory names:

```text
/var/local-path-provisioner/pvc-..._nextcloud_nextcloud-nextcloud
/var/local-path-provisioner/pvc-..._euro-office_postgres-data
/var/local-path-provisioner/pvc-..._forgejo_gitea-shared-storage
/var/local-path-provisioner/pvc-..._nfs-server_data-nfs-server-nfs-server-provisioner-0
```

### 6.2 Open a temporary restore pod on the node

Create a pod with a read-write hostPath and an empty work directory. The pod
uses the restic Secret; do not put credentials in the manifest.

```bash
kubectl -n backup apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: restic-restore
  namespace: backup
spec:
  restartPolicy: Never
  nodeName: talos-node-3
  containers:
    - name: restic
      image: restic/restic:0.18.1
      imagePullPolicy: IfNotPresent
      command: ["/bin/sh", "-c", "sleep 3600"]
      envFrom:
        - secretRef:
            name: restic-credentials
      volumeMounts:
        - name: host
          mountPath: /host
        - name: work
          mountPath: /restore
      securityContext:
        runAsUser: 0
        runAsGroup: 0
  volumes:
    - name: host
      hostPath:
        path: /var/local-path-provisioner
        type: Directory
    - name: work
      emptyDir: {}
EOF

kubectl -n backup wait --for=condition=Ready pod/restic-restore --timeout=120s
kubectl -n backup get pod restic-restore -o wide
```

Replace `talos-node-3` with the node from section 6.1. The pod must be on the
same node as the PV.

### 6.3 Restore one PVC into the work directory

Open a shell in the pod:

```bash
kubectl -n backup exec -it restic-restore -- sh
```

Inside the pod:

```sh
export RESTIC_REPOSITORY='s3:http://10.10.50.2:3900/restic'
export AWS_DEFAULT_REGION='garage'

# Replace with the snapshot host and the exact /data/pvc-... path.
restic -o s3.bucket-lookup=path restore latest \
  --host talos-node-3 \
  --target /restore \
  --include '/data/pvc-149b0113-4dd1-48ef-9e40-3e3343ff8724_nfs-server_data-nfs-server-nfs-server-provisioner-0'

find /restore/data -maxdepth 2 -type d | head
du -sh /restore/data
```

For a complete node tree, omit `--include`; that restores all PVC directories
from that node.

### 6.4 Stop the application, swap the directory, start it

Do this from another terminal. In the pod shell, note the **new** PV directory
if the reset created one, or use the old path if the PVC still exists.

For an existing PVC (`nextcloud-nextcloud` example):

```bash
# On the management host
kubectl -n nextcloud scale deploy/nextcloud --replicas=0
kubectl -n nextcloud get pods
```

Then in the restore pod shell:

```sh
PVC_DIR=pvc-a95a86a5-d6c1-4883-9e8d-5a50f604354d_nextcloud_nextcloud-nextcloud

mv "/host/$PVC_DIR" "/host/$PVC_DIR.pre-restore-$(date +%s)"
cp -a "/restore/data/$PVC_DIR" /host/
# cp -a preserves the snapshot's ownership. Only change ownership if the
# application's runtime user differs from the restored files.
ls -ld "/host/$PVC_DIR"
```

Adjust ownership to the application. Do not leave the old directory
indefinitely; verify and remove `.pre-restore-*` later.

Start the workload:

```bash
kubectl -n nextcloud scale deploy/nextcloud --replicas=1
kubectl -n nextcloud get pods -w
kubectl -n nextcloud logs deploy/nextcloud --tail=50
```

Then delete the temporary pod:

```bash
kubectl -n backup delete pod restic-restore
```

### 6.5 Restoring after a namespace/PVC was recreated

If the PVC/PV was deleted, the local-path provisioner creates a new PV with a
new `pvc-...` directory. In that case:

1. Restore Kubernetes objects with Velero first, but prevent application pods
   from starting before the data copy. A maintenance window and a temporary
   scale-down are safer than letting an app initialize an empty volume.
2. Wait for the new PVC to bind and find its new hostPath:
   ```bash
   kubectl -n nextcloud get pvc
   kubectl get pv -o custom-columns=NAME:.metadata.name,HOSTPATH:.spec.hostPath.path
   ```
3. Restore the old snapshot into `/restore`, then copy the **contents** of the
   old PVC directory into the **new** host path. The old directory name in the
   snapshot is not the new PV name:
   ```sh
   cp -a /restore/data/<old-pvc-dir>/. /host/<new-pvc-dir>/
   ```
4. Fix ownership, then start the workload and verify.

Do not restore a snapshot directly over a live database or a live NFS server.

---

## 7. Restore PostgreSQL

### 7.1 Preferred: physical local-path restore

For a clean shutdown, scale the database and its clients down first; this
makes the physical files consistent:

```bash
kubectl -n euro-office scale deploy/docservice deploy/converter --replicas=0
kubectl -n euro-office scale statefulset/example --replicas=0
kubectl -n nextcloud scale deploy/nextcloud --replicas=0
kubectl -n euro-office scale deploy/postgres --replicas=0
kubectl -n euro-office get pods
```

Then restore the `pvc-..._euro-office_postgres-data` directory from restic
using the procedure in section 6, and scale the database back up first:

```bash
kubectl -n euro-office scale deploy/postgres --replicas=1
kubectl -n euro-office logs deploy/postgres --tail=100
```

Verify before starting clients:

```bash
kubectl -n euro-office exec deploy/postgres -- \
  psql -U postgres -d postgres -c '\l'
kubectl -n euro-office exec deploy/postgres -- \
  psql -U postgres -d postgres -tAc 'select 1;'
```

Then restore the remaining workloads from GitOps or scale them back.

### 7.2 Logical dump restore

Use this when the physical files are suspect or you need a portable restore.
The dump is on `euro-office/postgres-dumps`; it is also inside restic.

First stop applications that write to the database, but leave PostgreSQL
running:

```bash
kubectl -n nextcloud scale deploy/nextcloud --replicas=0
kubectl -n euro-office scale deploy/docservice deploy/converter --replicas=0
kubectl -n euro-office scale statefulset/example --replicas=0
```

Create a temporary psql pod that mounts the dump PVC and has the database
password from the Secret:

```bash
kubectl -n euro-office apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pg-restore
  namespace: euro-office
spec:
  restartPolicy: Never
  containers:
    - name: psql
      image: postgres:16-alpine
      command: ["/bin/sh", "-ec", "sleep 3600"]
      env:
        - name: PGHOST
          value: postgresql.euro-office.svc.cluster.local
        - name: PGUSER
          value: postgres
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: POSTGRES_PASSWORD
      volumeMounts:
        - name: dumps
          mountPath: /dumps
  volumes:
    - name: dumps
      persistentVolumeClaim:
        claimName: postgres-dumps
EOF

kubectl -n euro-office wait --for=condition=Ready pod/pg-restore --timeout=120s
kubectl -n euro-office exec -it pg-restore -- sh
```

In the pod:

```sh
ls -lh /dumps
# Confirm the timestamp and size before overwriting anything.
gunzip -c /dumps/postgres-<timestamp>.sql.gz | psql -d postgres
```

The dump was made with `--clean --if-exists`, so it drops and recreates the
objects it contains. This is destructive to the current database; take a fresh
physical snapshot and confirm the dump file first. After the restore:

```sh
psql -d postgres -c '\l'
psql -d postgres -c 'select 1;'
exit
```

Delete the helper pod and start the applications:

```bash
kubectl -n euro-office delete pod pg-restore
kubectl -n euro-office scale deploy/docservice --replicas=1
kubectl -n euro-office scale deploy/converter --replicas=1
kubectl -n euro-office scale statefulset/example --replicas=1
kubectl -n nextcloud scale deploy/nextcloud --replicas=1
```

The exact replica counts may be managed by Argo CD; let Argo reconcile the
desired state if it owns those workloads.

### 7.3 Forgejo

Forgejo uses SQLite in `forgejo/gitea-shared-storage`, a local-path volume.
The physical snapshot is crash-consistent. For a stricter logical export, use
Forgejo's own `gitea dump` command from a maintenance window. That is not
automated yet.

For an in-place physical restore, stop Forgejo, restore the
`pvc-..._forgejo_gitea-shared-storage` directory with section 6, then start it:

```bash
kubectl -n forgejo scale deploy/forgejo --replicas=0
# ...restore the directory in the restic-restore pod...
kubectl -n forgejo scale deploy/forgejo --replicas=1
kubectl -n forgejo logs deploy/forgejo --tail=100
```

### 7.4 NFS server and NFS client volumes

The NFS server's backing PVC is
`nfs-server/data-nfs-server-nfs-server-provisioner-0`, a local-path volume.
The `ds-files` and `ds-runtime-config` NFS exports live inside that backing
directory. Restore the NFS server first; do not start the Euro-Office pods
against an empty NFS server.

```bash
# Stop the NFS clients and the server.
kubectl -n euro-office scale deploy/docservice deploy/converter --replicas=0
kubectl -n euro-office scale statefulset/example --replicas=0
kubectl -n nfs-server scale statefulset/nfs-server-nfs-server-provisioner --replicas=0

# Restore the nfs-server backing directory with section 6.
# Its directory name in the restic snapshot starts with:
#   pvc-..._nfs-server_data-nfs-server-nfs-server-provisioner-0

kubectl -n nfs-server scale statefulset/nfs-server-nfs-server-provisioner --replicas=1
kubectl -n nfs-server get pods,pvc
kubectl -n nfs-server logs statefulset/nfs-server-nfs-server-provisioner --tail=100
```

Then start the Euro-Office workloads through Argo CD or scale them back.
Verify that `ds-files` and `ds-runtime-config` are `Bound` and that the
document server can read both. If the NFS server pod is recreated on another
node, patch the old PV's node affinity as described in section 11 before
starting it; the restored data must be on the new node.

---

## 8. Restore Garage metadata and rebuild the target

### 8.1 Restore one metadata database

Stop Garage first. A running process must not have the database open while it
is replaced.

```bash
ssh root@192.168.0.224
systemctl stop garage.service

ls -lt /mnt/garage/meta-snapshots
cp -a /var/lib/garage/meta/db.sqlite /var/lib/garage/meta/db.sqlite.before-restore
rm -f /var/lib/garage/meta/db.sqlite-wal /var/lib/garage/meta/db.sqlite-shm
cp -a /mnt/garage/meta-snapshots/db-20261030T151036Z.sqlite \
  /var/lib/garage/meta/db.sqlite
chown garage:garage /var/lib/garage/meta/db.sqlite
systemctl start garage.service
systemctl is-active garage.service

garage -c /etc/garage.toml status
garage -c /etc/garage.toml bucket list
garage -c /etc/garage.toml bucket info velero
garage -c /etc/garage.toml bucket info restic
```

If the data directory (`/mnt/garage/data`) is intact, existing objects remain
usable. If the data directory is missing, metadata alone is not enough; you
need an off-site copy of the data volume.

### 8.2 Rebuild the Garage LXC

Use the Proxmox UI/API (root SSH is denied). Recreate the container with the
same layout described in `backup.md`, attach the external volume, and install
Garage. Then:

1. Restore `/etc/garage.toml` and `/etc/garage.env` from the password manager,
   or generate new RPC/admin tokens.
2. Install `garage.service`, the metadata script, and the timer from
   `ansible2/files/backup/`.
3. Recreate/attach `/mnt/garage` and restore `/mnt/garage/data` from off-site
   if the old volume was lost.
4. Restore `/var/lib/garage/meta/db.sqlite` from the newest metadata copy.
5. Start Garage and verify:
   ```bash
   garage -c /etc/garage.toml status
   garage -c /etc/garage.toml bucket list
   ```
6. If the access key changed, update `velero/velero-credentials` and
   `backup/restic-credentials`, then restart Velero and the restic DaemonSet.
7. Run a fresh Velero backup and restic snapshot; do not assume the old ones
   are usable until both complete.

### 8.3 If the external disk itself is lost

There is currently no off-site copy. Garage metadata snapshots, Velero
backups, and restic snapshots all live on that disk. Recovery is not possible
from this setup alone; this is the most important remaining gap.

---

## 9. Full cluster recovery order

For a rebuild of the Talos cluster or a new Kubernetes cluster:

1. Build/restore the Talos cluster and networking.
2. Rebuild or reattach the Garage LXC; verify `http://10.10.50.2:3900` and the
   `velero`/`restic` buckets.
3. Create the `velero` namespace, `velero-credentials` Secret, and install
   Velero with `ansible2/files/backup/values-velero.yaml`; wait for
   `backup-location` `Available`.
4. Restore the `backup` namespace/Secret needed by restic, or recreate
   `backup/restic-credentials` from the password manager.
5. Install the restic DaemonSet.
6. Restore Kubernetes objects with Velero, but keep application pods scaled
   down.
7. Restore local-path data on the matching nodes from restic.
8. Restore the NFS server's data before starting NFS clients.
9. Restore PostgreSQL physical data, or apply the logical dump.
10. Start applications; verify database, file shares, login, and document
    editing.
11. Run new backups and record the restore result.

Do not start Nextcloud, Forgejo, or PostgreSQL against an empty volume and then
restore over it; they may initialize data or change file ownership.

---

## 10. Restore verification

After any restore:

```bash
# Object restore status
velero restore get
velero restore describe <restore-name> --details

# Workloads and PVC binding
kubectl get pods,pvc -A
kubectl describe pvc -n <namespace> <pvc>
kubectl describe pv <pv>

# Applications
kubectl -n nextcloud logs deploy/nextcloud --tail=100
kubectl -n euro-office logs deploy/postgres --tail=100
kubectl -n euro-office logs deploy/docservice --tail=100
kubectl -n forgejo logs deploy/forgejo --tail=100
```

For a full check:

* Velero restore is `Completed`, with no unexplained errors.
* Every expected PVC is `Bound`.
* The pod is `Running` and `Ready`.
* Nextcloud loads files and can write a test file.
* Euro-Office can open and edit a blank document.
* Forgejo can log in and list repositories.
* PostgreSQL accepts queries; no recovery/fatal messages.
* The NFS server exports are mounted by clients.

---

## 11. Troubleshooting

### `restic: unable to open config file` / 403

* Set `RESTIC_REPOSITORY` to exactly
  `s3:http://10.10.50.2:3900/restic`.
* Set `AWS_DEFAULT_REGION=garage`.
* Use `-o s3.bucket-lookup=path`.
* Confirm the key has `R`/`W` permission:
  ```bash
  ssh root@192.168.0.224 'garage -c /etc/garage.toml bucket info restic'
  ```
* Confirm the bucket is not an old/empty repository; do not run `restic init`
  again in a bucket that already has data.

### `restic: wrong password`

The repository password is in `backup/restic-credentials`. If it is lost,
the restic repository cannot be decrypted. Check you are reading the same
cluster's Secret, not a test cluster's.

### Velero BSL unavailable

```bash
kubectl -n velero get backupstoragelocation default -o yaml
kubectl -n velero logs deploy/velero --tail=100
kubectl -n velero get secret velero-credentials -o jsonpath='{.data.cloud}' | base64 -d
```

Check `s3Url`, `region`, `s3ForcePathStyle`, and the Garage key. A `403` from
`curl` without credentials is expected; a `403` with credentials is a key or
bucket-permission problem.

### Velero restore is `PartiallyFailed`

Read the details before changing anything:

```bash
velero restore describe <name> --details
velero restore logs <name> | tail -100
```

A missing `nginx-demo` object or a resource that already exists can produce a
warning. Do not delete live resources to make a warning disappear.

### The restic restore pod is on the wrong node

The pod has `nodeName: talos-node-3`; change it to the node from the PV and
recreate the pod. The hostPath is node-local; a pod on another node sees an
empty or different directory.

### A local-path PV will not bind after a node replacement

The PV's `nodeAffinity` still names the old node. Patch it deliberately after
confirming the new node name and that the data has been restored there:

```bash
kubectl get pv <pv> -o yaml
kubectl patch pv <pv> --type=json -p='[
  {"op":"replace","path":"/spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values/0","value":"talos-node-2"}
]'
```

Do not patch blindly; a wrong node can make the data inaccessible or let the
application start with an empty volume.

### `pg_dumpall` fails with a version error

The PostgreSQL server is 16.15 and the dump image is `postgres:16-alpine`.
Keep the major version aligned. If the server is upgraded, update the CronJob
image.

### The metadata timer or Garage service is not active

```bash
ssh root@192.168.0.224 'systemctl status garage.service --no-pager -l'
ssh root@192.168.0.224 'systemctl status garage-meta-snapshot.timer --no-pager -l'
ssh root@192.168.0.224 'systemctl list-timers --no-pager'
```

The LXC's systemd is degraded; only these units need to be healthy. If you add
`PrivateTmp`, `ProtectSystem`, `ProtectHome`, or `ReadWritePaths` to the Garage
unit, systemd can fail it with `226/NAMESPACE`; do not add them.

### `/mnt/garage` is not mounted

```bash
ssh root@192.168.0.224 'findmnt /mnt/garage'
ssh root@192.168.0.224 'df -hT /mnt/garage'
```

Do not start Garage against an empty `/mnt/garage`, and do not reformat the
volume. Reattach the Proxmox volume first.

---

## 12. Known gaps

- No off-site copy; the external disk is a single failure domain.
- No Garage replication or second node.
- No Proxmox VM-level backup of the Talos nodes/etcd.
- No application-consistent quiesce for Nextcloud or Forgejo.
- No automated restore rehearsal.
- No TLS or authentication proxy in front of the internal S3 endpoint.
- No alerting for missed backups or restic repository errors.
- The NFS server's data is covered only through its local-path tree, not by a
  separate NFS-level backup.

Treat this as a working local backup, not a complete disaster-recovery plan.
