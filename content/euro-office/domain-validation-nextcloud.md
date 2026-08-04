Dat is een hele bekende drempel bij de installatie van **Nextcloud All-in-One (AIO)**!

Nextcloud AIO verwacht in de standaard ("normal mode") een **volledige, publieke domeinnaam** (zoals `nextcloud.jouwdomein.nl`), omdat de ingebouwde proxy automatisch geldige SSL-certificaten (HTTPS) probeert aan te vragen via *Let's Encrypt*. Een lokaal IP-adres (zoals `192.168.x.x`) of `localhost` accepteert dit veld in deze stand **niet**.

---

## 🛠️ Welke optie past bij jouw situatie?

Afhankelijk van wat je precies wilt bereiken op je lokale netwerk, zijn er drie manieren om dit op te lossen:

### Optie 1: Je wilt Nextcloud alléén lokaal gebruiken (zonder internettoegang)

Als je de server niet wilt blootstellen aan het internet en enkel binnen je eigen wifi/netwerk wilt gebruiken, moet je AIO vertellen dat de SSL-check overgeslagen mag worden.

* **Oplossing:** Je moet het `docker run` commando waarmee je AIO hebt opgestart uitbreiden met een extra omgevingsvariabele:
`-e SKIP_DOMAIN_VALIDATION=true`
* **Wat vul je daarna in het veld in?** Je vult dan de lokale hostname of het lokale IP-adres van je pc in (bijv. `192.168.1.100` of `mijnpc.local`).

> 💡 **Let op:** Je browser geeft dan wel een certificaatwaarschuwing ("Verbinding niet veilig"), omdat je een zelfondertekend SSL-certificaat gebruikt.

---

### Optie 2: Je hebt een eigen domeinnaam (bijv. bij TransIP, MijnDomein, Cloudflare)

Als je je Nextcloud ook vanaf buitenaf wilt kunnen bereiken:

1. Vul in het veld jouw (sub)domein in, bijv: `nextcloud.jouwdomein.nl`.
2. Zorg dat je in het beheerderspaneel van je domein een **A-record** aanmaakt die wijst naar het **externe IP-adres van jouw thuisnetwerk** (je publieke IP).
3. Stuur op je internetrouter **poort 80 en poort 443** (TCP) door (port forwarding) naar het lokale IP-adres van je computer.

---

### Optie 3: Je wilt een gratis publiek domein (deSEC of DuckDNS)

Als je geen eigen domein hebt, maar wél van buitenaf toegang wilt via HTTPS:

1. Maak een gratis domein aan via [deSEC.io](https://desec.io/) (deze link staat ook in je Nextcloud scherm) of [DuckDNS.org](https://www.duckdns.org/). Je krijgt dan bijvoorbeeld `mijnnextcloud.dedyn.io`.
2. Koppel jouw publieke IP-adres aan dit gratis domein.
3. Vul `mijnnextcloud.dedyn.io` in het veld in.
4. Vergeet niet om **poort 80 en poort 443** in je router open te zetten/door te sturen naar deze computer.

---
