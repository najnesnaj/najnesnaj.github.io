---
title: 'scratch'
draft: false
weight: 1000 
---

In Nix (and therefore NixOS/Hydra builds like the zlib example ), there are **multiple independent layers** that together provide strong assurance that the **source code** has not been tampered with and that the resulting binary faithfully comes from the declared sources. No single mechanism is perfect on its own, but the combination makes supply-chain tampering extremely difficult and — in many cases — detectable.

### 1. Integrity of the original source tarball (upstream source code)
The line you see:

```
unpacking source archive /nix/store/n22iqgfwr3jr08f9hl4140y3sqmrzf2z-zlib-1.3.1.tar.gz
```

This path is a **fixed-output derivation** (FOD) — specifically a `fetchurl` or `fetchzip` call in nixpkgs. Every source tarball in nixpkgs is declared with a cryptographic hash:

```nix
# Example from nixpkgspkgs/development/libraries/zlib/default.nix (roughly)
src = fetchurl {
  url = "https://zlib.net/zlib-1.3.1.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # or sha256-..., outputHashAlgo = "sha256";
};
```

- Nix **downloads** the tarball only once (when the hash is unknown).
- It computes the hash of what was actually received.
- If it doesn't match the hash in the .nix file → build fails immediately.
- If it does match → the store path is created and **never changes** again (immutable).
- Hydra (and your local machine) will get **exactly the same bytes** as long as the upstream URL serves the same content.

**→ This cryptographically pins the exact bytes of the source tarball.**  
Tampering with zlib.net (or a MITM on the download) would be detected the first time anyone anywhere builds it (including Hydra). The wrong hash would cause mass build failures → very visible.

### 2. Integrity & authenticity of the binary you download (cache.nixos.org)
Hydra builds packages → if successful, it signs the **.nar** (Nix archive) of the result with the official cache key and uploads it to cache.nixos.org.

Your Nix client verifies:

- The `.narinfo` file contains `Sig: cache.nixos.org-1:...`
- The signature is made with the public key you have trusted (in `/etc/nix/nix.conf` or defaults: `trusted-public-keys = cache.nixos.org-1:...`)
- Nix **rejects** anything without a valid signature from a trusted key.

**→ You know the binary came from Hydra (or someone with the private key — which is tightly controlled).**  
The signing key has been the same for many years; rotating it would be a massive event.

### 3. Reproducible builds as the strongest tamper-detection mechanism
Even if someone compromised Hydra / the signing key / upload pipeline:

- Many packages in nixpkgs (including zlib and large parts of the stdenv) are **reproducible** (byte-for-byte identical when built multiple times with the same inputs).
- The community (and projects like reproducible.nixos.org) periodically rebuilds important artifacts (e.g. minimal ISO) **independently**, without using any cache.nixos.org substitutes (`--option substitute false`).
- If the locally-built binary matches the one from cache → the cache binary really was built from the declared sources (no tampering).
- If it differs → tampering (or non-determinism) is proven.

**→ Reproducibility turns the binary itself into a verifiable proof.**  
You (or anyone) can re-execute the exact same derivation locally or on another machine and compare the output hash. For zlib-1.3.1 this is usually very reproducible.

### Summary of control mechanisms

| Layer                        | Mechanism                              | Detects what?                              | Who can verify?          |
|------------------------------|----------------------------------------|--------------------------------------------|--------------------------|
| Upstream source tarball      | Fixed-output hash in nixpkgs           | Changed / malicious tarball from URL       | Anyone building once     |
| Binary from cache            | Narinfo signature + trusted key        | Binary not produced by Hydra/key holder    | Every Nix user (automatic) |
| Binary fidelity to source    | Reproducible builds + independent rebuilds | Tampering after source fetch (Hydra compromise, etc.) | Anyone (takes CPU/time) |
| Entire build graph           | Sandbox + no network in normal builds  | Sneaky fetches or local tampering during build | Nix sandbox + reviewers  |

### Practical ways you can personally gain more confidence

- **Quick local check** — force rebuild zlib without cache:  
  ```bash
  nix build nixpkgs#zlib --no-use-remote-sudo --option substitute false --rebuild
  ```
  → Builds from source → compare `/nix/store/...-zlib-1.3.1/lib/libz.so` hash with cache version.

- **Extreme** — disable public cache entirely in `/etc/nix/nix.conf`:
  ```
  substituters = 
  trusted-public-keys = 
  ```
  → Everything builds locally from your pinned nixpkgs commit.

- **Pin nixpkgs to a known commit** (your earlier question) → you control the exact .nix expressions and hashes.
It's one of the strongest supply-chain security stories among major distros, even if it still requires some trust in the nixpkgs git commit history and the Hydra signing key. For highest security, build locally from a git checkout you trust/verify yourself.

