Om virtuele schijfbestanden (`.qcow2`) via Thunderbolt op je hoofdlaptop op te slaan en te laten benaderen door QEMU/KVM op je tweede laptop, doorloop je drie stappen:

1. **Een Point-to-Point netwerk opzetten over Thunderbolt** tussen de twee laptops.
2. **Een NFS-server (Network File System) starten op de hoofdlaptop** die de map met VM-bestanden deelt.
3. **Een nieuwe Storage Pool toevoegen in KVM/Virt-Manager** op de tweede laptop.

---

## Stap 1: Thunderbolt Netwerk opzetten (Point-to-Point IP)

Wanneer je twee laptops verbindt via een Thunderbolt-kabel, maken ze automatisch een netwerkinterface aan (meestal genaamd `enp...t1` of `thb0`).

Ken op beide apparaten een statisch IP-adres toe in een nieuw subnet (bijvoorbeeld `192.168.100.0/24`).

### Op de Hoofdlaptop (NFS Server):

```bash
# Zoek de naam van de Thunderbolt interface op (bijv. thb0 of enp1s0f0)
ip link

# Ken een IP-adres toe
sudo ip addr add 192.168.100.1/24 dev <thunderbolt-interface>
sudo ip link set dev <thunderbolt-interface> up

```

### Op de Tweede Laptop (Mint Live USB / KVM Host):

```bash
# Ken het client IP-adres toe
sudo ip addr add 192.168.100.2/24 dev <thunderbolt-interface>
sudo ip link set dev <thunderbolt-interface> up

# Test de verbinding
ping 192.168.100.1

```

---

## Stap 2: NFS-share opzetten op de Hoofdlaptop

NFS is extreem snel en heeft nauwelijks overhead, waardoor QEMU de bestanden over de Thunderbolt-pijp kan lezen Alsof ze lokaal op de schijf staan.

1. **Installeer de NFS server op je hoofdlaptop (bijv. Ubuntu/Debian/Mint):**
```bash
sudo apt update
sudo apt install -y nfs-kernel-server

```


2. **Maak de opslagmap aan voor de VM's:**
```bash
sudo mkdir -p /export/kvm-images
sudo chown -R libvirt-qemu:kvm /export/kvm-images  # Of pas rechten aan voor toegankelijkheid
sudo chmod 777 /export/kvm-images

```


3. **Configureer de NFS export:**
Open `/etc/exports` in je tekstverwerker (`sudo nano /etc/exports`) en voeg deze regel toe:
```text
/export/kvm-images 192.168.100.2(rw,sync,no_subtree_check,no_root_squash)

```


4. **Herstart en pas de exports toe:**
```bash
sudo exportfs -a
sudo systemctl restart nfs-kernel-server

```



---

## Stap 3: NFS Storage Pool toevoegen in KVM / Virt-Manager

Nu ga je op de **tweede laptop (Linux Mint)** KVM vertellen dat hij VM-schijven rechtstreeks van de hoofdlaptop moet halen.

### Optie A: Via Virt-Manager (Grafisch)

1. Open **Virt-Manager** (Virtuele-machinebeheerder) op de tweede laptop.
2. Klik met de rechtermuisknop op **QEMU/KVM** -> **Details**.
3. Ga naar het tabblad **Opslag (Storage)**.
4. Klik linksonder op het **+ (Plus)** icoon om een nieuwe pool toe te voegen:
* **Naam:** `hoofdlaptop-nfs`
* **Type:** `netfs: Network Exported Directory`


5. Vul de gegevens in:
* **Hostnaam / Server IP:** `192.168.100.1`
* **Source Path (Bronpad):** `/export/kvm-images`
* **Target Path (Doelpad):** `/mnt/kvm-images` (of een ander pad lokaal)


6. Klik op **Voltooien**.

### Optie B: Via de Terminal (virsh)

Als je liever de CLI gebruikt op de tweede laptop:

```bash
sudo virsh pool-define-as --name hoofdlaptop-nfs --type netfs --host 192.168.100.1 --dir /export/kvm-images --target /mnt/kvm-images
sudo virsh pool-autostart hoofdlaptop-nfs
sudo virsh pool-start hoofdlaptop-nfs

```

---

## Klaar voor gebruik!

Wanneer je nu in Virt-Manager een nieuwe Talos VM aanmaakt, kies je bij **Storage / Opslag** simpelweg voor de nieuw aangemaakte pool (`hoofdlaptop-nfs`).

Het `.qcow2` virtuele schijfbestand wordt nu fysiek aangemaakt en gelezen op de SSD van je hoofdlaptop, terwijl het RAM-geheugen en de CPU van de tweede laptop al het zware werk doen.
