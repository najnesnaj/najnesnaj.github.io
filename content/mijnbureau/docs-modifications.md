# docs-modifications

## 2026-06-30: Fixed database credential mismatch (Redis & PostgreSQL) and Keycloak connectivity

### 1. Database credential mismatch (docs backend CrashLoopBackOff)

**Issue**: docs-backend pods were in CrashLoopBackOff with `password authentication failed for user "docs"` and `invalid username-password pair` (Redis).

**Root cause**: The `docs` helm chart and its dependency charts (`docs-postgresql`, `docs-redis`) were deployed at different times, causing the passwords baked into the backend deployment to differ from the passwords in the Kubernetes secrets and running database/Redis servers.

- Backend expects `DB_PASSWORD`: `679d586a5cf497f77a79943ac3df99e5f135967e`
- PostgreSQL secret had `password`: `995da496c6c535c80d4c59141ac15437450c0335`
- Backend expects Redis password: `2000c645f9ca4deb209962754e96f2490cd3bb48`
- Redis secret had `redis-password`: `78716d1c871e69d7becd8dfa5ce7d1ca4a2ef883`

**Fix**:
1. Updated PostgreSQL database `docs` and `postgres` user passwords to match backend expectation
2. Patched `docs-cluster-rw` secret with matching passwords
3. Updated Redis server `requirepass` via `CONFIG SET`
4. Patched `docs-redis` secret with matching password
5. Restarted Redis pod and docs-backend pods

### 2. Network policy blocked Keycloak on wrong port

**Issue**: OIDC callback returned HTTP 500 with `ConnectTimeoutError: Connection to keycloak-keycloak timed out`.

**Root cause**: The `docs-backend` NetworkPolicy egress rule allowed port `80` to Keycloak, but the Keycloak pod listens on port `8080`. Kubernetes NetworkPolicy `port` refers to the destination pod port, not the service port — so traffic was silently dropped.

**Fix**:
- **File:** `helmfile/apps/docs/values.yaml.gotmpl:108` — Changed port from `80` to `8080`
- Applied the same fix to the live NetworkPolicy via `kubectl apply`

### 3. Permission denied for table `impress_user`

**Issue**: createsuperuser job failed with `permission denied for table impress_user`.

**Root cause**: Database tables were created by the migration job (running as `postgres` superuser), but the `docs` user had no permissions granted on the `impress_user` table or other objects.

**Fix**: Granted privileges to the `docs` user:
```sql
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO docs;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO docs;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO docs;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO docs;
GRANT USAGE ON SCHEMA public TO docs;
```
