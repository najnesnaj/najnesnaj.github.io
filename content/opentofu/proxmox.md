Het opzetten van een demo op een **Proxmox VE (Virtual Environment)** server is een uitstekende keuze. Proxmox is extreem populair bij Europese organisaties en overheden als open-source alternatief voor VMware en Azure Stack. Het is lichtgewicht, robuust en heeft een volwassen **Terraform/OpenTofu provider** (`bpg/proxmox`).

Met dit demo-scenario laat je de volledige keten zien: **OpenTofu (IaC) $\rightarrow$ Proxmox (IaaS) $\rightarrow$ Kubernetes (Orchestratie) $\rightarrow$ Nextcloud & Euro-Office (SaaS)**.

---

### De Demo-Architectuur op Proxmox

```
+-----------------------------------------------------------------------+
| SaaS Layer: Nextcloud Hub + Euro-Office Document Server               |
+-----------------------------------------------------------------------+
| Orchestratie: Kubernetes Cluster (Talos Linux of k3s)                 |
+-----------------------------------------------------------------------+
| Provisioning: OpenTofu / Terraform (via bpg/proxmox provider)         |
+-----------------------------------------------------------------------+
| Hypervisor: Proxmox VE (Beheert KVM VM's, LXC containers & ZFS/Ceph)  |
+-----------------------------------------------------------------------+
| Hardware: 1x Fysieke Server / Bare-Metal Mini PC                      |
+-----------------------------------------------------------------------+

```

---

### Stap 1: De OpenTofu Code (`main.tf`)

Met onderstaand OpenTofu-script schiet je automatisch een virtuele machine uit op de Proxmox-server, op basis van een Cloud-Init Ubuntu image.

#### `main.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0" # Officieel ondersteunde Proxmox provider
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.100:8006/" # IP van je Proxmox node
  api_token = "root@pam!opentofu=12345678-abcd-1234-abcd-123456789abc"
  insecure  = true # Voor demo-omgevingen met self-signed certificaat
}

# Virtuele Machine voor Kubernetes / Euro-Office Node
resource "proxmox_virtual_environment_vm" "k8s_node" {
  name        = "sovereign-k8s-node-01"
  node_name   = "pve" # De naam van je Proxmox host
  vm_id       = 200

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192 # 8 GB RAM
  }

  disk {
    datastore_id = "local-lzfs" # Je Proxmox storage pool
    file_id      = "local:iso/ubuntu-24.04-server-cloudimg-amd64.img"
    interface    = "virtio0"
    size         = 40 # 40 GB Schijfruimte
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_account {
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."]
      username = "ubuntu"
    }
  }
}

output "vm_ip" {
  value = proxmox_virtual_environment_vm.k8s_node.ipv4_addresses
}

```

---

### Stap 2: Het Demo-Script (Live voorbereiding & uitvoering)

Tijdens de presentatie voer je de onderstaande stappen uit om de automatisering te tonen.

#### 1. Laat het Proxmox Dashboard zien

Open de webinterface van Proxmox (`https://<proxmox-ip>:8006`). Laat zien dat de server leeg is of enkel basistemplates bevat.

> **Het verhaal:** *"Dit is onze interne soevereine cloud. Geen afhankelijkheid van Azure, maar onze eigen hardware onder controle. We gaan nu via code deze omgeving opbouwen."*

#### 2. Voer de Provisioning uit via OpenTofu

Open je terminal en draai de provisioning:

```bash
tofu init
tofu apply -auto-approve

```

Schakel direct over naar de Proxmox GUI: je publiek ziet live binnen **5 tot 10 seconden** een nieuwe VM (`sovereign-k8s-node-01`) verschijnen, opstarten en een IP-adres krijgen via Cloud-Init.

#### 3. Rol de Software Stack uit op de nieuwe VM

Via Ansible, Helm of een eenvoudig Kubernetes script (zoals `k3s`) rol je Nextcloud en Euro-Office uit op de zojuist geprovisioneerde VM.

```bash
# SSH naar de nieuwe Proxmox VM
ssh ubuntu@<VM-IP-UIT-OPENTOFU>

# Installeer lichtgewicht Kubernetes (k3s)
curl -sfL https://get.k3s.io | sh -

# Installeer Euro-Office / Nextcloud via Helm of Docker Compose
docker run -d -p 8080:80 \
  -e JWT_ENABLED=true \
  -e JWT_SECRET=MijnGeheimeDemoSleutel2026 \
  --name euro-office \
  onlyoffice/documentserver:latest

```

---

### Stap 3: De Interactieve Eindgebruikers-Demo

1. Open de browser en surf naar het IP-adres van de Proxmox VM waarop Nextcloud draait.
2. Open een `.docx` of `.xlsx` document.
3. Laat de **co-authoring** zien: open een tweede (incognito) scherm en bewerk het document gelijktijdig.

---

### Waarom dit een ijzersterke demonstratie is

| Onderdeel | Wat je aantoont | Waarom dit overtuigt |
| --- | --- | --- |
| **Proxmox** | Geen afhankelijkheid van Azure Stack of VMware. | Open-source, KVM-based en extreem populair in de EU. |
| **OpenTofu** | Geen Cloud Lock-in op infra-niveau. | Exact dezelfde ontwikkelaars-workflow als op AWS of Azure. |
| **Nextcloud + Euro-Office** | Geen Microsoft 365 / OneDrive lock-in. | Data blijft fysiek op de Proxmox-schijven in je eigen netwerk. |
