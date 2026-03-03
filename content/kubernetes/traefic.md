---
title: 'Traefic'
weight: 1020
draft: false
---

# traefik

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. It integrates with your existing infrastructure components and configures itself automatically and dynamically.
It is designed to work with Docker, Kubernetes, and other orchestration tools.
Traefik is a powerful tool for managing and routing traffic to your applications. It provides features like load balancing, SSL termination, and service discovery.
It is designed to be easy to use and configure, making it a popular choice for developers and DevOps teams.

## Installation

```bash
To install Traefik using Helm, follow these steps:
1. **Add the Traefik Helm repository**:
   ```bash
   helm repo add traefik https://traefik.github.io/charts
   ```
2. **Update your Helm repositories**:
   ```bash
   helm repo update
   ```
3. **Install Traefik**:
   ```bash
   helm install traefik traefik/traefik
   ```
4. **Verify the installation**:
   ```bash
   kubectl get pods -n kube-system
   ```
5. **Access the Traefik dashboard**:
   - By default, the dashboard is not exposed. You can access it by port-forwarding:
   ```bash
   kubectl port-forward service/traefik-dashboard 8080:80 -n kube-system
   ```
   - Open your browser and go to `http://localhost:8080/dashboard/`.
6. **Configure Ingress**:
```

```bash
root@talos-client:~/cluster# helm repo add traefik https://traefik.github.io/charts
"traefik" has been added to your repositories
root@talos-client:~/cluster# helm repo update
```

[root@talos-client](mailto:root@talos-client):~/cluster# helm install traefik traefik/traefik
W0401 08:36:54.160390     332 warnings.go:70] would violate PodSecurity “restricted:latest”: seccompProfile (pod or container “traefik” must set securityContext.seccompProfile.type to “RuntimeDefault” or “Localhost”)
NAME: traefik
LAST DEPLOYED: Tue Apr  1 08:36:53 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
traefik with docker.io/traefik:v3.3.4 has been deployed successfully on default namespace !

## Talos

the “proper” Talos approach is to add a worker node
talosctl apply-config –insecure –nodes 192.168.0.213 –file worker.yaml

## workaround

```bash
# traefik-values.yaml
tolerations:
- key: "node-role.kubernetes.io/control-plane"
    operator: "Exists"
    effect: "NoSchedule"

helm install traefik traefik/traefik -f traefik-values.yaml
```

## check

kubectl get ipaddresspool traefik-pool -n default -o yaml
NAME           AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
traefik-pool   true          false             [“192.168.0.200-192.168.0.210”]

kubectl get l2advertisement -n default
NAME         IPADDRESSPOOLS     IPADDRESSPOOL SELECTORS   INTERFACES
traefik-l2   [“traefik-pool”]

## change the default values

helm show values traefik/traefik > traefik-values.yaml

## make traefik use the docker registry certs

> helm upgrade traefik traefik/traefik   –namespace default   –set tls.stores.default.defaultCertificate.secretName=registr

y-certs
