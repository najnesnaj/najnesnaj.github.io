---
title: 'yubikey'
draft: false
---




**YubiKey can work very effectively on a NixOS installation in the cloud** (e.g., a VPS on Hetzner, AWS EC2, DigitalOcean, Linode, GCP, Azure, or any provider running NixOS), but the way it works depends on what you're trying to achieve and the physical reality of the cloud environment.

Since cloud instances are remote headless servers with **no physical USB access** from your local machine, you **cannot plug the YubiKey directly into the cloud VM**. Instead, YubiKey enhances security through these main patterns on NixOS cloud setups (all well-supported and commonly used in 2026):

### 1. SSH Authentication with FIDO2 Resident Keys (Recommended & Most Modern Approach)
Modern OpenSSH (≥ 8.2, which NixOS has had for years) supports **FIDO2 resident/discoverable keys** stored directly on the YubiKey hardware. This is phishing-resistant, hardware-bound, and perfect for cloud servers.

- **How it works**:
  - You generate the keypair **locally** on your machine (laptop/desktop), with the private key never leaving the YubiKey.
  - The public key is added to `~/.ssh/authorized_keys` on the cloud NixOS instance (or better: to `/etc/ssh/authorized_keys.d/` or via NixOS config).
  - When you `ssh user@cloud-ip`, OpenSSH on your local machine talks to the YubiKey (via USB), which performs the challenge-response signing. The server only sees the public key verification.
  - **No agent forwarding needed** (safer than old ssh-agent forwarding).

- **Local setup (on your laptop, any OS)**:
  ```bash
  # Generate discoverable/resident key (stores on YubiKey)
  ssh-keygen -t ed25519-sk -O resident -O verify-required -O passphrase= \
    -f ~/.ssh/id_ed25519_sk_yubikey \
    -C "yourname@cloud-nixos-2026"

  # Or shorter (defaults to resident + PIN required)
  ssh-keygen -t ed25519-sk
  ```

- **On the cloud NixOS side** (add to configuration.nix or flake):
  ```nix
  # Minimal SSH hardening + allow the pubkey
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Optional: require FIDO2 for extra paranoia
    };
  };

  # Declaratively add your YubiKey pubkey (from ssh-keygen -K or cat ~/.ssh/id_ed25519_sk_yubikey.pub)
  users.users.youruser.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... yourname@cloud-nixos-2026"
  ];
  ```

This is the cleanest, most secure way for cloud NixOS in 2026 — no software keys exposed, hardware protection against extraction.

### 2. Challenge-Response / U2F as Second Factor (via pam_u2f)
Use YubiKey as a **second factor** for SSH login (after password or pubkey).

- **Common pattern**: Pubkey + YubiKey touch = required for login.
- **NixOS config** (from NixOS wiki & pam_u2f module):
  ```nix
  services.openssh.enable = true;

  security.pam.u2f = {
    enable = true;
    interactive = true;          # Prompt during login
    cue = true;                  # "Please touch the requested security key"
    origin = "pam://nixos-cloud"; # Arbitrary, but consistent
  };

  # Enroll your YubiKey (run once locally or via initial console)
  # pamu2fcfg > /etc/u2f_mappings  (or per-user in ~/.config/Yubico/u2f_keys)
  ```

- **Limitation for cloud**: Enrollment requires temporarily having the YubiKey plugged in somewhere that can reach the server (e.g., initial setup via cloud console + forwarded USB, or do it before pushing to cloud).
- After enrollment, SSH login prompts for key touch — works remotely without the key being on the server.

### 3. GnuPG / OpenPGP Smartcard Mode (YubiKey as PIV/OpenPGP card)
Store GPG keys on YubiKey, use for SSH via gpg-agent.

- **NixOS config**:
  ```nix
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.pcscd.enable = true;  # If somehow USB forwarded, but rare on cloud
  ```

- **For cloud**: You run gpg-agent locally, forward `SSH_AUTH_SOCK` via `ssh -R` or use resident keys instead. Classic for signing git commits from cloud CI, but less common purely for login.

### 4. Edge Cases & Advanced Tricks for Cloud
- **USB forwarding** (rarely practical): Tools like usbip, VirtualHere, or cloud-specific USB-over-IP (some providers offer it for bare-metal-like instances) let you "attach" your local YubiKey to the remote VM. NixOS supports pcscd + libfido2 for this, but it's niche, latency-heavy, and insecure over internet.
- **yubikey-agent / pinentry**: For local agent forwarding of PIV/GPG keys — forward socket to cloud for short sessions (e.g., nixos-rebuild from remote builder).
- **Passwordless sudo on cloud console** (if console access): pam_u2f can protect escalated privileges, but again enrollment needs key access initially.

### Summary: Best Practices for NixOS Cloud + YubiKey (2026)
| Goal                          | Best Method                  | Requires Local YubiKey Plug-in? | Cloud-Side Config Needed? |
|-------------------------------|------------------------------|---------------------------------|----------------------------|
| Secure SSH login              | FIDO2 resident keys          | Yes (during key gen & use)      | Just authorizedKeys        |
| 2FA on top of pubkey/password | pam_u2f challenge-response   | Yes (enrollment)                | Yes (PAM module)           |
| Git commit signing from cloud | GPG on YubiKey + agent forward | Yes                             | gpg-agent + SSH_AUTH_SOCK  |
| Passwordless sudo (console)   | pam_u2f                      | Yes                             | Yes                        |

**Bottom line**: Yes — YubiKey works excellently on cloud NixOS, mostly **from your local machine** protecting the authentication to the remote server. The cloud instance itself stays minimal and never sees the private key material. Use FIDO2 resident keys for the simplest, strongest setup — it's declarative in NixOS, phishing-resistant, and widely used by NixOS users securing remote infra.
