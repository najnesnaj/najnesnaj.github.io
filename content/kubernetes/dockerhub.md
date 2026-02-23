---
title: 'Dockerhub'
draft: false
---

# Using dockerhub

Dockerhub is a public registry for Docker images. It is the default registry used by Docker when you run the docker pull command. You can use Docker Hub to store and share your Docker images with others.
You can also use it to find and download images created by other users. Docker Hub provides a web interface for browsing and searching for images, as well as a command-line interface for managing your images and repositories.

## installing custom database on Talos (kubernetes)

[https://hub.docker.com/repository/docker/buticosus/my-postgres-image/general](https://hub.docker.com/repository/docker/buticosus/my-postgres-image/general)

docker run –name myuser -e POSTGRES_PASSWORD=mypassword -p 5432:5432 -d buticosus/my-postgres-image
