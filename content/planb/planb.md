---
title: 'planB'
weight: 50
draft: false
---

**'Plan B': Gaining Insight into Potential Alternative Platforms for Office 365**

Assessing alternatives to Office 365 requires more than desk research and comparing features and prices. Building a minimum level of expertise is essential: setup, ease of use, maintenance, cost, functionality, interoperability, etc. To achieve this, the alternatives should be effectively installed and tested on a server.

Possible alternatives:

- LaSuite (for the French government)
- OpenDesk (for the German government)
- Nextcloud
- Geens.com – Belgian

### Overview of Alternatives to Office 365

Your "Plan B" focuses on building hands-on expertise through actual installation and testing. As an AI, I cannot install software myself, but I can provide detailed, up-to-date insights based on current sources (as of March 2026), including setup guidance, comparisons, and recommendations for practical evaluation. The options listed — LaSuite (French), OpenDesk (German), Nextcloud (open-source, widely adopted), and Geens.com (Belgian) — are primarily open-source or self-hostable, aligning well with the need to deploy them on your own server.

I structure the information per alternative, emphasizing setup, ease of use, maintenance, costs, functionality, and interoperability. At the end, you'll find a comparison table. For installation: Start with a test server (e.g., Linux VM via VirtualBox, Proxmox, or a cloud instance on Hetzner, AWS, or Scaleway). Always implement backups, firewalls, HTTPS (Let's Encrypt), and security best practices.

#### 1. LaSuite (French government sovereign suite)
LaSuite is an open-source, sovereign digital workspace developed by the French government (DINUM) for the public sector. It prioritizes digital sovereignty, with data hosted in France/EU, and is already in use by hundreds of thousands of civil servants. It is not an exact clone of Office 365 but offers comparable core tools with a strong focus on security, simplicity, and independence from Big Tech.

- **Functionality**: Core tools include secure chat (Tchap – Matrix-based, similar to Teams), video conferencing (Visio – replacing Zoom/Teams), large file transfer (FranceTransfert), email (Messagerie), file storage/sharing (Fichiers), collaborative document editing (Docs – content-focused, lightweight), spreadsheets/databases (Grist), and AI features (transcription, summarization, automation).
- **Interoperability**: Supports import/export of Microsoft formats (.docx, .xlsx, .pptx, .odt). Good for migrating Office 365 documents via format conversion. Uses open standards (e.g., Matrix for chat). Can run alongside existing tools but no direct real-time sync with Microsoft services.
- **Setup and Installation**:
  - Primarily offered as a managed service for French public entities, but fully open-source and self-deployable.
  - Steps: Clone repositories from GitHub (github.com/suitenumerique or related). Deploy on Linux (Ubuntu/Debian recommended). Dependencies include Matrix, LiveKit (for Visio), Grist. Use Docker Compose for easier deployment. Start with a pilot: set up core components (e.g., Tchap + Visio), configure authentication (ProConnect for official use), and test with a small group.
  - Documentation: Available on lasuite.numerique.gouv.fr, plus community resources, webinars, and FOSDEM talks (e.g., 2026 presentations on foundational libraries like BlockNote and Yjs).
- **Ease of Use**: Intuitive and fast interface, praised for simplicity and speed (e.g., quick transcription). Lower learning curve than feature-heavy suites.
- **Maintenance**: Managed by DINUM with community contributions. For self-hosted: follow GitHub releases for updates, apply security patches promptly. Strong GDPR compliance and accessibility focus.
- **Costs**: Open-source (free license). Self-hosting: server costs ~€50–200/month for small teams. Managed/mutualized options for public sector are significantly cheaper than Office 365 (e.g., up to 3× savings reported). Full Visio rollout across French government departments targeted for 2027.

#### 2. OpenDesk (German government sovereign workplace)
OpenDesk is an open-source, integrated suite for public administration, initiated by Germany's Federal Ministry of the Interior via ZenDiS (Center for Digital Sovereignty). It serves as a "sovereign workplace" alternative to Microsoft/Google, with deployments in federal ministries, state governments, and even the International Criminal Court.

- **Functionality**: Comprehensive: file storage/sharing (Nextcloud-based), real-time document editing (Collabora/ONLYOFFICE), chat/video (Matrix/Element + Jitsi), project management (OpenProject), email/calendars, spreadsheets/databases (CryptPad), and more. Modular and privacy-first.
- **Interoperability**: Excellent support for Microsoft formats via Collabora. Designed for gradual migration (can coexist with Office 365). Open standards enable integration with legacy systems.
- **Setup and Installation**:
  - Fully self-hosted. Download bundles/components from opendesk.eu or GitHub.
  - Steps: Linux server (Debian/Ubuntu). Use Docker/Kubernetes. Start with Nextcloud + Collabora as base, add modules (Jitsi, OpenProject). ZenDiS provides architecture guidance and framework contracts. Pilot: deploy for 10–50 users.
  - Documentation: Component-specific (e.g., nextcloud.com/docs), plus ZenDiS resources (zendis.de).
- **Ease of Use**: User-friendly with customizable interface. Low learning curve for Office 365 users. Strong emphasis on transparency and sovereignty.
- **Maintenance**: Community + ZenDiS-driven updates. Self-hosted requires patch monitoring (use Ansible for automation). GDPR-compliant by design.
- **Costs**: Open-source (free). Self-hosting: ~€100–500/month depending on scale. No per-user licensing fees → significantly cheaper than Office 365 long-term. Adoption target: ~160,000+ users in German public sector by end-2025/2026.

#### 3. Nextcloud
Nextcloud remains one of the most mature open-source collaboration platforms and a direct alternative to Office 365 for many organizations (including governments and enterprises).

- **Functionality**: Full suite — file sync/share (OneDrive-like), Talk (chat/video/Teams-like), Groupware (email/calendar/contacts/Outlook-like), online office editing (Collabora or ONLYOFFICE for docs/spreadsheets/presentations), AI Assistant (summaries, translations, image generation), workflow automation (Flow), and more. Real-time collaboration included.
- **Interoperability**: Native support for .docx/.xlsx/.pptx editing and import. Desktop/mobile sync clients. Can integrate with existing tools (e.g., Outlook via plugins). No vendor lock-in.
- **Setup and Installation**:
  - Self-hosted (or hosted providers). Download from nextcloud.com/install.
  - Steps: Linux (Ubuntu recommended). Easiest: `sudo snap install nextcloud`. Web-based setup (domain, MariaDB/PostgreSQL, HTTPS). Add apps from store (Office, Talk, etc.). Test on small scale (Raspberry Pi → full server/cluster).
  - Documentation: Excellent (docs.nextcloud.com — install, admin, security guides). Free trial instances available.
- **Ease of Use**: Modern, cross-platform apps (web/mobile/desktop). Transparent and straightforward.
- **Maintenance**: Frequent community updates (free), optional enterprise support. Regular security releases. Strong compliance (GDPR, HIPAA).
- **Costs**: Core free. Self-hosting: ~€50–300+/month (infrastructure). Enterprise support ~$3–5/user/month (3-year TCO much lower than Office 365's $24–46/user/month).

#### 4. Geens.com (Belgian)
Geens.com is a Belgian privacy-focused platform emphasizing end-to-end encrypted, zero-knowledge storage with blockchain timestamping. It is not a full Office 365-style collaboration suite.

- **Functionality**: Secure document storage/sharing (encrypted vault), anonymity features. No built-in chat, video, email, or real-time editing.
- **Interoperability**: Basic file upload/download. Supports common formats but no collaborative editing.
- **Setup**: Hosted service (no self-hosting). Register at geens.com.
- **Ease of Use**: Simple for personal secure storage, but limited scope.
- **Maintenance**: Fully managed by provider.
- **Costs**: Freemium (1 GB free encrypted storage; premium plans ~€5–10/month). Not comparable to full suites.

**Recommendation**: If full collaboration is needed, prioritize Nextcloud (easiest to start with) or OpenDesk/LaSuite for sovereignty focus. Test interoperability by importing Office 365 files. Use Docker for quick prototypes.

### Comparison Table

| Aspect              | LaSuite                              | OpenDesk                             | Nextcloud                            | Geens.com                            |
|---------------------|--------------------------------------|--------------------------------------|--------------------------------------|--------------------------------------|
| **Functionality**   | Chat, video, files, docs, spreadsheets, email, AI | Files, editing, chat/video, project mgmt, email | Files, chat/video, calendar/email, office editing, AI, workflows | Secure encrypted storage/sharing (limited) |
| **Interoperability**| MS formats, open standards           | MS formats, modular                  | MS formats, app integrations         | Basic files                          |
| **Setup**           | Self-deploy (GitHub), contact DINUM  | Self-host (Docker), component-based  | Snap install on Linux, web config    | Hosted, no install                   |
| **Ease of Use**     | Intuitive, fast                      | Customizable, low learning curve     | Cross-platform, straightforward      | Basic, limited                       |
| **Maintenance**     | DINUM + community                    | ZenDiS + community                   | Community updates                    | Provider-managed                     |
| **Costs**           | Free OSS, self-host ~€50–200/m       | Free OSS, self-host ~€100–500/m      | Free OSS, self-host ~€50–300/m       | Freemium ~€5–10/m                    |

Expertise:  Nextcloud (simplest install). Test file migration and real-world workflows. 

