# No-ops: minimizing human intervention

**Status:** plan, not yet implemented.

**Scope:** describe which operations are already automated in this
environment, which decisions still require a human today, and how an AI
operations agent ([OpenCode](https://opencode.ai)) running on the management
host can take over most of the remaining work so that human effort becomes
the exception, not the routine.

Related documents: [`platform-strategy-management.md`](platform-strategy-management.md)
(platform vision), [`monitoring.md`](monitoring.md) (Prometheus/Grafana),
[`backup.md`](backup.md) (Garage backup target),
[`backup-restore-howto.md`](backup-restore-howto.md) (operations runbook),
[`talos-opencode.md`](talos-opencode.md) (existing OpenCode instructions for
this cluster).

---

## 1. Principle

"No-ops" never literally means zero human interaction. It means a **single
low-effort control loop**:

* Software converges the infrastructure and the applications by itself
  (already achieved: OpenTofu, Ansible, ArgoCD).
* An AI agent constantly observes, decides, and proposes — and executes the
  *safe* class of changes directly through Git.
* Humans only handle what really needs them: approving risky actions,
  handling restores, and reviewing the weekly report.

The design rule that makes this safe: **the agent publishes intent, it does
not poke the cluster.** Every change the agent makes goes as a commit into
Forgejo via the GitOps repository (or an OpenTofu/Ansible change in this
repository); ArgoCD and the pipelines perform the mutation. That way every
agent action is reviewable, diffable, and reversible — the same properties
that keep a human operator honest, applied to a software one.

```text
              observe                    decide                    act
 ┌───────────────┐        ┌──────────────────────┐        ┌───────────────┐
 │ Prometheus /  │ alerts │  OpenCode agent      │ commits│ Forgejo GitOps│
 │ Grafana /     ├───────►│  (management LXC)    ├───────►│ repo          │
 │ Grafana reports│       │  reads logs, metrics,│        │       │       │
 │ cluster APIs  │        │  docs, git history   │        │       ▼       │
 └───────▲───────┘        │  writes intent       │        │   ArgoCD sync │
         │                └──────────┬───────────┘        └───────┬───────┘
         │  periodically every node  │ evaluates                  │
 ┌───────┴───────┐          ┌───────▼───────────┐        ┌───────▼───────┐
 │ Talos nodes   │          │ human             │◄───────┤  converged    │
 │ workloads     │          │ approves or edits │        │  cluster      │
 │ backup LXC    │          └───────────────────┘        └───────────────┘
 └───────────────┘
```

---

## 2. What is already automated (no human needed)

| Layer | Tool | Source in this repo | Human effort today |
| --- | --- | --- | --- |
| VM/LXC provisioning | OpenTofu (`tofu`) | `main.tf`, `talos.tf`, `management.tf`, `router.tf`, `argocd.tf` | only at `tofu plan/apply` |
| OS / node configuration | Ansible | `ansible/`, `ansible2/` | only at playbook run |
| Kubernetes OS | Talos v1.8.1 | `talos.tf` | upgrade occasionally |
| Application delivery | ArgoCD (GitOps) | `ansible2/files/gitops/apps/*` | only for new apps |
| Monitoring | kube-prometheus-stack | `monitoring.md`, `back_up_statistics.md` | dashboards occasionally |
| Backups | Velero, restic, Garage (LXC 107) | `backup.md` | restore only |
| Backup visibility | restic-exporter, Velero metrics | `back_up_statistics.md` | none |
| Backup web UI | garage-webui on CT 107 | `garage-web-installation.md` | none |

The remaining human work therefore is **triage and judgement**: is this
alert real, is this component degraded, did the backup actually run, is the
cluster drifting from Git, when do I have to upgrade. That is exactly the
class of work an AI agent is good at, because it is mostly
*read, correlate, report, and propose* — not *create or destroy*.

---

## 3. The three agent loops

The agent becomes useful when it runs continuously in clearly separated
loops. All three run on the management LXC (`192.168.0.192`), which already
holds `kubectl`, `talosctl`, `helm`, `tofu` and SSH access to CT 107, so the
agent needs no additional credentials or network paths.

### 3.1 Alert loop (event-driven)

Today no Alertmanager receiver is configured (`backup.md`, "Not yet
covered"). That is the missing link between failures and any automated
response, human or AI. Implementation steps:

1. Configure a webhook receiver in the Alertmanager Application values in
   `ansible2/files/gitops/apps/monitoring.yaml`, pointing at a small
   trigger service on the management LXC (e.g. `http://192.168.0.192:9900`).
2. The trigger service starts an OpenCode session (`opencode run` CLI or the
   SDK server API) with a fixed instruction doc — for example
   `noops-triage.md` in this directory — passing the alert JSON as
   structured context.
3. The agent's job in this loop is:
   * label the alert (`real / duplicate / self-healed / requires human`),
   * gather evidence (pods, logs, recent commits that could correlate,
     Prometheus queries),
   * for safe classes: open a Git commit through Forgejo (e.g. a
     PodDisruptionBudget bump, PVC capacity increase),
   * otherwise: notify and wait.
4. The trigger service stays dumb — it only serializes alerts into sessions.
   A failing trigger service itself is alertable by Prometheus
   (`probe_success == 0` on a blackbox check against `9900`).

### 3.2 Audit loop (scheduled)

A systemd timer on the management LXC runs an OpenCode session once per
day/week with the instruction doc `noops-audit.md`, which resembles the
existing daily/quick-verification sections of
[`backup-restore-howto.md`](backup-restore-howto.md):

* `systemctl is-active garage.service garage-webui` on CT 107 via SSH,
* `velero backup-location get`, latest backups/schedules,
* restic snapshots per node,
* `tofu plan` drift check against the Proxmox host state,
* ArgoCD app health (`kubectl get applications -o wide` or the ArgoCD API),
* certificate and PVC capacity checks,
* Prometheus queries for node pressure trends.

The output is a markdown report committed to Forgejo
(`reports/noops-YYYYMMDD.md`), and a summary appended to the rotating
"Grafana reports" that monitoring already produces. The human's weekly
effort shrinks to reading one document. This loop is also what keeps the
agent honest about its own infrastructure: the timer itself is monitored
(`timer_last_trigger_monotonic`-style metrics or a heartbeat file that
Prometheus checks).

### 3.3 Improvement loop (on demand)

Everything the human types into a chat can become a doc instead. The repo
already works this way: `install-euro-office.md` and
`opencode-cluster-instruct.md` are instruction documents for an agent. The
habit that replaces ops effort:

* when a manual fix is needed twice, write it as an instruction doc,
* let OpenCode turn the doc into a GitOps change or Ansible playbook,
* delete the manual step from the runbook.

---

## 4. Guardrails for the agent

An agent with industrial tools and root SSH keys can cause more damage than
the outage it was reacting to. The following rules are part of the design,
not recommendations:

| Rule | Reason |
| --- | --- |
| The agent commits to Git; it does not `kubectl apply` | keeps every change auditable and reversible, and forces the "desired state" mental model |
| Read-only cluster access by default (`kubectl get/describe/logs`, `talosctl read`), no `delete`, no `exec` | the destructive class of commands is what an LLM can get wrong |
| OpenTofu runs only in `plan` mode from the agent; `apply` stays human | `tofu destroy` is the largest blast radius in this setup |
| Restores (Velero, restic, Garage metadata) always human-approved | they overwrite live data and can make a situation worse |
| Secrets never in the GitOps repo, never shown in agent output | agent transcripts are logs; logs leave machines |
| One session per loop, all work done in a worktree, `git diff` before any push | no concurrent agent edits, no accidental pushes to main |
| Everything the agent does lands in the report of the week | no silent changes; the human can always diff the GitOps repo |

These map well onto OpenCode's existing permission model (allow read-only
tools, require manual approval for write commands) and onto a branch/PR
flow against Forgejo instead of pushing to main.

---

## 5. The escape ladder: what stays human

The following stays on a human, forever, and the agent should treat it as
"prepare, never execute":

* cluster and Talos OS upgrades,
* any restore or migration of persistent data,
* rotation of the Garage/RPC/S3/admin credentials,
* changes to the no-ops machinery itself (instruction docs, trigger
  service, Prometheus rules that gate the agent),
* any decision about the Proxmox host, disks, or power state,
* anything the agent itself classifies as "not covered by docs".

Everything else is expected to converge to: alert → triage → Git commit →
ArgoCD sync → report. The human appears in that chain only as a reviewer.

---

## 6. Maturity ladder

| Level | Meaning | Status here |
| --- | --- | --- |
| 0 | Manual operation, hands on every failure | historical |
| 1 | Declarative infra (IaC + GitOps) | ✓ done |
| 2 | Observability with useful dashboards | ✓ done (with reports) |
| 3 | Alerts reach a receiver | ✗ missing (section 3.1) |
| 4 | Agent triages alerts and writes report | ✗ missing |
| 5 | Agent performs safe classes as Git commits, human approves | ✗ missing |
| 6 | Agent plans but humans apply OpenTofu | today's default |
| 7 | True unattended operation for weeks, single weekly read | goal |

Getting from level 3 to 5 is roughly: receiver configured (1 evening), the
audit timer with a good instruction doc (1 day because the runbook already
exists in prose), and the trigger service (small).

---

## 7. First concrete steps

Ordered by effort-to-payoff:

1. **Configure the Alertmanager receiver** with a webhook into a tiny
   trigger service on `192.168.0.192`. This is valuable even before any AI:
   the human can be pager #1 today and be "paged" by the OpenCode session
   tomorrow. It also closes the known gap from [`backup.md`](backup.md).
2. **Write `noops-audit.md`** as the instruction doc for the daily audit
   loop; it is a formalization of the two existing verification checklists
   in [`backup-restore-howto.md`](backup-restore-howto.md) and
   [`backup.md`](backup.md) Appendix C, so its content is mostly done.
3. **Set the timer + report generation** (`systemd` timer, OpenCode session,
   commit `reports/noops-YYYYMMDD.md` into Forgejo).
4. **Set the alert triage instruction doc `noops-triage.md`** — label, gather
   evidence, and open a PR for the narrow classes: PVC capacity, retry limits,
   `PodDisruptionBudget`, and "restart the target of a bad CCD rollout".
5. **Add the meta-monitoring Prometheus rules** so the agent machinery
   itself is observable: timer age, session failures, report freshness, and
   a blackbox check against the trigger port.
6. Only then: restrict the agent's tool permissions for writes, research
   class, and restore abilities in the OpenCode configuration, and remove
   human approval from the (now well separated) categories that proved
   trivially safe in practice.
