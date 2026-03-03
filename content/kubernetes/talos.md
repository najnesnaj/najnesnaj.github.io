---
title: 'Talos'
weight: 860
draft: false
---

# Talos

Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal. Talos is a self-hosted Kubernetes distribution that runs on bare metal or virtualized infrastructure. Talos is designed to be managed by a central Kubernetes control plane, which can be hosted on the same cluster or on a separate cluster.

talosctl config add my-cluster –endpoints 192.168.0.242

talosctl config info

talosctl config endpoint 192.168.0.242

talosctl gen config my-cluster [https://192.168.0.242:6443](https://192.168.0.242:6443) –output-dir ./talos-config –force

## new install talos

[https://www.talos.dev/v1.9/talos-guides/install/virtualized-platforms/proxmox/](https://www.talos.dev/v1.9/talos-guides/install/virtualized-platforms/proxmox/)

> > talosctl gen config my-cluster [https://192.168.0.218:6443](https://192.168.0.218:6443)
> > talosctl -n 192.168.0.169 get disks –insecure (check disks)
> > talosctl config endpoint 192.168.0.218
> > talosctl config node 192.168.0.218

> > talosctl apply-config –insecure –nodes 192.168.0.218 –file controlplane.yaml

> > talosctl bootstrap
> > talosctl kubeconfig . (retrieve kubeconfig)
> > talosctl –nodes 192.168.0.218 version (verify)

> > export KUBECONFIG=./talos-config/kubeconfig

> > > kubectl get nodes
> > > kubectl get pods -n kube-system
> > > kubectl get pods -n kube-system -o wide

> kubectl describe pod my-postgres-postgresql-0 (is very useful in case the pod does get deployed

> [https://factory.talos.dev/](https://factory.talos.dev/) (create your custom image)

> ```bash
> talosctl upgrade --nodes 10.10.10.178 --image  factory.talos.dev/installer/c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac:v1.9.5
> ```

watching nodes: [10.10.10.178]
: talosctl get extensions –nodes 10.10.10.178

NODE           NAMESPACE   TYPE              ID   VERSION   NAME          VERSION
10.10.10.178   runtime     ExtensionStatus   0    1         iscsi-tools   v0.1.6
10.10.10.178   runtime     ExtensionStatus   1    1         schematic     c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac

## adding worker nodes

Since “longhorn” stores data on more than one node, we need to add more nodes to the cluster.

> talosctl apply-config –insecure –nodes 10.10.10.166 –file worker.yaml
> talosctl apply-config –insecure –nodes 10.10.10.173 –file worker.yaml

kubectl get nodes -o wide
NAME            STATUS   ROLES           AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION   CONTAINER-RUNTIME
talos-2ho-roe   Ready    <none>          113s    v1.32.3   10.10.10.173   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3
talos-swn-isw   Ready    control-plane   31d     v1.32.3   10.10.10.118   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3
talos-v1x-9s4   Ready    <none>          2m18s   v1.32.3   10.10.10.166   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3
talos-y7t-8ll   Ready    worker          29d     v1.32.3   10.10.10.178   <none>        Talos (v1.9.5)   6.12.18-talos    containerd://2.0.3

## label nodes

> kubectl label nodes talos-v1x-9s4 node-role.kubernetes.io/worker=””
> kubectl label nodes talos-2ho-roe node-role.kubernetes.io/worker=””
