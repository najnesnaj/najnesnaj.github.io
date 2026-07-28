# Euro-Office Installation Guide

This document provides detailed instructions for deploying Euro-Office, a self-hostable office suite consisting of a document server and Nextcloud integration.

## Table of Contents

- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
  - [Docker Installation](#docker-installation)
  - [Ubuntu Installation](#ubuntu-installation)
  - [Fedora Installation](#fedora-installation)
- [Nextcloud App Installation](#nextcloud-app-installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Overview

Euro-Office consists of two main components:

1. **Document Server** - Real-time collaboration server for office documents
2. **Nextcloud App** - Integration layer for Nextcloud

## System Requirements

### Document Server

| Requirement | Specification |
|-------------|---------------|
| **RAM** | 4 GB minimum |
| **Disk Space** | 10 GB minimum |
| **Supported Platforms** | Ubuntu 24.04 LTS, Debian 12, Fedora 41+, Docker |

### Nextcloud Server

- Nextcloud 25 or later
- PHP 8.0+
- PostgreSQL or MySQL database

## Installation Methods

### Docker Installation

**Prerequisites:**
- Docker Engine 20.10 or later
- 5 GB disk space for the image
- 4 GB RAM minimum

**Quick Start:**

```bash
docker run -d \
  --name euro-office \
  --restart=unless-stopped \
  -p 80:80 \
  -e JWT_ENABLED=true \
  -e JWT_SECRET=at-least-32-chars-long-for-hs256 \
  ghcr.io/euro-office/documentserver:latest
```

**Verify Installation:**

```bash
curl http://localhost/healthcheck
```

**Persistent Data:**

```bash
docker run -d \
  --name euro-office \
  --restart=unless-stopped \
  -p 80:80 \
  -e JWT_ENABLED=true \
  -e JWT_SECRET=at-least-32-chars-long-for-hs256 \
  -v /path/to/data:/var/lib/euro-office/documentserver \
  -v /path/to/logs:/var/log/euro-office/documentserver \
  -v /path/to/config:/etc/euro-office/documentserver \
  ghcr.io/euro-office/documentserver:latest
```

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_ENABLED` | `true` | Enable JWT authentication |
| `JWT_SECRET` | — | Shared secret for JWT |
| `JWT_HEADER` | `Authorization` | HTTP header carrying the JWT |
| `EXAMPLE_ENABLED` | `false` | Enable built-in example app |
| `WOPI_ENABLED` | `false` | Enable WOPI protocol support |

### Ubuntu Installation

**Step 1 — Install Prerequisites:**

```bash
sudo apt-get update
sudo apt-get install -y postgresql redis-server rabbitmq-server nginx supervisor
```

**Step 2 — Create Database:**

```bash
sudo -u postgres psql -c "CREATE USER ds WITH PASSWORD 'ds';"
sudo -u postgres psql -c "CREATE DATABASE ds OWNER ds;"
```

**Step 3 — Pre-seed Installer Answers:**

```bash
echo "ds ds/db-type select postgres
ds ds/db-host string localhost
ds ds/db-port string 5432
ds ds/db-user string ds
ds ds/db-pwd password ds
ds ds/db-name string ds" | sudo debconf-set-selections
```

**Step 4 — Download Package:**

Replace `<version>` and `<arch>` with your values (e.g., `9.3.1-rc.1` and `amd64` or `arm64`):

```bash
wget "https://github.com/Euro-Office/DocumentServer/releases/download/v<version>/euro-office-documentserver_<version>_<arch>.deb" \
  -O /tmp/euro-office-documentserver.deb
```

**Step 5 — Install Package:**

```bash
sudo apt-get install -y /tmp/euro-office-documentserver.deb
```

**Step 6 — Verify:**

```bash
systemctl is-active ds-docservice ds-converter ds-metrics nginx
curl http://localhost/healthcheck
```

### Fedora Installation

**Step 1 — Install Prerequisites:**

```bash
sudo dnf install -y \
  postgresql-server postgresql postgresql-contrib \
  valkey \
  rabbitmq-server \
  nginx \
  supervisor

sudo postgresql-setup --initdb
sudo systemctl enable --now postgresql valkey rabbitmq-server nginx supervisor
```

**Step 2 — Configure PostgreSQL Authentication:**

Edit `/var/lib/pgsql/data/pg_hba.conf` and change `ident` to `md5` on the `127.0.0.1` and `::1` lines.

**Step 3 — Create Database:**

```bash
sudo -u postgres psql -c "CREATE USER ds WITH PASSWORD 'ds';"
sudo -u postgres psql -c "CREATE DATABASE ds OWNER ds;"
```

**Step 4 — Download Package:**

```bash
wget "https://github.com/Euro-Office/DocumentServer/releases/download/v<version>/euro-office-documentserver-<version>.x86_64.rpm" \
  -O /tmp/euro-office-documentserver.rpm
```

**Step 5 — Install Package:**

```bash
sudo rpm -ivh --nodeps /tmp/euro-office-documentserver.rpm
```

**Step 6 — Initialize Database Schema:**

```bash
sudo -u postgres psql -d ds \
  -f /var/www/onlyoffice/documentserver/server/schema/postgresql/createdb.sql

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ds;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ds;"
```

**Step 7 — Fix nginx Configuration:**

Edit `/etc/nginx/nginx.conf` and:
1. Remove or comment out `include /etc/nginx/conf.d/*.conf;` in the `http {}` block
2. Comment out the default `server {}` block listening on port 80

**Step 8 — Install OpenSSL and Generate Caches:**

```bash
sudo dnf install -y openssl
sudo /usr/bin/documentserver-flush-cache.sh
```

**Step 9 — Configure JWT Authentication:**

Create `/etc/euro-office/documentserver/local.json` with your JWT secret.

**Step 10 — Start Services:**

```bash
sudo systemctl enable --now ds-docservice ds-converter ds-metrics
```

## Nextcloud App Installation

**Step 1 — Navigate to Nextcloud Apps Directory:**

```bash
cd /path/to/nextcloud/apps/
```

**Step 2 — Clone Repository:**

```bash
git clone https://github.com/Euro-Office/eurooffice-nextcloud.git eurooffice
cd eurooffice
git submodule update --init --recursive
```

**Step 3 — Build Frontend Assets:**

```bash
npm install
npm run build
```

**Step 4 — Install Composer Dependencies:**

```bash
composer install
```

**Step 5 — Set Permissions:**

```bash
chown -R www-data:www-data eurooffice
```

**Step 6 — Enable in Nextcloud:**

1. Open Nextcloud admin panel
2. Navigate to Settings → Apps → Disabled apps
3. Find **Euro-Office** and click **Enable**

## Configuration

### Via Nextcloud Admin UI

1. Open Settings → Admin → Euro-Office
2. Enter Document Server URL: `https://<documentserver>/`
3. Configure JWT secret (must match Document Server)

### Via occ Command

```bash
php occ config:app:set eurooffice DocumentServerUrl --value="https://<documentserver>/"
php occ config:app:set eurooffice jwt_secret --value="your_secret_key"
```

### Via config.php

Add to `config/config.php`:

```php
"eurooffice" => array (
    "DocumentServerUrl" => "https://<documentserver>/",
    "jwt_secret" => "your_secret_key",
)
```

### Key Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `DocumentServerUrl` | Document Server address | `https://doc.example.com/` |
| `jwt_secret` | JWT secret key | `your_secret_key` |
| `sameTab` | Open in same tab | `false` |
| `enableSharing` | Enable file sharing | `true` |
| `preview` | Use for previews | `true` |

## Verification

**Check Connection:**

```bash
occ eurooffice:documentserver --check
```

**Test with Example App (Docker):**

```bash
docker run -d \
  --name euro-office-test \
  -p 8080:80 \
  -e JWT_ENABLED=true \
  -e JWT_SECRET=test_secret \
  -e EXAMPLE_ENABLED=true \
  ghcr.io/euro-office/documentserver:latest
```

Open `http://localhost:8080/example/` in browser.

## Troubleshooting

### Self-Signed Certificates

If using self-signed certificates, either:

1. Check **Disable certificate verification** in Nextcloud admin panel, or

2. Add to `config/config.php`:
   ```php
   "eurooffice" => array (
       "verify_peer_off" => true
   )
   ```

### Editors Not Opening

If editors stop working after initial success:

1. Check network settings and SSL certificates
2. Verify Document Server is running:
   ```bash
   systemctl is-active ds-docservice ds-converter ds-metrics nginx
   ```

### Connection Check Interval

Modify the background check interval in `config/config.php`:

```php
"eurooffice" => array (
    "editors_check_interval" => 3624  // in seconds
)
```

Set to `0` to disable.

## Additional Resources

- [Euro-Office Documentation](https://euro-office.github.io/documentation/)
- [Nextcloud App Repository](https://github.com/Euro-Office/eurooffice-nextcloud)
- [Document Server Repository](https://github.com/Euro-Office/DocumentServer)
