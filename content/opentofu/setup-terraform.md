Dat is een heel slimme manier om de opslagruimte op je `nvme0` schijf beschikbaar te maken binnen Proxmox op `nvme1`.

Proxmox is gebaseerd op Debian Linux, wat betekent dat je de NVMe-schijf met Linux Mint (`nvme0`) simpelweg kunt **mounten in Proxmox** en daar een virtueel schijfbestand (zoals een `.raw` of `.img` bestand) op aan kunt maken. Dit virtuele schijfbestand koppel je vervolgens via een **Loop Device** als extra *Storage Pool* in Proxmox.

---

### Stap-voor-Stap Handleiding

#### Stap 1: Identificeer de Linux Mint schijf/partitie op Proxmox

Open de terminal op je Proxmox host (via de web-GUI of SSH) en bekijk de schijfindeling:

```bash
lsblk -f

```

Zoek naar `nvme0n1` en de specifieke partitie waar Linux Mint op staat (bijvoorbeeld `nvme0n1p2` met het bestandssysteem `ext4`).

---

#### Stap 2: Mount de Linux Mint partitie in Proxmox

Maak een koppelpunt (mount point) aan op Proxmox en koppel de partitie:

```bash
# 1. Maak de mount-map aan
mkdir -p /mnt/mint-nvme0

# 2. Mount de partitie (vervang nvme0n1p2 door jouw juiste partitienaam)
mount /dev/nvme0n1p2 /mnt/mint-nvme0

```

> **Automatisch mounten bij het opstarten:**
> Voeg deze regel toe aan `/etc/fstab` op Proxmox om te zorgen dat dit na een herstart blijft werken:
> ```text
> /dev/nvme0n1p2  /mnt/mint-nvme0  ext4  defaults,nofail  0  2
> 
> ```
> 
> 

---

#### Stap 3: Maak het virtuele schijfbestand (sparse file) aan

Nu maken we op het Linux Mint bestandssysteem een bestand aan van bijvoorbeeld 200 GB. We gebruiken `truncate`, waardoor het bestand **enkel de ruimte inneemt die echt gebruikt wordt** (sparse file):

```bash
# Maak een map voor Proxmox opslag op de Mint schijf
mkdir -p /mnt/mint-nvme0/proxmox-storage

# Maak een virtueel schijfbestand aan van 200 GB
truncate -s 200G /mnt/mint-nvme0/proxmox-storage/extra-disk.raw

# Format
mkfs.ext4 /mnt/mint-nvme0/proxmox-storage/extra-disk.raw

```

---

#### Stap 4: Voeg de map toe als Storage Pool in Proxmox

Nu vertellen we Proxmox dat hij de map op de Mint-schijf mag gebruiken om virtuele VM-schijven (zoals die voor je Longhorn worker nodes) op te slaan.

##### Optie A: Via de Proxmox Web GUI (Makkelijkst)

1. Open de Proxmox Web GUI.
2. Ga in het linkermenu naar **Datacenter -> Storage**.
3. Klik op **Add** -> **Directory**.
4. Vul het volgende in:
* **ID:** `nvme0-mint-storage`
* **Directory:** `/mnt/mint-nvme0/proxmox-storage`
* **Content:** Vink *Disk image*, *ISO image* en *Container* aan.


5. Klik op **Add**.

##### Optie B: Via de Proxmox Terminal

```bash
pvesm add dir nvme0-mint-storage --path /mnt/mint-nvme0/proxmox-storage --content images,iso

```

---

### Hoe je dit nu gebruikt in je OpenTofu / Terraform code

In je OpenTofu code verander je voor de Longhorn schijven (`disk2`) simpelweg de `datastore_id` van `local-lvm` naar `nvme0-mint-storage`:

```hcl
  # DISK 2: Dedicated Longhorn Storage Schijf (op nvme0 via Linux Mint bestand)
  disk {
    datastore_id = "nvme0-mint-storage" # <-- Gebruikt nu de ruimte op nvme0!
    interface    = "scsi1"
    size         = 100
    file_format  = "raw"
  }

```

Nu staan je basisschijven op Proxmox (`nvme1`), terwijl de extra grote schijven voor Longhorn netjes de schijfruimte op `nvme0` benutten!
