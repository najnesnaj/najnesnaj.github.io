# On-Premises Cloudplatform — Strategienota

**Bestemd voor:** Hoger management / directie
**Onderwerp:** Van containerpilots (MijnBureau, Euro-Office) naar een robuust on-premises Kubernetes-platform
**Status:** Voorstel — ter besluitvorming

---

## 1. Samenvatting

We onderzoeken applicaties zoals **MijnBureau** en **Euro-Office** voor gebruik in
een **semi-productieomgeving**. Een puur containergebaseerde pilot (de software
op één enkele Docker-host) volstaat voor een demonstratie, maar is niet robuust
genoeg voor semi-productie: het ontbreekt aan beschikbaarheid, herhaalbaarheid,
herstelbaarheid en een duidelijke audittrail.

We stellen voor om te evolueren naar een **Kubernetes-platform met hoge
beschikbaarheid (HA)** op onze eigen Proxmox-infrastructuur. Omdat zo'n platform
complex is, behandelen we de hele omgeving als **Infrastructure as Code (IaC)**:
ze wordt beschreven in versiebeheerde bestanden en kan automatisch worden
opgebouwd en gereproduceerd. Concreet:

- **OpenTofu (Terraform)** voorziet de infrastructuur op **Proxmox**.
- **Talos Linux** — een *immutable* (onveranderlijk) besturingssysteem — draait
  de Kubernetes-nodes.
- Een toegewijde **beheerserver (`k8s-management`)** beheert het cluster.
- **Ansible** automatiseert de serverconfiguratie (SSH-toegang, tooling zoals `talosctl`).
- **ArgoCD** levert applicaties vanuit Git (GitOps).

Zo krijgen we een **cloudachtig platform op onze eigen hardware**: dezelfde
tools, vaardigheden en werkwijzen die ons team al gebruikt op **Azure**, kunnen
lokaal worden toegepast. **OpenCode** (AI-ondersteuning) versnelt de opbouw en
documentatie van deze omgeving, onder menselijke controle.

**Aanbeveling:** keur een gefaseerde uitrol goed, te beginnen met een testcluster.

---

## 2. Waarom we verder moeten dan een "pure container"-opstelling

MijnBureau en Euro-Office worden doorgaans als containers geleverd. Eén enkele
Docker-host is snel opgezet, maar schiet voor semi-productie tekort:

| Aspect | Eén containerhost | Doelplatform |
| --- | --- | --- |
| Beschikbaarheid | Eén host = één storingspunt | HA-cluster met automatische herplaatsing |
| Herhaalbaarheid | Handmatige, ongedocumenteerde opzet | Volledige omgeving als versiebeheerde code |
| Herstel | Handmatig heropbouwen | Heropbouwen/vervangen vanuit code binnen enkele minuten |
| Schaalbaarheid | Handmatig | Declaratief en beheerst |
| Beveiliging | Ad-hoc toegang | Immutable OS, sleutelgebaseerde toegang, minimale rechten |
| Auditeerbaarheid | Beperkt | Elke wijziging beoordeeld en vastgelegd in Git |

De conclusie: we hebben een **platform** nodig, geen verzameling handmatig
geconfigureerde servers. De grootste drempel is de complexiteit — precies daarom
kiezen we voor IaC en GitOps in plaats van handmatig beheer.

---

## 3. Voorgestelde architectuur

Het platform is opgebouwd in lagen, elk met een bewezen, industriestandaard
component:

| Laag | Onze keuze | Waarom |
| --- | --- | --- |
| Virtualisatie | **Proxmox VE** | Al in gebruik on-premises; geen nieuwe hypervisor nodig |
| Provisioning | **OpenTofu (Terraform)** | Declaratieve, versiebeheerde, reproduceerbare infrastructuur |
| Besturingssysteem van nodes | **Talos Linux** | Immutable, minimaal en volledig API-gestuurd — kleiner aanvalsoppervlak, geen handmatige logins |
| Clusterbeheer | **`k8s-management`-server** | Een toegewijde host met `talosctl`/`kubectl`, geconfigureerd door Ansible |
| Serverconfiguratie | **Ansible** | Automatiseert en documenteert de configuratie (SSH-server, tooling) |
| Applicatielevering | **ArgoCD (GitOps)** | Houdt het cluster continu in lijn met de gewenste toestand in Git |
| Softwareverpakking | **Helm-charts in Git** | Standaard, versiebeheerde verpakking van Kubernetes-software |

### Testtopologie

Voor de eerste testopstelling zetten we in:

- **1 Kubernetes control plane**-node
- **3 worker-nodes**

> Opmerking: voor echte hoge beschikbaarheid wordt het control plane in fase 2
> uitgebreid naar **drie control planes**. De testtopologie bewijst de aanpak; de
> productietopologie levert de redundantie.

Talos biedt geen rechtstreekse shell-toegang en moet via zijn API worden beheerd
— daarom bestaat de toegewijde **`k8s-management`**-server. Ansible configureert
die server automatisch (inclusief de SSH-server en de Talos-/Kubernetes-tooling),
zodat ook die vanuit code kan worden heropgebouwd.

---

## 4. Hoe een wijziging verloopt — GitOps met ArgoCD

In plaats van individuele Helm-charts handmatig te installeren, kiezen we voor
**CI/CD en GitOps**:

1. Een engineer wijzigt een Helm-chart of de bijbehorende configuratie in de
   **Git-repository**.
2. De **CI/CD-pijplijn** valideert, test en publiceert de wijziging.
3. **ArgoCD** detecteert de nieuwe gewenste toestand en past ze toe op het cluster.
4. Het cluster wordt **continu in lijn gebracht** met Git: handmatige afwijking
   (drift) wordt automatisch gecorrigeerd en elke wijziging heeft een
   controleerbare geschiedenis.

Het resultaat is één bron van waarheid (Git), geen handmatige handelingen op het
cluster, en een volledige audittrail van wie wat en wanneer heeft gewijzigd.

---

## 5. Het voordeel "cloud on-premises"

Omdat het platform dezelfde bouwstenen gebruikt als de publieke cloud,
**bootsen we de cloud na op locatie**:

- Dezelfde containerformaten, Helm-charts en pijplijnen die op **Azure** worden
  gebruikt, werken lokaal — en omgekeerd.
- **Hetzelfde team en dezelfde vaardigheden** kunnen on-premises ontwikkelen en
  in de cloud uitrollen — minder omscholing, minder dubbel werk en minder
  leveranciersafhankelijkheid.
- Workloads kunnen met minimale aanpassingen tussen omgevingen worden verplaatst.

---

## 6. Beveiliging en governance

- **Immutable besturingssysteem** (Talos): nodes kunnen niet handmatig worden
  gewijzigd, wat configuratie-drift en het aanvalsoppervlak verkleint.
- **SSH op basis van sleutels, met minimale rechten**, en
  wachtwoordauthenticatie uitgeschakeld op beheerservers.
- **Git als enige bron van waarheid**: wijzigingen worden door collega's
  beoordeeld voordat ze productie bereiken.
- **Reproduceerbare heropbouw**: de omgeving kan vanuit code worden hersteld, wat
  rampherstel en compliance ondersteunt.

---

## 7. Rol van AI-ondersteuning (OpenCode)

We gebruiken **OpenCode** om het werk te versnellen:

- Het genereren en beoordelen van infrastructuurcode (OpenTofu/Terraform,
  Ansible) en documentatie.
- Ondersteuning bij probleemoplossing en het vastleggen van kennis.

Vangrails: AI-gegenereerd werk wordt **beoordeeld en goedgekeurd door onze
engineers**, en alle wijzigingen lopen nog steeds via Git en het normale
wijzigingsproces. AI verhoogt de snelheid; de verantwoordelijkheid blijft bij de mens.

---

## 8. Gefaseerde roadmap

| Fase | Scope | Resultaat |
| --- | --- | --- |
| **Fase 1 — Test** | Control plane + 3 workers op Proxmox, ingericht met OpenTofu, nodes op Talos, `k8s-management` + Ansible, ArgoCD GitOps. Validatie van MijnBureau en Euro-Office. | Bewezen, reproduceerbare testomgeving |
| **Fase 2 — Hoge beschikbaarheid** | 3 control planes, ingress, monitoring, back-ups, beheer van secrets. | Robuust platform |
| **Fase 3 — Semi-productie** | Hardening, RBAC, beleid, rampherstel, serviceniveaus, supportproces. | Productieklaar platform |

---

## 9. Risico's en maatregelen

| Risico | Maatregel |
| --- | --- |
| Complexiteit van Kubernetes | Inkapselen in IaC en GitOps; standaardcomponenten; gedocumenteerd |
| Kennistekort | Hergebruik bestaande Azure-/Kubernetes-vaardigheden; AI-ondersteunde onboarding |
| Nieuwe technologie (Talos) | Klein beginnen in fase 1; immutable OS verlaagt de beheerslast |
| Leveranciersafhankelijkheid | Open standaarden (Kubernetes, Helm, Terraform/OpenTofu, Git) |
| Beveiliging | Immutable OS, sleutelgebaseerde toegang, door collega's beoordeelde wijzigingen |

---

## 10. Aanbeveling

We bevelen aan om het **testplatform van fase 1** goed te keuren. Het is
laagrisico en zelfstandig, hergebruikt de bestaande Proxmox-hardware en de
cloudvaardigheden van ons team, en levert een reproduceerbare basis die kan
uitgroeien tot een semi-productieplatform met hoge beschikbaarheid voor
MijnBureau, Euro-Office en toekomstige applicaties.

**Gevraagd besluit:** goedkeuring om met fase 1 te starten en de benodigde
engineeringstijd toe te wijzen.
