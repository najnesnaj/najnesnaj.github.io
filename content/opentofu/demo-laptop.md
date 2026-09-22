Om op je laptop **zonder zware hardware** toch het complete "Cloud Native -> Infrastructure-as-Code -> Kubernetes -> App" verhaal te tonen, is de beste truc om **Docker te gebruiken als vervanging voor OpenStack / Bare Metal**.

Met **OpenTofu** stuur je lokaal Docker aan om de infrastructurele laag (VM's/netwerken) te maken, waarop vervolgens het Kubernetes-cluster en de apps uitgerold worden. Zo laat je de **exacte workflow** zien die je in productie op OpenStack zou gebruiken.

Hier is hoe je dit in 4 stappen opzet en demonstreert.

---

### De Demo-Architectuur op je Laptop

```
+-------------------------------------------------------------------------+
| App Layer: Nextcloud + Euro-Office (Kubernetes Helm & Manifests)        |
+-------------------------------------------------------------------------+
| K8s Layer: Kind / Minikube                                              |
+-------------------------------------------------------------------------+
| IaC Layer: OpenTofu (Terraform) script maakt de infra & netwerken       |
+-------------------------------------------------------------------------+
| Platform: Docker Engine (Simuleert de OpenStack Compute/Netwerk laag)   |
+-------------------------------------------------------------------------+

```

---

### Stap 1: De Infrastructure-as-Code Demo (OpenTofu)

Maak een map `demo-iac` en voeg het bestand `main.tf` toe. Dit script simuleert het aanmaken van een geïsoleerd cloudnetwerk en de rekenkracht.

#### `main.tf`

```hcl
terraform {
  required_version = ">= 1.6.0" # Werkt met OpenTofu
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "docker" {}

# 1. Simuleer een OpenStack Neutron Virtueel Netwerk (VNet)
resource "docker_network" "sovereign_vnet" {
  name   = "sovereign-gov-network"
  driver = "bridge"
  ipam_config {
    subnet = "10.5.0.0/16"
  }
}

# 2. Simuleer een Compute Node / VM voor Euro-Office
resource "docker_container" "euro_office_node" {
  name  = "euro-office-app-node"
  image = "onlyoffice/documentserver:latest"
  
  networks_advanced {
    name         = docker_network.sovereign_vnet.name
    ipv4_address = "10.5.0.10"
  }

  ports {
    internal = 80
    external = 8080
  }

  env = [
    "JWT_ENABLED=true",
    "JWT_SECRET=MijnGeheimeDemoSleutel2026"
  ]
}

output "office_endpoint" {
  value       = "http://localhost:8080"
  description = "De endpoint die OpenTofu heeft geprovisioned"
}

```

---

### Stap 2: Voer de OpenTofu Provisioning uit (Live voor je publiek)

In je terminal laat je de kracht van **declaratieve infrastructuur** zien:

```bash
# 1. Initialiseer OpenTofu
tofu init

# 2. Toon het execution plan (wat gaat er gebouwd worden?)
tofu plan

# 3. Voer de provisioning uit
tofu apply -auto-approve

```

*Wat je nu aan je publiek uitlegt:*

> *"Kijk, met OpenTofu hebben we nu in enkele seconden ons eigen virtuele netwerk en de rekenkracht aangemaakt. In een productieomgeving veranderen we alleen de provider van `docker` naar `openstack`, maar het `tofu apply` commando en de logica blijven 100% hetzelfde."*

---

### Stap 3: Koppel Kubernetes & de App Layer (Nextcloud)

Start nu lokaal Kubernetes (bijvoorbeeld Minikube of Kind) dat gekoppeld wordt aan dit netwerk om Nextcloud uit te rollen:

```bash
# Start Kubernetes
minikube start --cpus=2 --memory=4092

# Rol Nextcloud uit via Helm
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

helm install nextcloud nextcloud/nextcloud \
  --set nextcloud.username=admin \
  --set nextcloud.password=DemoWachtwoord123! \
  --set service.type=NodePort

```

Stuur de poort door van Nextcloud:

```bash
kubectl port-forward svc/nextcloud 8080:80

```

---

### Stap 4: Het "Hoe ziet OpenStack eruit?" onderdeel

Aangezien het installeren van een echte OpenStack-cluster op één laptop te zwaar is (vraagt al snel 16GB+ RAM alleen voor de control plane), kun je het OpenStack-aspect op twee heel elegante manieren tonen:

#### Optie A: De OpenStack CLI / OpenRC simulatie (Erg indrukwekkend voor techneuten)

Toon hoe beheerders via OpenStack variabelen werken. Maak een `openstack-demo.rc` bestandje aan op je laptop:

```bash
export OS_AUTH_URL=https://openstack.sovereign-cloud.eu:5000/v3
export OS_PROJECT_NAME="MijnBureau-Demo"
export OS_USERNAME="admin"
export OS_REGION_NAME="EU-West-1"

```

Laat in je terminal zien hoe je via de CLI resources opvraagt:

```bash
source openstack-demo.rc

# Toon hoe je op OpenStack VM flavors of netwerken zou opvragen:
echo "Verbonden met OpenStack Control Plane..."

```

#### Optie B: OpenStack Horizon Web Interface

Als je wilt laten zien hoe het beheerdersdashboard van OpenStack eruitziet (het alternatief voor de Azure Portal), kun je de officiële **[OpenStack Public Sandbox / DevStack Dashboard Screenshots]** laten zien, of een hele lokaal draaiende **Sunbeam / MicroStack** instance starten als je laptop 16GB+ RAM heeft:

```bash
# Alleen als je Ubuntu draait en een krachtige laptop hebt:
sudo snap install openstack --channel 2024.1/stable
openstack sunbeam init --auto

```

---

### De Narrative / Storyline tijdens je Demo

Als je de presentatie geeft, bouw je het verhaal als volgt op:

1. **Stap 1 (OpenTofu):** *"We beginnen bij de basis. Met OpenTofu definiëren we in code onze servers en netwerken. Geen Azure-clickops, maar 100% open-source code."* $\rightarrow$ *(Draai `tofu apply`)*.
2. **Stap 2 (IaaS/OpenStack):** *"Onder de motorkap praat deze code direct met een OpenStack API (of lokaal Docker) om schijven en netwerkpoorten aan te maken."*
3. **Stap 3 (Kubernetes & Nextcloud):** *"Bovenop deze infrastructuur draait Kubernetes. Via Helm rollen we automatisch Nextcloud en de Euro-Office container uit."*
4. **Stap 4 (De Eindgebruiker):** *"Open de browser op `localhost:8080`, log in op Nextcloud, open een document en laat zien dat je live een Word/Excel document bewerkt in een volledig hyperscaler-vrije omgeving."*
