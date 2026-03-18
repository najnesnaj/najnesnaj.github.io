---
title: 'nixos-kubernetes'
draft: false
weight: 60
---

**MijnBureau infra** (from https://github.com/MinBZK/mijn-bureau-infra) is **not** a native NixOS module or flake-based deployment. It is a **Kubernetes-native** stack managed entirely with **Helmfile** (a declarative way to deploy many Helm charts at once). All components (Keycloak, Nextcloud, Element/Matrix, Ollama, LiveKit, Collabora, Grist, OpenProject, etc.) are deployed as Helm releases on a Kubernetes cluster.

Because you already have NixOS running, the easiest path is to run a lightweight single-node Kubernetes cluster **on the same machine** (using k3s) and then apply the Helmfile stack. This gives you the full “MijnBureau” collaboration suite self-hosted on your hardware.

Here are the **exact, detailed steps** you need to follow (tested conceptually against the repo structure as of March 2026).

### Step 1: Enable a Kubernetes cluster on your NixOS machine (k3s – recommended for simplicity)

Add this to your `configuration.nix` (or your flake’s NixOS module):

```nix
services.k3s = {
  enable = true;
  role = "server";                  # single-node = server + agent in one
  extraFlags = [ "--disable traefik" ]; # we will use the ingress from the stack instead
};

# Make kubectl etc. available system-wide
environment.systemPackages = with pkgs; [ k3s ];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

After reboot (or immediately):

```bash
# Verify
sudo k3s kubectl get nodes
# You should see one node "Ready"

# Make kubeconfig easy to use (as normal user)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
export KUBECONFIG=~/.kube/config
kubectl get nodes
```

You now have a working Kubernetes cluster.

### Step 2: Install the deployment tools (Helm + Helmfile + SOPS + age)

Add them permanently to your NixOS config:

```nix
environment.systemPackages = with pkgs; [
  helm
  helmfile
  sops
  age
  kubectl
];
```

Or just for now:

```bash
nix shell nixpkgs#helm nixpkgs#helmfile nixpkgs#sops nixpkgs#age --command bash
```

### Step 3: Clone the repo and prepare your configuration

```bash
git clone https://github.com/MinBZK/mijn-bureau-infra.git
cd mijn-bureau-infra
```

The heart of the deployment lives in two places:
- `helmfile.yaml.gotmpl` (the main orchestrator)
- `helmfile/environments/default/*.gotmpl` (all your settings)

#### Critical files you **must** edit/customise:

1. `helmfile/environments/default/global.yaml.gotmpl`
   - Set your base domain (the subdomains like `id.yourdomain.nl`, `nextcloud.yourdomain.nl` etc. are already defined here).
   - `resourcesPreset = "small";` (or “medium” if you have more RAM).
   - `defaultLocale = "nl";` (already set).

2. `helmfile/environments/default/tls.yaml.gotmpl` and `cluster.yaml.gotmpl` (or wherever the main ingress domain is defined – look for `hostname` or `domain` keys).

For a quick local test you can set `tls.selfSigned = true;`.

3. **Secrets** (most important)
   - The stack derives almost all passwords from one master password via the template in `secret.yaml.gotmpl`.
   - Export it **before** running Helmfile:

     ```bash
     export MIJNBUREAU_MASTER_PASSWORD="a-very-strong-32+-char-password-here"
     ```

   - Real production secrets (the ones ending in `secrets.yaml`) are encrypted with **SOPS + age**.
   - The repo ships `.sops.yaml` with a public age key. For your own deployment you should generate a new key pair:

     ```bash
     age-keygen -o ~/.config/sops/age/keys.txt
     ```

     Then update `.sops.yaml` with your own public key (replace the `age:` line).

### Step 4: Deploy (the “one-command” part)

With the master password exported and your domain/TLS configured:

```bash
helmfile -f helmfile.yaml.gotmpl apply
```

This will:
- Template all the `.gotmpl` files
- Pull the required Helm charts
- Deploy ~15 releases (Keycloak, Nextcloud, Element, Ollama, LiveKit, Collabora, Grist, OpenProject, bureaublad dashboard, etc.)
- Set up Ingress (Traefik or NGINX – the stack includes its own gateway)

It can take 5–15 minutes the first time (pulling images, database init, etc.).

Watch progress with:

```bash
kubectl get pods -A -w
kubectl get ingress -A
```

### Step 5: Access MijnBureau

Once everything is `Running`:

- Main dashboard → `https://bureaublad.<your-domain>`
- Identity provider → `https://id.<your-domain>` (Keycloak)
- Chat → `https://element.<your-domain>`
- Files → `https://nextcloud.<your-domain>`
- etc. (all subdomains are defined in global.yaml.gotmpl)

Initial admin accounts are derived from your `MIJNBUREAU_MASTER_PASSWORD`. The first login usually uses:
- Username: `admin` (or the one in the secret templates)
- Password: derived automatically

### Optional: Local testing without touching your main k3s (using the repo’s kind.sh)

If you want to test first on a throw-away Kind cluster:

```bash
./scripts/kind.sh
```

(it creates a Kind cluster and deploys the stack – useful for dry-run).

### Troubleshooting / Common gotchas on NixOS

- Firewall: k3s opens ports 6443, 80, 443. Open them in your NixOS firewall if needed.
- Storage: Most apps use PVCs. On single-node k3s they go to local-path-provisioner by default (fine for start).
- Longhorn / Rook: If you want real HA storage later, enable one of the NixOS k8s storage modules.
- DNS: Point your domain’s A record (or wildcard) to your machine’s IP.
- TLS: For real certs, set `tls.selfSigned = false` and provide a cert-manager ClusterIssuer or use the built-in Let’s Encrypt flow (the stack supports it via the tls config).

### Next steps / customisation

- To disable features you don’t want: edit the logic files in `helmfile/bases/logic/` or the child helmfiles.
- To add your own charts: the `template/` folder is a ready scaffolding using the common chart.
- Secrets management: once you have real secrets, put them in files like `helmfile/environments/default/mysecrets.yaml` and let SOPS encrypt them.

The official documentation (https://minbzk.github.io/mijn-bureau-infra/) currently only has high-level pages and points back to the repo – the detailed “Getting Started” section is still being filled in. Everything above is derived directly from the repo structure (`helmfile.yaml.gotmpl`, the environments/*.gotmpl files, `.sops.yaml`, secret derivation logic, etc.).

If you get stuck on a specific error (e.g. “requiredEnv MIJNBUREAU_MASTER_PASSWORD” or ingress not working), paste the exact error + the output of `helmfile -f helmfile.yaml.gotmpl template` and I can help further.

