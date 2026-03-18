---
title: 'opencve'
draft: false
weight: 1500 
---
**OpenCVE** (at https://www.opencve.io/) is an open-source **vulnerability intelligence platform** designed to help security teams (SecOps, DevSecOps, IT security professionals, and organizations of all sizes) monitor, manage, and stay ahead of **Common Vulnerabilities and Exposures (CVEs)** efficiently.

It's essentially a centralized tool for **CVE tracking and alerting**, aggregating data from multiple authoritative sources and providing features to filter, prioritize, subscribe to, and collaborate on vulnerabilities relevant to your software stack (vendors, products, libraries, etc.).

### Main Purpose
In a world where thousands of new CVEs are published every year (often hundreds per week), keeping track manually is overwhelming. OpenCVE acts as a "central hub" to:
- Pull in fresh vulnerability data automatically.
- Let you subscribe to specific vendors/products (e.g., "Intel processors", "Apache HTTP Server", "WordPress plugins").
- Get real-time alerts when new CVEs or updates match your subscriptions.
- Use AI to help identify impacted products and summarize priorities in daily reports.
- Track remediation progress with team assignments, custom statuses, and ownership.

It's built for both **solo users / small teams** and **large enterprises**, with a focus on reducing noise (false positives) and speeding up response times.

### Key Features (as of March 2026)
- **Multi-source aggregation** — Combines data from MITRE, NVD (National Vulnerability Database), RedHat, CISA (Known Exploited Vulnerabilities / KEV catalog), Vulnrichment, and others into one unified, up-to-date view.
- **Powerful filtering & search** — By vendor, product, CVSS score, EPSS (Exploit Prediction Scoring System), CWE (Common Weakness Enumeration), publication date, KEV status, severity, etc.
- **Subscriptions & Projects** — Organize vendors/products into independent "projects" (e.g., one per customer, department, or client in an MSP context). Each project can have its own dashboards, rules, and notifications.
- **Real-time alerts & notifications** — Instant alerts for new CVEs or changes via Email, Slack, Webhook. Unlimited delivery on all plans.
- **AI-powered daily reports** — Summarizes highest-priority issues (new alerts, high EPSS, KEV additions, etc.).
- **CVE lifecycle tracking** — Assign CVEs to team members, set custom statuses (e.g., "Under Review", "Patched", "Accepted Risk"), add tags, and visualize progress.
- **Custom dashboards** — Draggable widgets showing CVE activity, trends, tags, subscriptions, etc. Multiple dashboards supported.
- **API access** — For integrations, querying your exposure, or automation (rate limits vary by plan).
- **Exports & audit logs** — CSV exports, logs for compliance (stronger in higher tiers).

### Deployment Options
- **SaaS (hosted at opencve.io)** — Easiest: sign up, no setup needed. Free tier available.
- **Self-hosted / On-premise** — Fully open-source (GitHub: https://github.com/opencve/opencve), Python-based. Free to use under its license, but commercial on-premise use (e.g., reselling or internal enterprise without SaaS) may require contacting them for a license.

### Pricing (as of March 2026)
Tiered SaaS plans (monthly or yearly, with discounts for annual):
- **Free** — $0: 1 project, 1 user, 5 subscriptions, basic features, 100 API calls/hour.
- **Starter** — $19/month: 3 projects, 3 users, 15 subscriptions.
- **Pro** — $49/month: 10 projects/users/subscriptions (expandable), 12-month report retention, higher API limits.
- **Enterprise** — $299/month: Unlimited everything, 24-month retention, priority support.

Higher plans add features like longer history, more API capacity, advanced audit logs, etc.

### Who Uses It?
- Security teams wanting better CVE visibility without paying for enterprise tools like Tenable, Qualys, or Rapid7 InsightVM.
- Small businesses, MSSPs (managed security providers), or consultants tracking client-specific software.
- Open-source enthusiasts or teams preferring self-hosted solutions.
- It's mentioned positively in cybersecurity communities (e.g., Reddit threads on CVE alerting tools) as a free/affordable alternative for subscriptions and notifications.

In short, if you need to monitor CVEs for specific software without drowning in generic feeds, and want alerts + team workflow features, OpenCVE is a modern, flexible option — especially strong for its open-source roots and AI-assisted prioritization.

Official docs: https://docs.opencve.io/  
GitHub repo: https://github.com/opencve/opencve (active development, recent releases like v2.4.0 in 2025 added multi-dashboards, CSV exports, etc.)

