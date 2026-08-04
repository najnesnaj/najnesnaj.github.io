<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Nextcloud EuroOffice integration (document saving fix)

This document records how EuroOffice is integrated into this Nextcloud All-in-One (Podman, local-only) setup and which fix was needed so that documents can be **saved**. It is a companion to [installation-steps.md](./installation-steps.md) and [local-nextcloud-fixes.md](./local-nextcloud-fixes.md).

## Environment

- Linux Mint 22.3, user `naj` (uid/gid 1000), rootless Podman 4.9.3
- AIO mastercontainer with `SKIP_DOMAIN_VALIDATION=true`, local-only domain `nextcloud.local` → `192.168.0.114`
- TLS on the apache container uses Caddy's **internal CA** (self-signed) because no public certificate can be issued for a LAN-only domain (see [local-nextcloud-fixes.md](./local-nextcloud-fixes.md))
- EuroOffice runs as the AIO-managed container `nextcloud-aio-eurooffice` on the `nextcloud-aio` network (IP `10.89.3.13`, port 80), reachable from the browser via `https://nextcloud.local/eurooffice`
- EuroOffice app in Nextcloud: `eurooffice` 11.0.1, `DocumentServerUrl = https://nextcloud.local/eurooffice`, shared JWT secret injected by AIO

> [!NOTE]
> There is an unused, standalone container `euro-office` (`ghcr.io/euro-office/documentserver`) publishing host port `8081`. It is **not** used by the EuroOffice app (which points to `https://nextcloud.local/eurooffice`). It can be removed to avoid confusion; it was left in place.

## Problem

Opening documents works (the browser can reach the documentserver), but **saving fails** with:

> The document cannot be saved. Please check connection settings or contact your administrator.

This is a callback/download failure: the documentserver's background services (converter, docservice) cannot talk to Nextcloud over the network. In this local-only setup the server-to-server requests use `https://nextcloud.local`, which:

1. is served with a **self-signed certificate** (Caddy internal CA), and
2. resolves to the **private IP** `192.168.0.114`.

## Root cause (from the logs)

The converter log in the documentserver container shows the download failing at the TLS handshake:

```
error downloadFile:url=https://nextcloud.local/apps/eurooffice/download?...;attempt=1;code:UNABLE_TO_GET_ISSUER_CERT_LOCALLY;connect:undefined Error: unable to get local issuer certificate
```

The same TLS failure breaks the callback POST of the saved document back to Nextcloud. Relevant paths (in `nextcloud-aio-eurooffice`):

- Config: `/etc/euro-office/documentserver/local.json` (and `default.json`)
- Converter log: `/var/log/euro-office/documentserver/converter/out.log`
- Docservice log: `/var/log/euro-office/documentserver/docservice/out.log`

### Mapping to the generic 4-step tutorial

| Generic step | Applied? | How |
| --- | --- | --- |
| 1. `allow_local_remote_servers => true` in Nextcloud `config.php` | Already done | Already present in the AIO-generated `config.php` |
| 2. `allowPrivateIPAddress: true` in the documentserver | Yes | via `ALLOW_PRIVATE_IP_ADDRESS=true` (see below) |
| 3. Internal routing URLs in the app | Not applicable | EuroOffice app 11.0.1 (as shipped by AIO) has no such setting |
| 4. `rejectUnauthorized: false` / `SSL_INSECURE=true` | Yes | via `USE_UNAUTHORIZED_STORAGE=true` (see below) |

## Fix

The documentserver image's entrypoint (`/entrypoint.sh`) natively supports two environment variables that map to the required JSON keys and are applied to `local.json` **on every container start**:

| Env var | JSON effect |
| --- | --- |
| `USE_UNAUTHORIZED_STORAGE=true` | `.services.CoAuthoring.requestDefaults.rejectUnauthorized = false` |
| `ALLOW_PRIVATE_IP_ADDRESS=true` | `.services.CoAuthoring["request-filtering-agent"].allowPrivateIPAddress = true` |

Two things were done: a **durable** change in `containers.json` (survives container recreates) and an **immediate** change in the running container (no recreate needed).

### 1. Durable: add the env vars to `nextcloud-aio-eurooffice` in `containers.json`

The container definitions live in `containers.json` inside the running mastercontainer (`/var/www/docker-aio/php/containers.json`). Add the two vars to the `environment` of `nextcloud-aio-eurooffice`:

```sh
podman exec -i nextcloud-aio-mastercontainer python3 - <<'PYEOF'
import json
path = '/var/www/docker-aio/php/containers.json'
data = json.load(open(path))
changed = False
for c in data['aio_services_v1']:
    if c.get('container_name') == 'nextcloud-aio-eurooffice':
        env = c.get('environment', [])
        for var in ('USE_UNAUTHORIZED_STORAGE=true', 'ALLOW_PRIVATE_IP_ADDRESS=true'):
            if var not in env:
                env.append(var)
                changed = True
json.dump(data, open(path, 'w'), indent=2)
print('changed:', changed)
PYEOF

podman restart nextcloud-aio-mastercontainer   # clears the containers.json cache
```

### 2. Immediate: edit `local.json` in the running container

This makes the fix effective without recreating the container:

```sh
podman exec -i nextcloud-aio-eurooffice python3 - <<'PYEOF'
import json
path = '/etc/euro-office/documentserver/local.json'
data = json.load(open(path))
co = data.setdefault('services', {}).setdefault('CoAuthoring', {})
co.setdefault('requestDefaults', {})['rejectUnauthorized'] = False
co.setdefault('request-filtering-agent', {})['allowPrivateIPAddress'] = True
json.dump(data, open(path, 'w'), indent=2)
PYEOF

podman restart nextcloud-aio-eurooffice
```

The manual edits survive a `podman restart`: the entrypoint's jq filter starts with `.` (identity) and only overrides the env-controlled keys, so the extra keys are preserved. They do **not** survive a container recreate - but then the env vars from step 1 regenerate `local.json` with the same values, so no manual step is needed.

### 3. Automation: keep the fix across mastercontainer recreates

The `containers.json` patch is **lost when the mastercontainer is recreated** (`podman rm -f` + `podman run`, e.g. on update). The helper script `~/.local/bin/nextcloud-aio-podman-fix.sh` (which already patches `cap_add` and the Caddyfile bind mount) was extended to also (re-)apply the two EuroOffice env vars. Run it after every mastercontainer recreate:

```sh
~/.local/bin/nextcloud-aio-podman-fix.sh
```

It is idempotent (`containers.json already patched` when nothing changes).

## Verification

```sh
# 1. env vars are in the container definition
podman exec nextcloud-aio-mastercontainer python3 -c "
import json
d=json.load(open('/var/www/docker-aio/php/containers.json'))
for c in d['aio_services_v1']:
    if c['container_name']=='nextcloud-aio-eurooffice':
        env=' '.join(c.get('environment',[]))
        print('USE_UNAUTHORIZED_STORAGE=true:', 'USE_UNAUTHORIZED_STORAGE=true' in env)
        print('ALLOW_PRIVATE_IP_ADDRESS=true:', 'ALLOW_PRIVATE_IP_ADDRESS=true' in env)
"

# 2. effective JSON in the running container
podman exec nextcloud-aio-eurooffice bash -lc "python3 -c \"
import json
d=json.load(open('/etc/euro-office/documentserver/local.json'))
co=d['services']['CoAuthoring']
print('rejectUnauthorized:', co['requestDefaults']['rejectUnauthorized'])
print('allowPrivateIPAddress:', co['request-filtering-agent']['allowPrivateIPAddress'])
\""

# 3. containers healthy
podman inspect nextcloud-aio-eurooffice --format '{{.State.Status}} {{.State.Health.Status}}'
podman inspect nextcloud-aio-mastercontainer --format '{{.State.Status}} {{.State.Health.Status}}'
```

Final check: open a document in EuroOffice and save it.

## Caveats

- The `containers.json` patch is lost when the **mastercontainer is recreated** - re-run `~/.local/bin/nextcloud-aio-podman-fix.sh` afterwards (the systemd user service `nextcloud-aio-podman-fix.service` already does this at each session start).
- Disabling `rejectUnauthorized` is acceptable only for a **local-only** instance with a self-signed certificate. If this setup ever moves to a public domain with a real Let's Encrypt certificate, the vars can be removed again (and local.json edits reverted) so TLS verification stays enabled.
- The unrelated Talk **standalone-signaling** server-side requests to `https://nextcloud.local` show the same `CERTIFICATE_VERIFY_FAILED` errors in `nextcloud.log`; that is a separate issue, not covered here.
