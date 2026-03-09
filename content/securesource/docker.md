---
title: 'docker'
draft: false
weight: 500
---

If you're approaching Docker with a high level of paranoia—meaning you want to minimize trust in third-party builds, reduce attack surfaces, ensure verifiability, and prioritize reproducibility—the key is to treat every layer and dependency as a potential risk. Standard bases like Ubuntu (e.g., `FROM ubuntu:22.04`) are convenient but introduce trust in the Canonical team's builds, package repositories, and any upstream changes over time. To substitute this with something you control entirely, focus on building as much as possible from source or using empty bases like `scratch`, while incorporating security hardening throughout.

Below, some best practices tailored for this mindset, drawing from security-focused guidelines (e.g., Docker's own docs, CIS benchmarks, and community audits). These emphasize self-verification, minimalism, and determinism. Note: This can make builds more complex and time-intensive, but it's the trade-off for paranoia.

### 1. **Start with Minimal or Self-Built Base Images**
   - **Avoid full OS bases like Ubuntu unless necessary**: They include unnecessary tools (e.g., shells, package managers) that expand the attack surface. If you must use one, opt for "slim" variants (e.g., `debian:bookworm-slim`) and immediately remove extras like `apt`, `curl`, `wget`, or network utils in your Dockerfile.
   - **Prefer `FROM scratch` for ultimate control**: This is Docker's empty base—no OS, no binaries. You build everything yourself by compiling static binaries from trusted sources and copying them in. This eliminates trust in pre-built images entirely.
     - **Why?** You verify every file and hash yourself, reducing vulnerabilities to zero extraneous components.
     - **How to do it**:
       - Use multi-stage builds: Compile in a "builder" stage (using a minimal trusted base like `golang:alpine` if needed), then copy only the final artifacts to `scratch`.
       - Example Dockerfile for a simple Go app (adapt for your needs):
         ```
         # Builder stage (use a minimal base here, but verify its hash first)
         FROM golang:1.21-alpine AS builder
         WORKDIR /app
         COPY . .
         RUN go mod download && CGO_ENABLED=0 GOOS=linux go build -o myapp .

         # Final stage: Self-built from nothing
         FROM scratch
         COPY --from=builder /app/myapp /myapp
         ENTRYPOINT ["/myapp"]
         ```
       - For non-Go apps (e.g., Python), use static compilation tools like PyInstaller or Nuitka to create standalone executables, then copy to `scratch`.
     - **Paranoid extras**: Download source code tarballs manually, verify SHA256 hashes against published values (e.g., from official repos), and build offline if possible.
   - **Alternatives if `scratch` is too extreme**:
     - Google's Distroless images (e.g., `gcr.io/distroless/static`): Minimal, no shell or package manager, but still built by Google—audit their Dockerfiles on GitHub first.
     - Alpine Linux: Tiny and musl-based, but some audits (e.g., from 2019–2025 analyses) note weaker security advisories and past issues like empty root passwords; avoid for prod if paranoid.
     - Build a custom base using tools like `debootstrap` (for Debian-like) in a privileged container, then export it as your own image. This lets you create a "personal Ubuntu" from scratch, but it's advanced—see Docker's rootfs docs for guidance.

### 2. **Enforce Reproducibility and Determinism**
   - From the papers we discussed (e.g., Malka et al., Guilloteau et al.), Docker builds drift over time due to unpinned deps. Counter this by:
     - **Pin everything**: Use exact versions/tags (e.g., `python:3.12.1-slim` instead of `python:latest`). For packages, use lockfiles (e.g., `requirements.txt` with hashes via `pip-tools`).
     - **Make builds deterministic**: Set `ARG BUILD_DATE` and `ARG VCS_REF` in Dockerfile, use `--no-cache` in builds, and avoid timestamps (e.g., via `COPY --chown`).
     - **Rebuild and compare periodically**: Script rebuilds at intervals and diff layers (using `docker history` or tools like `container-diff`).
     - **Use build caches wisely**: But disable if paranoid (`docker build --no-cache`).

### 3. **Harden Security in the Dockerfile and Runtime**
   - **Run as non-root user**: Always. Add a user in the builder stage and switch with `USER appuser` in the final image. Drop capabilities (e.g., via `docker run --cap-drop=ALL`).
   - **Minimize layers and contents**: Each `RUN` adds a layer—combine commands. Remove temp files, caches, and tools post-install (e.g., `RUN apt-get install -y pkg && apt-get clean && rm -rf /var/lib/apt/lists/*`).
   - **No secrets in images**: Use build-time args (`--build-arg`) or runtime env vars/bind mounts. Never hardcode keys.
   - **Disable unnecessary features**: No exposed ports unless needed; use read-only mounts (`--read-only`); limit network access if possible.
   - **Sign and verify images**: Use Docker Content Trust (`export DOCKER_CONTENT_TRUST=1`) or Cosign for signing your builds. Pull only signed images.

### 4. **Scan and Audit Everything**
   - **Static analysis**: Before running, use Trivy (`trivy image myimage`), Clair, or Snyk to scan for CVEs. Integrate into CI/CD.
   - **Runtime monitoring**: Tools like Falco or Sysdig for behavior anomalies. Run with seccomp profiles (`--security-opt seccomp=profile.json`) to restrict syscalls.
   - **Inspect manually**: Use `dive` to explore layers, or export images to tar and audit files.
   - **Paranoid auditing**: Review every Dockerfile line (yours and bases'). For any external image, fetch its Dockerfile from the repo and rebuild it yourself to verify.

### 5. **Operational Best Practices**
   - **Build in isolated environments**: Use a dedicated VM or air-gapped machine for builds to avoid contamination.
   - **Store and distribute securely**: Push to private registries (e.g., self-hosted Harbor) with TLS and auth. Avoid public hubs like Docker Hub if paranoid.
   - **Update strategy**: Automate vulnerability checks (e.g., via Dependabot) and rebuild/patch frequently, but test in staging.
   - **If Docker feels insufficient**: For even more paranoia, consider alternatives like Podman (rootless by default) or integrating Nix/Guix for bit-for-bit reproducible environments inside containers.

This approach shifts the burden to you for building/verifying, but it maximizes control. If your app is simple (e.g., static binary), `scratch`-based images can be under 10MB with zero CVEs. Start small: Prototype with a minimal app, scan it, and iterate. For more, check Docker's security benchmarks or OWASP Container Security guides. If you share specifics about your use case (e.g., language/runtime), I can refine examples.
