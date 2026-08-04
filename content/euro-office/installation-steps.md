<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Nextcloud All-in-One installation steps (with Podman)

This document records the steps performed to install [Nextcloud All-in-One](https://github.com/nextcloud/all-in-one) using **Podman** instead of Docker on this host. The Podman and local-only fixes applied here are summarized in [local-nextcloud-fixes.md](./local-nextcloud-fixes.md).

## Environment

- OS: Linux Mint 22.3 (Ubuntu 24.04 based), kernel 7.0.0
- User: `naj` (uid/gid 1000), member of the `sudo` group
- Podman: `4.9.3` (rootless, cgroups v2, `systemd` cgroup manager, `netavark` network backend)
- Conmon: `2.1.10`, crun: `1.14.1`
- Host LAN IP: `192.168.0.114`

> [!NOTE]
> Podman is not an officially supported container engine for Nextcloud AIO (see the AIO README). This installation follows the community guide [Rootless Podman Quadlet](https://github.com/nextcloud/all-in-one/discussions/3487) and works for the core stack. The built-in Borg backup and automatic mastercontainer self-update are not expected to work under rootless Podman.

## 0. Prerequisites

1. Podman must be installed and running rootless. Verify with:
   ```sh
   podman info
   ```
   A rootless setup with cgroups v2 is required (check `podman info | grep -A2 networkBackend` shows `netavark`).

2. Check that no other service uses ports `80`, `8080` or `8443`:
   ```sh
   ss -tlnp | grep -E ':(80|8080|8443) '
   ```

3. Make sure the Podman API socket is enabled and active (it provides the Docker-compatible API that AIO requires):
   ```sh
   systemctl --user enable --now podman.socket
   systemctl --user is-active podman.socket
   ```
   The socket path is reported by:
   ```sh
   podman info --format '{{ .Host.RemoteSocket.Path }}'
   ```
   Expected: `/run/user/1000/podman/podman.sock`

4. Enable the user service that restarts containers with `--restart always`:
   ```sh
   systemctl --user enable podman-restart.service
   systemctl --user start podman-restart.service
   ```

5. Pull the mastercontainer image:
   ```sh
   podman pull ghcr.io/nextcloud-releases/all-in-one:latest
   ```

## 1. Fix the Podman socket permissions

AIO's `www-data` user inside the mastercontainer must be able to talk to the container engine socket. The podman socket unit already declares `SocketMode=0660`, but the running socket had been created with mode `0600`, which broke the check in `Containers/mastercontainer/start.sh`. Restart the socket so it is recreated with the correct group-read/write mode:

```sh
systemctl --user restart podman.socket
```

Verify:
```sh
ls -la /run/user/1000/podman/podman.sock
# expected: srw-rw---- 1 naj naj ... podman.sock
```

Optional (persists across reboots): because the socket file is recreated on socket start, you may want to ensure the mode stays `0660` by confirming the socket unit:
```sh
cat /usr/lib/systemd/user/podman.socket   # contains SocketMode=0660
```

## 2. Create and start the mastercontainer

The standard `docker run` command from the AIO README, adapted for Podman:

- the Docker socket mount is replaced with the Podman socket
- `WATCHTOWER_DOCKER_SOCKET_PATH` points to the podman socket
- `DOCKER_API_VERSION=1.41` is required because Podman 4.9.3 exposes Docker API `v1.41`, while AIO defaults to `v1.44` and refuses to start otherwise
- `--network bridge` is needed so AIO can create and attach sibling containers to the `nextcloud-aio` network (rootless `slirp4netns` does not support `podman network connect`)
- `SKIP_DOMAIN_VALIDATION=true` is set because this is a **local-only** instance: no internet link is wanted, so the domain is not validated against the public DNS

```sh
podman run -d \
  --init \
  --sig-proxy=false \
  --name nextcloud-aio-mastercontainer \
  --restart always \
  --network bridge \
  --publish 80:80 \
  --publish 8080:8080 \
  --publish 8443:8443 \
  --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
  --volume /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro \
  --env WATCHTOWER_DOCKER_SOCKET_PATH=/var/run/docker.sock \
  --env DOCKER_API_VERSION=1.41 \
  --env SKIP_DOMAIN_VALIDATION=true \
  ghcr.io/nextcloud-releases/all-in-one:latest
```

> [!IMPORTANT]
> Do not change the container name `nextcloud-aio-mastercontainer` or the volume name `nextcloud_aio_mastercontainer` - both are required for AIO to work.

## 3. Verify the installation

```sh
podman ps -a | grep nextcloud-aio-mastercontainer
# STATUS should be "Up (healthy)"

podman logs nextcloud-aio-mastercontainer | tail -10
# should end with: "fpm is running" / "ready to handle connections"
```

Check the HTTP endpoints:
```sh
curl -sk -o /dev/null -w "interface: %{http_code}\n" https://localhost:8080
curl -s -o /dev/null -w "port 80: %{http_code}\n" http://localhost:80
```

## 4. Complete the setup in the browser

1. Open the AIO interface using the **IP address** (never a domain, to avoid HSTS issues):
   ```
   https://192.168.0.114:8080
   ```
2. Accept the self-signed certificate warning.
3. In the AIO interface, when asked for your domain: since `SKIP_DOMAIN_VALIDATION=true` is set, the interface shows **"domain validation is disabled so any domain will be accepted here"** and no internet/DNS check is performed. Use a local-only name (e.g. `nextcloud.local` or the machine's hostname) — it does not need to resolve publicly.
4. Enter your email address and create the AIO interface password.
5. Select the containers you want (Nextcloud, Database, Redis and Apache are required; optionally Collabora, Talk, etc.) and click **Start containers**.
6. Wait until the AIO interface reports the containers as running, then click the button to open your Nextcloud instance and set up your admin account.

> [!NOTE]
> Local-only access caveats:
> - No valid certificate can be issued for a LAN-only domain, so the Nextcloud page uses a self-signed certificate (issued by Caddy's internal CA, see section 4b) — accept the browser warning, or access it via a reverse proxy that terminates TLS locally (see the [reverse proxy docs](./reverse-proxy.md)).
> - To resolve your chosen domain on LAN clients, add it to the local DNS server or to the `/etc/hosts` of the clients (or use the AIO [dnsmasq](https://github.com/nextcloud/all-in-one/tree/main/community-containers/dnsmasq) / [pi-hole](https://github.com/nextcloud/all-in-one/tree/main/community-containers/pi-hole) community containers).

If you enable Nextcloud Talk, open ports `3478/TCP` and `3478/UDP` in the firewall/router.

> [!IMPORTANT]
> Before entering your domain, apply the port-443 fix from section 4a below, otherwise the **domaincheck** container (and later the **apache** container) will fail to start.

### 4a. Required fix: allow non-root containers to bind port 443

The AIO domaincheck and apache containers run as the non-root user `www-data` and bind host port `443`. Docker grants non-root processes `CAP_NET_BIND_SERVICE`, but **Podman grants no effective capabilities to non-root users by default**. The result is:

```
nextcloud-aio-domaincheck: (lighttpd) bind() [::]:443: Permission denied
```

(Note: setting `net.ipv4.ip_unprivileged_port_start=80` via `default_sysctls` in `containers.conf` does **not** work here - the Podman Docker-API compatibility path ignores `default_sysctls` for containers created by the mastercontainer.)

Fix: make the mastercontainer add `CAP_NET_BIND_SERVICE` to the domaincheck and apache containers. The container definitions in `containers.json` support a `cap_add` field which the mastercontainer forwards into the container-create request. Since `start.sh` refuses to start if `containers.json` is bind-mounted, patch the file inside the running mastercontainer instead (it lives in the container's writable layer and survives `podman restart`).

A helper script handles this automatically (idempotent; restarts the mastercontainer only when a change was made):

```sh
~/.local/bin/nextcloud-aio-podman-fix.sh
```

The script is installed as an enabled systemd user service so it also runs at every session start:

```sh
~/.config/systemd/user/nextcloud-aio-podman-fix.service
systemctl --user status nextcloud-aio-podman-fix.service
```

What the script does (equivalent manual steps):

```sh
# 1. add "cap_add": ["NET_BIND_SERVICE"] to the entries of
#    nextcloud-aio-domaincheck and nextcloud-aio-apache, and (since the
#    local-only TLS fix of section 4b) a bind mount of
#    /home/naj/aio-config/Caddyfile:/Caddyfile:ro to nextcloud-aio-apache,
#    all inside containers.json in the mastercontainer
podman exec nextcloud-aio-mastercontainer python3 - <<'PYEOF'
import json
path = '/var/www/docker-aio/php/containers.json'
data = json.load(open(path))
for c in data['aio_services_v1']:
    if c.get('container_name') in ('nextcloud-aio-domaincheck', 'nextcloud-aio-apache'):
        c.setdefault('cap_add', []).insert(0, 'NET_BIND_SERVICE')
    if c.get('container_name') == 'nextcloud-aio-apache':
        c.setdefault('volumes', []).append({
            'source': '/home/naj/aio-config/Caddyfile',
            'destination': '/Caddyfile',
            'writeable': False,
        })
json.dump(data, open(path, 'w'), indent=2)
PYEOF

# 2. restart the mastercontainer so the containers.json cache is cleared
podman restart nextcloud-aio-mastercontainer
```

> [!WARNING]
> The patch is lost when the mastercontainer container is **recreated** (`podman rm -f` + `podman run`, e.g. when updating per section 5). Re-run `~/.local/bin/nextcloud-aio-podman-fix.sh` afterwards.

To re-trigger the domaincheck after the fix (it is started on every load of the `/containers` page while no domain is set):

```sh
podman rm -f nextcloud-aio-domaincheck
# then load https://192.168.0.114:8080/containers (or re-submit the domain in the interface)
```

### 4b. Required fix for local-only setups: self-signed TLS (Caddy internal CA)

With a LAN-only domain like `nextcloud.local` the apache container's TLS endpoint (Caddy) tries to obtain a **Let's Encrypt** certificate via ACME. A `.local` name can never get a public certificate, so Caddy never issues one and fails the TLS handshake instead of falling back:

```
{"level":"error","logger":"tls.obtain","msg":"will retry",
 "error":"[nextcloud.local] Obtain: subject 'nextcloud.local' does not qualify for a public certificate", ...}
```

In the browser this shows as **`SSL_ERROR_INTERNAL_ERROR_ALERT`** (or `ERR_SSL_PROTOCOL_ERROR`).

Fix: make the apache container use Caddy's **internal CA** (`tls internal`), which issues a self-signed certificate valid for the configured domain. The Caddyfile template lives in the image at `/Caddyfile` and is rendered by `Containers/apache/start.sh`, so the fix is to bind-mount a custom template over it.

1. Create a custom Caddyfile template (a copy of the image's `/Caddyfile`) with the ACME issuer block replaced by the internal issuer:
   ```sh
   podman exec nextcloud-aio-apache cat /Caddyfile \
     | sed 's|issuer acme {|issuer internal {|; s|profile tlsserver||; s|disable_http_challenge||' \
     > /home/naj/aio-config/Caddyfile
   # keep the generated file stable - it is a template that start.sh post-processes
   # (lines "auto_https ...", "# trusted_proxies placeholder" and
   # "https://{$ADDITIONAL_TRUSTED_DOMAIN}:443," must stay intact)
   ```
   The helper script already ships a correct copy at `/home/naj/aio-config/Caddyfile` (the `tls` block reads `tls { issuer internal }`).

2. The fix script `~/.local/bin/nextcloud-aio-podman-fix.sh` additionally adds a read-only bind mount `/home/naj/aio-config/Caddyfile:/Caddyfile:ro` to the apache container definition in `containers.json` (same place as the `cap_add` patch). Run it:
   ```sh
   ~/.local/bin/nextcloud-aio-podman-fix.sh
   ```

3. Recreate the apache container so it is started with the new bind mount. In the AIO interface click **Stop containers** then **Start containers**. (Note: password login to the AIO interface is **blocked while the apache container runs** - that is how this was applied below. Alternatively remove apache first to unlock the login: `podman rm -f nextcloud-aio-apache`.)

4. Afterwards the certificate is issued by `Caddy Local Authority - ECC Intermediate` and the handshake succeeds; the browser shows a normal self-signed-certificate warning which you accept. Verify:
   ```sh
   echo | openssl s_client -connect nextcloud.local:443 -servername nextcloud.local 2>/dev/null | grep -i 'verify return code'
   ```

> [!IMPORTANT]
> After the apache container is recreated its IP in the `nextcloud-aio` bridge network **changes**. The Nextcloud container only allows php-fpm connections from the apache IP recorded at its own start (`listen.allowed_clients`), so you get HTTP `503` and log lines like `Connection disallowed: IP address '10.89.3.23' has been dropped.` Fix by restarting Nextcloud so it recomputes the allowed list with the current apache IP:
> ```sh
> podman restart nextcloud-aio-nextcloud
> ```
> This happens on every apache recreation (e.g. after a mastercontainer update that recreates all containers together; then a single restart of Nextcloud suffices).

> [!NOTE]
> If you later switch to a public domain, remove the bind mount (and the `tls internal` template) again so real Let's Encrypt certificates can be issued.

## 5. Management

- Start/stop:
  ```sh
  podman start nextcloud-aio-mastercontainer
  podman stop nextcloud-aio-mastercontainer
  ```
- View logs:
  ```sh
  podman logs -f nextcloud-aio-mastercontainer
  ```
- Update the mastercontainer manually (self-update via Watchtower is not expected to work with rootless Podman):
  ```sh
  podman rm -f nextcloud-aio-mastercontainer
  podman pull ghcr.io/nextcloud-releases/all-in-one:latest
  # then re-run the podman run command from section 2
  ```
- Restart all AIO containers:
  ```sh
  podman ps -a -f 'name=^nextcloud-aio' --format='{{.Names}}' | xargs podman restart
  ```

## 6. Persistence across reboots

- The mastercontainer has `--restart always`, which Podman honors via `podman-restart.service` while the user session runs.
- To have containers start even without an active login session, enable user linger (requires sudo, run interactively):
  ```sh
  sudo loginctl enable-linger naj
  ```

## Troubleshooting

- **"Docker socket is not readable by the www-data user"**: the podman socket was created with mode `0600`. Fix with `systemctl --user restart podman.socket` (unit sets `SocketMode=0660`) and restart the mastercontainer.
- **"Docker API v1.44 is not supported by your docker engine"**: Podman exposes a lower Docker API version. Set `--env DOCKER_API_VERSION=1.41` and recreate the mastercontainer. Check the supported version with:
  ```sh
  curl -s --unix-socket /run/user/1000/podman/podman.sock -D - -o /dev/null http://localhost/_ping | grep -i '^Api-Version'
  ```
- **Network-related failures when starting sibling containers**: ensure the mastercontainer runs with `--network bridge` so AIO can attach containers to its `nextcloud-aio` network.
- **"Domaincheck container is not running" / `bind() [::]:443: Permission denied`**: see section 4a. Podman does not give non-root container users effective capabilities, so `www-data` cannot bind port 443. Fix by adding `CAP_NET_BIND_SERVICE` to the domaincheck and apache container definitions (`~/.local/bin/nextcloud-aio-podman-fix.sh`). Re-run the fix after recreating the mastercontainer.
- **`SSL_ERROR_INTERNAL_ERROR_ALERT` / `ERR_SSL_PROTOCOL_ERROR` on `https://nextcloud.local`**: see section 4b. Caddy tries ACME for the local-only domain and cannot issue a certificate. Switch the apache container's Caddy to `tls internal` by bind-mounting `/home/naj/aio-config/Caddyfile:/Caddyfile:ro` (done by the fix script), then recreate the apache container.
- **HTTP 503 with `Connection disallowed: IP address '10.89.x.y' has been dropped.` in the Nextcloud logs**: the apache container was recreated and got a new bridge-network IP that is not in php-fpm's `listen.allowed_clients`. Run `podman restart nextcloud-aio-nextcloud`.
