---
title: 'ragflow-image'
draft: false
weight: 700
---

For a more secure deployment of RAGFlow (infiniflow/ragflow) on NixOS, avoiding pre-built Docker images from public registries reduces potential supply chain risks, such as tampered images. The project is open-source, so the primary secure alternatives are:

- **Building Docker images locally from source**: This lets you inspect and build the images yourself, ensuring you're using verified code from GitHub.
- **Running natively from source**: This avoids container images for the core RAGFlow services (backend and frontend), though it still relies on Docker for dependent services (e.g., MinIO, Elasticsearch/Infinity, Redis, MySQL). It's suitable for development or controlled environments, allowing finer-grained security controls like custom Python environments.

Both approaches assume you've cloned the repo from GitHub (a trusted source) and reviewed the code if needed. Recent updates (as of March 2026) include security patches for CVEs in dependencies like urllib3 and pypdf, and the project uses Trivy for vulnerability scanning—run `trivy image --exit-code 1 --no-progress --ignore-unfixed your-built-image` post-build for extra checks.

Hardware prerequisites remain: ≥4 CPU cores, ≥16 GB RAM, ≥50 GB disk. Enable Docker in your NixOS config as before (via `virtualisation.docker.enable = true;`), since both methods use it partially.

### Option 1: Build Docker Images Locally (Recommended for Simplicity and Security)
This builds all services from the Dockerfile, avoiding pulls from Docker Hub.

1. **Prepare NixOS Environment**:
   - In `/etc/nixos/configuration.nix`, ensure Docker and related packages:
     ```
     virtualisation.docker.enable = true;
     boot.kernel.sysctl."vm.max_map_count" = 262144;  # For Elasticsearch/Infinity
     environment.systemPackages = with pkgs; [ git docker-compose trivy ];  # Add Trivy for scanning
     ```
   - Rebuild: `sudo nixos-rebuild switch`.
   - Add user to docker group and reboot if needed.

2. **Clone and Build**:
   ```
   git clone https://github.com/infiniflow/ragflow.git
   cd ragflow
   ```
   - Optionally checkout latest release: `git checkout v0.24.0` (or check repo for newer).
   - Build the image: `docker build --platform linux/amd64 -f Dockerfile -t infiniflow/ragflow:custom .`
     - If behind a proxy: Add `--build-arg http_proxy=http://your-proxy:port --build-arg https_proxy=http://your-proxy:port`.
     - This creates a ~2 GB image with all components.

3. **Configure and Run**:
   - Navigate to `docker/` and edit `.env` and `conf/service_conf.yaml` as before (passwords, LLM keys, etc.).
   - Update `docker-compose.yml` to use your local image: Replace `image: infiniflow/ragflow:...` lines with `image: infiniflow/ragflow:custom` for relevant services.
   - Build and start: `docker-compose build && docker-compose up -d`.
   - Scan for vulnerabilities: `trivy image infiniflow/ragflow:custom`.
   - Access at `http://localhost`.

4. **Security Enhancements**:
   - Use Docker's `--no-cache` in build to ensure fresh dependencies.
   - Run with least privileges: Add `user: "youruser:yourgroup"` in docker-compose services.
   - Enable gVisor for sandboxing (install via Nix: `pkgs.gvisor`; configure in docker-compose with `runtime: gvisor` for code executor).
   - Monitor logs and update regularly: Pull repo changes and rebuild.

### Option 2: Run Natively from Source (More Control, But Complex)
This runs RAGFlow's Python backend and Node.js frontend directly, with Docker only for dependencies. It's more secure for auditing the core app, but requires managing a Python venv.

1. **Prepare NixOS Environment**:
   - Add packages to `configuration.nix`:
     ```
     environment.systemPackages = with pkgs; [
       git python312 python312Packages.pipx nodejs npm jemalloc  # jemalloc for performance/security
     ];
     ```
   - Rebuild and set env: `export LD_PRELOAD=${pkgs.jemalloc}/lib/libjemalloc.so`.
   - Install uv and pre-commit: `pipx install uv pre-commit` (or use Nix equivalents if available).

2. **Setup Dependencies**:
   ```
   git clone https://github.com/infiniflow/ragflow.git
   cd ragflow
   uv sync --python 3.12  # Installs Python deps in .venv
   uv run download_deps.py  # Downloads additional deps
   pre-commit install
   ```
   - If HuggingFace access issues: `export HF_ENDPOINT=https://hf-mirror.com`.
   - Edit `conf/service_conf.yaml` for LLM keys, etc.

3. **Launch Dependent Services (Still Uses Docker)**:
   ```
   cd docker
   cp .env.example .env  # Edit as needed
   docker compose -f docker-compose-base.yml up -d
   ```
   - Add to `/etc/hosts`: `127.0.0.1 es01 infinity mysql minio redis sandbox-executor-manager`.

4. **Launch Core Services**:
   - Backend: `source .venv/bin/activate && export PYTHONPATH=$(pwd) && bash docker/launch_backend_service.sh`.
   - Frontend: `cd web && npm install && npm run dev`.
   - Access frontend at `http://localhost:5173` (dev mode; for production, build with `npm run build` and serve statically).

5. **Stop and Security**:
   - Stop: `pkill -f "ragflow_server.py|task_executor.py"`; `docker compose -f docker-compose-base.yml down`.
   - Enhancements: Use Nix's Python overlays for pinned, hashed dependencies to avoid pip supply chain issues. Run backend under a dedicated user with `systemd` service for isolation. Enable gVisor in the Docker base compose for deps.

If neither fits, consider packaging RAGFlow as a Nix module (derivation for Python/Node deps), but that's custom work—start with the repo's setup.py and web/package.json. For ultimate security, air-gap the setup and verify all downloads' hashes from the repo. Check the project's Discord or issues for community tips on secure deploys.
