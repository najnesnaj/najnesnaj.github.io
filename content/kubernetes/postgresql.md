---
title: 'Postgresql'
draft: false
---

# PostgreSQL

pre-requisites : Longhorn

<a id="stateful-postgresql-kubernetes-longhorn"></a>

Why We Need a Stateful Solution for PostgreSQL in Kubernetes (Using Longhorn)
A stateful solution for PostgreSQL in Kubernetes, using Longhorn, is critical due to the unique requirements of stateful applications like databases. This document explains why such a solution is necessary and how Longhorn addresses these needs.
Stateful Nature of PostgreSQL
Data Persistence:
PostgreSQL stores critical data (e.g., tables, schemas, transaction logs). Unlike stateless applications, it requires persistent storage to prevent data loss during pod restarts or rescheduling.

Consistent Identity:
Each PostgreSQL instance (primary or replica) needs a stable network identity and consistent storage to maintain its role in a cluster (e.g., primary for writes, replicas for reads).

Ordered Operations:
Operations like provisioning, scaling, or failover must occur in a specific order (e.g., primary before replicas). Kubernetes StatefulSets provide this capability.

Why Kubernetes Needs a Stateful Solution
Stateless vs. Stateful:
Kubernetes handles stateless workloads with Deployments and ReplicaSets, but stateful applications like PostgreSQL require:
StatefulSets: Provide stable pod identities (e.g., pod-name-0), ordered startup/shutdown, and persistent volume bindings.

Persistent Volumes (PVs) and Persistent Volume Claims (PVCs): Ensure storage remains tied to a pod, even if rescheduled.

Dynamic Storage Management:
Storage must be provisioned and managed automatically to handle pod/node failures or scaling.

High Availability:
PostgreSQL’s primary-replica setup requires consistent storage for replication and failover.

Role of Longhorn in the Stateful Solution
Longhorn is a Kubernetes-native distributed block storage system, ideal for PostgreSQL’s persistent storage needs. Its key features include:
Distributed and Resilient Storage:
Replicates data across nodes, ensuring durability if a node fails.

Supports PostgreSQL’s high availability and disaster recovery needs.

Dynamic Provisioning:
Integrates with Kubernetes’ Container Storage Interface (CSI) to dynamically provision PVs for PVCs.

Simplifies scaling and recovery.

Snapshots and Backups:
Supports snapshots for point-in-time recovery (PITR) and backups to external storage (e.g., S3).

Critical for PostgreSQL’s data recovery.

Ease of Management:
Provides a user-friendly interface and Kubernetes-native integration.

Supports volume expansion for growing databases.

Cross-Node Mobility:
Ensures storage volumes are reattached to rescheduled pods, preserving data integrity.

Why Not Use Other Storage Solutions?
Local Storage:
Tied to specific nodes, making data inaccessible if a node fails. Longhorn’s distributed storage avoids this.

Cloud-Specific Storage:
Solutions like AWS EBS or Google Persistent Disk limit portability. Longhorn is cloud-agnostic.

Traditional SAN/NAS:
Require external management and lack Kubernetes integration, complicating stateful workloads.

How It Works in Practice
StatefulSet for PostgreSQL:
Defines replicas (e.g., one primary, two replicas).

Assigns unique pod names (e.g., postgres-0) and PVCs for storage.

Longhorn StorageClass:
Configured as the provisioner to dynamically create replicated block storage volumes.

Volume Binding:
Longhorn binds each pod’s PVC to a persistent volume, maintaining data across restarts.

Replication and Failover:
Longhorn replicates data across nodes, supporting failover (e.g., promoting a replica to primary).

Benefits of This Approach
Reliability: Longhorn’s replication and snapshots ensure data durability and recoverability.

Scalability: StatefulSets and Longhorn enable easy scaling of PostgreSQL instances.

Portability: Works across cloud, on-premises, or hybrid environments.

Automation: Reduces operational overhead with dynamic provisioning and orchestration.

Considerations
Performance:
Longhorn’s performance depends on hardware and network. Tune replica count or use faster disks for high-performance workloads.

Resource Overhead:
Replication and management consume resources. Ensure sufficient cluster capacity.

Backup Strategy:
Configure regular backups to external storage for disaster recovery.

Conclusion
A stateful solution for PostgreSQL in Kubernetes, using Longhorn, addresses the database’s need for persistent, reliable, and dynamically managed storage. Longhorn’s distributed block storage, replication, snapshots, and backups complement Kubernetes StatefulSets, ensuring PostgreSQL runs reliably with high availability and fault tolerance in a cloud-native environment. This approach simplifies management, enhances resilience, and supports Kubernetes’ dynamic workloads.

## pvc (persistant volume claim)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
name: postgres-pvc
namespace: default
spec:
accessModes:
    - ReadWriteOnce
resources:
    requests:
    storage: 1Gi
storageClassName: longhorn
```

## postgresql-values.yaml

```yaml
global:
storageClass: longhorn
primary:
persistence:
    enabled: true
    existingClaim: postgres-pvc
    # No need to specify size, as PVC is predefined (1Gi)
resources:
    requests:
    storage: 1Gi
configuration:
    postgresql.conf: |
    listen_addresses = '*'
    max_connections = 100
    pg_hba.conf: |
    host all all 0.0.0.0/0 md5
auth:
enablePostgresUser: true
postgresPassword: "mypostgres" # Change to a strong password
database: mydatabase
username: myuser
password: "mypassword"
```

## connecting to postgres

> helm install postgres bitnami/postgresql   –namespace postgres   -f values.yaml

values.yaml

myuser
mypassword
mydatabase

## creating database

```bash
cp mydatabase_backup.sql postgres-postgresql-0:/tmp/mydatabase_backup.sql -n postgres
exec -it postgres-postgresql-0 -n postgres -- bash
psql -U myuser -d mypassword -f /tmp/mydatabase_backup.sql
```
