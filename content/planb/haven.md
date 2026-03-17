---
title: 'haven'
weight: 600 
draft: false
---
**Talos** (more precisely **Talos Linux**) is a modern, open-source, **immutable**, and minimal Linux distribution specifically designed as an operating system **for running Kubernetes clusters**.

Developed by **Sidero Labs** (now often just referred to under the Talos project), it's built from the ground up to be:

- **Secure by default** — No SSH access (all management via a secure API), immutable root filesystem (prevents drift and unauthorized changes), full SBOM (Software Bill of Materials), signed commits, reproducible builds, SELinux enforcement, alignment with CIS benchmarks, and resistance to many common vulnerabilities (e.g., no xz utils, no SSH daemon).
- **Minimal** — Strips away unnecessary packages and services to reduce attack surface and improve performance.
- **API-driven and declarative** — Everything is configured via YAML manifests (like Kubernetes itself), with tools like `talosctl` for provisioning, upgrades, and management. No shell access needed on nodes.
- **Immutable and transactional** — Upgrades are atomic (rollback-capable), treating nodes as disposable.
- **Kubernetes-native** — Ships with upstream Kubernetes components; runs Kubernetes control plane and workers directly.

It runs on bare metal, VMs, clouds (AWS, Azure, GCP, etc.), edge devices, and even locally via containers. Popular for production clusters needing high security, consistency, and ease of operations.

### Is Talos a CNCF Certified Kubernetes Distribution?
**Yes, Talos Linux is CNCF-certified for Kubernetes conformance.**

- It passes the **Certified Kubernetes Conformance Program** tests, ensuring full compatibility with the Kubernetes API and standards.
- Official site and CNCF mentions confirm this (e.g., "Talos Linux is a Certified Kubernetes distribution").
- It also achieved **CNCF Kubernetes AI Conformance** certification in late 2025 for reliable AI/ML workloads.
- This means you can run standard Kubernetes workloads on Talos without compatibility issues, just like on other certified distros (e.g., vanilla kubeadm, Rancher RKE, etc.).

### What About "Haven Compliant" Kubernetes?
**Haven** refers to the Dutch **HAVEN** standard (from the Common Ground initiative), a set of requirements for secure, interoperable, and sovereign cloud/Kubernetes environments — especially for Dutch government and municipalities. It emphasizes:

- High availability, security hardening (e.g., SELinux/AppArmor/Grsecurity/LKRG, or equivalents like Talos/Flatcar).
- Interoperability and easy workload migration between providers.
- Compliance with Dutch public-sector rules (e.g., BIO security baseline, GDPR/NIS2 alignment).

Talos is **explicitly mentioned** in Haven-related documentation as one of the hardening options that can make a Kubernetes cluster Haven-compliant (alongside Flatcar Container Linux or specific kernel modules like SELinux).

- Providers like TrueFullstaq and others offer **managed Kubernetes platforms** built on Talos that are **Haven-compliant** (e.g., meeting government requirements for sovereignty, security, and Dutch/EU data residency).
- It's a strong fit for European digital sovereignty efforts (ties into earlier discussions on MijnBureau, EDIC, etc.), as Talos is fully open-source, self-hostable, and avoids vendor lock-in.

In short: **Talos** is an excellent choice if you're looking for a secure, minimal, CNCF-certified Kubernetes OS — especially in regulated or sovereign environments. It's production-ready, used by enterprises and governments, and pairs well with tools like Omni (Sidero’s management plane for large-scale clusters).

