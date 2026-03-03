---
title: 'Sda'
weight: 890
draft: false
---

# SDA (software defined architecture)

## Physical Infrastructure

## Proxmox Server Specifications

The foundation of the architecture is a physical server running Proxmox VE hypervisor.

| Component            | Description                                          |
|----------------------|------------------------------------------------------|
| **Hypervisor**       | Proxmox Virtual Environment (VE)                     |
| **Virtual Machines** | Multiple Talos OS nodes forming a Kubernetes cluster |
| **Containers**       | LXC container serving as a router                    |

## Virtual Machine Configuration

```console
# Example Talos configuration structure (simplified)
machine:
  type: controlplane  # or worker
  network:
    hostname: talos-node-1
  kubernetes:
    version: v1.26.0
```

## Networking Architecture

### Network Components

| Component                      | Function                                                 |
|--------------------------------|----------------------------------------------------------|
| **Proxmox Virtual Bridge**     | Creates isolated network segments for VMs and containers |
| **LXC Router**                 | Routes traffic between internal and external networks    |
| **Kubernetes Overlay Network** | Enables pod-to-pod communication (Cilium, Flannel, etc.) |

## Control & Automation

### API Management Layer

This architecture leverages multiple declarative APIs for infrastructure management:

| API                | Responsibility                                        |
|--------------------|-------------------------------------------------------|
| **Proxmox API**    | Manages physical resources, VMs, and containers       |
| **Talos API**      | Provides declarative OS configuration and maintenance |
| **Kubernetes API** | Orchestrates applications and services                |

## Benefits of This Architecture

- **Immutable Infrastructure**: Talos OS provides an immutable, declarative operating system
- **High Availability**: Kubernetes manages service availability and distribution
- **Resource Efficiency**: Consolidates multiple services on a single physical server
- **Isolation**: Separate network segments and container boundaries
- **Automation**: API-driven management at all levels
