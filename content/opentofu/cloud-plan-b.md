Als je je infrastructuur al cloud-agnostisch hebt opgezet met tools zoals Terraform, heb je de moeilijkste stap—de ontkoppeling van propriëtaire Cloud API's—al achter de rug.

Om volledig over te stappen op een alternatief **zonder afhankelijk te zijn van hyperscalers** (AWS, Azure, Google Cloud), zijn er drie volwaardige strategieën mogelijk:

---

### Strategie 1: Europese Cloud Providers (Sovereign Cloud)

In plaats van een Amerikaanse hyperscaler kies je voor infrastructurele spelers met een sterke focus op data-soevereiniteit, Europese privacywetgeving (GDPR) en transparante tarieven.

* **Exoscale** (Zwitsers/Oostenrijks) of **OVHcloud** (Frans): Bieden volwaardige OpenStack- en Kubernetes-architecturen aan met een uitstekende Terraform-provider.
* **Hetzner Cloud** (Duitsland): Erg populair vanwege de uitzonderlijk lage kosten/prestatie-verhouding voor Virtual Machines en Storage, gecombineerd met een hele stabiele Terraform-provider (`hetznercloud/hcloud`).
* **Scaleway** (Frankrijk): Direct alternatief voor Azure met beheerde Kubernetes (Kapsule), Object Storage (S3-compatible), en beheerde databases.

**Wat verandert er in je Terraform?**
Je vervangt de `azurerm` provider door de provider van de gekozen Europese partner (bijvoorbeeld `hcloud` of `ovh`). Doordat de logica (VM's, netwerken, firewalls) hetzelfde blijft, is de migratie-effort minimaal.

---

### Strategie 2: OpenStack / On-Premise of Co-location

Als de uitwijk-optie volledig **in eigen beheer** moet zijn (bijvoorbeeld in een lokaal datacentrum):

* **OpenStack**: Hét open-source cloudbesturingssysteem. Het heeft een officiële Terraform-provider (`terraform-provider-openstack`). Hiermee bouw je je eigen private cloud die exact op dezelfde wijze declareerbaar is als Azure.
* **Proxmox VE**: Een lichtgewicht open-source hypervisor met een volwassen Terraform-provider. Uitstekend geschikt voor uitwijkscenario's op eigen bare-metal servers.

---

### Strategie 3: Alles op Kubernetes (K8s jako de 'nieuwe OS')

Als de workloads gecontaineriseerd zijn, fungeert Kubernetes als de ultieme abstractielaag bovenop willekeurige hardware.

1. **Infrastructuur:** Gebruik Terraform alleen voor het uitrollen van de kale rekenkracht (bare metal of simpele VM's) en netwerklagen bij een alternatieve provider.
2. **Kubernetes:** Rol een lichtgewicht Kubernetes-cluster uit (bijv. met **RKE2**, **K3s** of **Talos Linux**).
3. **Application Layer:** Beheer alle workloads en afhankelijkheden (ingress, databases, messaging) via Helm of ArgoCD. Zo maakt het fysieke platform eronder niets meer uit.

---

### Aandachtspunten voor het Plan B

1. **Object Storage:** Zorg dat je applicaties S3-compatibele API's gebruiken (bijv. MinIO of de S3-API van Scaleway/Hetzner) in plaats van specifieke Azure Blob SDK's.
2. **Databases:** Schakel over op open-source engines (PostgreSQL, MySQL, Redis) in plaats van beheerde Azure-specifieke oplossingen (zoals Cosmos DB).
3. **State & Secrets:** Zorg voor een alternatief voor Azure Key Vault (bijv. **HashiCorp Vault**) en sla je Terraform state op in een algemene S3-bucket met lock-functionaliteit.
