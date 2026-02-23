---
title: 'About'
draft: false
---

# About

Warning : This project is in development and not ready for production. The documentation is a work in progress.
The document is rather a quick reminder than a full blown manual.

I attended a course, but I learn by doing. So I decided to create a project to apply the knowledge I gained.
The project is about investing in the stock market, but also about setting up Kubernetes, Docker, Helm, ML, CI/CD, github actions and other tools.

This project’s data is real stockdata. (which is messy and often incomplete, like real data)
The data is a large json object and stored in postgres as a JSONB field. (nosql)

Different techniques, learned while attending the course, were applied.

## Timeseries

Stockdata is timeseries data. (sequential data with a timestamp)
Stockdata can be considered public data, in contrast to the data of my workplace.
However, the project can be applied to other timeseries data (work related) as well.

## Container (cloud)

The software was packed in Docker containers.
This allows for deployment on a Kubernetes cluster as well. (helm script provided)
The software has been deployed on Azure as well.

## Visual

The data is accessible through a FASTAPI interface, and can be plotted.

## Patterns

As an investor, I’m interested in patterns.
Three green periods, followed by a red one.
Reoccuring patterns, turnaround pattern …
It would be cool to pick a certain pattern out of a haystack. (see : results)

## AI model

synthetic data was used to create a keras model.
The purpose is to filter out similar patterns in the database.

It was not entirely to my liking, so I tried a few other techniques (see: results)

## Cloud

This was my introduction to Azure containers as well as ML studio, Azure CLI. I used the data and scripts provided, but I still had to spend a lot of time due to the steep learning curve. It is a way to construct professional ML applications, by providing building blocks. To experiment and get quick results, I used my own environment.

## K8s

Apart from the recommended local setup of a simple k3s cluster, I installed Talos on a server. I used virtual machines, which allowed for easy adding of clusternodes (which would normally have been real servers). Talos is really naked, or stripped down (out of security concerns) , so you need to install all the functionality yourself. I figure, if the application works on Talos, it should work on Azure, whereas the other way around … There is an overhead, but it might prove worth while if moving away from Azure or to assure compatibility or avoid vendor locker in, or … Another advantage might be that the cloudservices are really within your own network!

## Todo / ideas / github actions

Containers are really a way to get up and running quickly. Kubernetes is an extension, which might be the choice in an production environment. I have installed a containerregistry and a github repository on a local kubernetes cluster. This might enable shielding your code from unwanted eyes.

As I noticed, changing code or training a new ML model, might trigger a lot of extra work. It would be cool if a codechange triggered the deployment of an updated container in a kubernetes cluster. I think there is a way to do this locally instead of using github actions, which publishes the containers, but then you would need another cloud service…
