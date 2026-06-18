# Mijn Bureau Installation History

## Overview

Installation of "mijnbureau" from [github.com/MinBZK/mijn-bureau-deploy-demo](https://github.com/MinBZK/mijn-bureau-deploy-demo)
on Linux Mint 22.3 (Wilma) using rootless Podman (4.9.3) instead of Docker.

## System Configuration

### OS
- Linux Mint 22.3 (Wilma), based on Ubuntu 24.04 LTS
- Kernel: 6.8.x
- Architecture: x86_64

### Podman Setup

1. **Installed Podman** (already present: v4.9.3)
2. **Created Docker wrapper** at `~/.local/bin/docker`:
   ```bash
   #!/bin/bash
   exec podman "$@"
   ```
3. **Expanded cgroup delegation** (required for kind rootless):
   Added user slice to `/etc/systemd/system/user-.slice.d/override.conf`:
   ```
   [Unit]
   Before=systemd-logind.service
 
   [Slice]
   Delegate=cpuset cpu io memory hugetlb pids
   ```
   Enabled subtree control in `~/.config/systemd/user/slice.d/override.conf`:
   ```
   [Slice]
   CPUAccounting=true
   CPUWeightAccounting=true
   IOAccounting=true
   MemoryAccounting=true
   TasksAccounting=true
   Delegate=cpuset cpu io memory hugetlb pids
   ```
4. **Set non-root port access**:
   ```bash
   sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
   ```

## Binary Installation

All binaries installed to `~/.local/bin/` (prepended to PATH):

| Binary   | Version    | Installation Method |
|----------|------------|---------------------|
| kind     | v0.24.0    | curl binary from GitHub releases |
| kubectl  | v1.32.0    | curl binary from Kubernetes releases |
| helm     | v3.17.0    | curl binary from GitHub releases |
| helmfile | v1.0.0     | curl binary from GitHub releases |
| mkcert   | v1.4.4     | curl binary from GitHub releases |

### kind binary
```bash
curl -Lo ~/.local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ~/.local/bin/kind
```

### kubectl binary
```bash
curl -Lo ~/.local/bin/kubectl https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl
chmod +x ~/.local/bin/kubectl
```

### helm binary
```bash
curl -Lo ~/.local/bin/helm https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz
tar xzf helm-v3.17.0-linux-amd64.tar.gz --strip-components=1 linux-amd64/helm
mv helm ~/.local/bin/helm
rm helm-v3.17.0-linux-amd64.tar.gz
```

### helmfile binary
```bash
curl -Lo ~/.local/bin/helmfile https://github.com/helmfile/helmfile/releases/download/v1.0.0/helmfile_1.0.0_linux_amd64.tar.gz
tar xzf helmfile_1.0.0_linux_amd64.tar.gz helmfile
mv helmfile ~/.local/bin/helmfile
rm helmfile_1.0.0_linux_amd64.tar.gz
```

### mkcert binary
```bash
curl -Lo ~/.local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
chmod +x ~/.local/bin/mkcert
```

## Repository Setup

```bash
git clone https://github.com/MinBZK/mijn-bureau-deploy-demo /tmp/mijn-bureau-deploy-demo
cd /tmp/mijn-bureau-deploy-demo
```

## TLS Certificates

Generated wildcard certificate for `*.127.0.0.1.sslip.io`:

```bash
mkcert -install
mkcert "*127.0.0.1.sslip.io"
```

## KIND Cluster Creation

### Initial Attempt (failed)
First attempt used a kind config without KubeletInUserNamespace:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mijnbureau
nodes:
  - role: control-plane
    image: kindest/node:v1.30.0
networking:
  ipFamily: ipv4
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
```
The kubelet failed to start due to rootless Podman limitations:
```
kubelet.go: Disk usage monitoring of service errors: ... unknown mounter
```

### Working Cluster Config
Created with `KubeletInUserNamespace` feature gate:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mijnbureau
nodes:
  - role: control-plane
    image: kindest/node:v1.30.0
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        metadata:
          name: config
        apiServer:
          extraArgs:
            feature-gates: "KubeletInUserNamespace=true"
        controllerManager:
          extraArgs:
            feature-gates: "KubeletInUserNamespace=true"
        scheduler:
          extraArgs:
            feature-gates: "KubeletInUserNamespace=true"
      - |
        kind: InitConfiguration
        metadata:
          name: config
        nodeRegistration:
          kubeletExtraArgs:
            feature-gates: "KubeletInUserNamespace=true"
networking:
  ipFamily: ipv4
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
```

Created with:
```bash
kind create cluster --config /tmp/kindcfg.yaml --name mijnbureau
```

### Critical: KIND Experimental Provider
Set environment variable to use Docker-compatible provider (aliases to Podman):
```bash
export KIND_EXPERIMENTAL_PROVIDER=docker
```

## Traefik Ingress Controller

Used Traefik instead of nginx-ingress (user preference):

```bash
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set ports.web.port=80 \
  --set ports.web.hostPort=80 \
  --set ports.websecure.port=443 \
  --set ports.websecure.hostPort=443 \
  --set ports.websecure.tls.enabled=true \
  --set providers.kubernetesIngress.publishedService.enabled=true
```

### HSTS Middleware (Global)
Created a globally-accessible HSTS middleware to avoid Helm ownership conflicts:
```bash
kubectl create -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: hsts-header
  namespace: default
spec:
  headers:
    stsSeconds: 31536000
    stsPreload: true
    stsIncludeSubdomains: true
EOF
```

Also created in kube-system namespace for Traefik's own ingress routes:
```bash
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: hsts-header
  namespace: kube-system
spec:
  headers:
    stsSeconds: 31536000
    stsPreload: true
    stsIncludeSubdomains: true
EOF
```

**Fix applied**: Removed duplicate `treafik-middleware.yaml` templates from all chart directories to prevent Helm ownership conflicts over the shared `hsts-header` Middleware resource.

## Local Environment Configuration

Created `helmfile/environments/local/` directory with environment-specific config:

```
helmfile/environments/local/
  mijnbureau.yaml.gotmpl
```

Key configuration values:
- Domain: `127.0.0.1.sslip.io`
- Ingress type: `traefik`, className: `traefik`
- Security contexts disabled (rootless compatibility)
- Apps enabled: keycloak, docs
- PVCs enabled with `standard` storage class (local-path-provisioner)
- OIDC client secrets configured

### Environment Base Modifications

Modified `helmfile/bases/environment.yaml.gotmpl` to remove secrets requirement for `local` environment (avoids needing `helm-secrets` plugin):

```yaml
  local:
    values:
      - "helmfile/environments/local/*.yaml*"
    # secrets stanza omitted for local
```

### Keycloak Modifications

Modified `helmfile/apps/keycloak/helmfile-child.yaml.gotmpl` to support `local` environment:
- Enabled PostgreSQL deployment for `local` env (in addition to `demo`)

### Docs Modifications

Modified `helmfile/apps/docs/helmfile-child.yaml.gotmpl` to support `local` environment:
- Enabled PostgreSQL, Redis, MinIO deployments for `local` env
- Updated `needs` dependency chains

## Storage Fix

### Problem
`local-path-provisioner` helper pod failed inside rootless kind container with:
```
Error: failed to create containerd task: ... error creating device nodes: mount /dev/bus/usb/003/012: no such file or directory
```

### Root Cause
A USB device node (`/dev/bus/usb/003/012`) inside the kind container had `0000` permissions and an empty ACL, making it inaccessible even to root inside the user namespace. containerd's OCI runtime (runc) could not bind-mount this device into helper pods.

### Fix
Masked the problematic USB device directories with tmpfs mounts inside the kind container:
```bash
podman exec mijnbureau-control-plane mount -t tmpfs tmpfs /dev/bus/usb/003/
podman exec mijnbureau-control-plane mount -t tmpfs tmpfs /dev/bus/usb/001/
podman exec mijnbureau-control-plane mount -t tmpfs tmpfs /dev/bus/usb/002/
podman exec mijnbureau-control-plane mount -t tmpfs tmpfs /dev/bus/usb/004/
```

This made USB device directories empty, preventing containerd from trying to pass through broken devices. Note: these mounts are lost on container restart and must be reapplied.

## Applications Deployed

### Keycloak (v26.3.3)
- **Helm chart**: keycloak-25.2.0
- **PostgreSQL**: bitnami/postgresql 17.5.0 (with persistent PVC)
- **Ingress**: `id.127.0.0.1.sslip.io` via Traefik
- **Status**: Running, OpenID Connect configuration available
- **Admin credentials**: user `admin`, password from `kubectl get secret keycloak-keycloak -o jsonpath="{.data.admin-password}" | base64 -d`

### Docs (v5.2.1)
- **Helm chart**: docs-0.1.0
- **Backend**: lasuite/impress-backend
- **Frontend**: separate frontend container
- **PostgreSQL**: docs-cluster-rw (with persistent PVC)
- **Redis**: docs-redis (with persistent PVC)
- **MinIO**: docs-minio (64Gi PVC for object storage)
- **Ingress**: `docs.127.0.0.1.sslip.io` via Traefik
- **Static**: `static-docs.127.0.0.1.sslip.io` via Traefik
- **Status**: Deploying (pods starting)

## Commands Reference

### Sync all enabled apps
```bash
export MIJNBUREAU_MASTER_PASSWORD="test123"
export MIJNBUREAU_CREATE_NAMESPACES=true
helmfile -e local --skip-refresh --file helmfile.yaml.gotmpl sync
```

### Check status
```bash
kubectl get pods -n default
kubectl get ingress -n default
kubectl get pvc -n default
curl -k https://id.127.0.0.1.sslip.io/realms/master/
```

### Fix storage after cluster restart
```bash
for dir in 001 002 003 004; do
  podman exec mijnbureau-control-plane mount -t tmpfs tmpfs /dev/bus/usb/$dir/ 2>/dev/null || true
done
```

## Known Issues

1. **USB device nodes in rootless Podman**: After kind node restart, the tmpfs mounts over `/dev/bus/usb/*/` are lost and must be reapplied for local-path-provisioner to work.
2. **Slow image pulls**: Container images take minutes to pull inside rootless kind due to network/overlay overhead.
3. **No persistence across cluster restart**: PVCs using local-path-provisioner store data on the kind node's ephemeral filesystem. Data is lost if the kind cluster is deleted.
4. **HSTS Middleware conflict**: All Helmm charts attempt to create the same `hsts-header` Middleware. The `treafik-middleware.yaml` template was removed from all charts; the middleware is created globally via kubectl instead.
