---
title: 'Docker'
weight: 400
draft: false
---

# docker

using ubuntu 22, I found out that the docker that came with it does not work like it should

- uninstall docker

docker version
Client: Docker Engine - Community

> Version:           27.3.1
> API version:       1.47
> Go version:        go1.22.7
> Git commit:        ce12230
> Built:             Fri Sep 20 11:41:00 2024
> OS/Arch:           linux/amd64

# running openwebui

* running it from within portainer did not allow to change the host
* command prompt

sudo docker run -d -p 3000:8080 –add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data –name open-webui –restart always ghcr.io/open-webui/open-webui:main

# copy data to container

docker cp manifests/ ollama:/root/.ollama/models
Successfully copied 12.8kB to ollama:/root/.ollama/models
