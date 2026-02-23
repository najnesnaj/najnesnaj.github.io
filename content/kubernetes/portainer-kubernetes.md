---
title: 'Portainer Kubernetes'
draft: false
---

# Manage Kubernetes Clusters with portainer

Portainer is useful on linux as it provides a GUI for managing docker containers and kubernetes!

sudo microk8s kubectl apply -f [https://downloads.portainer.io/ce2-20/portainer-agent-k8s-nodeport.yaml](https://downloads.portainer.io/ce2-20/portainer-agent-k8s-nodeport.yaml)
sudo microk8s kubectl get nodes -o wide

## Add Environment in portainer:

Open Portainer in your browser.

Click Environments (left sidebar or under Home).

Click Add Environment (should be a button at the top-right).

In the wizard, select Kubernetes.

Choose Agent > Kubernetes via NodePort.

Set Name: “microk8s-local”.

Set Environment URL: 127.0.0.1:30778. (here I used the server IP address instead of localhost)

Click Add Environment.

## create a helm chart repository

```bash
in de webserver directory : eg /var/www/html
create directory charts
cd charts

helm repo index . (this creates the index.yaml file)

URL=http://IP:80/charts
```
