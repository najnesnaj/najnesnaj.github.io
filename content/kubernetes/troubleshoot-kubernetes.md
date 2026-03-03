---
title: 'Troubleshoot Kubernetes'
weight: 1700
draft: false
---

# Troubleshooting Kubernetes

This section provides troubleshooting steps for common issues encountered in Kubernetes deployments, particularly focusing on PersistentVolumeClaims (PVCs) and scheduling problems.

```bash
kubectl get pods
NAME                                  READY   STATUS      RESTARTS   AGE
my-nginx-5c45c89568-bn47r             0/1     Pending     0          12h
my-nginx-5c45c89568-ltqvs             0/1     Completed   0          12h
postgres-deployment-b95b85d69-rfl88   0/1     Pending     0          13m
```

```bash
kubectl describe pod postgres-deployment-b95b85d69-rfl88

Name:             postgres-deployment-b95b85d69-rfl88
Namespace:        default
Priority:         0
Service Account:  default
Node:             <none>
Labels:           app=postgres
                pod-template-hash=b95b85d69
Annotations:      <none>
Status:           Pending
IP:
IPs:              <none>
Controlled By:    ReplicaSet/postgres-deployment-b95b85d69
Containers:
postgres:
    Image:      postgres:16
    Port:       <none>
    Host Port:  <none>
    Environment:
    POSTGRES_DB:        mydb
    POSTGRES_USER:      admin
    POSTGRES_PASSWORD:  password
    Mounts:
    /var/lib/postgresql/data from postgres-storage (rw)
    /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-5kw7k (ro)
Conditions:
Type           Status
PodScheduled   False
Volumes:
postgres-storage:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  database-pvc
    ReadOnly:   false
kube-api-access-5kw7k:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                            node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
```

Events:
: Type     Reason            Age                    From               Message
  —-     ——            —-                   —-               ——-
  Warning  FailedScheduling  13m                    default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
  Warning  FailedScheduling  13m (x2 over 13m)      default-scheduler  0/1 nodes are available: pod has unbound immediate PersistentVolumeClaims. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.
  Warning  FailedScheduling  3m39s (x2 over 8m39s)  default-scheduler  0/1 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

[root@talos-client](mailto:root@talos-client):~/cluster#
