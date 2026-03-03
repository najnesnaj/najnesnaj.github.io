---
title: 'Kompose'
weight: 820
draft: false
---

# Kompose

Kompose is a tool to help users who are familiar with docker-compose move to Kubernetes. It takes a Docker Compose file and translates it into Kubernetes resources.

## Install Kompose

```bash
curl -L https://github.com/kubernetes/kompose/releases/download/v1.26.1/kompose-linux-amd64 -o kompose
chmod +x kompose
sudo mv ./kompose /usr/local/bin/kompose

# Or with go
go install github.com/kubernetes/kompose@latest
kompose version  # check the version of Kompose   # On Linux
```

## create helm chart

```bash
kompose convert -f compose.yml --chart
# This will create a helm chart in the current directory

# To create a helm chart in a specific directory
kompose convert -f compose.yml --chart -o my-helm-chart
```

## Misery

#### NOTE
The tool cannot handle volumes, so persistent volumes have to be created manually.
The tool cannot handle specifics like “depends on”.
After adapting compose.yml it still did not work properly.
