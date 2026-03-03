---
title: 'Portainer'
weight: 310
draft: false
---

# Portainer

## using a script

use a template for the linux container

a script from :
[https://raw.githubusercontent.com/tteck/Proxmox/refs/heads/main/install/docker-install.sh](https://raw.githubusercontent.com/tteck/Proxmox/refs/heads/main/install/docker-install.sh)

systemctl start docker
systemctl status docker

[https://192.168.0.182:9443](https://192.168.0.182:9443) (your IP)

## by hand

- create CT ubuntu22 with template
- apt update
- sudo apt install docker.io -y
- sudo systemctl status docker
- sudo usermod -aG docker $USER (add current logged on user to docker group)
- docker pull portainer/portainer-ce:latest
- docker run -d -p 9000:9000 –restart always -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce:latest

## exporting & importing

this seems to work between systems:

(origin) sudo docker save ollama/ollama:latest  > my-ollama.tar
(target) sudo docker load < my-ollama.tar
