---
title: 'Cloud Setup'
weight: 350
draft: false
---

# Cloud Setup Documentation

This document provides an overview of the files used to set up Docker containers and Kubernetes deployments for the project. It explains the purpose of each file and how to use them.

## Docker Setup

1. **\`Dockerfile\`**
   - **Purpose**: Defines the instructions to build the Docker image for the API service.
   - **Usage**: The Dockerfile is used by Docker to create a containerized environment for the API. It includes the necessary dependencies and configurations for running the application.

   **Command to build the Docker image**:
   ``bash
   docker build -t my-api-image .
   ``
2. **\`compose.yml\`**
   - **Purpose**: Defines the Docker Compose configuration for running multiple services (e.g., PostgreSQL, pgAdmin, and the API) together.
   - **Usage**: This file is used to orchestrate the services required for the project.

   **Command to start the services**:
   ``bash
   docker-compose up -d
   ``

   **Services included**:
   - db: Runs a PostgreSQL database container.
   - pgadmin: Runs a pgAdmin container for managing the database.
   - api: Runs the API service container.
3. **\`.env\`**
   - **Purpose**: Stores environment variables used by the compose.yml file and the application.
   - **Usage**: Update this file with the required environment variables (e.g., database credentials).

   **Example**:
   ``plaintext
   POSTGRES_USER=myuser
   POSTGRES_PASSWORD=mypassword
   POSTGRES_DB=mydatabase
   ``

## Kubernetes Setup

1. **\`postgres-pv.yaml\`**
   - **Purpose**: Defines a PersistentVolume (PV) for PostgreSQL to store data persistently in Kubernetes.
   - **Usage**: Apply this file to create a PV in the Kubernetes cluster.

   **Command**:
   ``bash
   kubectl apply -f postgres-pv.yaml
   ``
2. **\`postgres-pvc.yaml\`**
   - **Purpose**: Defines a PersistentVolumeClaim (PVC) to request storage from the PersistentVolume for PostgreSQL.
   - **Usage**: Apply this file to create a PVC in the Kubernetes cluster.

   **Command**:
   ``bash
   kubectl apply -f postgres-pvc.yaml
   ``
3. **\`postgres-deployment.yaml\`**
   - **Purpose**: Defines the deployment and service for the PostgreSQL database in Kubernetes.
   - **Usage**: Apply this file to deploy PostgreSQL in the Kubernetes cluster.

   **Command**:
   ``bash
   kubectl apply -f postgres-deployment.yaml
   ``
4. **\`pgadmin-deployment.yaml\`**
   - **Purpose**: Defines the deployment and service for pgAdmin in Kubernetes.
   - **Usage**: Apply this file to deploy pgAdmin in the Kubernetes cluster.

   **Command**:
   ``bash
   kubectl apply -f pgadmin-deployment.yaml
   ``
5. **\`api-deployment.yaml\`**
   - **Purpose**: Defines the deployment and service for the API in Kubernetes.
   - **Usage**: Apply this file to deploy the API in the Kubernetes cluster.

   **Command**:
   ``bash
   kubectl apply -f api-deployment.yaml
   ``

## General Notes

- **Docker**: Use Docker Compose for local development and testing. It allows you to quickly spin up all required services.
- **Kubernetes**: Use Kubernetes for deploying the application in a production or cloud environment. Ensure that your cluster is properly configured before applying the YAML files.
