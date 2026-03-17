---
title: 'coco'
draft: false
weight: 1400 
---
**Smals (through Smals Research) actively explores and promotes Confidential Containers (CoCo)** as a practical solution for confidential computing in on-premise and sovereign IT environments — particularly for Belgian public-sector use cases.

From the March 17, 2026, Smals Research blog post you linked ("Je data beschermen tegen beheerders: ‘on-premise’ vertrouwelijke IT"), they explicitly discuss **Confidential Containers (CoCo)** as a key open-source technology to achieve this. Here's a breakdown:

### Smals' Position on CoCo
- **They highlight CoCo as the recommended path** for implementing confidential computing on-prem without relying on hyperscaler-specific services (e.g., AWS Nitro or Azure Confidential VMs).
- CoCo is presented as a mature, Kubernetes-native framework that runs application pods inside lightweight, hardware-backed **Trusted Execution Environments (TEEs)** (e.g., using AMD SEV-SNP, Intel TDX, or similar extensions on supported servers).
- The article describes CoCo's architecture in detail (with figures):
  - Pods execute in isolated confidential VMs (built on **Kata Containers** as the runtime base).
  - Integration via the Kubernetes Container Runtime Interface (e.g., containerd).
  - Use of **remote attestation** to prove the runtime is genuine and untampered.
  - A **Trustee** component (or external service) validates attestation and mediates key delivery — ensuring data/secrets are only released to verified workloads.
- Smals positions this as aligning with **zero-trust principles** in public administration: the cluster admin/orchestrator is explicitly untrusted, protecting "class 3" (highly confidential) data from insiders.

### Evidence of Usage / Adoption
- The post is not just theoretical — it's part of Smals' ongoing confidential computing research and pilots.
- Smals has previously published intros, webinars, and proofs-of-concept on confidential computing (including TEEs), and this article explicitly calls out CoCo as a deployable, open-source option for Belgian on-prem setups (e.g., future G-Cloud or self-hosted data centers).
- They note CoCo's advantages over alternatives like fully homomorphic encryption: it's more performant and practical for real workloads (e.g., secure data processing in eHealth, social security analytics, or cross-border exchanges without exposing raw data).
- While the article doesn't claim "we are running CoCo in production today," it strongly advocates for it as a realistic next step, promising a follow-up on installation/usage — indicating active evaluation and likely piloting.

### Context in Belgian/EU Landscape
- This fits perfectly with 2026 trends: Gaia-X Season 2.0 (trusted data spaces), EDIC digital commons (sovereign open-source like MijnBureau/OpenDesk), and Belgian providers (Proximus/Combell) offering managed Kubernetes.
- Running CoCo on a Belgian-managed K8s cluster (e.g., Combell or Proximus) would let you deploy sensitive parts of a sovereign stack (MijnBureau pods handling confidential data) with strong protections against admins — exactly the "post-project sustainability" resilience Smals aims for in public IT.

