Een hybride of "Azure-first, Cloud-Agnostic" strategie stelt je in staat om **vandaag te profiteren van de snelheid en het beheer van Azure**, terwijl je de **architectuur zo inricht dat je morgen zonder ingrijpende herbebouwing kunt overstappen naar een kale/eigen Kubernetes-stack** (zoals Talos Linux met K3s/RKE2 of een andere cloud provider).

Het kernprincipe van deze strategie is: **Azure leveren alleen de Compute, Opslag en Netwerk (Infrastructuur). Alle logica, applicaties en middleware draaien *in* de Kubernetes-cluster.**

---

### Strategisch Framework: De 4 Pijlers

```text
┌───────────────────────────────────────────────────────────┐
│              4. Applicatie & Helm Code                    │
│   (100% Identiek voor Azure, Talos, AWS of On-Prem)       │
├───────────────────────────────────────────────────────────┤
│           3. Cloud-Agnostic Platform Services             │
│   (Ingress, Cert-Manager, Vault, Prometheus, Postgres)    │
├───────────────────────────────────────────────────────────┤
│            2. Kubernetes Orchestratie Laag                │
│    (Fase 1: AKS | Fase 2: Talos Linux via Terraform)     │
├───────────────────────────────────────────────────────────┤
│             1. IaaS (Azure Core Infrastructure)           │
│           (Resource Groups, VNet, Basic Storage)          │
└───────────────────────────────────────────────────────────┘

```

---

### Pijler 1: Infrastructuur via Terraform (Ontkoppeld)

Houd je Terraform-code strikt gescheiden in twee lagen:

1. **Laag A (Cloud Provisioner):** Maakt Azure Virtual Networks, Subnets en Compute VM's (of AKS) aan.
2. **Laag B (App Provisioner):** Gebruikt de `kubernetes` en `helm` providers van Terraform om software op het cluster te installeren.

**Migratie-effect:** Als je overstapt naar Talos Linux (op bare-metal of generic VM's), vervang je enkel **Laag A**. **Laag B blijft 100% ongewijzigd.**

---

### Pijler 2: Vermijd Propriëtaire Azure PaaS-Services

Vervang Azure-specifieke diensten door open-source equivalenten die binnen Kubernetes kunnen draaien:

| Azure Service (Lock-in) | Cloud-Agnostic Alternatief | Hoe het draait in de strategie |
| --- | --- | --- |
| **Azure App Service** | **Standard Containers (Helm)** | Draait als Deployments/Services op Kubernetes. |
| **Azure Key Vault** | **HashiCorp Vault** of **External Secrets Operator** | External Secrets haalt eventueel secrets uit Azure Key Vault, maar je apps spreken alleen standaard Kubernetes `Secret` resources aan. |
| **Azure Service Bus** | **RabbitMQ / NATS / Apache Kafka** | Gedeployed via Helm-charts op Kubernetes. |
| **Azure Cosmos DB / Azure SQL** | **PostgreSQL (CloudNativePG Operator)** | Gebruik de CloudNativePG operator voor automatisering van back-ups, failover en opslag. |
| **Azure Blob Storage (Direct)** | **MinIO** of **CSI Drivers** | Laat applicaties communiceren via de S3-API (MinIO) of koppel opslag via standaard Kubernetes Persistent Volume Claims (PVC's). |

---

### Pijler 3: Ingress & Netwerkidentiteit op Kubernetes-niveau

Laat Azure niet de interne routering of SSL-afhandeling doen.

* **Ingress Controller:** Gebruik **Traefik** of **NGINX Ingress** *binnen* het cluster.
* **Certificaten:** Gebruik **Cert-Manager** gecombineerd met Let's Encrypt voor automatische SSL-certificaten.
* **Service Mesh / CNI:** Gebruik **Cilium** als CNI (Container Network Interface). Talos Linux ondersteunt Cilium uitstekend. Als je dit nu al op AKS gebruikt, is de netwerklaag bij een migratie exact gelijk.

---

### Roadmap: Van Azure (Fase 1) naar Talos Linux (Fase 2)

#### Fase 1: Opstarten op Azure (Gecontroleerde AKS)

1. **AKS als opstap:** Start met Azure Kubernetes Service (AKS), maar configureer het minimaal. Gebruik géén Azure-specifieke add-ons (zoals Application Gateway Ingress Controller).
2. **GitOps Workflow:** Gebruik **ArgoCD** of **FluxCD** voor de uitrol van applicaties. Alle configuraties (YAML/Helm) staan in Git repositories.
3. **PaaS Vermijden:** Implementeer databases, caching en messaging direct op AKS via operators (zoals CloudNativePG en RabbitMQ).

#### Fase 2: De overstap voorbereiden (Talos op Azure VM's of Proxmox/Bare-Metal)

1. **Talos Testen op Azure:** Talos Linux kan eenvoudig draaien op Azure Virtual Machines. Je kunt een nieuw Kubernetes-cluster bouwen *op Azure VM's* met Talos om de werking te valideren.
2. **Cluster Kopiëren:** Koppel je GitOps-tool (ArgoCD/FluxCD) aan het nieuwe Talos-cluster. ArgoCD leest je Git-repository uit en bouwt de exacte kweekvijver van applicaties en diensten op het nieuwe cluster.
3. **Data Migratie:** Synchroniseer databases (bijv. Postgres streaming-replicatie van AKS naar Talos) en zet de DNS om.

---

### Samenvatting van de Voordelen

* **Geen Vendor Lock-in:** Je applicaties, monitoring (Prometheus/Grafana), beveiliging en uitrol-pipelines zijn 100% onafhankelijk van Azure.
* **Lage Drempel:** Je kunt direct starten met het gemak van Azure (AKS) voor de opschaling, zonder dat je vastzit aan hun ecosysteem.
* **Simpele Migratie:** Bij een uiteindelijke overstap naar Talos Linux (op Proxmox, Hetzner, Bare-Metal of AWS) verander je alleen het "fundament" van de server-knoop-punten; de complete applicatielaag verhuist naadloos mee.
