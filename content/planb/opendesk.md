---
title: 'opendesk'
weight: 200
draft: false
---

**OpenDesk** (often stylized as **openDesk**) is the German federal government's sovereign, open-source digital workplace suite, developed and maintained by **ZenDiS** (Zentrum für Digitale Souveränität in der öffentlichen Verwaltung), a publicly owned GmbH under the Federal Ministry of the Interior (BMI). Launched around 2024 (with version 1.0 in October 2024), it serves as a secure, EU-sovereign alternative to Microsoft 365 or Google Workspace for public administrations.

It integrates mature open-source tools into a unified, customizable platform:

- **File storage & sharing** → Nextcloud
- **Collaborative office editing** → Collabora Online (or similar LibreOffice-based)
- **Knowledge/wiki/docs** → XWiki
- **Project & task management** → OpenProject
- **Encrypted collaborative editing** → CryptPad
- **Secure chat/messaging** → Element (Matrix-based)
- **Video conferencing** → Jitsi Meet
- **Email/messaging** → Integrated or via compatible components (often with external SMTP/IMAP relays for full email)
- **Single sign-on & portal** → Custom frontend with Keycloak or similar for OIDC

The full suite emphasizes **digital sovereignty** (data residency in Germany/EU, no foreign jurisdiction access), **transparency** (fully open-source), **BSI C5 compliance** (German federal cloud security standard), and **GDPR/DSGVO** alignment. It's used by German federal ministries, state governments (e.g., MPK conferences), and even international bodies like the ICC.

**Important**: Like LaSuite, openDesk is **not** a single app but a **composed stack**. Official deployments use **Kubernetes** (often via Helm charts or helmfile) for production. Self-hosting is fully supported via the community edition on **Open CoDE** (Germany's public GitLab instance at gitlab.opencode.de).

### How to deploy as securely as possible (step-by-step, maximum sovereignty & hardening)

To match or exceed official deployments (e.g., those on IONOS, STACKIT, or Sovereign Cloud Stack), prioritize German/EU-certified infrastructure, audited open-source components, and zero-trust principles.

#### 1. Choose sovereign & certified infrastructure (critical for true sovereignty)
- **Best option**: German/EU **BSI C5-certified** or **EUCS** (EU Cloud Services) Level High cloud:
  - **STACKIT** (Schwarz Group, used in recent MPK deployments)
  - **IONOS Cloud** (C5-certified, used in early pilots)
  - **Open Telekom Cloud** (T-Systems, sovereign zones)
  - **Sovereign Cloud Stack (SCS)** → Open-source Kubernetes distro for sovereign clouds (see opendesk-on-scs guide)
- On-premises: Bare-metal or private cloud in Germany with BSI-compliant segmentation, HSM for keys, and physical access controls.
- Avoid non-EU clouds (even "sovereign" Azure/GCP zones reduce full sovereignty).
- Use dedicated VPCs, private subnets, no public IPs for core services, and zero-trust network access (e.g., via SPIFFE/SPIRE or mTLS).

#### 2. Source code & deployment artifacts (official & verifiable)
- Main repo: https://gitlab.opencode.de/bmi/opendesk (core orchestration, Helm charts)
- Community edition: https://gitlab.opencode.de/bmi/opendesk/info
- SCS-specific guide: https://github.com/SovereignCloudStack/opendesk-on-scs (excellent for Kubernetes deployment)
- Helm charts are signed with GPG keys → verify signatures before install.
- Clone from official sources only — never use unofficial mirrors or Docker Hub images.

#### 3. Authentication & identity (zero-trust base)
- Use **Keycloak** (included or external) with mandatory **MFA** (TOTP, WebAuthn/hardware keys).
- Support for German **BundID** or institutional IdPs via OIDC/SAML.
- Enforce strong policies: short sessions, IP restrictions, device certificates if possible.
- All components (Nextcloud, Element, Jitsi, etc.) integrate via SSO.

#### 4. Deployment methods (production-ready)
**Kubernetes + Helm/helmfile** is the official/recommended way for scale and security:

1. Get a compliant K8s cluster (e.g., via SCS, STACKIT, or self-managed with kubeadm + security hardening).
2. Clone repo: `git clone https://gitlab.opencode.de/bmi/opendesk`
3. Use helmfile (preferred in many guides) or direct Helm:
   - Install helmfile if needed.
   - Customize `helmfile/environments/.../values.yaml` (or sample.gotmpl): set domains, secrets, storage classes, ingress, etc.
   - Run `helmfile sync` or `helm install/upgrade`.
4. Alternative: Docker Compose for testing/small setups (not production).
5. GitOps: Use FluxCD or ArgoCD to manage deployments declaratively.

Expose only via ingress controller (e.g., NGINX with mTLS, cert-manager for Let's Encrypt/internal CA).

#### 5. Hardening & security controls (apply everywhere)
- **Containers**:
  - Non-root users, read-only root FS, drop all capabilities.
  - Seccomp/AppArmor/SELinux profiles.
  - Pod Security Admission: enforce **restricted** or **baseline** policies.
- **Network**:
  - Kubernetes NetworkPolicies: deny-all + explicit allows.
  - mTLS between services (Istio or cert-manager + Linkerd).
  - WAF (ModSecurity, Coraza) + rate limiting.
- **Data protection**:
  - Encryption at rest: provider-managed (e.g., STACKIT) or CSI drivers with LUKS.
  - Encryption in transit: TLS 1.3 only, HSTS, certificate pinning.
  - Encrypted backups (offsite, tested, air-gapped if sensitive).
- **Secrets management**:
  - Never hardcode → Use external-secrets-operator + HashiCorp Vault, or Sealed Secrets.
  - Helm: Avoid `--set` literals for secrets; use sops/age-encrypted values files.
- **Image security**:
  - Scan with Trivy/Grype in CI/CD.
  - Pin versions, use distroless/minimal base images where possible.
  - Sign images (cosign/sigstore).
- **Updates & patching**:
  - Automate with Renovate/Dependabot + CI/CD.
  - Weekly rebuilds, monitor advisories (BSI, CVE feeds).
- **Monitoring & observability**:
  - Prometheus + Grafana + Loki (centralized).
  - Falco or similar for runtime threat detection.
  - Audit logs to SIEM.
- **Additional**:
  - Regular pentests (BSI-style).
  - Static analysis (SonarQube).
  - Compliance with BSI "IT-Grundschutz" or "C5" controls.

#### 6. Operational security & governance
- Automate with GitOps (Flux/ArgoCD).
- Least-privilege RBAC + regular reviews.
- Disaster recovery tested quarterly.
- For public-sector: Consider BSI certification path or external audit.
- Join community: Open CoDE issues, ZenDiS channels.

#### Summary: Maximum security checklist
- Infra → BSI C5 / EU sovereign cloud (STACKIT, IONOS, SCS).
- Auth → Keycloak + MFA + institutional IdP.
- Deployment → Official GitLab repo + helmfile on hardened K8s.
- Hardening → Restricted PSA, mTLS, encrypted everywhere, external secrets.
- Ops → GitOps, auto-updates, scanning, monitoring.
- Responsibility → Self-hosted instances are your responsibility (as with any open-source stack).

For public administrations, contact ZenDiS via https://www.opendesk.eu/en/contact or book a demo — they provide guidance, pilots, and sometimes managed hosting. For self-host/private use, start with the SCS guide (https://github.com/SovereignCloudStack/opendesk-on-scs) or quickstart in the repo — it's one of the best-documented paths.

This setup delivers security comparable to (or better than) official German government instances while remaining fully sovereign and open-source. If you need help with a specific component (e.g., helm values for Nextcloud or Jitsi hardening), share your target scale/infra!
