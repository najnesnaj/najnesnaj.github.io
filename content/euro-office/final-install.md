# Euro-Office Installation Summary

## Users and Passwords

### Nextcloud
| Setting | Value |
|---------|-------|
| Admin username | `admin` |
| Admin password | `nextcloud-admin-pw` |
| Database type | PostgreSQL |
| Database name | `nextcloud` |
| Database host | `nextcloud-db` |
| Database user | `nextcloud` |
| Database password | `nextcloud-secret` |

### Euro-Office Document Server
| Setting | Value |
|---------|-------|
| JWT secret | `euro-office-jwt-secret-at-least-32-chars` |
| Internal DB type | PostgreSQL (built-in, localhost) |
| Internal DB name | `eurooffice` |
| Internal DB user | `eurooffice` |
| Internal DB password | `eurooffice` |
| Storage secret | `mWrmSfMffVigfbZQdGJq` |

### Euro-Office Nextcloud App Configuration
| Setting | Value |
|---------|-------|
| DocumentServerUrl | `http://host.docker.internal:8081/` |
| StorageUrl | `http://host.docker.internal/` |
| jwt_secret | `euro-office-jwt-secret-at-least-32-chars` |
| sameTab | `false` |
| enableSharing | `true` |
| preview | `true` |

### Nextcloud System Config
| Setting | Value |
|---------|-------|
| trusted_domains | `localhost`, `host.docker.internal`, `192.168.0.114` |
| overwriteprotocol | `http` |
| overwritehost | `host.docker.internal` |
| overwritewebroot | `/` |

### Credentials from install_office.md (Nextcloud AIO - stopped)
| Setting | Value |
|---------|-------|
| AIO Passphrase | `uncross shiny divisibly trading dig marbling crablike astronaut` |
| AIO Admin user | `admin` |
| AIO Admin password | `36273f71761aca7672b1f5619465b768f7c848018dc377a9` |
| deSEC email | `najnesnaj@yahoo.com` |
| deSEC password | `5acab4f9d6b1919c5444edf8c094585e8d609daa4d9ce95b` |
| Domain | `euro-office.dedyn.io` |

## Running Containers

| Container | Image | Port | Status |
|-----------|-------|------|--------|
| `euro-office` | `ghcr.io/euro-office/documentserver:latest` | `0.0.0.0:8081->80/tcp` | Up |
| `nextcloud` | `quay.io/linuxserver.io/nextcloud:latest` | `0.0.0.0:80->80/tcp` | Up |
| `nextcloud-db` | `quay.io/fedora/postgresql-16:latest` | internal | Up |

## Modifications Made

### 1. Podman systemd socket enabled
```bash
systemctl --user enable --now podman.socket
```

### 2. Nextcloud AIO container (replaced)
The Nextcloud AIO container (`ghcr.io/nextcloud-releases/all-in-one:latest`) was stopped and removed due to Docker API version incompatibility with Podman (v1.41 vs required v1.44).

### 3. Docker.io registry authentication issue
Docker Hub was rate-limiting pulls. Switched to alternative registries:
- PostgreSQL: `quay.io/fedora/postgresql-16:latest`
- Nextcloud: `quay.io/linuxserver.io/nextcloud:latest`

### 4. Podman network created
```bash
podman network create nextcloud-net
```

### 5. Nextcloud + PostgreSQL stack
- PostgreSQL container `nextcloud-db` connected to `nextcloud-net`
- Nextcloud container `nextcloud` connected to `nextcloud-net`, port 80

### 6. Nextcloud installation completed via occ
```bash
php /app/www/public/occ maintenance:install \
  --database=pgsql \
  --database-host=nextcloud-db \
  --database-name=nextcloud \
  --database-user=nextcloud \
  --database-pass=nextcloud-secret \
  --admin-user=admin \
  --admin-pass=nextcloud-admin-pw
```

### 7. Missing PHP extensions installed in Nextcloud container
```bash
apk add php83-posix php83-pdo php83-pdo_pgsql php83-pgsql
apk add php83-simplexml php83-ctype php83-curl php83-dom php83-gd php83-gmp \
       php83-intl php83-json php83-mbstring php83-openssl php83-session \
       php83-xml php83-xmlreader php83-xmlwriter php83-zip
```

### 8. PHP memory limit increased in Nextcloud container
```ini
memory_limit = 512M
```

### 9. Data directory fix in Nextcloud container
```bash
echo "# Nextcloud data directory" > /data/.ncdata
echo "# Nextcloud data directory" > /data/.ocdata
```

### 10. Euro-office document server container
- Image: `ghcr.io/euro-office/documentserver:latest`
- Port: 8081
- JWT enabled

### 11. Document server local.json config updated
Added `request-filtering-agent` section to allow private IP addresses:
```json
"request-filtering-agent": {
    "allowPrivateIPAddress": true,
    "allowMetaIPAddress": true
}
```

### 12. Euro-office Nextcloud app installed
```bash
git clone --recursive https://github.com/Euro-Office/eurooffice-nextcloud.git
npm install && npm run build
composer install --no-dev
php /app/www/public/occ app:enable eurooffice
```

### 13. Euro-office app configured via occ
```bash
occ config:app:set eurooffice DocumentServerUrl --value="http://host.docker.internal:8081/"
occ config:app:set eurooffice StorageUrl --value="http://host.docker.internal/"
occ config:app:set eurooffice jwt_secret --value="euro-office-jwt-secret-at-least-32-chars"
occ config:app:set eurooffice sameTab --value="false"
occ config:app:set eurooffice enableSharing --value="true"
occ config:app:set eurooffice preview --value="true"
```

### 14. Nextcloud trusted domains and overwrite settings
```bash
occ config:system:set trusted_domains 0 --value=localhost
occ config:system:set trusted_domains 1 --value=host.docker.internal
occ config:system:set trusted_domains 2 --value=192.168.0.114
occ config:system:set overwriteprotocol --value=http
occ config:system:set overwritehost --value=host.docker.internal
occ config:system:set overwritewebroot --value=/
```

## Verification

```bash
# Document server healthcheck
curl http://localhost:8081/healthcheck
# → true

# Nextcloud connection check
php /app/www/public/occ eurooffice:documentserver --check
# → Document server http://host.docker.internal:8081/ version 9.3.1.37 is successfully connected
```
