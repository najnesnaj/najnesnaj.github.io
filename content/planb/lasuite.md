---
title: 'lasuite'
weight: 100 
draft: false
---

**LaSuite (La Suite numérique)** is an open-source, sovereign digital workspace developed by the French government’s DINUM (Direction interministérielle du numérique) in collaboration with ANCT and European partners (e.g., Germany, Netherlands). It provides a full set of collaborative tools as a secure alternative to proprietary suites like Microsoft 365 or Google Workspace.

It is designed primarily for French public agents (used by >500,000 monthly across 15+ ministries) but is fully open-source (mostly MIT/AGPL/Apache licenses) so any organization or individual can self-host their own instance under their own responsibility. Official instances run on **SecNumCloud-qualified** French infrastructure with RSSI audits, bug bounties, and data residency in France (suitable for sensitive administrative data under SREN law, but not “Diffusion Restreinte” or health data).

**Important**: LaSuite is **not a single monolithic application**. It is a modular suite of independent tools. You deploy each component separately (or the ones you need) and integrate them via single sign-on (SSO). Core self-hostable open-source components include:

- **Docs** (collaborative editor/wiki, like Notion) → https://github.com/suitenumerique/docs
- **Meet** (video conferencing, like Visio) → https://github.com/suitenumerique/meet (powered by LiveKit)
- **Drive** (file storage/sharing) → https://github.com/suitenumerique/drive
- **Messages** (collaborative inbox) → https://github.com/suitenumerique/messages
- **People** (user & team management) → https://github.com/suitenumerique/people
- **Grist** (spreadsheets/databases) → https://github.com/betagouv/grist-core
- **Tchap** (secure messaging, Matrix-based) → https://github.com/tchapgouv (under separate org)
- Others (FranceTransfert, Webconf based on Jitsi, etc.)

Non-open-source parts (e.g., Resana) cannot be self-hosted.

### How to deploy as securely as possible (step-by-step)

To achieve **maximum security** (sovereignty + hardening comparable to official DINUM instances), follow this layered approach. The goal is to replicate the official model: French/EU data residency, audited open-source code, strong isolation, and zero-trust principles.

#### 1. Choose sovereign & certified infrastructure (most critical for sovereignty)
- **Best option**: Deploy on a **SecNumCloud-qualified** French cloud provider (e.g., Outscale, OVHcloud SecNumCloud, Scaleway, etc.). This is exactly what the official DINUM instance uses and gives you the highest assurance for French public data.
- Alternative: On-premises bare-metal or private cloud in France with physical security, ANSSI-compliant segmentation, and hardware security modules (HSM) for keys.
- Avoid foreign clouds (AWS, Azure, GCP) unless you use their EU sovereign zones with strict controls — but this reduces sovereignty.
- Use dedicated VPCs, private subnets, and zero-trust network access (no public IPs where possible).

#### 2. Authentication & identity (zero-trust foundation)
- Integrate **ProConnect** (French government SSO) if your organization is eligible — this is the official, MFA-enabled, certified identity provider.
- Otherwise, use a self-hosted OIDC provider (Keycloak, Authelia, or Ory) with mandatory MFA, hardware keys (Yubikey), and strong password policies.
- Centralize users with the **People** app or an external directory (LDAP/SCIM).
- All tools support OIDC/OAuth2 out of the box.

#### 3. Deployment methods (official recommendations)
Each repo provides production-ready setups:
- **Docker Compose** — for small/medium deployments (quick start).
- **Kubernetes** (recommended for production/scale) — with Helm charts or manifests in some repos (e.g., Docs has full K8s support + bin/ scripts).
- Community options: Nix, YunoHost (for simpler setups).

**Example workflow for Docs** (the most complex/central tool):
1. Clone `https://github.com/suitenumerique/docs`
2. Use the provided `compose.yml` (or K8s manifests in the repo).
3. Configure environment variables securely:
   - Database (PostgreSQL) with encryption at rest.
   - Redis for cache/sessions.
   - Storage backend (S3-compatible on SecNumCloud).
   - Set `DEBUG=false`, strong secrets, TLS termination.
4. Run with `docker compose up -d` (or `kubectl apply`).
5. Expose only via reverse proxy (Traefik, Nginx, or Caddy with automatic Let’s Encrypt or internal CA).

Repeat for Meet (LiveKit server + frontend), Drive, etc. Use the shared **integration** package (`@gouvfr-lasuite/integration`) for consistent UI/SSO across tools.

#### 4. Hardening & security controls (apply to every component)
- **Containers**: Always run as non-root user, enable seccomp/AppArmor/PodSecurityPolicies, read-only root filesystem, drop all capabilities.
- **Network**: Kubernetes NetworkPolicies or Docker networks; WAF (ModSecurity or Cloudflare Zero Trust); only expose 443 (HTTPS). Use mTLS between services.
- **Data protection**:
  - Encryption at rest (LUKS, filesystem-level, or provider-managed on SecNumCloud).
  - Encryption in transit (TLS 1.3 mandatory).
  - Database encryption + regular encrypted backups (offsite, tested).
- **Secrets**: Never in env vars or code — use Docker secrets, Kubernetes Secrets + external vault (HashiCorp Vault or AWS Secrets Manager equivalent on French cloud), or sealed secrets.
- **Updates & patching**: Subscribe to GitHub releases. Automate with Renovate or Dependabot + CI/CD. Rebuild images weekly. Monitor CVEs with Trivy or Grype.
- **Monitoring & logging**: Centralized logs (ELK or Loki) + metrics (Prometheus/Grafana). Send alerts to SIEM. Enable audit logging in every tool.
- **Additional**: Regular penetration tests (or bug bounty), static code analysis (SonarQube), and compliance with ANSSI “30 règles” or “Guide d’hygiène informatique”.

#### 5. Operational security & governance
- Automate everything with GitOps (ArgoCD/Flux).
- Implement least-privilege RBAC and regular access reviews.
- Test disaster recovery quarterly.
- If you handle sensitive data, consider external security audit (DINUM-style) and publish results transparently (as the project does).
- Join the community (Matrix rooms via Tchap or GitHub discussions) and contribute improvements.

#### 6. Optional integration for a full workspace
Deploy **People** + **Docs** + **Drive** + **Meet** + **Messages** behind a single reverse proxy with unified SSO. Use the official integration widgets for a coherent experience. Add Tchap for messaging and Grist for spreadsheets.

### Summary: Maximum security checklist
- Infrastructure → SecNumCloud or ANSSI-compliant on-prem.
- Auth → ProConnect or hardened OIDC + MFA.
- Deployment → Official Docker/K8s from suitenumerique repos (never random Docker Hub images).
- Hardening → Non-root, secrets vault, encryption everywhere, network policies.
- Operations → Automated updates, monitoring, backups, audits.
- Responsibility → You are fully responsible for your instance (as stated by DINUM).

In case public-sector eligible:  first book a pilot meeting via the official site (https://lasuite.numerique.gouv.fr) — they can advise on architecture and security. For private/self-host setups, start with the Docs repository installation folder and scale from there.

This approach gives you a deployment as secure as (or better than) many official instances while remaining fully sovereign and open-source. 
