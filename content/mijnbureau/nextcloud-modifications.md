# nextcloud-modifications

## 2026-06-30: Fixed Redis password mismatch causing 500 error on /login

**Issue**: Nextcloud `/login` returned HTTP 500 with `RedisException: NOAUTH Authentication required`.

**Root cause**: The `nextcloud-externalredis` Kubernetes secret contained a stale Redis password that didn't match the actual Redis server's password.

- Correct Redis password (in `nextcloud-redis` secret): `8659e99b7b20f1f996fa66c7d4123058d40a4c3a`
- Stale password (in `nextcloud-externalredis` secret): `e8eecd763df125e15f3bfc9497b3e527e5c6ae63`

The `REDIS_HOST_PASSWORD` env var in the Nextcloud deployment pulls from `nextcloud-externalredis`, which caused the PHP session handler and Redis cache operations to fail authentication.

**Fix**:
1. Patched `nextcloud-externalredis` secret with the correct password from `nextcloud-redis`
2. Restarted the Nextcloud deployment (`kubectl rollout restart deployment nextcloud`)

**Commands used**:
```bash
CORRECT_PASS=$(kubectl get secret nextcloud-redis -n default -o jsonpath='{.data.redis-password}' | base64 -d)
kubectl patch secret nextcloud-externalredis -n default -p "{\"data\":{\"password\":\"$(echo -n $CORRECT_PASS | base64 -w0)\"}}"
kubectl rollout restart deployment nextcloud -n default
```

**Verification**: Pod env `REDIS_HOST_PASSWORD` now shows correct value; HTTP 200 on `/login`.
