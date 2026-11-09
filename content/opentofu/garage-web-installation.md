# Garage Web UI installation steps, LXC 107

**Status:** installed and verified on 2026-11-03.

**Scope:** how the Garage Web UI was installed on the Garage backup LXC, so
that the same steps can be repeated after a rebuild of CT 107
(reachable as `192.168.0.224` from the management host, `10.10.50.2` from the
Kubernetes network). The reference copies of the unit and env file live in
[`ansible2/files/backup/`](ansible2/files/backup/README.md); the operational
background is in [`backup.md`](backup.md).

Garage v2.5 itself ships no admin interface (the official one is still being
developed under the NLnet grant), so the community UI
[`garage-webui`](https://github.com/khairul169/garage-webui) v1.1.0 runs as a
second systemd unit next to `garage.service`. It talks only HTTP to the Garage
admin API on `127.0.0.1:3903` and requires no extra port on the Garage side.

---

## 1. Prerequisites

* Garage is up: `systemctl is-active garage.service` on
  `root@192.168.0.224` reports `active`.
* `/etc/garage.toml` exists with the admin API bound to
  `127.0.0.1:3903` and holds `admin_token`/`metrics_token`.
* The LXC has outbound HTTPS (DNS pointing at `192.168.0.1` / `1.1.1.1` is
  already configured by `/usr/local/sbin/garage-net-init`).
* LXC entrypoint quirk: excessive/parallel SSH sessions hang; use one
  connection at a time, or `ControlMaster`/`ControlPersist` multiplexing.

---

## 2. Install the binary

```bash
ssh root@192.168.0.224
wget -q -O /tmp/garage-webui \
  https://github.com/khairul169/garage-webui/releases/download/1.1.0/garage-webui-v1.1.0-linux-amd64
chmod +x /tmp/garage-webui
mv /tmp/garage-webui /usr/local/bin/garage-webui
```

Notes:

* Arch is amd64; CT 107 is `x86_64`.
* Do **not** test-launch it in the shell (`garage-webui` alone or with
  `--version` starts a server on port 3909 in the foreground). A forgotten
  instance keeps the port occupied and later makes the systemd service
  crash-loop with `bind: address already in use`. Check with
  `ps auxww | grep garage-webui` and kill leftovers before `systemctl` start.

---

## 3. Generate the login password

`apache2-utils` must be available on the LXC (installed for this purpose):

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2-utils
htpasswd -nbBC 10 admin 'CHANGE-ME'
# admin:$2y$10$...
```

Two format details that matter:

1. The UI expects `AUTH_USER_PASS=user:$hash`, username field `admin`,
   bcrypt cost 10.
2. Go's bcrypt library accepts only `$2a$` and `$2b$` prefixes, and
   `htpasswd` emits `$2y$`. Those prefixes select the same algorithm; only
   the prefix has to be replaced:

```bash
htpasswd -nbBC 10 admin 'CHANGE-ME' | tr -d '\n' | sed 's/\$2y\$/\$2b\$/'
```

Store the produced line in the password manager before continuing.

---

## 4. Write the env file

`/etc/garage-webui.env` (root-only, mode 0600). The real password hash lives
only on the LXC and in the password manager.

```txt
AUTH_USER_PASS=admin:$2b$10$<...bcrypt hash from step 3...>
PORT=3909
CONFIG_PATH=/etc/garage.toml
```

Systemd specifics learned here:

* `EnvironmentFile=` performs **no** variable expansion: a `$` in the hash is
  written and passed through literally. Do not escape it (`$$` ends up in the
  process environment and breaks the bcrypt check).
* This invalid hash symptom is sneaky: the service runs and serves the UI,
  but `/api/auth/login` always answers `401 invalid username or password`.
  Verify what the process really got:

```bash
p=$(pgrep -f '^/usr/local/bin/garage-webui$')
tr '\0' '\n' < /proc/$p/environ | grep AUTH
```

---

## 5. Write the systemd unit

`/etc/systemd/system/garage-webui.service` (reference copy:
`ansible2/files/backup/garage-webui.service`):

```txt
[Unit]
Description=Garage Web UI (garage-webui)
Documentation=https://github.com/khairul169/garage-webui
After=network.target garage.service

[Service]
Type=simple
User=garage
Group=garage
EnvironmentFile=/etc/garage-webui.env
ExecStart=/usr/local/bin/garage-webui
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Running it as the existing `garage` user avoids an extra user: the webui
needs only read access to `/etc/garage.toml` (`root:garage 640`) and outbound
connectivity to `127.0.0.1:3903`. The Garage admin API itself stays bound to
loopback and is never exposed.

---

## 6. Activate and verify

```bash
chmod 600 /etc/garage-webui.env
chown root:root /etc/garage-webui.env
chmod 644 /etc/systemd/system/garage-webui.service
systemctl daemon-reload
systemctl enable --now garage-webui
systemctl is-active garage-webui

# login page served (200 expected, unauthenticated)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3909/

# admin API access requires a session (401 expected)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3909/api/buckets

# full login round-trip
curl -s -c /tmp/cookies -X POST http://127.0.0.1:3909/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"CHANGE-ME"}'
# {"authenticated":true}
curl -s -b /tmp/cookies http://127.0.0.1:3909/api/buckets
rm -f /tmp/cookies
```

Then from the management host:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://192.168.0.224:3909/
```

Open <http://192.168.0.224:3909>, log in with the password from the password
manager, and confirm the dashboard shows the `velero` and `restic` buckets.

The login request body uses the field names `username`/`password` (not
`user`). The login page at `/` always returns 200/unknown-auth state; only
the `/api/*` routes are behind the cookie session.

---

## 7. Day-2 operations

```bash
# status / restart
ssh root@192.168.0.224 'systemctl status garage-webui --no-pager'
ssh root@192.168.0.224 'systemctl restart garage-webui'

# change the UI password (both commands on the LXC)
htpasswd -nbBC 10 admin 'NEW-PASSWORD' | tr -d '\n' | sed 's/\$2y\$/\$2b\$/'
# edit /etc/garage-webui.env with the new line, then:
systemctl restart garage-webui
```

The UI keeps running while `garage.service` restarts (metadata restore,
bucket work); it shows the cluster again as soon as the admin API answers.
Logs go to the journald instance of the container; a fresh
`journalctl` inside this privileged LXC may report no files, so use
`systemd` status output instead. After a container reboot both Garage and the
web UI start automatically: the unit is `enabled` and `WantedBy=multi-user.target`.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `bind: address already in use`, service `activating`/crash-loop | A manually started instance still holds port 3909 | `ps auxww \| grep garage-webui`, kill the stray, `systemctl restart garage-webui` |
| Login always `401 invalid username or password` although the hash matches | The hash inside the live process was mangled or `$$`-escaped | Check `/proc/$p/environ` (section 4), rewrite the env file, restart |
| Login always `401` with a freshly generated `htpasswd` hash | `$2y$` prefix not understood by Go's bcrypt | Replace the prefix with `$2b$` (section 3) |
| Login always `500 AUTH_USER_PASS not set` | Env file not picked up (syntax or path) | `systemctl show garage-webui --property=EnvironmentFiles`, check `/proc/$p/environ` |
| UI up but buckets empty / API errors | Admin API token or admin bind changed | Recheck `/etc/garage.toml` (`[admin] api_bind_addr`, `admin_token`) and restart the webui |

---

## 9. Rebuild-from-scratch checklist

1. Recreate CT 107 per [`backup.md`](backup.md) sections 3-5 (network
   entrypoint, `/etc/garage.toml`, `/etc/garage.env`, `garage.service`,
   metadata timer) and restore the metadata database.
2. Install `apache2-utils`, generate a new bcrypt password line, store it in
   the password manager.
3. Download the binary (section 2), write the env file (section 4), write the
   unit from `ansible2/files/backup/garage-webui.service`, activate and verify
   (section 6).
4. Re-run the quick verification in [`backup.md`](backup.md) Appendix C.
