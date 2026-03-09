---
title: 'ragflow-nix'
draft: false
weight: 800
---

Using NixOS with reproducible builds is a solid approach for minimizing supply chain risks, as it ensures exact dependency pinning and bit-for-bit identical outputs from source. For a Docker-based project like RAGFlow (an open-source RAG engine that typically deploys via Docker Compose with services like Elasticsearch, Redis, and MySQL), integrating it doesn't inherently add massive overhead, but it does require some upfront configuration to align with Nix's philosophy. Here's a breakdown:

### Basic Integration: Running Docker on NixOS
NixOS natively supports Docker without much friction. You can declaratively enable and manage it:
- Add `virtualisation.docker.enable = true;` to your NixOS configuration (e.g., in `/etc/nixos/configuration.nix`).
- This starts the Docker daemon as a systemd service and allows you to use tools like `docker` or `docker-compose` directly.
- For RAGFlow, clone its repo, navigate to the `docker` directory, and run `docker compose up -d` as per its docs. It pulls and runs the necessary images (around 2-3 GB total for the base setup).

This is low-overhead if you're okay with pulling pre-built images from Docker Hub or building them locally via the provided Dockerfile. However, pulling pre-builts could expose you to supply chain issues (e.g., if the upstream images are compromised), which contradicts your goal of building from scratch.

### Reproducible Approach: Building Docker Images with Nix
To fully leverage Nix for reproducibility and avoid trusting external binaries:
- Nixpkgs includes `dockerTools` (e.g., `pkgs.dockerTools.buildImage` or `pkgs.dockerTools.buildLayeredImage`), which lets you define Docker images declaratively in Nix expressions. This builds layers with only the exact runtime dependencies, resulting in smaller, verifiable images.
- For RAGFlow, since its source is open and includes a Dockerfile, you can create a Nix derivation that fetches the source via `fetchFromGitHub`, builds the image using `dockerTools`, and pins all deps (e.g., Python libs, Ollama for local models if needed).
- Benefits:
  - Bit-for-bit reproducibility: Builds are sandboxed, so no network access or timestamps affect outputs.
  - Layer efficiency: Nix minimizes rebuilds by caching unchanged deps.
  - Integration: Deploy the resulting image via NixOS modules like `virtualisation.oci-containers` (which turns containers into systemd services) or tools like Arion for Compose-like setups.
- Potential overhead:
  - Initial setup: Writing a Nix flake or expression for RAGFlow might take 30-60 minutes if you're familiar with Nix (e.g., defining build inputs for its Python backend and services). If not, it's a learning curve but reusable.
  - Build time: First builds could be longer (e.g., compiling deps from source), but subsequent ones are fast due to caching.
  - Size: Custom Nix-built images might be slightly larger or smaller depending on optimizations, but they're auditable.
  - No extra runtime cost: Once built, running is identical to plain Docker.

If RAGFlow's deps are already in nixpkgs (e.g., many Python packages are), you could even skip Docker entirely and package it as a native Nix service module for zero container overhead—though this might require more effort if it's tightly coupled to Docker.

Overall, the "overhead" is mostly one-time setup for the Nix config, which pays off in security and maintainability. If you share your NixOS config or RAGFlow specifics, I can suggest more tailored tweaks.
