---
title: 'container'
draft: false
weight: 1100 
---

Here are the two main ways to run an **NGINX** container on your NixOS system with Podman already enabled (via `virtualisation.podman.enable = true;` and friends).

### 1. The standard way (imperative / Podman CLI — same as on any Linux distro)

This is the classic Podman command-line approach. It's quick for testing and works identically to Docker.

```bash
# Pull the official NGINX image (alpine variant is small & common)
podman pull docker.io/library/nginx:latest
# or just let 'run' pull it automatically

# Run NGINX in detached mode, mapping host port 8080 → container port 80
podman run -d \
  --name my-nginx \
  -p 8080:80 \
  -v $(pwd)/html:/usr/share/nginx/html:ro,Z \   # optional: mount a local folder for custom content
  docker.io/library/nginx:latest

# Check it's running
podman ps

# Test in browser or curl
curl http://localhost:8080
# → should show the default NGINX welcome page

# Logs
podman logs my-nginx

# Stop & remove when done
podman stop my-nginx
podman rm my-nginx
# or one-shot: podman rm -f my-nginx
```

**Extras often used:**
- Add `--restart=unless-stopped` for persistence across reboots (Podman supports systemd-like restart policies).
- Use a pod for multi-container apps: `podman pod create myapp && podman run --pod myapp ...`
- Rootless by default (nice on NixOS).

This is not declarative — the container won't auto-start after reboot unless you generate a systemd unit with `podman generate systemd`.

### 2. The NixOS way (declarative — via `virtualisation.oci-containers`)

NixOS has built-in support for running OCI containers (Podman or Docker backend) as systemd services. This is the **preferred declarative method** on NixOS when using Podman.

Add this to your `/etc/nixos/configuration.nix` (or equivalent flake/module):

```nix
{ config, pkgs, ... }:

{
  # (you already have these from earlier Podman setup)
  virtualisation.containers.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;           # optional: docker alias
    defaultNetwork.settings.dns_enabled = true;  # optional but useful
  };

  # ← This is the important part: declarative containers
  virtualisation.oci-containers = {
    backend = "podman";   # or "docker" if you prefer/switch later

    containers.nginx = {
      autoStart = true;                  # start on boot
      image = "nginx:alpine";            # or "nginx:latest" — alpine is ~10× smaller
      ports = [
        "8080:80"                        # host:container
        # "8443:443"                     # if you add HTTPS later
      ];

      # Optional: mount a local directory for custom HTML
      volumes = [
        "/var/lib/nginx/html:/usr/share/nginx/html:ro"   # read-only
      ];

      # Optional: extra args / env
      extraOptions = [ "--pull=always" ];  # always try to update image
      # environment = { NGINX_PORT = "80"; };  # if needed

      # Optional: auto-remove stopped container (cleaner)
      autoRemoveOnStop = true;
    };
  };

  # Optional but recommended: open the firewall port
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Optional: create the mount point if using volumes
  systemd.tmpfiles.rules = [
    "d /var/lib/nginx/html 0755 root root - -"
  ];

  # Optional: example custom index.html via systemd tmpfiles or activation script
  # system.activationScripts.nginxIndex = ''
  #   echo "<h1>Hello from NixOS + Podman NGINX!</h1>" > /var/lib/nginx/html/index.html
  # '';
}
```

Then apply:

```bash
sudo nixos-rebuild switch
```

- The container appears as a systemd service: `container-nginx.service`
- Check status: `systemctl status container-nginx`
- Logs: `journalctl -u container-nginx -f`
- Test: `curl http://localhost:8080`

**Advantages over CLI method:**
- Declarative → reproducible, version-controlled config
- Auto-starts on boot
- Integrated with NixOS firewall, updates via rebuild
- Easy to add more containers later (e.g., reverse-proxy + app containers)

**Notes (as of 2026):**
- Podman is fully supported as backend since ~20.09; very stable now.
- For production with real domains / HTTPS → consider mounting a custom `/etc/nginx/conf.d` volume and using Let's Encrypt via NixOS `services.nginx` on the host (or Caddy/ACME in another container).
- If you want pods (multi-container groups), look into community modules like `quadlet-nix` (from GitHub) — the built-in `oci-containers` doesn't natively handle pods yet.

The declarative NixOS way is usually the better long-term choice once you're past quick tests.

