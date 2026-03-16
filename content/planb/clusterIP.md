---
title: 'clusterIP'
weight: 300
draft: false
---

**ClusterIP** is one of the fundamental **Service types** in Kubernetes (the default one, in fact). It provides a stable, internal virtual IP address (often called the "Cluster IP") that allows reliable communication **only within the Kubernetes cluster** — never directly from outside.

### Key characteristics of a ClusterIP Service
- **Internal-only access**  
  The IP address assigned to the Service exists **only inside the cluster's network**.  
  Pods, other Services, or any workload running in the same Kubernetes cluster can reach it (via the IP or via DNS name like `my-service.my-namespace.svc.cluster.local`).  
  Nothing from outside the cluster (your laptop, the public internet, another cluster) can connect directly to this IP — it's not routable externally.

- **Virtual IP (not a real pod IP)**  
  Kubernetes allocates a **virtual IP** from a special reserved range in the cluster (usually something like `10.96.0.0/12` — this is configured in the cluster's networking setup).  
  This IP does **not** belong to any single pod or node; it's a stable frontend managed by Kubernetes.

- **Load balancing built-in**  
  When multiple Pods match the Service's selector (e.g., all Pods with label `app=backend`), Kubernetes automatically load-balances traffic sent to the ClusterIP across those Pods (round-robin by default).  
  This makes it perfect for microservices: front-end Pods talk to a stable `backend-service` address, and Kubernetes handles which actual Pod gets the request.

- **Stable DNS name**  
  Even if Pods are created/deleted/scaled/restarted, the Service name and ClusterIP stay the same.  
  Other components discover and connect using DNS (Kubernetes' internal CoreDNS or kube-dns handles resolution).

### When do you use ClusterIP? (most common use case)
- Backend APIs, databases (PostgreSQL, Redis, MongoDB), message queues, internal caches — anything that should **only** be reachable by other parts of your application inside the cluster.
- In secure setups (like sovereign workspaces such as OpenDesk or LaSuite on Kubernetes), you use ClusterIP for **all core/internal services** to enforce "no public IPs for core services" → drastically reducing the attack surface.

### Quick comparison with other Service types
| Service Type    | Accessibility                  | Gets a public/external IP? | Typical use case                          |
|-----------------|--------------------------------|-----------------------------|-------------------------------------------|
| **ClusterIP**   | Only inside the cluster        | No                          | Internal microservices, databases, queues |
| **NodePort**    | Cluster + external via node IP + high port (30000–32767) | Indirectly (via nodes)     | Quick external testing/debugging          |
| **LoadBalancer**| External via cloud LB IP       | Yes (provisioned by cloud)  | Public-facing web apps, APIs              |
| **ExternalName**| Maps to external DNS           | N/A                         | Point to AWS RDS, external SaaS           |

### Simple example YAML
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-backend
spec:
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80          # what clients connect to
      targetPort: 8080  # what the Pods listen on
  type: ClusterIP       # this is actually the default — you can omit it
```

After applying this:
- Kubernetes assigns something like `10.96.5.123` as the ClusterIP.
- Any Pod in the cluster can curl `http://my-backend:80` (or `http://my-backend.default.svc.cluster.local:80`).
- Nothing outside can reach `10.96.5.123` directly.

### Headless variation (special case)
If you set `clusterIP: None` in the spec, you get a **headless** ClusterIP Service:
- No single virtual IP is created.
- DNS resolves directly to the individual Pod IPs (useful for stateful apps like databases where you need direct Pod-to-Pod communication, e.g., etcd, Cassandra, StatefulSets).

In short: **ClusterIP = the safe, default way to let things inside your Kubernetes cluster talk to each other reliably, without ever exposing them to the outside world.** It's a cornerstone of secure, internal service communication in production Kubernetes deployments.
