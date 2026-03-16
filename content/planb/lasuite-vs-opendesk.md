---
title: 'lasuite-vs-opendesk'
weight: 200 
draft: false
---

**Suite Numérique** (also called **La Suite** or **La Suite numérique**) and **openDesk** are both major European open-source initiatives aimed at creating sovereign digital workplaces as alternatives to Microsoft 365 and Google Workspace. They target public administrations with a strong emphasis on **data sovereignty**, GDPR compliance, security, and independence from non-EU tech giants. Both emerged in the mid-2020s as part of national strategies for digital autonomy.

### Suite Numérique (France)
- **Origin & Governance** — Developed and operated by **DINUM** (Direction interministérielle du numérique), under the French Prime Minister's authority, with involvement from ANCT (for territorial adaptations) and partnerships (e.g., Mistral AI for features).
- **Approach** — Mix of integrating mature open-source tools and **building new custom components** from scratch (often MIT-licensed, fully auditable code on GitHub under organization `suitenumerique`). Focuses on modern, user-friendly web apps designed specifically for public sector needs.
- **Key Components** (as of early 2026):
  - **Docs** — Collaborative text editor (custom-built, Django + React backend/frontend).
  - **Visio** — Secure videoconferencing (custom, replacing Zoom/Teams; being generalized across the French state by 2027, with features like AI transcription).
  - **Fichiers / Drive** — File storage and sharing.
  - **Tchap** — Instant messaging (based on **Element/Matrix**).
  - **Grist** — Spreadsheet/data management.
  - **Assistant IA** — Integrated AI chatbot (powered by Mistral AI).
  - Single sign-on via **ProConnect**.
- **Target & Deployment** — Primarily French public agents (ministries, local authorities, hospitals, etc.). Already serving hundreds of thousands (e.g., 200,000+ users for Visio pilots). Hosted on sovereign French clouds (e.g., SecNumCloud). Also available as open-source for self-hosting or adaptation (e.g., **Suite territoriale** for local governments).
- **Strengths** — Highly integrated, modern UX, strong focus on high-security environments (e.g., adaptations for Défense ministry), rapid feature additions (like native AI), and direct state control over core tools.

### openDesk (Germany)
- **Origin & Governance** — Led by **ZenDiS** (Zentrum für Digitale Souveränität der öffentlichen Verwaltung), a federal government-owned entity under the BMI (Ministry of the Interior). Enterprise Edition supported by partners like B1 Systems and STACKIT.
- **Approach** — **"Best-of-breed" integration** — assembles and deeply integrates existing mature open-source projects into one unified portal (Nubus interface) with single sign-on. Avoids reinventing the wheel; funds improvements to upstream projects.
- **Key Components** (as of 2026):
  - **Nextcloud** — File storage, sync, and sharing (core file hub).
  - **Collabora Online** — Real-time document editing (Word/Excel/PowerPoint compatible).
  - **Element / Matrix** — Chat and communications.
  - **Jitsi** (or similar) — Videoconferencing.
  - **OpenProject** — Project/task management (Gantt, issues).
  - **XWiki** — Knowledge base/wiki.
  - **Open-Xchange** — Groupware (email, calendar).
- **Target & Deployment** — German public administration (federal, states/Länder, municipalities). Community Edition fully open-source; Enterprise Edition offers SaaS/hosted options. Pilots and rollouts in multiple German states.
- **Strengths** — Leverages proven, battle-tested tools (many already widely used), modular/flexible (swap or upgrade components), strong ecosystem support from vendors (Nextcloud, Collabora, etc.).

### Key Comparison

| Aspect                  | Suite Numérique (France)                      | openDesk (Germany)                            |
|-------------------------|-----------------------------------------------|-----------------------------------------------|
| **Primary Developer**   | DINUM (French state agency)                   | ZenDiS (German federal agency)                |
| **Philosophy**          | Build custom + integrate existing (some from-scratch apps) | Integrate & enhance existing mature OSS projects |
| **Core File Tool**      | Custom "Fichiers/Drive"                       | Nextcloud (very mature)                       |
| **Document Editing**    | Custom "Docs"                                 | Collabora Online                              |
| **Videoconferencing**   | Custom "Visio" (strong push for generalization) | Jitsi + Element integrations                  |
| **Chat/Messaging**      | Tchap (Element/Matrix)                        | Element/Matrix                                |
| **Project Mgmt**        | Limited/native (some via Grist)               | OpenProject (dedicated & powerful)            |
| **Knowledge Base**      | Emerging/integrated                           | XWiki (very strong)                           |
| **Email/Groupware**     | Partial/in development                        | Open-Xchange                                  |
| **AI Integration**      | Built-in Assistant (Mistral AI)               | Less emphasized (as of 2026)                  |
| **Maturity/Scale**      | Rapid growth in France (200k+ users in pilots) | Expanding in Germany, strong vendor backing   |
| **Licensing**           | Mostly MIT, fully open                        | Open-source (components + integrations)       |
| **European Cooperation**| Collaborates with openDesk (shared components like Matrix) | Collaborates with La Suite (e.g., Docs in openDesk ecosystem) |

### In Short (March 2026 Perspective)
- Choose **Suite Numérique** if you're in France (or need French-state-aligned tools), prioritize a tightly unified modern interface, native AI features, or high-security custom videoconferencing (Visio is being mandated across French public services).
- Choose **openDesk** if you prefer leveraging ultra-mature components (especially Nextcloud + Collabora), need strong project management (OpenProject), or want maximum modularity/flexibility for large-scale public-sector deployments in Germany/EU.

Both projects actively collaborate (e.g., shared Matrix/Element, Docs appearing in openDesk contexts), contributing to a broader **European sovereign workspace** ecosystem. They're not direct competitors but complementary national efforts toward the same goal: digital independence for public administrations.
