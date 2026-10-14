# On-Premises Cloud Platform — Strategy Note

**Prepared for:** Senior Management
**Subject:** From container pilots (MijnBureau, Euro-Office) to a resilient on-premises Kubernetes platform
**Status:** Proposal — for decision

---

## 1. Executive summary

We are evaluating applications such as **MijnBureau** and **Euro-Office** for use
in a **semi-production** environment. A purely container-based pilot (running
the software on a single Docker host) is adequate for demonstration, but it is
not robust enough for semi-production: it lacks availability, repeatability,
recoverability and a clear audit trail.

We propose to evolve towards a **high-availability Kubernetes platform** on our
own Proxmox infrastructure. Because such a platform is complex, we treat the
entire environment as **Infrastructure as Code (IaC)**: it is described in
version-controlled files and can be rebuilt and reproduced automatically.
Concretely:

- **OpenTofu (Terraform)** provisions the infrastructure on **Proxmox**.
- **Talos Linux** — an *immutable* operating system — runs the Kubernetes nodes.
- A dedicated **management server (`k8s-management`)** administers the cluster.
- **Ansible** automates server configuration (SSH access, tooling such as `talosctl`).
- **ArgoCD** delivers applications from Git (GitOps).

This gives us a **cloud-like platform on our own hardware**: the same tools,
skills and workflows our team already uses on **Azure** can be applied locally.
**OpenCode** (AI assistance) accelerates the build and documentation of this
environment, under human review.

**Recommendation:** approve a phased rollout, starting with a test cluster.

---

## 2. Why we need to move beyond a "pure container" setup

MijnBureau and Euro-Office are typically delivered as containers. A single
Docker host is quick to stand up, but for semi-production it falls short:

| Concern | Single container host | Target platform |
| --- | --- | --- |
| Availability | One host = single point of failure | High-availability cluster, automatic rescheduling |
| Repeatability | Manual, undocumented setup | Entire environment defined as versioned code |
| Recovery | Rebuild by hand | Rebuild/replace from code within minutes |
| Scaling | Manual | Declarative, controlled |
| Security | Ad-hoc access | Immutable OS, key-only access, least privilege |
| Auditability | Limited | Every change reviewed and recorded in Git |

The conclusion: we need a **platform**, not a collection of hand-configured
servers. The main obstacle is complexity — which is exactly why we adopt IaC and
GitOps rather than trying to manage it manually.

---

## 3. Proposed architecture

The platform is built in layers, each using a proven, industry-standard
component:

| Layer | Our choice | Why |
| --- | --- | --- |
| Virtualisation | **Proxmox VE** | Already in use on-premises; no new hypervisor to buy |
| Provisioning | **OpenTofu (Terraform)** | Declarative, version-controlled, reproducible infrastructure |
| Node operating system | **Talos Linux** | Immutable, minimal and fully API-managed — smaller attack surface, no manual logins |
| Cluster administration | **`k8s-management` server** | A dedicated host running `talosctl`/`kubectl`; configured by Ansible |
| Server configuration | **Ansible** | Automates and documents configuration (SSH server, tooling) |
| Application delivery | **ArgoCD (GitOps)** | Continuously reconciles the cluster with the desired state in Git |
| Software packaging | **Helm charts in Git** | Standard, versioned packaging for Kubernetes software |

### Test topology

For the initial test setup we deploy:

- **1 Kubernetes control plane** node
- **3 worker nodes**

> Note: for true high availability in Phase 2, the control plane is expanded to
> **three control planes**. The test topology proves the approach; the production
> topology delivers the redundancy.

Talos has no direct shell access, so it must be managed through its API — this is
why the dedicated **`k8s-management`** server exists. Ansible configures that
server automatically (including its SSH server and the Talos/Kubernetes tooling),
so it too can be rebuilt from code.

---

## 4. How a change flows — GitOps with ArgoCD

Instead of installing individual Helm charts by hand, we adopt **CI/CD and GitOps**:

1. An engineer changes a Helm chart or its configuration in the **Git repository**.
2. The **CI/CD pipeline** validates, tests and publishes the change.
3. **ArgoCD** detects the new desired state and applies it to the cluster.
4. The cluster is **continuously reconciled** with Git: any manual drift is
   corrected automatically, and every change has a reviewable history.

The result is a single source of truth (Git), no manual operations on the
cluster, and a full audit trail of who changed what and when.

---

## 5. The "cloud on-premises" benefit

Because the platform uses the same primitives as the public cloud, we **mimic the
cloud on-site**:

- The same container formats, Helm charts and pipelines used on **Azure** work
  locally, and vice versa.
- The **same team and skills** can develop on-premises and deploy to the cloud —
  reducing retraining, duplication and vendor lock-in.
- Workloads can be moved between environments with minimal change.

---

## 6. Security and governance

- **Immutable operating system** (Talos): nodes cannot be altered by hand,
  reducing configuration drift and attack surface.
- **SSH key-based, least-privilege access**, with password authentication
  disabled on management hosts.
- **Git as the single source of truth**: changes are peer-reviewed before they
  reach production.
- **Reproducible rebuilds**: the environment can be recreated from code, which
  supports disaster-recovery and compliance.

---

## 7. Role of AI assistance (OpenCode)

We use **OpenCode** to accelerate the work:

- Generating and reviewing infrastructure code (OpenTofu/Terraform, Ansible) and
  documentation.
- Assisting with troubleshooting and knowledge capture.

Guardrails: AI-generated work is **reviewed and approved by our engineers**, and
all changes still pass through Git and the normal change process. AI increases
speed; accountability remains human.

---

## 8. Phased roadmap

| Phase | Scope | Outcome |
| --- | --- | --- |
| **Phase 1 — Test** | Control plane + 3 workers on Proxmox, provisioned with OpenTofu, nodes on Talos, `k8s-management` + Ansible, ArgoCD GitOps. Validate MijnBureau and Euro-Office. | Proven, reproducible test environment |
| **Phase 2 — High availability** | 3 control planes, ingress, monitoring, backups, secrets management. | Resilient platform |
| **Phase 3 — Semi-production** | Hardening, RBAC, policy, disaster recovery, service levels, support process. | Production-ready service |

---

## 9. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Kubernetes complexity | Encapsulate it in IaC and GitOps; standard components; documented |
| Skills gap | Reuse existing Azure/Kubernetes skills; AI-assisted onboarding |
| New technology (Talos) | Start small in Phase 1; immutable OS reduces operational burden |
| Vendor lock-in | Open standards (Kubernetes, Helm, Terraform/OpenTofu, Git) |
| Security | Immutable OS, key-only access, peer-reviewed changes |

---

## 10. Recommendation

We recommend approving the **Phase 1 test platform**. It is low-risk and
self-contained, reuses existing Proxmox hardware and our team's cloud skills, and
produces a reproducible foundation that can grow into a high-availability,
semi-production platform for MijnBureau, Euro-Office and future applications.

**Decision requested:** approval to proceed with Phase 1 and to allocate the
necessary engineering time.
