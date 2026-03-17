---
title: 'implement'
weight: 600 
draft: false
---
**To implement MijnBureau (the Dutch government's open-source collaboration suite, also known as part of the OpenDesk ecosystem in the EDIC/DC-EDIC framework) on a Kubernetes cluster in Belgium, you have several strong, locally focused options.**  

MijnBureau/OpenDesk deploys via Infrastructure-as-Code (Helm charts or helmfile) on any standard CNCF-certified Kubernetes cluster (v1.24+). It works best on production-grade or "Haven-compliant" setups (a Dutch/EU security profile for public sector), but even lightweight options like K3s are supported with official guides. No hyperscaler lock-in is required — the whole point of EDIC-style digital commons is sovereignty and self-hosting.

Here are the practical options available **in Belgium** (data residency in Belgian data centres, local support, GDPR/ISO compliance):

### 1. Combell Managed Kubernetes (Best for quick, fully managed production rollout)
- **Belgian company** with its own data centres in Belgium (Benelux focus).
- Fully managed service (two tiers: "Start" entry-level and "Full" enterprise).
- Key features: autoscaling, 99.999 % uptime, auto-HTTPS, Helm pre-installed, CI/CD integration (GitLab/GitHub), logging (Elasticsearch + Kibana), monitoring/alerts, dedicated IP, Harbor registry, and staging environments.
- Perfect fit for MijnBureau: experts help containerise and deploy multi-component open-source suites; you just apply the official Helm charts.
- Compliance: ISO 27001, ISO 27701, GDPR-native — ideal for public-sector or sovereign use.
- Pricing: fixed monthly (no surprises), with discounts on entry plans.
- Why it fits Belgium/EDIC: Local control, no US-cloud dependency, fast setup.

### 2. Proximus Private Cloud / NXT (Best for Gaia-X sovereignty and large-scale/public-sector alignment)
- **Belgium’s national telecom/cloud provider** and official Gaia-X member (they run the Belgian Gaia-X Digital Clearing House).
- You deploy your own Kubernetes clusters (or use their container platform) inside a virtual private cloud on redundant Belgian data centres (Evere + Machelen).
- Supports Red Hat OpenShift and MicroK8s natively; they run OpenShift in production internally.
- Full data sovereignty in Belgium + direct Gaia-X compliance path (trust framework, secure data exchange).
- Tailored for large organisations and public sector — exactly the scale of GendBuntu or EDIC rollouts.
- Not "fully managed Kubernetes" like Combell (you handle more of the cluster ops), but Proximus infrastructure + optional professional services give you Belgian-hosted, sovereign K8s with national backing.

### 3. Econocom Managed Kubernetes (Enterprise-grade alternative, Belgian operations)
- Belgian-focused IT services provider offering fully managed Kubernetes based on **Red Hat OpenShift**.
- End-to-end management (installation, upgrades, security, monitoring) — they operate the cluster for you.
- Can run in their data centres, your own colocation, or hybrid.
- Strong on cost control (capex/opex models) and multi-cloud portability if you ever expand.
- Good for organisations without deep in-house K8s expertise who still want Belgian/EU control.

### 4. Self-managed / on-premises in Belgian data centres (Maximum sovereignty, GendBuntu-style)
- Use any Belgian colocation or dedicated server provider (Combell DCs, LCL Brussels, or others) and install:
  - Plain Kubernetes
  - Lightweight K3s (official OpenDesk guide exists)
  - Or OpenShift
- Deploy the official MijnBureau/OpenDesk IaC repo directly.
- Full control, no vendor in the middle — exactly how the Dutch government and French Gendarmerie run their stacks long-term.
- Combine with Proximus connectivity or Gaia-X labelling for extra sovereignty.

### Quick recommendation based on context
- Want **fast & hands-off** (like a public administration pilot)? → **Combell Managed Kubernetes**.
- Want **maximum EU digital sovereignty + Gaia-X tie-in** (EDIC/Season 2.0 spirit)? → **Proximus Private Cloud** (or combine with their services).
- Need **enterprise OpenShift support**? → **Econocom** or Proximus OpenShift path.
- All options keep data in Belgium, support Helm-based MijnBureau deployment, and avoid the "post-project sustainability" trap that killed earlier migrations.

