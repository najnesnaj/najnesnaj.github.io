Ja, dat klopt helemaal! Als je een apart apparaat of een router hebt (bijvoorbeeld een dedicated server, mini-PC of een virtuele machine in je netwerk) die als centrale entrypoint fungeert voor je Cloudflare Tunnels (en waar `cloudflared` op draait), dan is het daar inderdaad nodig om het verkeer netjes door te sturen naar de juiste cluster-nodes.

Omdat je Kubernetes NodePorts draaien op de nodes in het cluster (bijv. `10.10.50.x`) en niet direct op dat router/tunnel-apparaat zelf, kun je daar diensten zoals `socat` of een lokale proxy op draaien als **systemd service**. Zo blijft de doorsturing altijd stabiel draaien, ook na een herstart van dat apparaat.

### Hoe richt je dit in als systemd service op je router/tunnel-apparaat?

1. **Installeer socat op het apparaat:** Socat installeren.
Zorg ervoor dat `socat` geïnstalleerd is op het apparaat waar je tunnels op binnenkomen:

```bash
sudo apt update && sudo apt install socat -y

```

*Verification:* Voer `socat -V` uit om te controleren of het correct is geïnstalleerd.


2. **Maak een servicebestand aan voor je poorten:** Systemd service per poort.
Maak voor elke dienst (bijv. Forgejo op poort `30000` en Nextcloud op poort `30020`) een eigen systemd service aan.

Maak bijvoorbeeld `/etc/systemd/system/k8s-forgejo-proxy.service` aan:

```ini
[Unit]
Description=Forward Forgejo NodePort to K8s Cluster Node
After=network.target

[Service]
ExecStart=/usr/bin/socat TCP-LISTEN:30000,fork,reuseaddr TCP:10.10.50.10:30000
Restart=always

[Install]
WantedBy=multi-user.target

```

*(Herhaal dit eventueel voor Nextcloud met poort `30020` die doorstuurt naar `10.10.50.10:30020`).*
*Verification:* Het bestand is opgeslagen in de map `/etc/systemd/system/`.


3. **Start en enable de services:** Service activeren.
Laat systemd de nieuwe configuratie inlezen en start de services direct:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now k8s-forgejo-proxy.service

```

*Verification:* Controleer de status met `sudo systemctl status k8s-forgejo-proxy.service` om te zien of deze op `active (running)` staat.
