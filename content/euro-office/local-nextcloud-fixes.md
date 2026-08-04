<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Local Nextcloud AIO fixes (Podman)

This document collects the fixes needed to run [Nextcloud All-in-One](https://github.com/nextcloud/all-in-one) with **Podman** as a **local-only** instance (no public domain, no internet link). It is a companion to [installation-steps.md](./installation-steps.md), which contains the full install log.

Two problems were solved:

1. Non-root AIO containers cannot bind host port `443` under Podman.
2. Caddy in the apache container tries to obtain a Let's Encrypt certificate for a LAN-only domain (e.g. `nextcloud.local`), which can never succeed, so HTTPS fails with `SSL_ERROR_INTERNAL_ERROR_ALERT`.

## Environment

- Linux Mint 22.3, user `naj` (uid/gid 1000), rootless Podman 4.9.3
- Docker-compatible API via `podman.socket` (exposes API `v1.41`)
- AIO mastercontainer runs with `--network bridge`, `DOCKER_API_VERSION=1.41` and `SKIP_DOMAIN_VALIDATION=true`
- Chosen local domain: `nextcloud.local` (mapped in `/etc/hosts` to `192.168.0.114`)
- AIO interface password: `scolding alfalfa perm greyhound ranger decal juice much`

---

## Fix 1: Allow non-root containers to bind port 443

### Problem

The AIO `nextcloud-aio-domaincheck` and `nextcloud-aio-apache` containers run as the non-root user `www-data` and bind host port `443`. Docker grants non-root processes `CAP_NET_BIND_SERVICE`; **Podman grants no effective capabilities to non-root users by default**, so binding fails:

```
nextcloud-aio-domaincheck: (lighttpd) bind() [::]:443: Permission denied
```

(Setting `net.ipv4.ip_unprivileged_port_start=80` via `default_sysctls` in `~/.config/containers/containers.conf` does **not** help: the Podman Docker-API compatibility path ignores `default_sysctls` for containers created by the mastercontainer.)

### Fix

Make the mastercontainer add `CAP_NET_BIND_SERVICE` to the domaincheck and apache container definitions. The definitions live in `containers.json` inside the running mastercontainer (`/var/www/docker-aio/php/containers.json`, in the container's writable layer) and support a `cap_add` field that the mastercontainer forwards into the container-create request.

The patch survives `podman restart` but is **lost when the mastercontainer is recreated** — re-apply afterwards (see the helper script below).

## Fix 2: Self-signed TLS for a local-only domain

### Problem

The apache container runs Caddy for TLS termination. Its Caddyfile (`/Caddyfile` in the image, rendered to `/tmp/Caddyfile` by `Containers/apache/start.sh`) uses an ACME issuer:

```
tls {
    issuer acme {
        profile tlsserver
        disable_http_challenge
    }
}
```

Caddy tries to obtain a Let's Encrypt certificate for `nextcloud.local`. A `.local` name can never get a public certificate, so Caddy keeps retrying and **never serves TLS**, which shows as `SSL_ERROR_INTERNAL_ERROR_ALERT` / `ERR_SSL_PROTOCOL_ERROR` in the browser. Apache container logs show:

```
{"level":"error","logger":"tls.obtain","msg":"will retry",
 "error":"[nextcloud.local] Obtain: subject 'nextcloud.local' does not qualify for a public certificate","attempt":1,...}
```

### Fix

Replace the ACME issuer with Caddy's internal CA, which issues a self-signed certificate valid for the configured domain. Since the Caddyfile is regenerated on every container start, a custom template is **bind-mounted** into the container at `/Caddyfile`.

### Fix 3 (follow-up): stale php-fpm `listen.allowed_clients`

Recreating the apache container gives it a **new IP** in the `nextcloud-aio` bridge network. The Nextcloud container's php-fpm only accepts connections from the apache IP recorded when Nextcloud started (`listen.allowed_clients`), so requests are dropped:

```
ERROR: Connection disallowed: IP address '10.89.3.23' has been dropped.
```

This surfaces as HTTP `503` (Apache `AH01074: Failed writing Environment`). Fix by restarting Nextcloud so its `start.sh` recomputes the allowed list with the current apache IP.

---

## Files

| Path | Purpose |
| --- | --- |
| `~/.local/bin/nextcloud-aio-podman-fix.sh` | Helper script: idempotently patches `containers.json` (cap_add + Caddyfile bind mount) and restarts the mastercontainer if something changed. |
| `~/.config/systemd/user/nextcloud-aio-podman-fix.service` | Runs the helper script at session start (after `podman.socket` / `podman-restart.service`). |
| `/home/naj/aio-config/Caddyfile` | Custom apache Caddyfile template with `tls { issuer internal }`, bind-mounted into the apache container at `/Caddyfile:ro`. |
| `containers.json` (inside mastercontainer) | Patched container definitions (source of truth for the mastercontainer's container creation). |

## Applying the fixes

### Prerequisites

- The host file `/home/naj/aio-config/Caddyfile` must exist (the script aborts otherwise). Content: copy of the apache image's `/Caddyfile` template, with the ACME issuer block replaced by `tls { issuer internal }`:

  ```caddy
  tls {
      issuer internal
  }
  ```

- The mastercontainer must be running (the script waits up to 60 s for it).

### Run the helper script

```sh
~/.local/bin/nextcloud-aio-podman-fix.sh
```

It:

1. Adds `"cap_add": ["NET_BIND_SERVICE"]` to `nextcloud-aio-domaincheck` and `nextcloud-aio-apache` in `containers.json`.
2. Adds the bind mount `/home/naj/aio-config/Caddyfile:/Caddyfile:ro` to `nextcloud-aio-apache` (if missing).
3. Restarts the mastercontainer only when something changed (clears the `containers.json` cache).

### Recreate the apache container

The apache container must be (re)created for the changed definition to take effect:

1. In the AIO interface click **Stop containers**, then **Start containers**.

   Or, because password login to the AIO interface is **blocked while apache runs**:

   ```sh
   podman rm -f nextcloud-aio-apache      # temporarily unblocks interface login
   # then log in at https://192.168.0.114:8080 and click "Start containers"
   ```

### Restart Nextcloud (only if it returns 503)

```sh
podman restart nextcloud-aio-nextcloud
```

### Verify

```sh
# 1. bind mount present on the apache container
podman inspect nextcloud-aio-apache --format '{{json .HostConfig.Binds}}'
# -> contains "/home/naj/aio-config/Caddyfile:/Caddyfile:ro"

# 2. rendered Caddyfile uses the internal issuer
podman exec nextcloud-aio-apache cat /tmp/Caddyfile | grep -A2 'TLS options'

# 3. TLS handshake succeeds (self-signed)
echo | openssl s_client -connect nextcloud.local:443 -servername nextcloud.local 2>/dev/null | grep -i 'verify return code'

# 4. site reachable
curl -sk -o /dev/null -w '%{http_code}\n' https://nextcloud.local/login   # expect 200
```

## Automation

The systemd user service applies the patch at every session start (idempotent):

```sh
systemctl --user status nextcloud-aio-podman-fix.service
```

## Caveats

- The `containers.json` patch and the Caddyfile bind mount are **lost when the mastercontainer is recreated** (`podman rm -f` + `podman run`, e.g. when updating). Always re-run `~/.local/bin/nextcloud-aio-podman-fix.sh` afterwards.
- Recreating the apache container changes its bridge IP → restart `nextcloud-aio-nextcloud` if you get HTTP `503` (see Fix 3).
- The certificate is self-signed: every client must accept the browser warning. For a trusted certificate on the LAN, put a local reverse proxy in front instead (see [reverse-proxy.md](./reverse-proxy.md)).
- If you later switch to a public domain, remove the Caddyfile bind mount (and the `tls internal` template) again so real Let's Encrypt certificates can be issued.
