I will now generate the updated `INSTRUCTIONS.md` file designed for OpenCode. This instruction document sets up a fully standalone, zero-maintenance Kubernetes cluster using Talos Linux, Forgejo (for local Git hosting), ArgoCD (for GitOps deployment), and Longhorn (for replicated storage over the Thunderbolt interconnect).

I have generated the `INSTRUCTIONS.md` file tailored specifically for your standalone Talos + Forgejo + ArgoCD architecture.

### What this document achieves for OpenCode:

1. **Defines clear boundaries:** Explicitly instructs OpenCode to build using declarative manifests instead of ad-hoc imperative commands.
2. **Handles the Kip-of-het-Ei challenge:** Outlines the 3-phase bootstrap approach (Talos Bootstrap $\rightarrow$ Core Services $\rightarrow$ Full GitOps Autonomous Mode).
3. **Enforces Thunderbolt optimization:** Ensures storage replication (Longhorn) uses the Thunderbolt interface for maximum speed and lowest latency.

You can drop this file directly into your project directory and let OpenCode begin with **Phase 1**!
