# Renew Garage Web UI password

Use this procedure when the Garage Web UI login returns
`401 invalid username or password`.

## 1. Generate a new bcrypt hash

```bash
htpasswd -nbBC 10 admin 'NEW-PASSWORD' | tr -d '\n' | sed 's/\$2y\$/\$2b\$/'
```

Go's bcrypt implementation requires the `$2b$` prefix. If `htpasswd` emits
`$2y$`, replace that prefix.

## 2. Update the env file

Edit `/etc/garage-webui.env` on LXC 107. Keep the `$` characters unescaped;
systemd's `EnvironmentFile=` does not expand variables.

```text
PORT=3909
CONFIG_PATH=/etc/garage.toml
AUTH_USER_PASS=admin:$2b$10$...
```

Do not add `$$`; that would be passed literally and break authentication.

## 3. Restart the service

```bash
systemctl restart garage-webui
```

## 4. Test the login

```bash
curl -s -i -X POST http://127.0.0.1:3909/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"NEW-PASSWORD"}'
```

A successful login returns `{"authenticated":true}`.

## 5. Verify the live process

```bash
p=$(pgrep -f '^/usr/local/bin/garage-webui$')
tr '\0' '\n' < /proc/$p/environ | grep '^AUTH_USER_PASS='
cat -A /etc/garage-webui.env
```

The value from `/proc/$p/environ` must exactly match the value in
`/etc/garage-webui.env`. Also check for trailing spaces or CR characters.