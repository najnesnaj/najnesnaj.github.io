---
title: 'Azure Cli'
weight: 1440
draft: false
---

# Configuring the Azure CLI

The Azure CLI is a command-line tool that allows you to manage Azure resources. You can configure the CLI to use different authentication methods, set default values for commands, and customize the output format.
This document provides an overview of the configuration options available in the Azure CLI and how to set them up.

## Installation

[https://learn.microsoft.com/nl-nl/cli/azure/](https://learn.microsoft.com/nl-nl/cli/azure/)

**first : activate azure (portal)**

```bash
To install the Azure CLI, follow these steps:
1. **Install the Azure CLI**:
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```
2. **Verify the installation**:
   ```bash
   az --version
   ```
3. **Login to your Azure account**:
     ```bash

     az login
     ```
 A browser window will open for you to sign in with your Azure credentials
```

-> first need to activate the azure

```bash
az account show
{
"environmentName": "AzureCloud",
"homeTenantId": "4ded4bb1-6bff-42b3-aed7-6a36a503bf7a",
"id": "76f32639-1556-4f3a-bdb3-833b5946aa46",
"isDefault": true,
"managedByTenants": [],
"name": "MCT",
"state": "Enabled",
"tenantDefaultDomain": "hogeschool-wvl.be",
"tenantDisplayName": "Hogeschool West-Vlaanderen",
"tenantId": "4ded4bb1-6bff-42b3-aed7-6a36a503bf7a",
"user": {
    "name": "jan.jansen@ibz.be",
    "type": "user"
}
}
```

## basic commands

```bash
# View account info
az account show

# List all resource groups
az group list

# List available regions
az account list-locations

# Get help for commands
az --help
az group --help
```

## prepare environment

(resource group already exist, if not : az group create –name <name> –location <location>)

#create container registry
az acr create –resource-group HAC9909-MasterclassDeployingAISolutions –name jjaacr –sku basic

## using dockerhub image

pull from docker and push to azure

```bash
az acr login --name jjaacr
docker pull buticosus/my-postgres-image:latest

docker tag buticosus/my-postgres-image:latest jjaacr.azurecr.io/my-postgres-image:latest
docker push jjaacr.azurecr.io/my-postgres-image:latest
```

## delete a container

```bash
az containerapp delete \
  --name postgres-app \
  --resource-group HAC9909-MasterclassDeployingAISolutions \
  --yes
```

## create azure container apps environment

```bash
az containerapp env create --name jja-env --resource-group HAC9909-MasterclassDeployingAISolutions --location westeurope

az containerapp list   --resource-group HAC9909-MasterclassDeployingAISolutions   --output table
```

Name            Location     ResourceGroup                            Fqdn
————–  ———–  —————————————  —————————————————————————
postgres-app    West Europe  HAC9909-MasterclassDeployingAISolutions  postgres-app.internal.wittydesert-4044e50c.westeurope.azurecontainerapps.io
ana-report-app  West Europe  HAC9909-MasterclassDeployingAISolutions  ana-report-app.wittydesert-4044e50c.westeurope.azurecontainerapps.io

## Create Azure Container Apps Environment (cursus extract)

```bash
# Create Container Apps environment
az containerapp env create \
  --name myapp-env-[ns] \
  --location westeurope

# Create PostgreSQL Container App
az containerapp create \
  --name postgres-app \
  --environment myapp-env-[ns] \
  --image myappacrns.azurecr.io/postgres:13 \
  --registry-server myappacrns.azurecr.io \
  --env-vars POSTGRES_USER=user POSTGRES_PASSWORD=password POSTGRES_DB=fastapi_db \
  --target-port 5432 \
  --ingress internal

# Create FastAPI Container App
az containerapp create \
  --name fastapi-app \
  --environment myapp-env-[ns] \
  --image myappacrns.azurecr.io/fastapi-app:latest \
  --registry-server myappacrns.azurecr.io \
  # Look at the environment variables you used in your fastapi-application that you created in the previous assignments
  --env-vars DATABASE_URL="postgresql://user:password@postgres-app:5432/fastapi_db" \
  --target-port 80 \
  --ingress external
```

## getting login

```bash
az acr credential show --name jjaacr --resource-group HAC9909-MasterclassDeployingAISolutions
```

## connect to internally db

```bash
az containerapp exec --name postgres-app2-jja  --resource-group HAC9909-MasterclassDeployingAISolutions
INFO: Successfully connected to container: 'postgres-app2-jja'. [ Revision: 'postgres-app2-jja--twvwkg2', Replica: 'postgres-app2-jja--twvwkg2-7cc8f44987-r9d7w'].
# psql -U myuser -d mydatabase

---check content db
select count(*) from companies;
```

## starting containers

```bash
az login
az acr login --name myappacrjja
az containerapp env create --name myapp-env2-jja --location westeurope
```

```bash
 az containerapp create \
--name postgres-buticosus-app \
--environment myapp-env2-jja \
--image myappacrjja.azurecr.io/my-postgres-image:latest \
--registry-server myappacrjja.azurecr.io \
--env-vars POSTGRES_USER=myuser POSTGRES_PASSWORD=mypassword POSTGRES_DB=mydatabase \
--target-port 5432 \
--transport tcp \
--ingress internal \
--registry-server myappacrjja.azurecr.io \
--registry-username myappacrjja \
--registry-password f4Kl31+A0+p9079IqAgtMf1/4nI/UOnmTvTcFH1fKe+ACRCnl67c \
--min-replicas 1 \
--max-replicas 1


 az containerapp create   --name adminer-app-jja   --environment myapp-env2-jja   --image myappacrjja.azurecr.io/adminer:latest  --env-vars ADMINER_DEFAULT_SERVER=postgres-buticosus-app   --target-port 8080   --ingress external  --registry-username myappacrjja --registry-password f4Kl31+A0+p9079IqAgtMf1/4nI/UOnmTvTcFH1fKe+ACRCnl67c --registry-server myappacrjja.azurecr.io


 az containerapp create \
--name ana-report-app \
--resource-group HAC9909-MasterclassDeployingAISolutions\
--environment myapp-env2-jja \
--env-vars POSTGRES_USER=myuser POSTGRES_PASSWORD=mypassword POSTGRES_DB=mydatabase POSTGRES_HOST=postgres-buticosus-app \
--registry-password f4Kl31+A0+p9079IqAgtMf1/4nI/UOnmTvTcFH1fKe+ACRCnl67c \
--image myappacrjja.azurecr.io/ana_report:latest \
--registry-server myappacrjja.azurecr.io \
--target-port 8001 \
--ingress external

 az containerapp create   --name ana-report-app   --resource-group HAC9909-MasterclassDeployingAISolutions  --environment myapp-env2-jja   --image myappacrjja.azurecr.io/ana_report:latest   --registry-server myappacrjja.azurecr.io   --env-vars   POSTGRES_USER=myuser POSTGRES_PASSWORD=mypassword POSTGRES_DB=mydatabase POSTGRES_HOST=postgres-buticosus-app  --target-port 8001   --ingress external
```
