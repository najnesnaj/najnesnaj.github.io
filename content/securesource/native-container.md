---
title: 'native container'
draft: false
weight: 1200 
---

There is a fully **Nix-native** way to run NGINX in isolation on NixOS without relying on any Alpine Linux (or any other foreign distro/image like the official `nginx:alpine` OCI image).

NixOS provides two main isolation mechanisms that stay entirely within the Nix ecosystem:

1. **NixOS declarative containers** (using `boot.enableContainers = true;` + `containers.<name>`)  
   → These are lightweight **systemd-nspawn** containers running a full (but minimal) NixOS instance inside.  
   → You configure NGINX exactly like on the host — using the native `services.nginx` module.  
   → No Docker/Podman/OCI images involved at all. This is the purest "NixOS way".

2. **Build your own minimal OCI image from nixpkgs' `nginx` package** (using `pkgs.dockerTools.buildImage` or `buildLayeredImage`)  
   → Then run it declaratively via `virtualisation.oci-containers` (with Podman backend).  
   → This keeps everything reproducible and source-based from nixpkgs, without Alpine.

The first option (native NixOS containers) is usually preferred for services like NGINX that have excellent native NixOS module support — it's simpler, more integrated, and avoids any container image layers.

### Recommended: Pure NixOS Container (systemd-nspawn based)

Add this to your `configuration.nix` (or flake module):

```nix
{ config, pkgs, lib, ... }:

{
  # Enable the containers subsystem (usually already on if you have Podman)
  boot.enableContainers = true;
  # virtualisation.containers.enable = true;  # often implied/enabled already

  containers.nginx-webserver = {
    autoStart = true;

    # Minimal NixOS config *inside* the container
    config = { config, pkgs, ... }: {

      # Very slim system — no unnecessary services
      system.stateVersion = "25.05";  # or your channel's version

      # Networking: private network + host bridge by default
      networking.hostName = "nginx-webserver";
      networking.firewall.allowedTCPPorts = [ 80 ];

      # The star: native NGINX module
      services.nginx = {
        enable = true;

        # Recommended hardening & perf settings
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts."localhost" = {
          # Example: serve static files from a bind-mounted host directory
          root = "/var/www/html";  # we'll bind-mount this

          locations."/" = {
            # Or proxy to something else, add SSL, etc.
            index = "index.html";
          };
        };
      };

      # Minimal users/services — nginx runs as dynamic user
      users.users.nginx = { };  # usually created automatically

      # Optional: suppress most logs/noise
      services.journald.extraConfig = "Storage=volatile";
    };

    # Bind-mount your content from host → container
    bindMounts = {
      "/var/www/html" = {
        hostPath = "/var/lib/nginx-container/html";  # create on host
        isReadOnly = true;
        mountPoint = "/var/www/html";
      };
    };

    # Optional: give it a private veth network
    privateNetwork = true;
    hostBridge = "br0";  # or use NAT/default

    # Forward host port 8080 → container's port 80
    forwardPorts = [
      { sourcePort = 8080; protocol = "tcp"; destinationPort = 80; }
    ];
  };

  # Create the content directory on host (and optional default index.html)
  systemd.tmpfiles.rules = [
    "d /var/lib/nginx-container/html 0755 root root - -"
    "f /var/lib/nginx-container/html/index.html 0644 root root - - Hello from NixOS container NGINX!"
  ];

  # Open host firewall if needed
  networking.firewall.allowedTCPPorts = [ 8080 ];
}
```

Apply with `sudo nixos-rebuild switch`.

- Test: `curl http://localhost:8080` → "Hello from NixOS container NGINX!"
- Logs: `machinectl shell root@nginx-webserver -- journalctl -u nginx`
- Enter container: `sudo nixos-container login nginx-webserver`
- Stop/start: `sudo nixos-container stop/start nginx-webserver`

This gives you:
- Full NixOS config reproducibility inside the container
- No Alpine or foreign base
- Native `services.nginx` with all its options (virtual hosts, ACME/Let's Encrypt, proxy, etc.)
- Lightweight (no image layers, shares Nix store via bind mounts where possible)

### Alternative: Build & Run a Minimal NGINX OCI Image from nixpkgs (no Alpine)

If you prefer sticking with Podman/OCI but want to avoid Alpine:

```nix
{ pkgs, ... }:

let
  nginxImage = pkgs.dockerTools.buildLayeredImage {
    name = "my-nginx";
    tag = "latest";
    contents = [
      pkgs.nginx
      pkgs.fakeNss  # minimal /etc/passwd etc. for nginx user
    ];
    config = {
      Cmd = [ "${pkgs.nginx}/bin/nginx" "-g" "daemon off;" ];
      ExposedPorts = { "80/tcp" = {}; };
      WorkingDir = "/var/www/html";
    };
    extraCommands = ''
      mkdir -p var/www/html
      echo "Hello from pure nixpkgs NGINX!" > var/www/html/index.html
    '';
  };
in
{
  virtualisation.oci-containers = {
    backend = "podman";
    containers.nginx-pure-nix = {
      autoStart = true;
      imageFile = nginxImage;          # ← use local Nix-built image (no pull!)
      image = "my-nginx:latest";       # dummy name
      ports = [ "8080:80" ];
      volumes = [
        "/var/lib/my-nginx/html:/var/www/html:ro"
      ];
    };
  };

  # Same tmpfiles & firewall as above
}
```

This builds a tiny image (~few MB beyond nginx closure) purely from nixpkgs — no internet pull at runtime.

The **native NixOS container** approach is generally cleaner and more "NixOS idiomatic" for services like NGINX. If you want full HTTPS/ACME, reverse proxy, etc., the `services.nginx` module inside the container handles it beautifully.

