# Opdracht: Automatiseer de Talos Kubernetes Cluster Setup (3-Node) via KVM en Proxmox NFS

Doel:
Zet op deze hulplaptop (Linux Mint) een virtueel Talos Kubernetes cluster op bestaande uit 3 VM's in QEMU/KVM via `virsh` / `virt-install`. De virtuele schijven worden via een NFS-mount over Thunderbolt opgeslagen op de Proxmox-hoofdlaptop.

---

## Omgevingsparameters & IP-Schema
- **Proxmox Hoofdlaptop (NFS Server):** IP `192.168.100.1`
- **Linux Mint Hulplaptop (KVM Host):** IP `192.168.100.2`
- **Thunderbolt Interface Name:** Krijg deze automatisch via `ip link` (bijv. `thb0` of `enp...`).
- **NFS Share Pad op Proxmox:** `/export/kvm-images` (of de aangemaakte Proxmox NFS storage mount).
- **Lokale Mount Point op Hulplaptop:** `/mnt/proxmox-nfs`

---

## Uit te voeren stappen door OpenCode:

### Stap 1: Systeemcontrole en KVM Afhankelijkheden
1. Controleer of `qemu-kvm`, `libvirt-daemon-system`, `virtinst`, `nfs-common` en `talosctl` zijn geïnstalleerd. Installeer ze automatisch als ze ontbreken (`sudo apt update && sudo apt install -y qemu-kvm libvirt-daemon-system virt-viewer virtinst nfs-common`).
2. Download de nieuwste `talosctl` CLI-binary indien nog niet aanwezig.

### Stap 2: Thunderbolt & NFS Mount
1. Zorg dat het IP-adres `192.168.100.2/24` actief is op de Thunderbolt-interface op de hulplaptop.
2. Maak de lokale map `/mnt/proxmox-nfs` aan.
3. Test de verbinding met `ping 192.168.100.1` en mount de NFS-share:
   `sudo mount -t nfs 192.168.100.1:/export/kvm-images /mnt/proxmox-nfs`

### Stap 3: Virtuele Thunderbolt Mesh Netwerken Aanmaken (Libvirt)
Maak 3 gesloten (isolated) virtuele netwerken aan in libvirt om de Thunderbolt-ring topologie tussen de 3 VM's te simuleren:
1. `tb-ring-12` (Subnet: `10.10.12.0/24`)
2. `tb-ring-23` (Subnet: `10.10.23.0/24`)
3. `tb-ring-31` (Subnet: `10.10.31.0/24`)

### Stap 4: Talos VM's Aanmaken via virt-install
Maak 3 VM's aan (`talos-node-1`, `talos-node-2`, `talos-node-3`) met de volgende specificaties:
- **RAM:** 6144 MB (6 GB per VM)
- **CPU:** 2 vCPU's (Host passthrough)
- **OS Schijf (Disk 1):** 15 GB QCOW2 bestand geplaatst op `/mnt/proxmox-nfs/talos-node-X-os.qcow2`.
- **Ceph/Longhorn Storage Schijf (Disk 2):** 40 GB QCOW2 bestand geplaatst op `/mnt/proxmox-nfs/talos-node-X-data.qcow2`.
- **Netwerkinterfaces:**
  - `default` (NAT / Internettoegang)
  - `tb-ring-XX` (Virtuele Thunderbolt ring)
- **Boot ISO:** Koppel het Talos Linux ISO-bestand dat te vinden is op de Proxmox NFS share of download `talos-amd64.iso` direct naar `/tmp`.

### Stap 5: Talos Cluster Bootstrap Genereren
1. Genereer de Talos clusterconfiguratie via `talosctl`:
   `talosctl gen config thunderbolt-cluster https://192.168.122.10:6443`
2. Schrijf de Gegenereerde `controlplane.yaml` en `talosconfig` weg in de werkmap.
3. Wacht tot de VM's zijn opgestart en geef instructies of voer `talosctl apply-config` uit voor de IP's van de 3 nodes.

---

## Verwacht Eindresultaat:
- 3 Draaiende Talos VM's in KVM.
- Aparte OS- en Data-schijven opgeslagen op de Proxmox NFS-share.
- Mashing netwerkinterfaces ingesteld voor Thunderbolt-simulatie.
- Gereed voor `talosctl bootstrap` en latere installatie van Rook-Ceph of Longhorn.
