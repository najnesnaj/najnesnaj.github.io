---
title: 'nixos'
weight: 800 
draft: false
---



**this approach is one of the easiest and most declarative ways to get a fully configured NixOS VM (with K3s baked in) running on Proxmox.** The `nixos-generate -f proxmox` command does exactly what you described: it turns a `configuration.nix` into a ready-to-import Proxmox `.vma.zst` backup file that you can restore as a VM. This is a supported format in `nixos-generators` and works great for repeatable, infrastructure-as-code style deployments.

You don’t even need to run the generator *inside* Proxmox — booting the NixOS live ISO (on any machine or as a temporary Proxmox VM) is perfect because it gives you a clean Nix environment with everything you need.

### Quick step-by-step (the easy path)

1. **Boot the NixOS ISO**  
   Download the latest NixOS minimal ISO and boot it (you can create a tiny throwaway VM in Proxmox just to run the generator if you want).

2. **Generate the Proxmox VM image**  
   ```bash
   nixos-generate -f proxmox -c ./configuration.nix
   ```
   Or if you prefer the flake version (always up-to-date):
   ```bash
   nix run github:nix-community/nixos-generators -- --format proxmox -c ./configuration.nix
   ```

   The first run can take a while (it builds a patched QEMU for the `.vma` format).  
   Output: a file like `nixos-*.vma.zst` in your current directory (or `/nix/store`).

3. **Copy to Proxmox**  
   ```bash
   scp nixos-*.vma.zst root@your-proxmox-host:/var/lib/vz/dump/
   ```

4. **Import & create the VM on Proxmox**  
   On the Proxmox host:
   ```bash
   # Option A: CLI (recommended)
   qmrestore /var/lib/vz/dump/nixos-*.vma.zst <VMID> --unique true


   this creates a VM on your host disk -- change this!! modify memory and cpu!!

   # Option B: GUI
   Go to the storage where you put the .vma.zst → Content → select the file → Restore
   ```

   Pick a new unused VMID. The VM will boot with your full NixOS config already applied (users, SSH, networking, K3s, etc.).

5. **Start the VM and enjoy**  
   You now have a fully declarative NixOS machine. Later updates are just `nixos-rebuild switch` (or remotely with flakes).

### Make it include K3s from day one

Just add the following to your `configuration.nix` (this is a minimal single-node K3s setup — adjust as needed for a multi-node cluster):

```nix
{ config, pkgs, ... }: {
  # Basic system stuff (add your SSH keys, user, etc.)
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "k3s" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 YOUR-KEY-HERE" ];
  };
  security.sudo.wheelNeedsPassword = false;

  # Networking / firewall for K3s
  networking.firewall.allowedTCPPorts = [ 6443 ];  # kube-apiserver
  networking.firewall.allowedUDPPorts = [ 8472 ]; # flannel

  # K3s (single-node server)
  services.k3s = {
    enable = true;
    role = "server";           # use "agent" for worker nodes
    # clusterInit = true;      # only needed on the very first server node
    # tokenFile = /run/secrets/k3s-token;  # optional for HA

    # Extra flags (common useful ones)
    extraFlags = toString [
      "--disable=traefik"      # use your own ingress if you want
      "--write-kubeconfig-mode=644"
    ];
  };

  # Optional: auto-deploy some manifests (e.g. nginx test pod)
  # services.k3s.manifests.nginx = { ... };  # see NixOS docs

  system.stateVersion = "24.11";  # or whatever release you're on
}
```

You can also set Proxmox VM hardware specs directly in the same file (cores, RAM, disk size, etc.) using the `proxmox` module options — no need to tweak them in the Proxmox GUI after restore.

### Why this is the easy way
- **Fully declarative** — one `configuration.nix` (or flake) defines *everything*.
- **Reproducible** — spin up identical nodes in seconds.
- **No manual post-install** — K3s, users, SSH, firewall, etc. are already there when the VM boots.
- After the first deploy you can manage the VM with plain `nixos-rebuild` (even remotely).

If you want an even more automated workflow later, you can combine this with flakes + `nixos-anywhere` or `deploy-rs`, but for getting started the method you described is already excellent.


{ config, pkgs, lib, ... }: {

  imports = [
    <nixpkgs/nixos/modules/virtualisation/proxmox-image.nix>   # Important!
    # or if using flakes: "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-image.nix"
  ];
  users.users.root.initialPassword = "your-password";
  # Proxmox VM hardware settings (example)
  proxmox.qemuConf = {
    cores = 4;
    memory = 8192;     # in MiB
    # bios = "ovmf";   # for UEFI if you prefer
  };
  # === Basic system setup ===
  networking.hostName = "k3s-nixos"; 

  # === K3s ===
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = "--disable=traefik";   # remove if you want Traefik
  };



  system.stateVersion = "25.11";
}








nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/nixos-generators -- \
  --format proxmox -c ./configuration.nix



scp nixos-*.vma.zst root@192.168.0.143:/var/lib/vz/dump/

on proxmox host
qmrestore /var/lib/vz/dump/nixos-*.vma.zst 9000 --unique true



====================================
in the new virtual image is no configuration.nix
you can create it using : 

sudo nixos-generate-config

this can be used as a basis for further installation
