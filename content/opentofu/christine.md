# Cloudplatform on-premises — beknopte nota

**Voor:** Christine
**Onderwerp:** Van containerpilots (MijnBureau, Euro-Office) naar een robuust Kubernetes-platform
**Status:** Ter besluitvorming

---

## Kern

Voor MijnBureau en Euro-Office volstaat een eenvoudige containeropstelling voor
een demo, maar niet voor semi-productie. We stellen voor om te evolueren naar een
**Kubernetes-platform met hoge beschikbaarheid (HA)** op onze eigen
Proxmox-hardware. Omdat dit complex is, beschrijven we de hele omgeving als
**Infrastructure as Code**: reproduceerbaar, versiebeheerd en automatisch op te bouwen.

## Waarom niet op één Docker-host

- Eén host = één storingspunt, geen echte beschikbaarheid.
- Handmatige opzet is foutgevoelig en moeilijk te herhalen of te herstellen.
- Geen duidelijke audittrail van wijzigingen.

## Onze oplossing

- **OpenTofu (Terraform)** richt de infrastructuur in op **Proxmox**.
- **Talos Linux** (immutable/onveranderlijk OS) draait de Kubernetes-nodes.
- **`k8s-management`-server** beheert het cluster; **Ansible** automatiseert de configuratie.
- **ArgoCD (GitOps)** levert applicaties vanuit **Git**; elke wijziging wordt
  automatisch doorgevoerd en gecontroleerd.
- Software komt als **Helm-charts in Git** — geen handmatige installaties.

Testopstelling: **1 control plane + 3 workers**. Voor echte HA groeien we in
fase 2 naar **3 control planes**.

## Voordelen

- **Cloud on-premises:** dezelfde tools en vaardigheden als op **Azure**; het team
  kan lokaal ontwikkelen en uitrollen, met minder leveranciersafhankelijkheid.
- **Betrouwbaar en herhaalbaar:** uitval wordt opgevangen en de omgeving kan
  binnen enkele minuten vanuit code worden hersteld.
- **Veilig en aantoonbaar:** immutable OS, sleutelgebaseerde toegang,
  peer-reviewed wijzigingen in Git.

## Roadmap

1. **Test** — platform opzetten en MijnBureau/Euro-Office valideren.
2. **Hoge beschikbaarheid** — 3 control planes, monitoring, back-ups.
3. **Semi-productie** — hardening, RBAC, rampherstel, serviceniveaus.

## Gevraagd besluit

Goedkeuring om met **fase 1 (het testplatform)** te starten en de benodigde
engineeringstijd toe te wijzen. Laag risico, hergebruikt bestaande hardware en
vaardigheden, en vormt de basis voor verdere groei.
