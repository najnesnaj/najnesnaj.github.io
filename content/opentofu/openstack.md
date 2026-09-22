Het verschil in gebruikersgroep komt voort uit het niveau waarop beide technologieën opereren: **OpenStack beheert de hardware** (IaaS), terwijl **Kubernetes de applicaties beheert** (PaaS/Containers).

Er is een duidelijke verdeling in wie wat gebruikt, én waarom ze in de praktijk heel vaak samen worden ingezet.

---

### 1. Wie gebruikt OpenStack? (De 'Cloud Builders')

OpenStack wordt gebruikt door organisaties die hun **eigen fysieke datacenters willen transformeren tot een volwaardige private cloud**. Zij hebben behoefte aan virtuele netwerken, storage-pools en Virtual Machines (VM's) op bare-metal hardware.

* **Telecomproviders (Telco's):** Bedrijven zoals *Vodafone, Deutsche Telekom, Orange en AT&T*. Zij gebruiken OpenStack voor *Network Functions Virtualization (NFV)* om 5G-netwerkinfrastructuur en virtuele routers te draaien.
* **Grote Enterprise Bedrijven:** Financiële instellingen, verzekeraars en overheden (bijv. *Bloomberg, Walmart, CERN*). Zij hebben strikte wetgeving rondom data-soevereiniteit of willen besparen op dure Azure/AWS rekeningen voor zware, traditionele VM-workloads.
* **Europese Cloud Providers:** Onafhankelijke hostingpartijen zoals *OVHcloud, Scaleway en Exoscale* bouwen hun commerciële cloudplatformen op OpenStack.

**Primaire focus:** Systeembeheerders, Cloud Engineers en Network Engineers die de onderliggende infrastructurele lagen beheren.

---

### 2. Wie gebruikt Kubernetes? (De 'App Developers')

Kubernetes wordt gebruikt door vrijwel **elk modern softwareteam** dat microservices en gecontaineriseerde applicaties op schaal wil draaien en automatisch wil schalen.

* **SaaS-bedrijven en Tech Startups:** Bedrijven zoals *Spotify, Airbnb, Uber, Pinterest, GitHub*. Zij bouwen applicaties die snel moeten updaten, uitrollen (CI/CD) en meeschalen op basis van drukte.
* **DevOps-teams binnen MKB & Corporate:** Vrijwel elke IT-afdeling die afstapt van monolithische applicaties en overgaat op Docker-containers.
* **Multi-cloud / Hybrid-cloud Gebruikers:** Bedrijven die hun applicaties exact hetzelfde willen laten draaien op Azure (AKS), AWS (EKS), Google Cloud (GKE) én on-premise.

**Primaire focus:** Software Developers, DevOps Engineers en Platform Engineers die applicaties uitrollen zonder zich bezig te houden met fysieke servers of netwerkkaarten.

---

### 3. De Werkelijkheid: K8s óp OpenStack

Het is zelden een vraag van *OpenStack óf Kubernetes*. In een eigen datacenter-omgeving versterken ze elkaar juist:

```
+-------------------------------------------------------+
|  Applicaties / Microservices                          |
+-------------------------------------------------------+
|  Kubernetes (Beheert de containers & applicaties)     |
+-------------------------------------------------------+
|  OpenStack (Beheert VM's, virtuele netwerken & disks) |
+-------------------------------------------------------+
|  Fysieke Hardware (Bare-metal servers in datacenter)  |
+-------------------------------------------------------+

```

* **Hoe het samenwerkt:** Volgens de *OpenInfra Foundation* draait Kubernetes op meer dan **85% van alle OpenStack-installaties**.
* **Waarom?** OpenStack levert de virtuele VM's en de fysieke opslag/netwerkisolatie binnen het datacenter. Bovenop die virtuele machines wordt een Kubernetes-cluster uitgerold waar ontwikkelaars hun applicaties op deployen.

---

### Samengevat

| Categorie | OpenStack | Kubernetes |
| --- | --- | --- |
| **Wat beheert het?** | Fysieke hardware, VM's, netwerken, bare-metal | Containers en microservices |
| **Doelgroep** | Infrastructure Engineers, Telco's, Hoster/Cloudproviders | Software Developers, DevOps & Platform Engineers |
| **Doel** | Een eigen "Azure/AWS" bouwen in een datacenter | Cloud-native applicaties schalen en beheren |
| **Analoog** | De grond en het fundament van een flatgebouw | Het interieur en de indeling van de appartementen |

Als je **Plan B** is om Azure te verlaten:

* Gebruik **Kubernetes** als je applicatie-abstractielaag (omdat applicaties daardoor direct overzetbaar zijn).
* Gebruik **OpenStack** alleen als je besluit om de fysieke hardware in een eigen datacentrum volledig zelf te gaan beheren als onderlaag voor die Kubernetes-clusters.
