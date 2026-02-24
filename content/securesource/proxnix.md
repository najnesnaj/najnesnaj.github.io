---
title: 'proxmoxx on nix os '
draft: false
---






NixOS isn't designed primarily as a hypervisor like Proxmox — it's a general-purpose declarative Linux distro — but you can turn it into a powerful virtualization host for home labs or servers. Many people migrate from Proxmox to NixOS precisely for the declarative config, reproducibility, atomic updates/rollbacks, and integration with Nix flakes/modules.

### Closest Equivalents / Setups on NixOS
Here are the main realistic paths, ordered from "most Proxmox-like" to more lightweight/declarative:

1. **Proxmox-NixOS** (experimental port of Proxmox itself to NixOS)  
   - This is literally Proxmox running on NixOS — including the web interface, clustering, PBS (backup server), etc.  
   - GitHub project: SaumonNet/proxmox-nixos  
   - Status: Still experimental (as of recent discussions), basic features work (booting VMs, user management), but advanced stuff like full HA/clustering is WIP.  
   - If you love Proxmox's UI and workflow but want NixOS declarative config underneath → this is the closest match.  
   - People are testing it on real hardware; not yet production-ready for everyone.

2. **NixOS + Incus** (most popular migration path right now)  
   - Incus = community fork of LXD → supports both system containers (like Proxmox LXC) **and** full VMs (QEMU-based).  
   - Many ex-Proxmox users switch to bare-metal NixOS + Incus for their entire homelab (2025–2026 blog posts show full migrations).  
   - Benefits: Declarative host config via Nix, lightweight (no heavy hypervisor overhead), ZFS support, easy migration from Proxmox LXC/VMs.  
   - No built-in web UI like Proxmox, but you can use:  
     - Incus CLI (very powerful)  
     - Web UIs like Incus UI projects or third-party tools  
   - Example: Run containers for services + VMs for things like Home Assistant or Windows.  
   - Great if you want Nix purity + container/VM mix without Proxmox's "imperative" feel.

3. **NixOS + libvirt + Virt-Manager / virsh** (classic KVM stack)  
   - Enable in configuration.nix:  
     ```nix
     virtualisation.libvirtd.enable = true;
     virtualisation.libvirtd.qemu.enable = true;  # or similar options
     boot.kernelModules = [ "kvm-intel" "kvm-amd" ];  # depending on CPU
     ```
   - Manage remotely via **virt-manager** (GUI from your desktop) or virsh CLI.  
   - Supports KVM/QEMU VMs (full OS isolation), PCI passthrough, snapshots, etc.  
   - For declarative VMs: Check out NixVirt or combine with microvm.nix.  
   - Solid for headless servers; many use this for home labs.  
   - Less "integrated" than Proxmox but very flexible.

4. **microvm.nix** (ultra-lightweight, declarative NixOS VMs)  
   - If your VMs are mostly NixOS guests → run them as micro-VMs (Firecracker or QEMU).  
   - Extremely efficient, boot in seconds, perfect for "cattle" workloads.  
   - Not ideal for Windows/non-NixOS guests or if you need a rich GUI.

### Quick Comparison Table

| Feature                  | Proxmox                  | NixOS + Incus            | NixOS + libvirt          | Proxmox-NixOS (experimental) |
|--------------------------|--------------------------|--------------------------|--------------------------|------------------------------|
| Web UI                   | Excellent built-in      | Limited/third-party      | Virt-Manager (remote GUI)| Yes (Proxmox UI)            |
| KVM VMs                  | Yes                     | Yes                      | Yes (best support)       | Yes                         |
| LXC-style containers     | Yes (LXC)               | Yes (Incus native)       | No (but can add)         | Yes                         |
| Declarative config       | Partial (some scripts)  | Full (Nix)               | Partial → full w/ tools  | Full (Nix)                  |
| ZFS support              | Excellent               | Good                     | Good                     | Yes                         |
| Clustering/HA            | Built-in                | Possible (manual/K8s)    | Possible (manual)        | WIP                         |
| Learning curve           | Low                     | Medium-High (Nix)        | Medium                   | Medium-High                 |
| Best for                 | Easy hypervisor         | Nix lovers + containers  | Classic KVM management   | Proxmox fans wanting Nix    |

### Recommendation
- If you want **as close as possible to Proxmox** (UI + features) → try **Proxmox-NixOS** first (experimental, but improving fast).  
- If you want **Nix philosophy + good VM/container support** → go **NixOS + Incus** (most real-world migrations in 2025–2026).  
- If you mostly need VMs and remote GUI → **NixOS + libvirt + virt-manager** is straightforward and battle-tested.

All of these are doable today on current NixOS (unstable or 25.05+ channels have good module support). Start with the NixOS wiki pages on libvirt/Incus, or search Discourse/Reddit for recent configs — people share full `configuration.nix` examples for hypervisor setups.

Let me know what your main use case is (e.g., mostly containers, Windows VMs, ZFS, clustering), and I can give more targeted config pointers!
