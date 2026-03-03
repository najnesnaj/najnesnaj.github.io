---
title: 'Ana Overview'
weight: 160
draft: false
---

# Overview

> - ana_report

this contains the Docker container with a FastAPI to consult&plot the data

> - ana_model

here the model is generated, this is used for experimenting with an LLM

> - ana_github_actions

the purpose is to use github actions to build the Docker container. I want to have github build the model as well, based on an LLM generated python function that describes the disered pattern. This way a user can feed any pattern into the container and filter the database for similar patterns.

> - ana_check

this is a script that gets from ana_report all the companies, and then checks if they match the desired pattern, and create an entry in the database
