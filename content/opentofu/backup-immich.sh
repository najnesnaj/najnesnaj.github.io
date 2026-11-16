#!/usr/bin/env bash
# Back up Immich (library snapshots, PostgreSQL dump, compose config) to
# /mnt/big-extern/immich. Run on the backup host that has /mnt/big-extern
# mounted. See immich-backup.md for prerequisites, restore steps, and risks.
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

# Fail with an actionable message instead of a bare "mkdir: Permission denied"
# from set -e when the mount is owned by another user (e.g. root) than the
# account running this script.
if ! mkdir -p "$SNAPS" "$DUMPS" "$CONFIGS" "$LOGS" 2>/dev/null; then
  die "$DEST is not writable by $(id -un). Run this script as root, or fix ownership of /mnt/big-extern (for example: sudo chown $(id -un) /mnt/big-extern)."
fi
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
