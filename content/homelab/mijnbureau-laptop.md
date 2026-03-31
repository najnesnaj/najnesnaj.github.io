---
title: 'mijnbureau-laptop'
weight: 1000 
draft: false
---

Here's a realistic assessment and **step-by-step guide** tailored to your situation.

### Important Reality Check
The repository **mijn-bureau-deploy-demo** is **not** a simple Docker Compose demo. It is a **Helmfile-based deployment** designed for **Kubernetes**.

- The main file you linked (`helmfile.yaml.gotmpl`) is a Go-templated Helmfile configuration.
- It expects a full **Kubernetes cluster** (with `kubectl`, `helm`, `helmfile`, and usually a cluster like **kind**, **minikube**, or a real K8s cluster).
- It also uses **SOPS** for encrypted secrets (`.sops.yaml` is present).

**Running this directly on WSL + Ubuntu without Kubernetes is not straightforward** and will likely fail or be very complex.

### Recommended Options for Your Laptop (WSL)

Here are your realistic paths, ordered from easiest to more advanced:

#### Option 1: Best & Recommended – Use the Main Mijn Bureau Infra (if it has a simpler mode)
Go back to the main project:
```bash
cd ~
git clone https://github.com/MinBZK/mijn-bureau-infra.git
cd mijn-bureau-infra
```

Then check the **Getting Started** documentation carefully:
→ https://minbzk.github.io/mijn-bureau-infra/docs/category/getting-started

Many government "deploy-demo" repos point back to the main infra repo for the actual streamlined/one-command setup. Look specifically for any **local / development / Docker-based** deployment options.

#### Option 2: Try the Deploy-Demo Repo Anyway (with Kind on WSL)

If you still want to try the demo repo with Kubernetes on WSL2:

1. **Install prerequisites in Ubuntu (WSL)**

```bash
sudo apt update && sudo apt upgrade -y

# Install Docker (you probably already have this)
# ... (use the Docker install commands from previous response if needed)

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Helmfile
sudo snap install helmfile --classic
# or: wget https://github.com/helmfile/helmfile/releases/latest/download/helmfile_linux_amd64.tar.gz && tar -xzf ... etc.

# Install SOPS (for secrets)
sudo apt install -y sops

# Install kind (lightweight Kubernetes for local testing)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/
```

2. **Create a local Kubernetes cluster with Kind**

```bash
kind create cluster --name mijnbureau-demo --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
EOF
```

3. **Clone and prepare the demo repo**

```bash
git clone https://github.com/MinBZK/mijn-bureau-deploy-demo.git
cd mijn-bureau-deploy-demo
```

4. **Look at the files**

```bash
ls -la
cat README.md
ls helmfile/          # check if there are values or environments
```

5. **Try to render / apply the helmfile** (this is where it often gets tricky)

```bash
helmfile template     # first try to render without applying
# or
helmfile sync         # this deploys everything
```

You will very likely need to:
- Create or decrypt secrets (using SOPS)
- Provide environment variables or override values for domains, TLS, etc.
- Configure ingress (Kind supports it via the port mappings above)



```bash
 helmfile sync -f helmfile.yaml.gotmpl --values local-values.yaml
```



