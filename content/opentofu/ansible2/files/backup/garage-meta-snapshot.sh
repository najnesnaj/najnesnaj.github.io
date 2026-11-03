#!/bin/sh
set -eu

# Snapshot the live Garage metadata database with SQLite's online backup API.
# The data volume itself is already on the external Proxmox disk; this second
# copy protects against metadata corruption, not against loss of that disk.
SNAP_DIR=/mnt/garage/meta-snapshots
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$SNAP_DIR"
chown garage:garage "$SNAP_DIR" 2>/dev/null || true
chmod 0750 "$SNAP_DIR" 2>/dev/null || true

sqlite3 /var/lib/garage/meta/db.sqlite ".backup '${SNAP_DIR}/db-${STAMP}.sqlite'"
chown garage:garage "${SNAP_DIR}/db-${STAMP}.sqlite" 2>/dev/null || true
chmod 0640 "${SNAP_DIR}/db-${STAMP}.sqlite" 2>/dev/null || true

find "$SNAP_DIR" -name 'db-*.sqlite' -mtime +30 -delete
