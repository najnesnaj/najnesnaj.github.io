# Immich backup to `/mnt/big-extern`

**Last verified:** 2026-11-10 against the running Immich instance at
`192.168.0.180:2283` (Immich `v3.2.0`, PostgreSQL `14.19`). Access, paths, the
database dump, and rsync/hardlink behaviour were tested. A full 309 GB library
copy was not run during verification.

**Scope:** back up the Immich photo/video library, the logical PostgreSQL
database, and the Immich compose configuration to `/mnt/big-extern/immich`. This is a
host-initiated **pull** backup: the machine that has `/mnt/big-extern` mounted pulls
the data from the Immich server over SSH.

> This document is separate from [`backup.md`](backup.md), which covers the
> Kubernetes Velero/restic/Garage backup target. Both use `/mnt/big-extern`, but
> Immich lives in its own `/mnt/big-extern/immich` directory.

**Reference:** [Immich backup and restore](https://docs.immich.app/administration/backup-and-restore/).

---

## 1. What is backed up

| Data | Location on the Immich server | Method |
| --- | --- | --- |
| Original photos and videos | `UPLOAD_LOCATION/upload/` | rsync snapshot |
| Storage-template library | `UPLOAD_LOCATION/library/` | rsync snapshot |
| External-library files | `UPLOAD_LOCATION/external/` and any path mounted outside `UPLOAD_LOCATION` | rsync snapshot; back up outside paths separately |
| Generated files | `UPLOAD_LOCATION/thumbs/`, `encoded-video/`, `profile/` | rsync snapshot |
| Built-in Immich database dumps | `UPLOAD_LOCATION/backups/` | included in the library snapshot |
| PostgreSQL logical dump | database `immich` inside `immich_postgres` | `pg_dump` + gzip, once per run |
| Compose configuration | `/opt/immich/docker-compose.yml` and `/opt/immich/.env` | copied per run |
| Raw PostgreSQL data directory | `DB_DATA_LOCATION` (`.../postgres/`) | **not copied while running** |
| Machine-learning model cache, Redis | Docker volumes | not backed up; re-downloadable/ephemeral |

The actual values in `/opt/immich/.env` are:

```text
UPLOAD_LOCATION=/mnt/immich-data/usr/src/immich/immich-store/library
DB_DATA_LOCATION=/mnt/immich-data/usr/src/immich/immich-store/postgres
IMMICH_VERSION=v3.2.0
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
```

### Why the raw `postgres/` directory is not copied

Copying the files of a running PostgreSQL data directory with rsync does not
produce a consistent database. Use the logical dump instead. The dump contains
all Immich metadata: users, albums, assets, face data, and the file paths that
point into the library.

### Backup ordering

The Immich documentation recommends backing up the **database first**, then the
filesystem. With that order, files uploaded during the copy can appear in the
library but not in the dump; those extra files are harmless and can be
re-uploaded or cleaned up later. The reverse order can produce database rows
that point to files that were never copied.

The dump-first order does not protect against deletions: if an asset is deleted
after the dump but before rsync reaches its file, the dump still references a
file that the copy no longer contains. For a fully consistent point-in-time
copy, stop `immich_server` and `immich_machine_learning` for the duration of
the file copy (PostgreSQL and Redis can stay up for `pg_dump`), run the backup,
then start them again. For the daily hot run the window is small; do a cold run
before upgrades or other risky changes.

---

## 2. Topology and prerequisites

```text
Immich server (Proxmox VM 111, hostname "homeassistant")
  192.168.0.180:2283
  /opt/immich/docker-compose.yml + .env
  /mnt/immich-data/usr/src/immich/immich-store/
    library/    309 GB, 115,875 files at verification time
    postgres/   507 MB database, 71 tables
  containers: immich_server, immich_postgres,
              immich_machine_learning, immich_redis

Backup host (management container "ubuntu26CT")
  192.168.0.223
  /mnt/big-extern   /dev/sdb1, 932 GB, 760 GB free, NTFS (fuseblk)
    immich/    this document's backup target
```

The exact hostname of the backup host does not matter. It must be the machine
where `/mnt/big-extern` is mounted and from which the following works:

```bash
ssh -o BatchMode=yes jan@192.168.0.180 'sudo -n true && echo OK'
```

Requirements on the backup host:

* `rsync`, `ssh`, `gzip`, `flock`, `findmnt`/`mountpoint`, `sha256sum`;
* an SSH key for `jan@192.168.0.180`;
* passwordless sudo for `jan` on the Immich server (needed for Docker and
  `rsync` reads);
* `/mnt/big-extern` actually mounted. The script refuses to run if it is not, so a
  missing mount cannot silently fill the root filesystem.

Requirements on the Immich server:

* `rsync` installed (`/usr/bin/rsync`, version 3.4.1 at verification);
* the Docker containers are healthy;
* `jan` can run `sudo -n docker ...`.

Do **not** reformat `/mnt/big-extern` and do not point this backup at the same
directory as the Velero/restic data. Use `/mnt/big-extern/immich`.

### Destination layout

```text
/mnt/big-extern/immich/
  snapshots/
    2026-11-10T031500/
      library/
        backups/
        encoded-video/
        external/
        library/
        profile/
        thumbs/
        upload/
  database/
    immich-db-2026-11-10T031500.sql.gz
    immich-db-2026-11-10T031500.sql.gz.sha256
  config/
    2026-11-10T031500/
      docker-compose.yml
      .env
  logs/
    backup-2026-11.log
  .backup.lock
```

Snapshots use hardlinks: unchanged files in a new snapshot point to the same
data blocks as the previous snapshot, so only new or changed files consume
additional space. `/mnt/big-extern` is currently NTFS (`fuseblk`); hardlinks were
tested and work there, but POSIX ownership, modes, ACLs, and xattrs are not
preserved. That is why the rsync commands below do **not** use `-a`.

---

## 3. Manual backup

Run these commands on the backup host (the machine with `/mnt/big-extern`).

Set the variables once, in one shell, and enable error checking so a failed
`ssh` cannot leave a valid-looking empty `gzip` file:

```bash
set -Eeuo pipefail

IMMICH=192.168.0.180
IMMICH_USER=jan
REMOTE_LIBRARY=/mnt/immich-data/usr/src/immich/immich-store/library
DEST=/mnt/big-extern/immich
STAMP=$(date +%Y-%m-%dT%H%M%S)
```

### 3.1 Preflight

```bash
mountpoint -q /mnt/big-extern || { echo "/mnt/big-extern is not mounted"; exit 1; }
mkdir -p "$DEST"/{snapshots,database,config,logs}

df -h /mnt/big-extern
ssh -o BatchMode=yes "$IMMICH_USER@$IMMICH" 'sudo -n docker ps --format "{{.Names}} {{.Status}}"'
ssh -o BatchMode=yes "$IMMICH_USER@$IMMICH" "test -d '$REMOTE_LIBRARY' && echo library-ok"
```

At the time of writing the library used 309 GB and `/mnt/big-extern` had 760 GB
free. The first snapshot needs roughly the full library size: confirm at least
340 GiB free before the first run (309 GB plus headroom). Later snapshots only
need space for changed data, plus the explicit database dump (about 158 MB /
151 MiB) and the built-in dumps (about 142 MB / 135 MiB per day).

`MIN_FREE_GIB` in the script is only a lower-bound guard. Before the **first**
run, check manually that at least about 340 GiB is free on `/mnt/big-extern`, or the
copy can stop halfway with a full disk. The script enforces this first-run
threshold as `FIRST_RUN_FREE_GIB` (default `340`); lower it only when you
deliberately back up a smaller subtree.

### 3.2 Dump the database

```bash
mkdir -p "$DEST/database"
ssh -o BatchMode=yes "$IMMICH_USER@$IMMICH" \
  'sudo -n docker exec immich_postgres pg_dump --clean --if-exists --dbname=immich --username=postgres' \
  | gzip -1 > "$DEST/database/.immich-db-$STAMP.sql.gz.part"

gzip -t "$DEST/database/.immich-db-$STAMP.sql.gz.part"
mv "$DEST/database/.immich-db-$STAMP.sql.gz.part" \
   "$DEST/database/immich-db-$STAMP.sql.gz"
sha256sum "$DEST/database/immich-db-$STAMP.sql.gz" \
  > "$DEST/database/immich-db-$STAMP.sql.gz.sha256"
```

The dump is written to a hidden `.part` file first. Only a dump that passes
`gzip -t` is renamed into place, so a failed or truncated dump is never
mistaken for a good backup.

The database can stay online during `pg_dump`; PostgreSQL gives the dump a
consistent snapshot. No database password is needed because the command runs
inside the `immich_postgres` container as the `postgres` user.

### 3.3 Copy the library

Find the previous snapshot so unchanged files can be hardlinked:

```bash
PREV=$(find "$DEST/snapshots" -mindepth 1 -maxdepth 1 -type d \
  -name '20??-??-??T*' | sort | tail -n 1)

LINK=()
[[ -n "$PREV" ]] && LINK=(--link-dest="$PREV/library")

mkdir -p "$DEST/snapshots/$STAMP/library"
rsync -rltH --no-perms --no-owner --no-group --numeric-ids --delete "${LINK[@]}" \
  -e 'ssh -o BatchMode=yes' --rsync-path='sudo rsync' \
  "$IMMICH_USER@$IMMICH:$REMOTE_LIBRARY/" \
  "$DEST/snapshots/$STAMP/library/"
```

Notes:

* `-rlt` copies recursively, preserves symlinks, and preserves modification
  times. `-H` preserves hardlinks within the tree. `--numeric-ids` is used
  because the destination does not store meaningful user/group names.
* Do not add `-a`, `-p`, `-o`, `-g`, `-A`, or `-X` on this NTFS target.
* `--delete` makes the new snapshot match the source. It does not delete files
  from the previous snapshot.
* If a previous snapshot exists, `--link-dest` turns the new directory into a
  hardlinked copy of it, and only changed files are transferred or stored.
* The copy is not atomic as a whole. Run it again after an interruption; rsync
  continues where it left off. The script in section 4 writes into a
  `.incomplete-*` directory and renames it only after a successful rsync.
* If a **manual** copy is interrupted, remove the incomplete
  `$DEST/snapshots/$STAMP` directory before the next attempt. Otherwise the
  next run can select it as the `--link-dest` predecessor and compare against a
  partial tree.

### 3.4 Copy the compose configuration

```bash
mkdir -p "$DEST/config/$STAMP"
rsync -rlt --exclude '*.bak' --no-perms --no-owner --no-group \
  -e 'ssh -o BatchMode=yes' --rsync-path='sudo rsync' \
  "$IMMICH_USER@$IMMICH:/opt/immich/" \
  "$DEST/config/$STAMP/"
```

`/opt/immich/.env` contains `DB_PASSWORD`. `/mnt/big-extern` is not encrypted and
the NTFS mount does not enforce Unix permissions, so treat this copy as a
secret. If that is not acceptable, leave `.env` out of the copy and keep it in
a password manager or encrypted archive.

### 3.5 Verify the result

```bash
LATEST=$(find "$DEST/snapshots" -mindepth 1 -maxdepth 1 -type d \
  -name '20??-??-??T*' | sort | tail -n 1)

find "$LATEST/library" -type f | wc -l
du -sh "$LATEST/library"
gzip -t "$DEST/database/immich-db-$STAMP.sql.gz"
sha256sum -c "$DEST/database/immich-db-$STAMP.sql.gz.sha256"

# Compare with the live source (the counts can differ slightly during uploads)
ssh -o BatchMode=yes "$IMMICH_USER@$IMMICH" \
  "sudo -n find '$REMOTE_LIBRARY' -type f | wc -l"
```

Expected at verification time: 115,875 files and about 309 GB. Also open a
random original photo and video from the snapshot to confirm the content is
readable. A file count alone does not prove that the files are intact.

---

## 4. Automated daily backup

Save the following script on the backup host as `/tmp/immich-backup.sh` for now;
the install commands after the block move it to `/home/jan/bin/`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

IMMICH_HOST="${IMMICH_HOST:-192.168.0.180}"
IMMICH_USER="${IMMICH_USER:-jan}"
REMOTE_LIBRARY="${REMOTE_LIBRARY:-/mnt/immich-data/usr/src/immich/immich-store/library}"
REMOTE_COMPOSE="${REMOTE_COMPOSE:-/opt/immich}"

DEST="${DEST:-/mnt/big-extern/immich}"
KEEP_SNAPSHOTS="${KEEP_SNAPSHOTS:-14}"
KEEP_DUMPS="${KEEP_DUMPS:-30}"
MIN_FREE_GIB="${MIN_FREE_GIB:-100}"
FIRST_RUN_FREE_GIB="${FIRST_RUN_FREE_GIB:-340}"
ALLOW_SHRINK="${ALLOW_SHRINK:-0}"

STAMP="$(date +%Y-%m-%dT%H%M%S)"
SNAPS="$DEST/snapshots"
DUMPS="$DEST/database"
CONFIGS="$DEST/config"
LOGS="$DEST/logs"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=15 "$IMMICH_USER@$IMMICH_HOST")
RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=15"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

mountpoint -q /mnt/big-extern || die "/mnt/big-extern is not mounted"
mkdir -p "$SNAPS" "$DUMPS" "$CONFIGS" "$LOGS"
exec > >(tee -a "$LOGS/backup-$(date +%Y-%m).log") 2>&1

exec 9>"$DEST/.backup.lock"
flock -n 9 || die "another Immich backup is already running"

# Remove leftovers from a run that was killed with SIGKILL or lost power. The
# lock guarantees no other run is active, so anything named .incomplete-* here
# is stale and would otherwise leak space on the shared disk.
find "$SNAPS" -mindepth 1 -maxdepth 1 -type d -name '.incomplete-*' \
  -exec rm -rf -- {} + 2>/dev/null || true

prev="$(find "$SNAPS" -mindepth 1 -maxdepth 1 -type d -name '20??-??-??T*' | sort | tail -n 1)"
if [[ -n "$prev" ]]; then
  need_gib="$MIN_FREE_GIB"
else
  # First snapshot needs room for the whole library plus some slack.
  need_gib="$FIRST_RUN_FREE_GIB"
fi
avail_gib="$(df -Pk "$DEST" | awk 'NR == 2 { print int($4 / 1024 / 1024) }')"
(( avail_gib >= need_gib )) || \
  die "only ${avail_gib} GiB free on /mnt/big-extern; need at least ${need_gib} GiB"

"${SSH[@]}" 'sudo -n true' || die "passwordless sudo is not available on ${IMMICH_HOST}"
"${SSH[@]}" "test -d '$REMOTE_LIBRARY'" || die "remote library not found: $REMOTE_LIBRARY"
"${SSH[@]}" 'sudo -n docker exec immich_postgres pg_isready -U postgres -d immich >/dev/null' \
  || die "immich_postgres is not accepting connections"
if "${SSH[@]}" 'command -v curl >/dev/null 2>&1'; then
  "${SSH[@]}" 'curl -fsS --max-time 10 http://127.0.0.1:2283/api/server/version >/dev/null' \
    || die "Immich API on ${IMMICH_HOST}:2283 is not healthy"
else
  log "WARNING: curl not found on ${IMMICH_HOST}; skipping API health check"
fi

log "starting Immich backup ${STAMP} (${avail_gib} GiB free)"

# 1. Database first. Immich/Docker documentation recommends this order so that
#    a crash can only leave extra files, never database rows without files.
dump_partial="$DUMPS/.immich-db-${STAMP}.sql.gz.part"
if ! "${SSH[@]}" \
  'sudo -n docker exec immich_postgres pg_dump --clean --if-exists --dbname=immich --username=postgres' \
  | gzip -1 > "$dump_partial"; then
  rm -f -- "$dump_partial"
  die "database dump failed"
fi
gzip -t "$dump_partial" || { rm -f -- "$dump_partial"; die "database dump is not valid gzip"; }
mv -- "$dump_partial" "$DUMPS/immich-db-${STAMP}.sql.gz"
sha256sum "$DUMPS/immich-db-${STAMP}.sql.gz" > "$DUMPS/immich-db-${STAMP}.sql.gz.sha256"
log "database dump written: immich-db-${STAMP}.sql.gz"

# 2. Compose file and .env. The .env file contains DB_PASSWORD; keep the
#    destination on a trusted disk.
mkdir -p "$CONFIGS/$STAMP"
rsync -rlt --exclude '*.bak' --no-perms --no-owner --no-group \
  -e "$RSYNC_SSH" --rsync-path='sudo rsync' \
  "$IMMICH_USER@$IMMICH_HOST:$REMOTE_COMPOSE/" "$CONFIGS/$STAMP/"
log "configuration copied to config/${STAMP}/"

# 3. Library snapshot. Hardlink unchanged files from the previous snapshot.
#    Do not use -a/-p/-o/-g on the NTFS /mnt/big-extern: it does not hold POSIX
#    ownership, modes, ACLs or xattrs. Hardlinks themselves do work.
link_args=()
[[ -n "$prev" ]] && link_args=(--link-dest="$prev/library")

tmp="$(mktemp -d "$SNAPS/.incomplete-${STAMP}.XXXXXX")"
mkdir -p "$tmp/library"
cleanup() {
  rc=$?
  trap - EXIT
  (( rc == 0 )) || rm -rf -- "$tmp"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

rsync -rltH --no-perms --no-owner --no-group --numeric-ids --delete --info=stats2 \
  "${link_args[@]}" -e "$RSYNC_SSH" --rsync-path='sudo rsync' \
  "$IMMICH_USER@$IMMICH_HOST:$REMOTE_LIBRARY/" "$tmp/library/"

# Refuse an empty or implausibly small snapshot. A broken source mount or a
# half-dead disk must not silently replace a good snapshot with an empty one.
new_count="$(find "$tmp/library" -type f | wc -l)"
(( new_count > 0 )) || die "refusing to keep an empty library snapshot"
prev_count=0
if [[ -n "$prev" ]]; then
  prev_count="$(find "$prev/library" -type f | wc -l)"
fi
if (( prev_count > 0 && new_count < prev_count / 2 )) && [[ "$ALLOW_SHRINK" != 1 ]]; then
  die "snapshot has ${new_count} files; previous had ${prev_count}; set ALLOW_SHRINK=1 to accept"
fi
log "library files: ${new_count} (previous: ${prev_count})"

mv -- "$tmp" "$SNAPS/$STAMP"
trap - EXIT
log "library snapshot written: snapshots/${STAMP}/library/"

# 4. Retention. Deleting an old hardlinked snapshot only frees disk space for
#    files that are unique to that snapshot.
mapfile -t old_snaps < <(find "$SNAPS" -mindepth 1 -maxdepth 1 -type d \
  -name '20??-??-??T*' | sort | head -n -"$KEEP_SNAPSHOTS")
for d in "${old_snaps[@]}"; do
  log "removing old snapshot: $d"
  rm -rf -- "$d"
done

mapfile -t old_dumps < <(find "$DUMPS" -maxdepth 1 -type f \
  -name 'immich-db-*.sql.gz' | sort | head -n -"$KEEP_DUMPS")
for f in "${old_dumps[@]}"; do
  log "removing old database dump: $f"
  rm -f -- "$f" "$f.sha256"
done

mapfile -t old_configs < <(find "$CONFIGS" -mindepth 1 -maxdepth 1 -type d \
  | sort | head -n -"$KEEP_SNAPSHOTS")
for d in "${old_configs[@]}"; do
  log "removing old configuration copy: $d"
  rm -rf -- "$d"
done

# Emergency retention: if the shared /mnt/big-extern disk is still below the
# minimum, give space back by deleting the oldest snapshots, but never the
# newest two.
while :; do
  avail_gib="$(df -Pk "$DEST" | awk 'NR == 2 { print int($4 / 1024 / 1024) }')"
  (( avail_gib < MIN_FREE_GIB )) || break
  snap_count="$(find "$SNAPS" -mindepth 1 -maxdepth 1 -type d -name '20??-??-??T*' | wc -l)"
  (( snap_count > 2 )) || {
    log "WARNING: only ${avail_gib} GiB free and only ${snap_count} snapshots left"
    break
  }
  oldest="$(find "$SNAPS" -mindepth 1 -maxdepth 1 -type d -name '20??-??-??T*' | sort | head -n 1)"
  log "low space (${avail_gib} GiB): removing oldest snapshot $oldest"
  rm -rf -- "$oldest"
done

log "Immich backup ${STAMP} completed"
```

Save the block above as `/tmp/immich-backup.sh`, then install and schedule it
as `jan` so it uses the same SSH key that was tested:

```bash
chmod 0755 /tmp/immich-backup.sh
install -Dm0755 /tmp/immich-backup.sh /home/jan/bin/immich-backup.sh
crontab -e
```

Add one line:

```cron
15 3 * * * /home/jan/bin/immich-backup.sh >> /mnt/big-extern/immich/logs/cron.log 2>&1
```

The script also writes its own monthly log under
`/mnt/big-extern/immich/logs/backup-YYYY-MM.log`. It uses `flock`, so a second run
will exit immediately if the previous one is still copying.

Check the result:

```bash
tail -50 /mnt/big-extern/immich/logs/backup-$(date +%Y-%m).log
ls -1 /mnt/big-extern/immich/snapshots
ls -lh /mnt/big-extern/immich/database | tail
df -h /mnt/big-extern
```

A failed run exits non-zero and leaves no renamed snapshot. The `.incomplete-*`
directory is removed by the cleanup trap. The database dump may still have
succeeded; that is fine and usable.

### Retention and free space

Default retention is 14 library snapshots (about two weeks) and 30 database
dumps. Because snapshots are hardlinked, 14 snapshots do not use 14 × 309 GB.
The first snapshot uses about 309 GB; later snapshots use only changed files,
new uploads, and one new database dump per day.

The script refuses to keep a snapshot that contains fewer than half the files
of the previous snapshot, and it refuses an empty snapshot. This protects
against a broken source mount or a half-dead disk silently replacing a good
backup with an empty one. After a deliberate large deletion, set
`ALLOW_SHRINK=1` for that run.

At verification time `/mnt/big-extern` was 932 GB with 760 GB free, also shared with
Garage/Velero. Keep `MIN_FREE_GIB` at 100 or higher and monitor:

```bash
df -h /mnt/big-extern
du -sh /mnt/big-extern/immich
```

If `/mnt/big-extern` fills up, reduce `KEEP_SNAPSHOTS`, remove the oldest snapshots,
or move the Immich backup to a larger/off-site target. Never let the backup
target fill the disk shared with the Kubernetes backup data. As a last resort,
the script deletes the oldest snapshots when free space falls below
`MIN_FREE_GIB`, but it always keeps the newest two and logs every deletion.

---

## 5. Restore

Restoring is always database **and** library. A database without the matching
files gives broken thumbnails and missing assets; files without the database
lose albums, people, and metadata.

### 5.1 Choose a backup

On the backup host:

```bash
SNAP=$(find /mnt/big-extern/immich/snapshots -mindepth 1 -maxdepth 1 -type d \
  -name '20??-??-??T*' | sort | tail -n 1)
DB=$(find /mnt/big-extern/immich/database -maxdepth 1 -type f \
  -name 'immich-db-*.sql.gz' | sort | tail -n 1)
echo "$SNAP"
echo "$DB"
gzip -t "$DB" && echo database-dump-ok
```

The snapshots also contain Immich's own daily dumps under
`library/backups/`. Those are the safest files to use with Immich's web-based
restore, because Immich knows their version and filename format.

### 5.2 Restore the library

On the backup host:

```bash
rsync -rltH --no-perms --no-owner --no-group --numeric-ids --delete \
  -e 'ssh -o BatchMode=yes' --rsync-path='sudo rsync' \
  "$SNAP/library/" \
  jan@192.168.0.180:/mnt/immich-data/usr/src/immich/immich-store/library/
```

Stop Immich first if you want to avoid writes while restoring:

```bash
ssh jan@192.168.0.180 'cd /opt/immich && sudo docker compose down'
# ... run the rsync above ...
```

`--delete` makes the destination match the snapshot. That is what a restore
should do, but it also deletes any file that was created after the snapshot.
Do not run it against the live library unless you mean it.

### 5.3 Restore the database

#### Option A — Immich web interface (recommended)

1. Restore the library first (section 5.2).
2. Start Immich on the server:

   ```bash
   ssh jan@192.168.0.180 'cd /opt/immich && sudo docker compose up -d'
   ```

3. Open `http://192.168.0.180:2283` and log in as an administrator.
4. Go to **Administration → Maintenance → Restore database backup**.
5. Choose one of the built-in backups from `library/backups/`, or upload the
   explicit `immich-db-*.sql.gz` file with **Select from computer**.
6. Confirm. Immich creates a restore point, restores the database, runs
   migrations if needed, and rolls back if the restore fails.

This is the method documented by Immich for v3.2.0 and the one to try first.

#### Option B — command line

This is useful for automation or when the web interface is unavailable. It
performs a destructive restore, so stop the stack and preserve the old database
directory first. Run these commands on the **backup host**; the dump stays on
`/mnt/big-extern` and is streamed over SSH, because `/mnt/big-extern` is not mounted on
the Immich server.

```bash
# 1. Stop Immich and move the old database directory aside. On a fresh host
#    there is nothing to move, so the mv only runs when the directory exists.
ssh jan@192.168.0.180 '
  cd /opt/immich &&
  sudo docker compose down &&
  pgdir=/mnt/immich-data/usr/src/immich/immich-store/postgres &&
  if [ -d "$pgdir" ]; then
    sudo mv "$pgdir" "$pgdir.broken-$(date +%Y%m%dT%H%M%S)"
  fi
'

# 2. Create the containers and start only PostgreSQL so it initialises a
#    fresh, empty database directory. The live directory is owned by UID 999
#    (the postgres user in this image); the entrypoint will fix it if needed.
ssh jan@192.168.0.180 '
  cd /opt/immich &&
  sudo install -d -m 700 -o 999 -g 0 \
    /mnt/immich-data/usr/src/immich/immich-store/postgres &&
  sudo docker compose create &&
  sudo docker start immich_postgres
'

# Wait for PostgreSQL instead of guessing with a fixed sleep.
for _ in {1..60}; do
  ssh jan@192.168.0.180 \
    'sudo docker exec immich_postgres pg_isready -U postgres -d immich >/dev/null' \
    && break
  sleep 2
done
ssh jan@192.168.0.180 \
  'sudo docker exec immich_postgres pg_isready -U postgres -d immich >/dev/null' \
  || { echo "postgres did not become ready"; exit 1; }

# 3. Stream the dump into PostgreSQL. The sed expression is the workaround
#    from the Immich restore documentation for the search_path setting.
gzip -dc "$DB" \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | ssh jan@192.168.0.180 \
      'sudo docker exec -i immich_postgres psql --dbname=immich --username=postgres --single-transaction --set ON_ERROR_STOP=on'

# 4. Start the remaining Immich services.
ssh jan@192.168.0.180 'cd /opt/immich && sudo docker compose up -d'
```

The `--single-transaction` and `ON_ERROR_STOP=on` make the restore
all-or-nothing: on an error, psql aborts instead of leaving a half-restored
database.

If the restore fails because the database is not empty, repeat step 1 and make
sure the `postgres/` directory really is empty before starting the container.
The note in the Immich documentation is important: a logical restore expects a
fresh database; restoring over a database that Immich has already started can
produce "relation already exists" or foreign-key errors.

Use the version of the dump that belongs to the library snapshot. Do not mix a
database dump from one day with a library snapshot from another day unless you
accept that difference.

### 5.4 Full restore to a fresh server

All commands in this section run on the **backup host** unless they are marked
as running on the new Immich host. The backup host is the only machine with
`/mnt/big-extern` mounted, so it pushes both the configuration and the library to the
new host over SSH.

1. Install Docker and the Compose plugin on the new host.
2. Create `/opt/immich` on the new host and push the saved configuration to it:

   ```bash
   SNAP=/mnt/big-extern/immich/snapshots/<stamp>
   CONFIG=/mnt/big-extern/immich/config/<stamp>
   NEW_HOST=jan@<new-host>

   ssh "$NEW_HOST" 'sudo install -d -m 755 /opt/immich'
   rsync -rlt --no-perms --no-owner --no-group \
     -e 'ssh -o BatchMode=yes' --rsync-path='sudo rsync' \
     "$CONFIG/" "$NEW_HOST:/opt/immich/"
   ```

3. Keep `IMMICH_VERSION=v3.2.0` in the pushed `.env` (the version that made the
   backup) until the data is restored. Upgrading later is a separate step.
4. Create the target directory and restore the library from the backup host:

   ```bash
   ssh "$NEW_HOST" 'sudo mkdir -p /mnt/immich-data/usr/src/immich/immich-store/library'
   rsync -rltH --no-perms --no-owner --no-group --numeric-ids \
     -e 'ssh -o BatchMode=yes' --rsync-path='sudo rsync' \
     "$SNAP/library/" \
     "$NEW_HOST:/mnt/immich-data/usr/src/immich/immich-store/library/"
   ```

5. Restore the database. Either:
   * stream it from the backup host with option B above, substituting
     `jan@<new-host>` for `jan@192.168.0.180`; or
   * start a fresh Immich and use the onboarding **Restore from backup** flow,
     which expects the library directories to be in place before you click
     restore. On a truly fresh host there is no old `postgres/` directory, so
     the conditional `mv` in option B is a no-op; just start PostgreSQL once
     the data directory exists and is empty.

6. Start the remaining services **on the new host** with
   `sudo docker compose -f /opt/immich/docker-compose.yml up -d`.
7. Log in, open a few photos and videos, and run the integrity check in
   **Administration → Maintenance**. If thumbnails or encoded videos are
   missing because only the original folders were restored, run the
   **Generate Thumbnails** and **Transcode Videos** jobs.

The live library has mixed ownership: at verification time 78,522 files were
`nobody:nogroup` and 37,353 were `root:root`. File modes are mixed too (78,521
files at `674`, 14,604 at `777`, 13,297 at `644`, and 9,453 at `664`);
directories are `775`, and the top-level directory is `777`. The Immich
container runs as `root`, so a plain file restore is readable. If you restore
to a host where the container runs as a non-root user, or you want one
consistent owner, fix ownership after the copy:

```bash
ssh jan@<host> 'sudo chown -R root:root /mnt/immich-data/usr/src/immich/immich-store/library'
```

---

## 6. Verification and test restore

After every backup, check:

```bash
# Exit code of the run is 0
tail -30 /mnt/big-extern/immich/logs/backup-$(date +%Y-%m).log

# Latest snapshot and dump exist
find /mnt/big-extern/immich/snapshots -mindepth 1 -maxdepth 1 -type d | sort | tail -1
find /mnt/big-extern/immich/database -maxdepth 1 -name '*.sql.gz' | sort | tail -1

# Database dump is not corrupt
gzip -t "$(find /mnt/big-extern/immich/database -maxdepth 1 -name '*.sql.gz' | sort | tail -1)"

# File count is close to the source
find "$(find /mnt/big-extern/immich/snapshots -mindepth 1 -maxdepth 1 -type d | sort | tail -1)/library" -type f | wc -l
```

A backup that is never restored is only a hope. At least once per quarter,
restore the latest database dump and a sample of the library to a scratch
host, or restore into a temporary Immich instance, and confirm that:

* the server starts and `/api/server/version` returns the expected version;
* an admin can log in;
* a photo opens and a video plays;
* albums and people are present;
* the integrity check does not report missing files.

### Test restore performed on 2026-11-10

The database side was verified end to end without touching the live database:

* `pg_dump` piped through `gzip -1` produced about 158 MB and passed `gzip -t`;
* the dump was loaded into a scratch database (`immich_restore_test`) on the
  same PostgreSQL 14.19 instance with the `search_path` rewrite and
  `--single-transaction --set ON_ERROR_STOP=on`;
* the restored counts matched the live database exactly: 23,548 rows in
  `asset` and 46,702 rows in `asset_file`;
* the scratch database was dropped afterwards.

The library side was tested only with a small source subtree, including
`--link-dest` hardlinks on `/mnt/big-extern`. A full 309 GB copy and restore was not
run. Before relying on this backup, do one full restore to a scratch host.

A scratch database test can be repeated at any time. It does not stop Immich
and does not modify the live database:

```bash
ssh jan@192.168.0.180 'sudo docker exec immich_postgres createdb -U postgres immich_restore_test'
gzip -dc "$DB" \
  | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
  | ssh jan@192.168.0.180 \
      'sudo docker exec -i immich_postgres psql --dbname=immich_restore_test --username=postgres --single-transaction --set ON_ERROR_STOP=on'
ssh jan@192.168.0.180 \
  'sudo docker exec immich_postgres psql -U postgres -d immich_restore_test -c "select count(*) from asset"'
ssh jan@192.168.0.180 'sudo docker exec immich_postgres dropdb -U postgres immich_restore_test'
```

---

## 7. Risks and limitations

| Risk | Detail |
| --- | --- |
| No off-site copy | `/mnt/big-extern` is on the same Proxmox host as the Immich VM. A fire, theft, lightning strike, or host failure can destroy both. Copy the backup to a NAS or cloud target for 3-2-1 protection. |
| Shared target | `/mnt/big-extern` also holds the Garage/Velero/restic data. A full disk affects both backups. Monitor free space and keep `MIN_FREE_GIB` at 100 or more. |
| NTFS metadata | `/mnt/big-extern` is NTFS. Hardlinks work, but POSIX ownership, modes, ACLs, and xattrs are not preserved. Restore uses content and timestamps; fix ownership after restore. |
| Live consistency | The database is dumped first and the library is copied live. Files uploaded during the copy can appear in the library but not in the dump; they are untracked and can be re-uploaded or cleaned up. Files deleted after the dump but before rsync reaches them leave rows that point to missing files, and the next run does not repair that. For a consistent point-in-time copy, stop `immich_server` and `immich_machine_learning` for the duration of the file copy (leave PostgreSQL and Redis up for `pg_dump`). |
| Secrets on disk | `config/<stamp>/.env` contains `DB_PASSWORD`. The destination is not encrypted and is world-writable on the NTFS mount. Protect it or exclude `.env` and keep it in a password manager. |
| Version changes | A dump from PostgreSQL 14.19 / Immich v3.2.0 is intended for the same major version. Restore with matching versions first, then upgrade Immich. |
| External libraries | If an Immich external library points outside `UPLOAD_LOCATION`, the files are not in this backup. Add those paths as separate rsync sources. |
| Raw Postgres files | `.../postgres/` is intentionally not copied. Do not add it to rsync; use the logical dump. |
| NTFS filenames | NTFS rejects characters such as colon, question mark, asterisk, angle brackets, pipe, and double quote in file names. None of the 115,875 files used those characters at verification time, but a future asset with such a name would make rsync report an error for that file. |

The NTFS filename restriction is the main reason to move this backup to a
Linux filesystem (ext4/XFS) when a larger disk is available. On a Linux target
the rsync flags can be simplified to `-aHAX` and ownership can be preserved.

---

## 8. Quick reference

| Task | Command |
| --- | --- |
| Manual run | `/home/jan/bin/immich-backup.sh` |
| Follow log | `tail -f /mnt/big-extern/immich/logs/backup-$(date +%Y-%m).log` |
| List snapshots | `ls -1 /mnt/big-extern/immich/snapshots` |
| Latest snapshot | `find /mnt/big-extern/immich/snapshots -mindepth 1 -maxdepth 1 -type d \| sort \| tail -1` |
| List dumps | `ls -lh /mnt/big-extern/immich/database` |
| Check dump | `gzip -t /mnt/big-extern/immich/database/immich-db-<stamp>.sql.gz` |
| Check checksum | `sha256sum -c /mnt/big-extern/immich/database/immich-db-<stamp>.sql.gz.sha256` |
| Free space | `df -h /mnt/big-extern` |
| Immich status | `ssh jan@192.168.0.180 'sudo docker compose -f /opt/immich/docker-compose.yml ps'` |
| Immich version | `curl -fsS http://192.168.0.180:2283/api/server/version` |
