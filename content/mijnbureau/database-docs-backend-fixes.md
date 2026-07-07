# Database Docs-Backend Fixes

## 2026-07-06: Fixed PostgreSQL password mismatch (docs-backend CrashLoopBackOff)

### Diagnosis

The `docs-backend` pod was in `CrashLoopBackOff` with:

```
FATAL: password authentication failed for user "docs"
```

**Root cause**: The `MIJNBUREAU_MASTER_PASSWORD` environment variable used during different `helmfile` runs differed, causing the deterministically-derived passwords to diverge between releases.

The password derivation formula in `helmfile/environments/default/database.yaml.gotmpl:80-81`:

```yaml
password: {{ derivePassword 1 "long" (requiredEnv "MIJNBUREAU_MASTER_PASSWORD") "docs" "database" | sha1sum | quote}}
adminpassword: {{ derivePassword 1 "long" (requiredEnv "MIJNBUREAU_MASTER_PASSWORD") "docs" "database_admin" | sha1sum | quote}}
```

Since the `docs` chart (backend deployment) and `docs-postgresql` chart (Bitnami PostgreSQL) are separate `helmfile` releases, they can be deployed at different times with different values of `MIJNBUREAU_MASTER_PASSWORD`.

**Cluster state at diagnosis:**

| Component | Password hash | Status |
|---|---|---|
| Database `docs` user (actual) | `679d586a5cf497f77a79943ac3df99e5f135967e` | Works |
| Database `postgres` user (actual) | `679d586a5cf497f77a79943ac3df99e5f135967e` | Works |
| Secret `docs-cluster-rw` `password` (docs user) | `c78a89da23e2a3246a3309a99454d38caab181d5` | **Wrong** |
| Secret `docs-cluster-rw` `postgres-password` | `2e8ff8d31985ef461d5cdf1372cae27f42cebde9` | **Wrong** |
| New backend `DB_PASSWORD` | `2e8ff8d31985ef461d5cdf1372cae27f42cebde9` | **Wrong** |
| Old backend `DB_PASSWORD` (working) | `679d586a5cf497f77a79943ac3df99e5f135967e` | Correct |

The previous fix (from `docs-modifications.md`) had set both database users to `679d586a5cf497f77a79943ac3df99e5f135967e`. A later helmfile deploy updated the `docs` chart (backend env vars) AND the `docs-cluster-rw` secret, but the actual database passwords were left unchanged.

### Fix Applied

#### Step 1: Update the Kubernetes secret with the correct password

The `docs-cluster-rw` secret is consumed by the Bitnami PostgreSQL pod to authenticate. It must match what the database actually has.

```bash
CORRECT_PW="679d586a5cf497f77a79943ac3df99e5f135967e"
kubectl patch secret docs-cluster-rw -p "{\"data\":{\"password\":\"$(echo -n $CORRECT_PW | base64)\",\"postgres-password\":\"$(echo -n $CORRECT_PW | base64)\"}}"
```

Both `password` (docs user) and `postgres-password` (postgres admin) were set to the same value, matching the actual database state.

#### Step 2: Restore the backend deployment env vars with correct DB_PASSWORD

The `kubectl set env` command accidentally wiped all env vars from the deployment. Restored them from the working ReplicaSet `docs-backend-7b7469c655` with the corrected `DB_PASSWORD`:

```bash
# Extract env vars from working ReplicaSet
kubectl get replicaset docs-backend-7b7469c655 \
  -o jsonpath='{.spec.template.spec.containers[0].env}' > /tmp/working-env.json

# Patch DB_PASSWORD and apply back to deployment
python3 -c "
import json
with open('/tmp/working-env.json') as f:
    env = json.load(f)
for e in env:
    if e['name'] == 'DB_PASSWORD':
        e['value'] = '679d586a5cf497f77a79943ac3df99e5f135967e'
patch = [{'op': 'replace', 'path': '/spec/template/spec/containers/0/env', 'value': env}]
print(json.dumps(patch))
" | kubectl patch deployment docs-backend --type=json -p -
```

#### Step 3: Clean up stale ReplicaSets

ReplicaSets created with the wrong env vars or incomplete templates were removed:

```bash
kubectl delete replicaset docs-backend-595ffc785d
kubectl delete replicaset docs-backend-798dfc7cfb
kubectl delete replicaset docs-backend-7c7c8c8b76
```

### Verification

After the fix:

- Secret `docs-cluster-rw` `password` = `679d586a5cf497f77a79943ac3df99e5f135967e` ✓
- Secret `docs-cluster-rw` `postgres-password` = `679d586a5cf497f77a79943ac3df99e5f135967e` ✓
- Backend deployment `DB_PASSWORD` = `679d586a5cf497f77a79943ac3df99e5f135967e` ✓
- Database `docs` user authenticates with `679d586a5cf497f77a79943ac3df99e5f135967e` ✓
- Database `postgres` user authenticates with `679d586a5cf497f77a79943ac3df99e5f135967e` ✓
- Heartbeat: `{"status": "ok"}` ✓

```
Password used in PostgreSQL       = 679d586a5cf497f77a79943ac3df99e5f135967e
Password used in docs-backend     = 679d586a5cf497f77a79943ac3df99e5f135967e
Password in docs-cluster-rw secret = 679d586a5cf497f77a79943ac3df99e5f135967e
```

### Root Cause Analysis

The password is derived deterministically from `MIJNBUREAU_MASTER_PASSWORD` using:

```
sha1(derivePassword(1, "long", MASTER_PW, "docs", "database"))
```

There are 8 separate helmfile releases for the `docs` application, each rendered independently at deploy time:

```
docs-postgresql  →  Bitnami PostgreSQL  →  Secret `docs-cluster-rw`
docs-cluster-credentials  →  (CNPG, not used here)
docs-cluster              →  (CNPG, not used here)
docs-redis       →  Redis
docs-minio       →  MinIO
docs             →  Backend + Frontend etc.
docs-nginx       →  Nginx reverse proxy
docs-static      →  Static assets
```

If any release is deployed at a different time with a different `MIJNBUREAU_MASTER_PASSWORD`, the rendered passwords will differ. This is the fundamental architectural weakness.

### Prevention

1. **Always deploy all docs releases together** using a single `helmfile sync` invocation so that `MIJNBUREAU_MASTER_PASSWORD` is consistent
2. **Pin `MIJNBUREAU_MASTER_PASSWORD`** in your CI/CD environment and never change it without a coordinated database password update
3. **Consider using a static/random password** for `database.docs` (stored as a Kubernetes Secret managed independently of helmfile) instead of deriving from a master password
4. **If using Bitnami PostgreSQL**, note that `helm upgrade` does NOT update the custom user password (`auth.password`) if the secret already exists — it only regenerates `postgres-password` on some conditions, which can lead to credential drift
5. **Document the master password** in a secure vault (e.g., SOPS-encrypted file) so it can be recovered if needed
