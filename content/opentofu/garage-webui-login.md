# Garage Web UI login troubleshooting

## Correct URL

The Garage Web UI is served from the root path:

```text
http://192.168.0.224:3909/
```

Do not use `http://192.168.0.224:3909/auth/login` for the browser login page.

The login API endpoint is:

```text
POST http://192.168.0.224:3909/api/auth/login
```

with this JSON body:

```json
{"username":"admin","password":"YOUR-PASSWORD"}
```

## Diagnostics

Run these commands on LXC 107:

```bash
ssh root@192.168.0.224
systemctl status garage-webui --no-pager
p=$(pgrep -f '^/usr/local/bin/garage-webui$')
tr '\0' '\n' < /proc/$p/environ | grep '^AUTH_USER_PASS='
curl -s -i -X POST http://127.0.0.1:3909/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"YOUR-PASSWORD"}'
```

## Common causes

- The browser is opened at `/auth/login` instead of `/`.
- The bcrypt hash still starts with `$2y$`; Go bcrypt needs `$2b$`.
- The env file contains `$$` instead of `$`, so the running process received a
  mangled hash.
- `AUTH_USER_PASS` is missing or malformed, which produces
  `500 AUTH_USER_PASS not set`.
- The password used at login is not the same password used to generate the
  hash.

## Reset the password

Generate a new hash for a known password:

```bash
htpasswd -nbBC 10 admin 'NEW-PASSWORD' | tr -d '\n' | sed 's/\$2y\$/\$2b\$/'
```

Then replace the `AUTH_USER_PASS` line in `/etc/garage-webui.env` with the
generated value, without escaping `$`:

```text
AUTH_USER_PASS=admin:$2b$10$...
```

Restart the service:

```bash
systemctl restart garage-webui
```

Test with the same `NEW-PASSWORD`:

```bash
curl -s -i -X POST http://127.0.0.1:3909/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"NEW-PASSWORD"}'
```

## Verify the live process

```bash
p=$(pgrep -f '^/usr/local/bin/garage-webui$')
tr '\0' '\n' < /proc/$p/environ | grep '^AUTH_USER_PASS='
```

The value shown here must exactly match the line in
`/etc/garage-webui.env`. Also check for trailing spaces or CR characters:

```bash
cat -A /etc/garage-webui.env