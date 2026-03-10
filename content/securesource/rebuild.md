---
title: 'rebuild'
draft: false
weight: 1000 
---

To verify that the Podman binary you are using on your NixOS system was built faithfully from its declared source code (i.e., that you can reproduce the exact same binary bits by compiling everything yourself), you can perform a **local reproducibility check**.

Nix makes this relatively straightforward thanks to its deterministic build model and the `--check` / `--rebuild` flags. However, Podman itself is a fairly complex package (Go + C dependencies + many transitive deps), and **full bit-for-bit reproducibility is not guaranteed for every package in nixpkgs** — even in 2026, nixpkgs overall hovers around high-90% reproducibility rates for sampled packages, but individual large ones like podman may have minor non-determinism (timestamps, build paths in debug info, ordering issues in Go, etc.).

Still, the procedure below is the standard way to test it on your machine.

### Step-by-step: Check if you can reproduce Podman locally

1. **Make sure you are on a known/pinned nixpkgs version**  
   Reproducibility only makes sense against the exact same nixpkgs commit that Hydra used to build the binary you currently have.  
   If you use the channel or a flake input, find out which revision your current Podman comes from:

   ```bash
   nix eval --raw nixpkgs#podman.drvPath    # shows the .drv → look at the hash or use nix show-derivation
   # or (more readable)
   nix derivation show nixpkgs#podman | jq -r '.[].inputsSrc[]'
   ```

   Better: if you use flakes, pin nixpkgs to a specific commit (e.g. in `flake.nix`):

   ```nix
   inputs.nixpkgs.url = "github:NixOS/nixpkgs/<commit-hash-or-nixos-25.05>";
   ```

   Rebuild your system or just proceed with that pinned input.

2. **Get the hash of the binary you currently have (from cache)**

   ```bash
   nix-store --query --hash $(which podman)
   # or more precisely the whole closure
   nix hash path $(which podman)
   # example output: sha256-...
   ```

   Or just note the full store path:

   ```bash
   realpath $(which podman)
   # → /nix/store/somehash-podman-5.x.y/bin/podman
   ```

3. **Force a local rebuild of Podman (without using any cache)**

   Use one of these (they do roughly the same thing):

   **Modern flake style (recommended if you use flakes):**

   ```bash
   nix build nixpkgs#podman \
     --rebuild \
     --no-link \
     --print-out-paths \
     --option substitute false   # ← crucial: no cache downloads
   ```

   **Classic / non-flake style:**

   ```bash
   nix-build '<nixpkgs>' -A podman \
     --check \
     --option substitute false \
     --keep-failed   # helpful if it fails midway
   ```

   - `--rebuild` / `--check` tells Nix: "build it again even if the output is already in the store".
   - `--option substitute false` forces source build instead of downloading the pre-built binary from cache.nixos.org.
   - Expect this to take a **long time** (30–120+ minutes depending on your machine, because Podman + Go toolchain + runc + conmon + many deps get built from scratch).

4. **Compare the results**

   After the build finishes:

   - If Nix says something like:

     ```
     checking outputs of ‘/nix/store/…-podman.drv’...
     output path ‘/nix/store/…-podman’ should have hash … but got …
     error: build of … failed
     ```

     → **Not reproducible** (bit-for-bit difference detected). Nix itself found the mismatch.

   - If it succeeds silently (or says "outputs are identical") → **Reproducible on your machine** (very good sign).

   - Even if `--check` passes, compare manually for extra confidence:

     ```bash
     diff -r /nix/store/oldhash-podman /nix/store/newhash-podman
     # or use diffoscope (much better for binaries)
     nix-shell -p diffoscope --run "diffoscope /nix/store/old...-podman /nix/store/new...-podman"
     ```

     Install `diffoscope` if needed: `environment.systemPackages = [ pkgs.diffoscope ];`

5. **Interpret the outcome**

   | Outcome                          | Meaning                                                                 | Next step? |
   |----------------------------------|--------------------------------------------------------------------------|------------|
   | Build fails with hash mismatch   | Non-deterministic build (or very rarely: cache tampering)                | Report to nixpkgs (label "reproducible builds") |
   | Build succeeds, bits identical   | Your local build matches Hydra's → strong evidence of no tampering      | Good!      |
   | Build succeeds, bits differ      | Non-determinism (common in complex pkgs)                                 | Acceptable for most; use diffoscope to understand why |
   | Build diverges very early        | Possible config difference (sandbox, __structuredAttrs, etc.)           | Try on another machine |

### Additional tips

- Podman is **not** among the tiny/core packages that are tracked as 100% reproducible (like hello, zlib). Go builds can embed non-deterministic data (e.g. module cache ordering, buildid).
- For highest confidence → try on **two different machines** (different CPU, distro, Nix version). If both match the cache binary → extremely strong evidence.
- Check https://reproducible.nixos.org/ occasionally — it tracks stats and known issues (though not every package is tested continuously).
- If you want to go extreme: disable the binary cache globally (`substituters = ` in nix.conf) and rebuild your whole system — but that's rarely practical.

In practice, for most users the combination of **fixed source hashes + signature verification + sandboxed deterministic builds** already provides very strong protection — the local rebuild is the ultimate personal trust step you can take. If it matches once, you can reasonably trust future cache updates for that same nixpkgs revision.

