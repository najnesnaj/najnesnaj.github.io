---
title: 'mijnbureau'
weight: 900 
draft: false
---
Here's a **clear, step-by-step guide** tailored to your existing NixOS + K3s single-node setup.

You already have this in your `configuration.nix`:

```nix
services.k3s = {
  enable = true;
  role = "server";
  extraFlags = toString [
    "--disable=traefik"      # Good choice — we'll use our own ingress later
    "--write-kubeconfig-mode=644"
  ];
};
```

### Step 1: Add Required Tools to Your NixOS Configuration

Add the following to your `configuration.nix` (merge it with your existing `environment.systemPackages`):

```nix
environment.systemPackages = with pkgs; [
  # ... your other packages ...

  # Tools needed for MijnBureau deployment
  helm
  kubectl
  helmfile
  sops          # for decrypting secrets
  git           # to clone the repo
  age           # often used together with SOPS (recommended)
  gnupg         # in case you use GPG with SOPS
];
```

Then apply the change:

```bash
sudo nixos-rebuild switch
```

After this, `helm`, `kubectl`, `helmfile`, and `sops` will be available system-wide.

### Step 2: Verify K3s is Ready

Run these commands to make sure your cluster is healthy:

```bash
# Check K3s service status
systemctl status k3s

# Check nodes and pods
kubectl get nodes
kubectl get pods -A
```

You should see your node as `Ready` and core pods (like coredns, local-path-provisioner, etc.) running.

**Important:** Because you disabled Traefik, you will need to install your own Ingress controller later (common choices on NixOS + K3s: **nginx-ingress**, **traefik** via Helm, or **Caddy**). MijnBureau likely expects an Ingress (or the newer Gateway API).

### Step 3: Clone the MijnBureau Infra Repository

```bash
cd ~                     # or any directory you prefer, e.g. /var/lib/mijnbureau
git clone https://github.com/MinBZK/mijn-bureau-infra.git
cd mijn-bureau-infra
```

### Step 4: Understand the Deployment Structure

The main deployment file is **`helmfile.yaml.gotmpl`** in the root of the repository (it uses Go templating for flexibility).

Inside the `helmfile/` directory you will find:
- `apps/` — individual applications (Keycloak, Element, Collabora, Ollama, Bureaublad, Meet, etc.)
- `bases/` and `environments/` — shared configuration and environment-specific settings

Deployment is done with **helmfile**, which reads the `.gotmpl` file and applies multiple Helm charts at once.

### Step 5: Prepare Secrets (Very Important)

MijnBureau uses **SOPS** for encrypted secrets.

1. Look at the `.sops.yaml` file in the repo root — it defines how secrets are encrypted (usually with `age` or GPG).
2. You need to create or decrypt secret files (often `secrets.yaml` or values files containing passwords, tokens, TLS certs, Keycloak admin password, etc.).
3. Typical workflow:
   ```bash
   # Create your own secrets file if none exists, then encrypt it
   sops --encrypt --age YOUR_AGE_PUBLIC_KEY secrets.enc.yaml > secrets.yaml
   ```

   Or if the repo already provides encrypted files, you just need your private key in `~/.config/sops/age/keys.txt` (or equivalent).

**Do not skip this** — many charts will fail without proper secrets (especially Keycloak, database credentials, etc.).

### Step 6: Deploy with Helmfile

The standard command is usually one of these (run from inside the `mijn-bureau-infra` directory):

```bash
# Dry-run first (highly recommended!)
helmfile --file helmfile.yaml.gotmpl template --debug

# Or just:
helmfile template

# Actual deployment / sync
helmfile --file helmfile.yaml.gotmpl sync

# Or the shorter version (if helmfile finds helmfile.yaml.gotmpl automatically):
helmfile sync
```

Common useful flags:
- `helmfile sync --skip-diff-on-install` — faster on first run
- `helmfile apply` — some people prefer `apply` instead of `sync`
- `helmfile -e production sync` — if environments are defined

**First deployment can take 10–30 minutes** because it pulls many container images and starts databases, Keycloak, etc.

### Step 7: Post-Deployment Steps

After `helmfile sync` succeeds:

```bash
# Check all releases
helmfile list

# See running pods
kubectl get pods -A -w

# Check services and ingresses
kubectl get svc,ing -A
```

You will then need to:
- Install an **Ingress Controller** (since Traefik is disabled).
- Configure DNS (or use a local domain like `mijnbureau.local` with `/etc/hosts` for testing).
- Set up TLS (Let's Encrypt via cert-manager is common, or self-signed).
- Access the dashboard / Bureaublad startpage.

### Tips Specific to Your Single-Node K3s Setup

- **Storage**: K3s uses `local-path-provisioner` by default → fine for testing. For production, consider Longhorn or Rook.
- **Resources**: A single node needs decent RAM/CPU (recommend at least 16 GB RAM, 4+ cores) because Ollama + several services run together.
- **Ingress Recommendation**: Deploy the official `nginx-ingress` via Helm or add it to your own helmfile.
- **Updates**: Later you can run `helmfile sync` again to update everything when the repo changes.

### Next Recommended Actions:

1. Add the packages and rebuild NixOS first.
2. Clone the repo and explore `helmfile.yaml.gotmpl` + the `helmfile/` folder.
3. Set up SOPS + your age key (this is the most common stumbling block).
4. Run `helmfile template` to see what will be deployed before applying.


