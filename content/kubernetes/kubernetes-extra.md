---
title: 'Kubernetes Extra'
draft: false
---

# Kubernetes extra

## join the party

```bash
sudo snap install microk8s --classic
connecting a node to the cluster :
sudo microk8s join 192.168.0.103:25000/ec0284a420056e7a3b427ef767ff6045/a7e4cd55b373
```

## velero

velero is a backup and restore tool for Kubernetes resources. It can be used to backup and restore the state of the cluster, including persistent volumes, namespaces, and resources.

Velero needs a place to store the backup. This can be a cloud storage service like AWS S3, Google Cloud Storage, or Azure Blob Storage. Alternatively, it can be a local storage location.
I choose for minIO. MinIO is an open-source object storage server compatible with Amazon S3 APIs.

```bash
wget https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz
tar -xzf velero-v1.13.0-linux-amd64.tar.gz
sudo mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/
velero install   --provider aws   --plugins velero/velero-plugin-for-aws:v1.9.0   --bucket backupvoorlaptop   --secret-file ./credentials-velero   --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://10.152.183.52:9000   --use-volume-snapshots=false
```

```bash
KUBECONFIG=/var/snap/microk8s/current/credentials/client.config
velero backup create my-third-backup --include-namespaces default

velero backup logs my-third-backup

sudo microk8s kubectl exec -it deployment/velero -n velero -- sh

velero restore create my-fifth-restore --from-backup my-fifth-backupq
```

## minIO

MinIO is an open-source object storage server compatible with Amazon S3 APIs. It is used to store the backups created by Velero.

## metallb

metallb is a load balancer for bare metal Kubernetes clusters. It provides a network load balancer implementation that can be used to expose services externally in a bare metal cluster.

```bash
sudo microk8s enable metallb
sudo microk8s kubectl -n metallb-system get pods
```

## registry

A registry is a storage and content delivery system that holds named Docker images, available in different tagged versions. It can be used to store and distribute Docker images.
You can use docker hub, but I choose to use a local registry.
It can be configured as a kubernetes service.
