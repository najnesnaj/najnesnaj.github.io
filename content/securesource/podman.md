---
title: 'podman'
draft: false
weight: 900
---

Here is a structured, document-style explanation of how to **manage Podman on NixOS** (based on the declarative approach we discussed earlier). This covers applying changes, checking/verifying, and uninstalling/removing it cleanly.

### Podman on NixOS: Apply, Check, Verify & Uninstall Guide

**Goal**  
Declaratively enable **Podman** (with Docker compatibility) via your NixOS configuration. This makes containers reproducible, auditable, and easy to manage/rollback.

#### 1. Applying / Enabling Podman (Installation)

Edit your configuration file (usually `/etc/nixos/configuration.nix` or in your flake-based config folder):

Add this block (minimal recommended setup):

```nix
{ config, pkgs, ... }:

{
  virtualisation = {
    containers.enable = true;                # Creates /etc/containers/policy.json, registries.conf, etc.
    
    podman = {
      enable = true;
      
      # Makes 'docker' command alias to 'podman' (great compatibility for scripts/tools)
      dockerCompat = true;
      
      # Optional: auto-remove unused images/containers weekly
      autoPrune.enable = true;
      
      # Optional: better default network with DNS resolution inside containers
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  # Optional: add useful companion tools
  environment.systemPackages = with pkgs; [
    podman-compose     # for docker-compose.yml files
    podman-tui         # nice TUI for managing containers/pods
  ];
}
```

**Apply the changes** (this is the equivalent of "installing" or "upgrading"):

```bash
sudo nixos-rebuild switch
```

- **What happens**: NixOS builds a new system closure including Podman + config files + aliases, then atomically switches to it (via symlink flip in `/run/current-system`).
- **Time**: Usually 15–40 seconds (as discussed earlier).
- **Alternative (test without bootloader changes)**: `sudo nixos-rebuild test` — faster for quick checks, changes revert on reboot.

#### 2. Checking / Verifying Podman Works

After rebuild, verify everything is active and functional:

| Check | Command | Expected Output / Meaning |
|-------|---------|----------------------------|
| Podman version | `podman --version` | `podman version X.Y.Z` (shows it's in PATH) |
| Rootless socket active | `systemctl --user status podman.socket` | Should be "active (listening)" (rootless is default for normal users) |
| Docker alias | `docker --version` | Should say "podman version ..." if `dockerCompat = true;` |
| Test container (rootless) | `podman run --rm hello-world` | Prints hello message → Podman works |
| List running containers | `podman ps` or `docker ps` | Shows table (empty is fine) |
| Config files created | `ls /etc/containers/` | See `policy.json`, `registries.conf`, `storage.conf` etc. |
| System-wide info | `podman info` | Detailed config, registries, store paths, etc. |

If something fails:
- Check logs: `journalctl -u podman.socket` (system-wide) or `journalctl --user -u podman.socket`
- Re-run `sudo nixos-rebuild switch` if activation partially failed.

#### 3. Uninstalling / Removing Podman

To completely remove Podman (reverse the installation):

1. **Edit configuration.nix**  
   - Remove or comment out the entire `virtualisation.containers.enable = true;` and `virtualisation.podman = { ... };` block.
   - Remove any `podman-compose`, `podman-tui`, etc. from `environment.systemPackages`.

   Example after removal:

   ```nix
   # virtualisation.containers.enable = true;          # ← commented out or deleted
   # virtualisation.podman = { ... };                  # ← removed
   ```

2. **Apply removal**:

   ```bash
   sudo nixos-rebuild switch
   ```

   - This rebuilds the system without Podman → old generations still exist (for rollback).
   - Podman binary, socket, aliases, and `/etc/containers/*` files disappear from the active system.

3. **Optional: Clean up old generations & free space** (after confirming everything works without Podman):

   ```bash
   sudo nix-collect-garbage -d          # Deletes all old generations (careful!)
   # or safer:
   sudo nix-env --delete-generations  +5   # Keeps last 5 generations
   sudo nix-collect-garbage
   ```

   - This removes old closures containing Podman (if no other references exist).

4. **Stop & disable user socket** (if rootless was used):

   ```bash
   systemctl --user stop podman.socket
   systemctl --user disable podman.socket
   systemctl --user mask podman.socket   # Optional: prevent accidental restart
   ```

#### 4. Where to Find What Was Installed (for SBOM or Auditing)

NixOS makes the full list of installed packages **deterministic and queryable**. For Software Bill of Materials (SBOM) or compliance/audit needs:

**Quick human-readable list of system packages** (including Podman if enabled):

```bash
# All runtime dependencies of the current system (most complete/accurate)
nix-store -q --requisites /run/current-system | xargs -n1 nix-store -q --tree | sort -u

# Simpler: top-level packages from your config
nixos-option environment.systemPackages   # shows declared ones
# or
nix eval --raw .#nixosConfigurations.$(hostname).config.environment.systemPackages   # if using flakes
```

**For proper SBOM generation** (CycloneDX / SPDX format, machine-readable, with versions, purls, hashes):

Nixpkgs doesn't have built-in SBOM export yet (as of March 2026), but community tools work well:

- **sbomnix** (most mature for NixOS/Nixpkgs): https://github.com/tiiuae/sbomnix  
  ```bash
  nix run github:tiiuae/sbomnix#sbomnix -- /run/current-system
  # → produces sbom.cdx.json (CycloneDX) or other formats
  ```

- **bombon** (CycloneDX focused, flake-friendly): https://github.com/nikstur/bombon  
  Integrate in your flake or use:
  ```bash
  nix run github:nikstur/bombon#buildBom .#your-system-attribute
  ```

- **Other options**: genealogos (from Tweag), or tools like syft/grype after generating a basic manifest.

These tools walk the Nix closure graph of `/run/current-system` (or any derivation) and produce a full dependency tree with metadata. Podman + its runtime deps (runc, conmon, slirp4netns, etc.) + any transitive libs will appear there.

**Summary: SBOM sources on NixOS**
- Runtime closure: `/run/current-system`
- Query: `nix-store -qR /run/current-system`
- Generate SBOM: Use sbomnix or bombon on the system path
- Store paths: Everything lives in `/nix/store/...-podman-5.x/...` (immutable, hash-based)

This keeps your setup fully declarative, auditable, and reversible — core NixOS strengths.

If you need help integrating SBOM generation into your rebuild workflow or flake, let me know!
