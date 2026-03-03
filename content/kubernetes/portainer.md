---
title: 'Portainer'
weight: 520
draft: false
---

# Portainer

Community Edition was used.

Portainer is useful on linux as it provides a GUI for managing docker containers and kubernetes!

Usually it is available at https://localhost:9443 after installation.

## install

```bash
#!/bin/bash

# Update system packages
#sudo apt update
#sudo apt upgrade -y

# Install Docker (if not already installed)
sudo apt install -y docker.io

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Create Docker volume for Portainer data
sudo docker volume create portainer_data

# Pull and run Portainer Community Edition
sudo docker run -d \
-p 8000:8000 \
-p 9443:9443 \
--name portainer \
--restart=always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer-ce:latest
```

## managing docker

## managing kubernetes

here you hit a limit to what is possible with the community edition.
However there still is ways to manage kubernetes clusters with the community edition.
