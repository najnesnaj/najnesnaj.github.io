---
title: 'nix os '
draft: false
weight: 20
---




### Why Nix Makes the “One Tool to Rule Them All” Dream Real
- **Flakes** pin your entire world (Nixpkgs version, inputs, outputs) so `nix build` or `nixos-rebuild` on your laptop in 2026 produces the exact same artifact as your CI or production.
- **Nix language** is fully declarative and functional — you describe *what* you want, not *how* to build it step-by-step.
- **Nix store** gives bit-for-bit reproducibility, shared layers/caching, and zero “it works on my machine”.
- Same expressions work for:
  - Local dev shells (`devShells`)
  - Your application packages (`packages`)
  - Docker/OCI images
  - Full NixOS disk images for VirtualBox, KVM/QEMU, AWS EC2, Google Compute Engine, Azure, DigitalOcean, etc.
  - Deployment (via `nixos-rebuild`, colmena, deploy-rs, nixos-anywhere, or Terraform + NixOS modules)

### 1. Forget Dockerfiles — Build Docker/OCI Images Declaratively
Use `pkgs.dockerTools` (or the newer OCI helpers). No `docker build`, no layers you have to manage manually, perfect caching because every dependency is a Nix store path.

Modern flake example (`flake.nix`):

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      packages.x86_64-linux.myapp-image = pkgs.dockerTools.buildLayeredImage {
        name = "myapp";
        tag = "latest"; # or use self.rev or a git tag for reproducibility
        contents = [ self.packages.x86_64-linux.myapp pkgs.cacert ]; # your app + certs, etc.
        config = {
          Cmd = [ "${self.packages.x86_64-linux.myapp}/bin/myapp" ];
          ExposedPorts = { "8080/tcp" = {}; };
          Env = [ "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
        };
      };

      # Your actual app (can be built from source, Rust, Go, Python, whatever)
      packages.x86_64-linux.myapp = pkgs.buildGoModule { ... }; # or whatever
    };
}
```

Build & load:
```bash
nix build .#myapp-image
docker load < result
docker run -p 8080:8080 myapp:latest
```

Layers are automatically split per package → instant cache hits on rebuilds. You can even `FROM` another Nix-built image or pull external ones with `pkgs.dockerTools.pullImage`.

### 2. One NixOS Configuration → Cloud Images, VM Images, KVM, VirtualBox, etc.
Since NixOS 25.05, the best parts of `nixos-generators` are upstreamed. You write **one** configuration and generate any format with a single command.

Example flake:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      nixosConfigurations.myServer = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix          # your shared config (users, services, firewall, etc.)
          # Format-specific modules are auto-included by nixos-rebuild build-image
        ];
      };

      # Optional: expose images directly for `nix build .#images.<variant>`
      packages.${system} = {
        aws-ami     = self.nixosConfigurations.myServer.config.system.build.images.amazon;
        gcp-image   = self.nixosConfigurations.myServer.config.system.build.images.gce;
        azure-vhd   = self.nixosConfigurations.myServer.config.system.build.images.azure;
        vbox-vm     = self.nixosConfigurations.myServer.config.system.build.images.virtualbox;
        kvm-qcow2   = self.nixosConfigurations.myServer.config.system.build.images.qcow;
      };
    };
}
```

**Build commands (2026 way):**
```bash
# AWS EC2 AMI
nixos-rebuild build-image --image-variant amazon --flake .#myServer

# Google Cloud image
nixos-rebuild build-image --image-variant gce --flake .#myServer

# Azure VHD
nixos-rebuild build-image --image-variant azure --flake .#myServer

# VirtualBox VM
nixos-rebuild build-image --image-variant virtualbox --flake .#myServer

# KVM/QEMU (qcow2, perfect for Proxmox, libvirt, etc.)
nixos-rebuild build-image --image-variant qcow --flake .#myServer
```

All formats: `amazon`, `azure`, `gce`, `do`, `linode`, `openstack`, `virtualbox`, `qcow`, `qcow-efi`, `raw-efi`, `vmware`, `hyperv`, `proxmox`, `iso`, etc.

Your `./configuration.nix` stays 100% the same — just add `imports = [ (modulesPath + "/virtualisation/amazon-image.nix") ];` only if you want format-specific tweaks (most people don’t).

### 3. From Zero to Cloud in One Workflow
```bash
# 1. Start a new project
nix flake init -t github:NixOS/templates#full  # or minimal

# 2. Develop locally (same env as prod)
nix develop  # drops you into a shell with your exact toolchain

# 3. Build & test your app
nix build .#myapp
nix run .#myapp

# 4. Build Docker image
nix build .#myapp-image

# 5. Build cloud/VM images
nixos-rebuild build-image --image-variant amazon --flake .#myServer

# 6. Deploy
# Option A: Upload AMI to AWS + launch via Terraform / console
# Option B: Use colmena / deploy-rs / nixos-anywhere for existing machines
# Option C: nixos-rebuild switch --target-host root@my-cloud-ip
```

### Bonus: Full Declarative Deployment Stack
- **Infra provisioning**: Terraform (or even Nix + terraform-provider-nixos)
- **OS config**: Pure NixOS modules
- **App deployment**: Nix-built binaries or Docker images pushed to your registry
- **Fleet management**: colmena (excellent for hundreds of machines), deploy-rs, or NixOps 2.0 experiments
- **CI/CD**: GitHub Actions / GitLab CI just run `nix build` and `nixos-rebuild`

This is the DevOps dream realized: **change one line in your flake or configuration.nix → the entire pipeline (dev shell → Docker → AMI → running instance) updates deterministically**.

Nix + Docker really *is* a match made in heaven. NixOS on the cloud (or anywhere) with the same tool you use for local development is pure joy.

Want a ready-to-clone starter repo with a full example (Rust/Go/Python app + Docker + AWS/GCP/Azure + KVM/VirtualBox images)? Just say the word and I’ll give you the exact flake layout. 🚀

From zero to cloud — with **one tool**. That’s Nix.
