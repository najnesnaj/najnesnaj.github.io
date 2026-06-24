# MijnBureau WSL Installation Guide

Step-by-step instructions for deploying the MijnBureau demo environment on WSL (Windows Subsystem for Linux).

## Prerequisites

Ensure the following tools are installed:

- **Docker Desktop** (with WSL2 backend)
- **kind** - `brew install kind` or download from https://kind.sigs.k8s.io
- **kubectl** - `brew install kubectl`
- **helm** - `brew install helm`
- **helmfile** - `brew install helmfile`
- **mkcert** - `brew install mkcert`
- **age** + **sops** - for secrets: `brew install age sops`
- **jq**, **yq** - `brew install jq yq`
- **openssl** (usually pre-installed on WSL)

## 1. Clone the Repository

```bash
git clone https://github.com/anomalyco/mijn-bureau-deploy-demo.git
cd mijn-bureau-deploy-demo
```

## 2. Create the Kind Cluster

Create a Kind cluster with ingress-ready configuration and port mappings for 80/443:

```bash
cat <<'EOF' | kind create cluster --name mijnbureau --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
nodes:
- role: control-plane
  image: kindest/node:v1.34.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30001
    hostPort: 30001
EOF
```

Verify the cluster is running:

```bash
kubectl cluster-info --context kind-mijnbureau
```

## 3. Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.yaml
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=120s
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --timeout=120s
```

## 4. Install metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s
```

## 5. Install NGINX Ingress Controller

**Important:** This step must be done AFTER cert-manager is running, because ingress-nginx uses a SelfSigned cert-manager issuer for its admission webhook certificate.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.2/deploy/static/provider/kind/01-namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.2/deploy/static/provider/kind/02-mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.2/deploy/static/provider/kind/04-hotplug-namespaces.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.13.2/deploy/static/provider/kind/05-ingress-kind.yaml
```

Wait for the controller to be ready:

```bash
kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=120s
```

## 6. Enable Snippet Annotations (Required for Keycloak)

The default ingress-nginx v1.13.2 has snippet annotations disabled. Keycloak's ingress uses `configuration-snippet` annotations, so we must enable them:

```bash
kubectl -n ingress-nginx patch configmap ingress-nginx-controller --type merge \
  -p '{"data":{"allow-snippet-annotations":"true","annotations-risk-level":"Critical"}}'
kubectl -n ingress-nginx rollout restart deployment ingress-nginx-controller
kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller --timeout=120s
```

## 7. Configure CoreDNS for Wildcard DNS Resolution

To resolve `*.127.0.0.1.sslip.io` domains to the ingress-nginx controller:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        rewrite name regex (.*)\.127\.0\.0\.1\.sslip\.io {1}.127.0.0.1.sslip.io
        hosts {
          10.96.0.10 127.0.0.1.sslip.io
          fallthrough
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
EOF
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns --timeout=120s
```

## 8. Add Hosts Entry (Optional)

If DNS resolution for `*.127.0.0.1.sslip.io` does not work, add this to your `/etc/hosts`:

```bash
echo "127.0.0.1 id.127.0.0.1.sslip.io docs.127.0.0.1.sslip.io nextcloud.127.0.0.1.sslip.io bureaublad.127.0.0.1.sslip.io" | sudo tee -a /etc/hosts
```

## 9. Set Environment Variables

```bash
export MIJNBUREAU_MASTER_PASSWORD="mijnbureau-demo-pa$$word-2024"
```

> **Note:** The `$$` escapes to a literal `$` in the shell, resulting in the password `mijnbureau-demo-pa$word-2024`.

## 10. Add Required Helm Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo update
```

## 11. Deploy All Services with helmfile

```bash
helmfile -e demo apply
```

This deploys the following services (as configured in `helmfile/environments/demo/mijnbureau.yaml.gotmpl`):

| Service | URL | Description |
|---------|-----|-------------|
| Keycloak | `https://id.127.0.0.1.sslip.io` | Identity and access management |
| Nextcloud | `https://nextcloud.127.0.0.1.sslip.io` | File sync and share |
| Docs | `https://docs.127.0.0.1.sslip.io` | Documentation portal |
| Bureaublad | `https://bureaublad.127.0.0.1.sslip.io` | Dashboard / homepage |

If the apply fails on the first attempt (e.g., due to ingress snippet validation), simply re-run:

```bash
helmfile -e demo apply
```

## 12. Verify Deployment

Check all pods are running:

```bash
kubectl get pods -A
```

Check ingresses are configured:

```bash
kubectl get ingress -A
```

Access the services in your browser:

- **Keycloak:** https://id.127.0.0.1.sslip.io (admin credentials derived from `MIJNBUREAU_MASTER_PASSWORD`)
- **Nextcloud:** https://nextcloud.127.0.0.1.sslip.io
- **Docs:** https://docs.127.0.0.1.sslip.io
- **Bureaublad:** https://bureaublad.127.0.0.1.sslip.io

## 13. Clean Up

To destroy the cluster and all resources:

```bash
kind delete cluster --name mijnbureau
```

## Troubleshooting

### Ingress Snippet Annotations Denied

**Error:** `admission webhook "validate.nginx.ingress.kubernetes.io" denied the request: annotation group ConfigurationSnippet contains risky annotation`

**Fix:** Enable snippet annotations in the ingress-nginx ConfigMap:

```bash
kubectl -n ingress-nginx patch configmap ingress-nginx-controller --type merge \
  -p '{"data":{"allow-snippet-annotations":"true","annotations-risk-level":"Critical"}}'
kubectl -n ingress-nginx rollout restart deployment ingress-nginx-controller
```

### Clean up failed Helm releases before retrying

```bash
helm delete <release-name> -n <namespace>
kubectl delete pvc -l app.kubernetes.io/instance=<instance-name>
```

### ContainerCreating Pods Stuck

Wait a few moments for images to pull. If pods remain stuck, check:

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```
