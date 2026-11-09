# Backup configuration files

These files are reference copies of the backup target configuration. They do
not contain credentials.

| File | Installed where | Notes |
| --- | --- | --- |
| `garage-net-init.sh` | LXC `/usr/local/sbin/garage-net-init` | LXC entrypoint; sets both addresses then execs `/sbin/init` |
| `garage.service` | LXC `/etc/systemd/system/garage.service` | Keep systemd sandboxing off; see `backup.md` |
| `garage-webui.service` | LXC `/etc/systemd/system/garage-webui.service` | Garage Web UI; runs as user `garage`, see `backup.md` section 5 |
| `garage-webui.env.example` | LXC `/etc/garage-webui.env` (0600) | Password hash is live-only, not reproduced here |
| `garage.toml.example` | LXC `/etc/garage.toml` | Replace generated placeholders |
| `garage-meta-snapshot.sh` | LXC `/usr/local/sbin/garage-meta-snapshot.sh` | SQLite online backup |
| `garage-meta-snapshot.service` | LXC `/etc/systemd/system/` | Oneshot unit |
| `garage-meta-snapshot.timer` | LXC `/etc/systemd/system/` | Daily 01:15 UTC |
| `values-velero.yaml` | Helm values on management | Object-only Velero backup |
| `restic-daemonset.yaml` | cluster `backup` namespace | Per-node local-path backup |
| `restic-exporter.yaml` | cluster `backup` namespace | Prometheus exporter for the restic repository |
| `postgres-dump.yaml` | cluster `euro-office` namespace | PostgreSQL logical dump |

Create the Kubernetes Secrets separately. The Velero Secret key is `cloud`;
the restic Secret keys are `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and
`RESTIC_PASSWORD`. See `backup-restore-howto.md`.
