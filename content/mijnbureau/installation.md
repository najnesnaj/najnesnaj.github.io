### 1. Prerequisites

- **Podman** (or Docker) + **KIND** (as discussed before)
- **kubectl**
- **Helm** + **Helmfile**
- **mkcert** (for local TLS certificates)
- Git


### 2. Clone the Repository

```bash
git clone https://github.com/MinBZK/mijn-bureau-deploy-demo.git
cd mijn-bureau-deploy-demo
```

### 3. Create a Local KIND Cluster (Recommended for Demo)

The repo includes a convenient script:

```bash
cd scripts
chmod +x kind.sh
./kind.sh
```

This script:
- Creates a KIND cluster named `mijnbureau`
- Sets up NGINX Ingress Controller
- Configures a local registry
- Generates local TLS certs with `mkcert`
- Prepares everything for the demo environment

After it finishes, you should see:
> `Kind cluster ready for use, Execute the following command to install MijnBureau: helmfile -e demo apply --skip-refresh`

### 4. Deploy MijnBureau with Helmfile

cp mijnbureau.yaml.gotmpl to environments/demo 


```bash
# From the root of the repo
helmfile -e demo apply --skip-refresh
```

Or with the suggested environment variable:
```bash
export MIJNBUREAU_CREATE_NAMESPACES=true
helmfile -e demo apply
```


### 5. Access the Services

Once deployed:
- The ingress is configured for domains like `*.127.0.0.1.sslip.io`
- Main entry point is usually the **Bureaublad** (start page / portal)

You can access services via:
- `https://bureaublad.127.0.0.1.sslip.io`
- Or other subdomains depending on the apps (keycloak, nextcloud, element, etc.)

**Tip:** Add `127.0.0.1 sslip.io *.127.0.0.1.sslip.io` to your `/etc/hosts` if needed, although `sslip.io` usually works without it.

### Customization & Configuration

- **Environments**: Look in `helmfile/environments/demo/` (or `default/`)
- **Values**: Most configuration lives in YAML files under `helmfile/environments/`
- **Enable/Disable apps**: Edit the `helmfile.yaml.gotmpl` or environment files to include/exclude specific apps
- **Secrets**: The project uses **SOPS** (`.sops.yaml`) for encrypted secrets

### Alternative: Production / Bare-metal Setup

For real hardware / production:
1. Use a real Kubernetes cluster (k3s, Talos, etc.)
2. Prepare proper certificates (Let’s Encrypt or your own CA)
3. Use the same `helmfile` structure but with a different environment

### Troubleshooting Tips

- Check pod status: `kubectl get pods -A`
- Ingress issues: `kubectl get pods -n ingress-nginx`
- Logs: `kubectl logs <pod-name> -n <namespace>`
- Re-apply changes: `helmfile -e demo apply`
- Clean up cluster: `kind delete cluster --name mijnbureau`

Would you like me to explain:
- How to enable/disable specific apps (e.g. only Nextcloud + Keycloak)?
- How to make it work better with **Podman** instead of Docker?
- How to customize domains / TLS?
- Or dive into any specific component?

The setup is quite polished for a government-backed demo — you should have a full working suite fairly quickly on your local machine.
