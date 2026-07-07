# Meet Deployment Fix

## Problem
The `meet` application's infrastructure dependencies were missing from the Kubernetes cluster:
- `meet-postgresql` (Bitnami PostgreSQL) — not deployed
- `meet-redis` (Redis cache) — not deployed
- `meet-static` (Nginx static file server) — not deployed

This caused:
- `meet-superuser` job in `CrashLoopBackOff` (19 restarts) — database unreachable
- `meet-migrate` job stuck in `Running` for 103 minutes — waiting for database
- `meet-frontend` pod stuck in `Init:0/1` — ConfigMap `meet-static-files` missing

## Root Cause
The meet Helm chart was deployed via helmfile, but the supporting releases (`meet-postgresql`, `meet-redis`, `meet-static`) defined in `helmfile/apps/meet/helmfile-child.yaml.gotmpl` were never installed. The database host was configured as `meet-cluster-rw` (the Bitnami PostgreSQL service with `fullnameOverride: meet-cluster-rw`), but the service didn't exist.

## Fix Applied
Deployed the three missing releases using helmfile with selectors:

```bash
helmfile -e demo sync --selector name=meet-postgresql
helmfile -e demo sync --selector name=meet-redis
helmfile -e demo sync --selector name=meet-static
```

### Resulting state (final):
| Resource | Status |
|---|---|
| `meet-postgresql` release → `meet-cluster-rw-0` pod | Running |
| `meet-redis` release → `meet-redis-master-0` pod | Running |
| `meet-static` release → `meet-static-nginx-*` pod | Running |
| `meet-backend` deployment | Running |
| `meet-frontend` deployment | Running |
| `meet-migrate` job | Completed |
| `meet-superuser` job | Completed ("Superuser created successfully.") |
