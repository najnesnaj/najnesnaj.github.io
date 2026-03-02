---
title: 'nix os vulnerable for xz hack?'
draft: false
---








** NixOS would score meaningfully better than most other major Linux distributions in the context of the XZ backdoor incident (CVE-2024-3094), but not for the reasons people sometimes assume.**

The XZ backdoor (in versions 5.6.0 and 5.6.1) was a sophisticated supply-chain attack where malicious code was hidden in release tarballs (not in the upstream git repo). It only activated during builds that matched certain conditions (mainly distributions that patched OpenSSH to use libsystemd notifications, like Fedora and Debian sid/testing at the time).

Here's how NixOS compared:

- **NixOS was technically exposed** — NixOS unstable did briefly ship the compromised xz 5.6.1 package (built from the malicious tarball), just like Arch, openSUSE Tumbleweed, and others.

- **NixOS was **not vulnerable** to the actual backdoor / RCE exploit** — The backdoor never activated on NixOS systems because:
  - NixOS does not apply the systemd-notification patch to OpenSSH → liblzma is never preloaded into sshd.
  - NixOS's non-FHS filesystem layout and build environment likely would have broken the backdoor's assumptions anyway.

  Distributions like Fedora (Rawhide/41), Debian sid/testing (briefly), openSUSE Tumbleweed, and Kali were the ones that shipped both the bad xz **and** the vulnerable sshd configuration → they were the truly at-risk ones.

- **NixOS response and recovery** — NixOS quickly downgraded xz to 5.4.6 in unstable (via staging channels), though mass-rebuild delays slowed full propagation a bit. Still, no reports of actual compromise ever surfaced on NixOS.

Now, where NixOS arguably scores **better** overall (especially in hindsight and for future similar incidents):

- **Deterministic / reproducible builds** — Nix builds everything from source in isolated, pinned environments. This makes it much harder for subtle build-time injections to go unnoticed if anyone ever compares bit-for-bit output across machines or rebuilds from git instead of tarballs.
- **Theoretical detection advantage** — Several post-incident analyses (e.g. Julien Malka's blog and related papers) argue that NixOS's reproducibility + ability to rebuild packages from git sources (after bootstrap) could have mechanically detected the discrepancy between the git repo and the tampered release tarball. If Nixpkgs had implemented a post-bootstrap cross-check build of xz from GitHub (instead of the maintainer tarball), the binary difference would have been a red flag.
- **Source-based philosophy & less reliance on upstream binaries** — Nix rarely trusts pre-generated configure scripts or autotools artifacts blindly; many packages run autogen.sh. This reduces one vector the XZ attacker used.

In contrast, most binary-focused distributions (even those with reproducible builds efforts like Debian) were more directly exposed because:

- They imported the upstream tarball as-is.
- Their OpenSSH was often patched in ways that made liblzma preload happen.
- They lacked Nix's extreme environment isolation.

**Bottom line ranking (practical security outcome in this specific incident)**:

1. Distributions that never picked up 5.6.x (most stable releases: Ubuntu LTS, RHEL, Debian stable) → best outcome (unaffected).
2. NixOS, Arch, Gentoo → shipped bad xz but **never vulnerable** due to OpenSSH differences + (in Nix's case) build philosophy.
3. Fedora Rawhide/41, Debian sid, openSUSE Tumbleweed → actually vulnerable for a short window.

So yes — NixOS scores **better than most rolling/binary distributions** that were vulnerable (Fedora, Debian testing, etc.), and its design gives it structural advantages against similar future tarball-targeted supply-chain attacks. However, it was not immune, and reproducibility alone did not automatically catch this one in 2024 (though it plausibly could have with small process changes).
