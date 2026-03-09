---
title: 'ragflow'
draft: false
weight: 600
---

Infiniflow/ragflow (RAGFlow) is Docker-based. It relies on Docker and Docker Compose for its primary deployment method, using pre-built images or custom builds to orchestrate services like MinIO for storage, Elasticsearch (or Infinity) for search, Redis for caching, and MySQL for the database. The official quickstart and documentation emphasize Docker as the recommended way to run it, with a docker-compose.yml file handling the multi-container setup.

To get it up and running on NixOS, you'll need to enable and configure Docker declaratively (as NixOS manages system services this way), meet the hardware prerequisites (≥4 CPU cores, ≥16 GB RAM, ≥50 GB disk), and follow the standard RAGFlow setup. Here's what it would take, step by step:

### 1. **Prepare Your NixOS Configuration**
   Edit `/etc/nixos/configuration.nix` (or your main config file) to enable Docker and set the required kernel parameter for Elasticsearch/Infinity. Add or modify these lines:

   ```
   { config, pkgs, ... }:

   {
     # Enable Docker
     virtualisation.docker.enable = true;

     # Set kernel sysctl for vm.max_map_count (required for Elasticsearch/Infinity)
     boot.kernel.sysctl = {
       "vm.max_map_count" = 262144;
     };

     # Install necessary packages system-wide (git for cloning, docker-compose for orchestration)
     environment.systemPackages = with pkgs; [
       git
       docker-compose
     ];

     # Optional: If you want to use gVisor for the sandboxed code executor feature
     # virtualisation.containers.enable = true;  # This enables containerd, which gVisor uses
     # Then install gVisor separately if needed: https://gvisor.dev/docs/user_guide/install/
   }
   ```

   - Run `sudo nixos-rebuild switch` to apply changes.
   - Add your user to the `docker` group for non-root access: `users.users.<your-username>.extraGroups = [ "docker" ];` (then rebuild and log out/in).
   - Reboot if sysctl changes don't apply immediately.

### 2. **Clone the RAGFlow Repository**
   ```
   git clone https://github.com/infiniflow/ragflow.git
   cd ragflow/docker
   ```

   - Optionally, switch to a specific version (e.g., latest stable): `git checkout v0.24.0` (check the repo for the current release).

### 3. **Configure Environment and Services**
   - Copy and edit the template files:
     ```
     cp .env.example .env
     cp service_conf.yaml.template conf/service_conf.yaml
     ```
   - In `.env`, set passwords and ports (e.g., `MYSQL_PASSWORD`, `MINIO_PASSWORD`). Defaults are fine for local testing.
   - In `conf/service_conf.yaml`, configure LLM API keys (e.g., for OpenAI, Grok, or local models via Ollama). Follow the [LLM setup guide](https://ragflow.io/docs/dev/llm_api_key_setup) for details.
   - Optional: Switch the document engine to Infinity (faster than Elasticsearch) by setting `DOC_ENGINE=infinity` in `.env`.

### 4. **Start the Services**
   ```
   docker-compose up -d
   ```

   - This pulls images and starts containers. Monitor with `docker-compose logs -f`.
   - Access the web UI at `http://localhost` (or your server's IP on port 80; change ports in docker-compose.yml if needed).
   - If issues arise (e.g., port conflicts), edit docker-compose.yml and restart: `docker-compose down && docker-compose up -d`.

### Potential NixOS-Specific Considerations
- **Networking/Firewall**: If using a firewall, open ports (e.g., `sudo firewall-cmd --add-port=80/tcp --permanent; sudo firewall-cmd --reload`). NixOS firewall is enabled via `networking.firewall.enable = true;`.
- **Storage**: Ensure your disk has space; NixOS's /nix/store can grow, so mount /var/lib/docker on a large partition if needed.
- **GPU Support**: If using NVIDIA GPUs for LLMs/embeddings, enable `hardware.nvidia.package` in your config and add `virtualisation.docker.enableNvidia = true;`.
- **Local LLMs**: For tools like Ollama, install it via Nix (e.g., `pkgs.ollama`) and configure RAGFlow's service_conf.yaml to point to it.
- **Troubleshooting**: If Docker doesn't start, check `journalctl -u docker.service`. For RAGFlow errors, refer to the [FAQ](https://ragflow.io/docs/dev/faq) or Discord community.
- **Alternatives**: If you prefer a pure Nix setup without Docker, you could build a Nix package/module for RAGFlow (involving Python deps like uv/pre-commit and manual service orchestration), but that's more complex and not officially supported—stick to Docker for simplicity.

This should get RAGFlow running reliably. If you hit issues, the project's docs or GitHub issues are good resources.
