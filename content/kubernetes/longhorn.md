---
title: 'Longhorn'
weight: 1240
draft: false
---

# Longhorn

Longhorn is a cloud-native distributed block storage solution for Kubernetes. It is designed to provide highly available and durable storage for containerized applications. Longhorn is built on top of Kubernetes and leverages its features to provide a seamless experience for developers and operators.
It is an open-source project that is part of the Cloud Native Computing Foundation (CNCF) and is designed to work with any Kubernetes cluster, regardless of the underlying infrastructure. Longhorn provides a simple and efficient way to manage storage for Kubernetes applications, making it an ideal choice for organizations looking to adopt cloud-native technologies.

#### NOTE
Talos needs the iscsi extension!!

[root@talos-client](mailto:root@talos-client):~/postgres-buticosus# talosctl get extensions
ExtensionStatus   1    1         schematic     c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac

10.10.10.178   runtime     ExtensionStatus   0    1         iscsi-tools   v0.1.6
10.10.10.178   runtime     ExtensionStatus   1    1         schematic     c9078f9419961640c712a8bf2bb9174933dfcf1da383fd8ea2b7dc21493f8bac

## talos patch

```bash
cat <<EOF > longhorn-volume-patch.yaml
machine:
kubelet:
extraMounts:
  - destination: /var/lib/longhorn
    type: bind
    source: /var/lib/longhorn
    options:
      - bind
      - rshared
      - rw
```

talosctl patch mc –nodes 10.10.10.178 –patch @longhorn-volume-patch.yaml
patched MachineConfigs.config.talos.dev/v1alpha1 at the node 10.10.10.178
Applied configuration without a reboot

helm repo add longhorn [https://charts.longhorn.io](https://charts.longhorn.io)
helm repo update
helm install longhorn longhorn/longhorn –namespace longhorn-system –create-namespace

## check

kubectl get pods -n longhorn-system
NAME                                        READY   STATUS     RESTARTS   AGE
longhorn-driver-deployer-7f95558b85-sx7cq   0/1     Init:0/1   0          114s
longhorn-ui-7ff79dfb4-48pwj                 1/1     Running    0          114s
longhorn-ui-7ff79dfb4-r6zp5                 1/1     Running    0          114s

# Installing Longhorn on a Talos Cluster

This guide explains how to install Longhorn, a distributed block storage system for Kubernetes, on a Talos cluster.

## Prerequisites

1. A running Talos Kubernetes cluster.
2. kubectl configured to interact with the Talos cluster.
3. Sufficient disk space on the nodes for Longhorn storage.

## Installation Steps

1. **Add the Longhorn Helm Repository**:
   Add the Longhorn Helm repository to your Helm configuration:
   ``bash
   helm repo add longhorn https://charts.longhorn.io
   helm repo update
   ``
2. **Create a Namespace for Longhorn**:
   Create a dedicated namespace for Longhorn:
   ``bash
   kubectl create namespace longhorn-system
   ``
3. **Install Longhorn Using Helm**:
   Install Longhorn in the longhorn-system namespace:
   ``bash
   helm install longhorn longhorn/longhorn --namespace longhorn-system
   ``
4. **Verify the Installation**:
   Check the status of the Longhorn components:
   ``bash
   kubectl -n longhorn-system get pods
   ``
   Ensure all pods are in the Running state.
5. **Access the Longhorn UI**:
   Expose the Longhorn UI using a kubectl port-forward command:
   ``bash
   kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
   ``
   Open your browser and navigate to http://localhost:8080 to access the Longhorn UI.
6. **Configure Longhorn StorageClass**:
   Longhorn automatically creates a default StorageClass. You can list it using:
   ``bash
   kubectl get storageclass
   ``
   To use Longhorn as the default StorageClass, run:
   ``bash
   kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ``
7. **Test Persistent Volume Claims (PVCs)**:
   Create a test PVC to verify Longhorn functionality:

   ```
   ``
   ```

   ```
   `
   ```

   yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
   > name: test-pvc

   spec:
   : accessModes:
     : - ReadWriteOnce
     <br/>
     resources:
     : requests:
       : storage: 5Gi
     <br/>
     storageClassName: longhorn

   ``
   Apply the PVC:
   ```bash
   kubectl apply -f test-pvc.yaml
   ``
   Verify the PVC is bound:
   ``bash
   kubectl get pvc
   ``
8. **Clean Up**:
   To uninstall Longhorn, run:
   ``bash
   helm uninstall longhorn --namespace longhorn-system
   kubectl delete namespace longhorn-system
   ``

## Notes

- Ensure that all nodes in the Talos cluster have additional disks or directories available for Longhorn to use as storage.
- Longhorn requires Kubernetes 1.18 or later.

## References

- [Longhorn Documentation]([https://longhorn.io/docs/](https://longhorn.io/docs/))
- [Talos Documentation]([https://www.talos.dev/docs/](https://www.talos.dev/docs/))

## remove longhorn

```bash
kubectl delete namespace longhorn-system
namespace "longhorn-system" deleted
kubectl delete crd $(kubectl get crd | grep longhorn | awk '{print $1}')
```

## running longhorn on 1 NODE

Single-Node Cluster: You have only one node (talos-y7t-8ll), but the volume is configured for 3 replicas. Longhorn requires at least 3 nodes to schedule 3 replicas (one per node).

kubectl -n longhorn-system patch volume pvc-25af21a6-d280-47ba-b19e-2edf408b0c12 -p ‘{“spec”:{“numberOfReplicas”:1}}’ –type=merge
