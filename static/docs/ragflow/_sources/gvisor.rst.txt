How InfiniFlow RAGFlow Uses gVisor
**********************************

InfiniFlow RAGFlow is an open-source RAG (Retrieval-Augmented Generation) engine that supports document understanding and LLM orchestration. To enhance security when executing untrusted or user-provided code (e.g., Python agents, dynamic data processing scripts, or custom tool functions), RAGFlow runs certain components inside isolated sandboxes.

gVisor Integration
==================

RAGFlow leverages **gVisor** as its primary sandboxing technology in containerized (Docker/Kubernetes) deployments.

What is gVisor?
---------------

gVisor is an open-source project by Google that provides a user-space kernel (the Sentry component) and a lightweight virtual machine (runsc runtime). It intercepts and emulates Linux system calls instead of letting the container directly access the host kernel.

Key benefits of gVisor in a containerized environment:

- **Strong syscall isolation**: Only a limited, explicitly allowed set of syscalls reaches the host kernel. Unknown or dangerous syscalls are blocked or emulated in user space.
- **Reduced kernel attack surface**: Even if a process escapes the container’s namespaces/cgroups/seccomp filters, it still operates through gVisor’s restricted interface.
- **Compatibility with standard Docker**: gVisor integrates as an OCI-compatible runtime (``runsc``), so no changes to Dockerfile or Kubernetes pod spec syntax are required beyond specifying the runtime.

How RAGFlow Uses gVisor Sandboxes
=================================

When the sandbox feature is enabled (default in recent RAGFlow releases), the following happens:

1. **Agent/Tool Execution Sandbox**
   - Python-based agents and custom tools are executed inside a dedicated gVisor-powered container.
   - The sandbox container has extremely limited privileges:
     - No direct access to the host filesystem (only a small tmpfs and necessary code mounts as read-only).
     - Restricted network access (usually completely disabled or limited to internal RAGFlow services).
     - Dropped capabilities and a strict seccomp profile enforced by gVisor.

2. **Runtime Selection**
   - RAGFlow’s Docker Compose and Helm charts include a ``ragflow-sandbox`` service that uses the ``runsc`` runtime:
     
     .. code-block:: yaml

        runtime: runsc
        runtime-config:
          # Optional gVisor flags
          platform: ptrace  # or kvm on supported hardware

3. **Communication**
   - The main RAGFlow application communicates with the sandbox via gRPC or stdin/stdout (depending on version).
   - Code and data are injected securely at container startup; no runtime file writes from inside the sandbox are allowed.

Security Advantages in Practice
===============================

+---------------------------+-----------------------------------------------+
| Threat                    | Mitigation by gVisor in RAGFlow               |
+===========================+===============================================+
| Container escape via      | gVisor blocks or emulates dangerous syscalls  |
| kernel exploits           | (e.g., dirty pipe, recent CVEs)               |
+---------------------------+-----------------------------------------------+
| Arbitrary file access     | Minimal filesystem + read-only mounts        |
+---------------------------+-----------------------------------------------+
| Network-based attacks     | Network namespace + optional full disable     |
+---------------------------+-----------------------------------------------+
| Privilege escalation      | No capabilities, non-root user, strict        |
| inside container          | seccomp via gVisor                            |
+---------------------------+-----------------------------------------------+

Enabling/Disabling the Sandbox
==============================

In ``docker-compose.yml`` or Helm values:

.. code-block:: yaml

   services:
     ragflow:
       environment:
         - ENABLE_SANDBOX=true   # default true in v0.10+

To run without gVisor (less secure, for trusted environments only):

.. code-block:: yaml

   environment:
     - ENABLE_SANDBOX=false

Summary
=======

By running untrusted code execution inside gVisor-powered containers, RAGFlow significantly reduces the risk of a compromised agent or malicious user-uploaded script affecting the host system or other services, while maintaining good performance and seamless integration with standard container orchestration tools.
