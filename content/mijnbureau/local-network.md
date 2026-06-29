# Local network access

To access the MijnBureau applications using the local network IP `192.168.0.215`
instead of `127.0.0.1`, the following changes were made:

## Configuration

**`helmfile/environments/demo/mijnbureau.yaml.gotmpl`**
- Changed `global.domain` from `127.0.0.1.sslip.io` to `192.168.0.215.sslip.io`

**`helmfile/environments/demo/mijnbureau.yaml.gotmpl-wsl`**
- Changed `global.domain` from `127.0.0.1.sslip.io` to `192.168.0.215.sslip.io`
- Changed OIDC endpoint URLs from `id.127.0.0.1.sslip.io` to `id.192.168.0.215.sslip.io`

## Cluster setup

**`scripts/kind.sh`**
- Fixed `$DOMAIN` → `$HOMEIP` check so the `-d <IP>` flag works correctly
- Added CoreDNS rewrite rule for `*.${HOMEIP}.sslip.io`
- Run with: `./scripts/kind.sh -d 192.168.0.215`

## Access URLs

After redeploying (`helmfile -e demo apply`), applications are accessible at:

| Service | URL |
|---------|-----|
| Keycloak | https://id.192.168.0.215.sslip.io |
| Nextcloud | https://nextcloud.192.168.0.215.sslip.io |
| Docs | https://docs.192.168.0.215.sslip.io |
| Bureaublad | https://bureaublad.192.168.0.215.sslip.io |

These URLs resolve to `192.168.0.215` via sslip.io DNS.
