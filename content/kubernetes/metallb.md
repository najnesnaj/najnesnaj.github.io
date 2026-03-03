---
title: 'Metallb'
weight: 950
draft: false
---

# metallb

helm install metallb metallb/metallb

Configuring MetalLB with Custom Resources
MetalLB uses CRs like IPAddressPool and L2Advertisement (for Layer 2 mode) or BGPPeer and BGPAdvertisement (for BGP mode) to manage IP allocation and advertisement. Given your bare-metal Proxmox environment and Traefik’s <pending> IP issue, Layer 2 mode with MetalLB is likely the simplest and most appropriate starting point unless you have a BGP-enabled router. Here’s how to set it up:

## talos

Solution: Relax Pod Security for MetalLB
You can either move MetalLB to a namespace with a privileged policy or adjust the default namespace to allow the speaker to run. Since your Traefik and MetalLB are already in default, let’s modify that namespace.

kubectl label ns default pod-security.kubernetes.io/enforce=privileged –overwrite
kubectl label ns default pod-security.kubernetes.io/enforce-version=v1.32 –overwrite

## Update: metallb-config.yaml

create seperate network on proxmox, because of talos-bug.

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.10.10.50-10.10.10.59  # Reserve 10 IPs outside DHCP range
  autoAssign: true

---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
```
