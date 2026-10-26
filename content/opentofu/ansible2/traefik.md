# Traefik als ingress controller voor de nginx-demo

Dit document beschrijft hoe **Traefik** de nginx-demo ontsluit op
`http://nginx-demo.kubernetes.local`, zonder `kubectl port-forward` per
applicatie. De hostnaam verwijst via `/etc/hosts` naar de managementcontainer;
Traefik routeert op de `Host`-header naar de juiste Kubernetes-Service.

Eindresultaat:

- Traefik draait in namespace `traefik` (Helm-release `traefik`, chart
  `42.1.3`, Traefik `v3.7.16`);
- de IngressClass `traefik` is de standaard;
- de Ingress `nginx-demo/nginx` routeert `nginx-demo.kubernetes.local` naar
  Service `nginx-demo/nginx:80`;
- Traefik is bereikbaar als NodePort `30080`/`30443` op `10.10.50.22`;
- op de managementcontainer forwardt `systemd-socket-proxyd` TCP `80`/`443`
  naar die NodePorts;
- vanaf het thuisnetwerk werkt `http://nginx-demo.kubernetes.local` (en
  `https://...` met een certificaatwaarschuwing) na één regel in `/etc/hosts`.

## Waarom een bridge op de managementcontainer?

De opzet is bewust:

```text
Werkstation (192.168.0.0/24)
  /etc/hosts: 192.168.0.137  nginx-demo.kubernetes.local
        |
        | TCP 80/443
        v
Managementcontainer 192.168.0.137 (thuisnetwerk)
                    10.10.50.5      (clusternetwerk)
        |  systemd-socket-proxyd
        |  TCP 80  -> 10.10.50.22:30080
        |  TCP 443 -> 10.10.50.22:30443
        v
Talos-node 10.10.50.22
  Traefik (NodePort 30080/30443)
        |  Host: nginx-demo.kubernetes.local
        v
Service nginx-demo/nginx:80 -> Pod nginx
```

De Talos-node hangt alleen aan het geïsoleerde netwerk `10.10.50.0/24`. Vanaf
het thuisnetwerk is `10.10.50.22` niet direct bereikbaar. De
managementcontainer is de enige host die beide netwerken ziet. Daar draait een
kleine **L4-proxy** (geen Kubernetes-port-forward) die één keer voor alle
ingress-hosts werkt:

- Traefik doet de **L7-routing** op hostnaam, path en later TLS;
- de proxy doet alleen TCP-doorgifte naar de NodePort;
- voor een nieuwe app is geen nieuwe proxy of poort nodig: alleen een Ingress
  en een regel in `/etc/hosts`.

Alternatieven (niet gekozen):

| Alternatief | Waarom niet |
| --- | --- |
| `kubectl port-forward` per app | Precies wat we wilden vervangen; per app een sessie. |
| NodePort direct vanaf het werkstation | Vereist een route naar `10.10.50.0/24` en forwarding/NAT op de managementcontainer; bovendien een niet-standaard poort in de URL. |
| MetalLB + LoadBalancer | Extra component; L2-advertentie zit nog steeds op het geïsoleerde netwerk, dus alsnog een route/NAT of bridge nodig. |
| `hostPort: 80` op de node | Zelfde netwerkprobleem; bovendien minder schoon dan een NodePort. |

De bridge is dus een bewuste netwerkbrug, geen vervanging van Traefik: alle
HTTP-routing gebeurt in Traefik.

> **Bron-IP:** `systemd-socket-proxyd` opent een nieuwe TCP-verbinding naar de
> NodePort. Traefik ziet daardoor `10.10.50.5` (eth1 van de
> managementcontainer) als bron, niet het IP van de browser. Voor op IP
> gebaseerde allowlists of access logs is een route/NAT-oplossing of
> PROXY-protocol nodig; voor host-routing maakt dit niet uit.

## Wat is er gewijzigd?

| Bestand / object | Wijziging |
| --- | --- |
| `files/gitops/apps/nginx-demo/app.yaml` | Ingress `nginx-demo/nginx` toegevoegd. |
| `files/traefik-values.yaml` | Helm-waarden: NodePort, IngressClass, tolerations, ingress-endpoint. |
| `traefik.yml` | Nieuw playbook: Traefik installeren, bridge instellen en verifiëren. |
| `argocd.yml` | Wacht bij nginx-demo op `Synced` (Ingress mag vóór Traefik op `Progressing` staan); resultaat verwijst naar de ingress-URL. |
| `traefik.md` | Dit document. |
| `README.md`, `nginx-demo-argocd.md`, `argocd-forgejo.md` | Verwijzingen naar de ingress-setup. |
| Managementcontainer | Vier systemd-units voor de HTTP/HTTPS-bridge. |
| Werkstation | Eén regel in `/etc/hosts` (handmatig; zie verderop). |
| Kubernetes | Helm-release `traefik`, namespace `traefik`, IngressClass `traefik`, Service `traefik` (NodePort), Deployment/Pod. |

De Ingress staat in Git en wordt door ArgoCD uit Forgejo gesynchroniseerd. De
Traefik-installatie en de bridge zijn infrastructuur en staan in `traefik.yml`.

## Vereisten

- `forgejo.yml`, `argocd.yml` en de nginx-demo zijn al uitgerold;
- de Ingress bestaat: `kubectl -n nginx-demo get ingress nginx`;
- de managementcontainer heeft `helm`, `kubectl` en `systemd`;
- poorten `80` en `443` op `192.168.0.137` zijn vrij;
- de managementcontainer kan `10.10.50.22:30080` bereiken.

Controleer de laatste twee:

```sh
ssh root@192.168.0.137 \
  "ss -ltn | grep -E ':(80|443) ' || echo 'poorten vrij'"
ssh root@192.168.0.137 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   -H 'Host: nginx-demo.kubernetes.local' http://10.10.50.22:30080/"
```

De tweede kan nog `000` of `404` geven voordat Traefik draait; dat is prima.

## Stap 1 — Ingress in de GitOps-repo

De Ingress staat achteraan `files/gitops/apps/nginx-demo/app.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  namespace: nginx-demo
  labels:
    app.kubernetes.io/name: nginx-demo
    app.kubernetes.io/part-of: nginx-demo
spec:
  ingressClassName: traefik
  rules:
    - host: nginx-demo.kubernetes.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  name: http
```

Zet hem in Forgejo en laat ArgoCD syncen:

```sh
cd ansible
ansible-playbook argocd.yml
```

Het playbook seedt het bestand, vraagt ArgoCD om een refresh en wacht tot de
Application op de nieuwste commit `Synced` staat. Zonder Traefik blijft de
Ingress op `Progressing` staan (geen controller); `argocd.yml` accepteert dat
en de Deployment/HTTP-check bewaken de demo zelf. Na `traefik.yml` wordt de
health `Healthy`.

Controleer:

```sh
ssh root@192.168.0.137 \
  "kubectl -n nginx-demo get ingress nginx"
```

## Stap 2 — Traefik en de bridge installeren

```sh
cd ansible
ansible-playbook traefik.yml
```

De `tools`-rol zorgt eerst voor `helm`, `kubectl` en de overige tooling op de
beheercontainer. Daarna doet het playbook:

1. controleert dat de nginx-Ingress bestaat (anders stopt het met de melding
   eerst `argocd.yml` te draaien);
2. installeert/upgrade Traefik met de OCI-chart
   `oci://ghcr.io/traefik/helm/traefik`, versie `42.1.3`, in namespace
   `traefik`;
3. gebruikt `files/traefik-values.yaml`:
   - Service type `NodePort` met `30080` (HTTP) en `30443` (HTTPS);
   - IngressClass `traefik` als default;
   - tolerations voor de control-plane-taint;
   - `providers.kubernetesIngress.ingressEndpoint.ip: 192.168.0.137`, zodat de
     Ingress-status het adres krijgt dat clients gebruiken (ArgoCD vindt de
     Ingress dan gezond);
   - resources en één replica;
4. wacht op de Traefik-deployment en controleert IngressClass en Service;
5. schrijft vier systemd-units op de managementcontainer:
   - `traefik-ingress-http.socket` → luistert op `192.168.0.137:80`;
   - `traefik-ingress-http.service` → `systemd-socket-proxyd` naar
     `10.10.50.22:30080`;
   - `traefik-ingress-https.socket` → luistert op `192.168.0.137:443`;
   - `traefik-ingress-https.service` → `systemd-socket-proxyd` naar
     `10.10.50.22:30443`;
6. test Traefik rechtstreeks via de NodePort en via de bridge;
7. toont de toegangsinformatie.

De bridge-units zien er zo uit (het playbook schrijft ze):

```ini
# /etc/systemd/system/traefik-ingress-http.socket
[Unit]
Description=Traefik ingress HTTP socket (thuisnetwerk)
After=network-online.target
Wants=network-online.target

[Socket]
ListenStream=192.168.0.137:80
NoDelay=true

[Install]
WantedBy=sockets.target
```

```ini
# /etc/systemd/system/traefik-ingress-http.service
[Unit]
Description=Traefik ingress HTTP proxy naar de cluster-NodePort
Requires=traefik-ingress-http.socket
After=traefik-ingress-http.socket network-online.target
Wants=network-online.target

[Service]
ExecStart=/lib/systemd/systemd-socket-proxyd --exit-idle-time=300 10.10.50.22:30080
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
```

De HTTPS-variant is identiek met poort `443` en doel `30443`.

> **Belangrijk bij het herstarten van een socket:** stop eerst de bijbehorende
> proxyservice. Anders houdt de actieve proxy de oude luister-socket vast en
> geeft systemd `Address already in use`:
>
> ```sh
> sudo systemctl stop traefik-ingress-http.service
> sudo systemctl restart traefik-ingress-http.socket
> ```

Het playbook doet deze volgorde automatisch als een unit is gewijzigd. Bij een
ongewijzigde configuratie worden de sockets niet herstart.

Verwacht aan het einde:

```text
Ingress: http://nginx-demo.kubernetes.local
/etc/hosts: 192.168.0.137 nginx-demo.kubernetes.local
Traefik NodePort: 10.10.50.22:30080 (HTTP), :30443 (HTTPS)
IngressClass: traefik ...
Traefik-service: traefik NodePort ... 80:30080/TCP,443:30443/TCP
```

Een tweede run is idempotent: alleen de Helm-taak meldt `changed`.

## Stap 3 — `/etc/hosts` op het werkstation

Voeg op de machine waarmee je de browser opent deze regel toe:

```text
192.168.0.137  nginx-demo.kubernetes.local
```

### Linux en macOS

```sh
grep -q 'nginx-demo.kubernetes.local' /etc/hosts || \
  echo '192.168.0.137  nginx-demo.kubernetes.local' | sudo tee -a /etc/hosts
```

Controleren:

```sh
getent hosts nginx-demo.kubernetes.local
# 192.168.0.137    nginx-demo.kubernetes.local
```

### Windows

Open Kladblok **als administrator** en bewerk:

```text
C:\Windows\System32\drivers\etc\hosts
```

Voeg de regel toe en sla op. Of via PowerShell als administrator:

```powershell
Add-Content -Path "$env:SystemRoot\System32\drivers\etc\hosts" `
  -Value "192.168.0.137  nginx-demo.kubernetes.local"
```

Controleren:

```powershell
Resolve-DnsName nginx-demo.kubernetes.local
```

### DNS-cache

Als de naam eerst niet resolveert:

```sh
# Linux (systemd-resolved)
sudo resolvectl flush-caches
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

```powershell
# Windows
ipconfig /flushdns
```

Gebruik eventueel een incognitovenster of herstart de browser.

> **Let op:** `.local` is gereserveerd voor mDNS. Meestal wint `/etc/hosts`,
> maar op sommige systemen kan mDNS de naam verstoren. Werkt het niet, gebruik
> dan bijvoorbeeld `nginx-demo.k8s.local` (pas dan de Ingress-host en de
> `/etc/hosts`-regel aan) of schakel mDNS voor deze naam uit.

## Stap 4 — Openen en testen

Open in de browser:

```text
http://nginx-demo.kubernetes.local
```

Verwacht: **“Welkom bij de nginx-demo”**.

Vanaf de managementcontainer:

```sh
ssh root@192.168.0.137 \
  "curl -s -o /dev/null -w '%{http_code}\n' \
   --resolve nginx-demo.kubernetes.local:80:192.168.0.137 \
   http://nginx-demo.kubernetes.local/"
```

Vanaf een ander thuisnetwerkadres, zonder `/etc/hosts` aan te passen:

```sh
curl -s --resolve nginx-demo.kubernetes.local:80:192.168.0.137 \
  http://nginx-demo.kubernetes.local/ | grep 'Welkom bij de nginx-demo'
```

Rechtstreeks naar de Traefik-NodePort (alleen vanaf het clusternetwerk):

```sh
curl -s -H 'Host: nginx-demo.kubernetes.local' \
  http://10.10.50.22:30080/
```

HTTPS:

```sh
curl -sk --resolve nginx-demo.kubernetes.local:443:192.168.0.137 \
  https://nginx-demo.kubernetes.local/
```

Traefik heeft nog geen certificaat voor deze host; je krijgt het standaard
self-signed certificaat (`CN=TRAEFIK DEFAULT CERT`) en dus een
browserwaarschuwing. HTTP werkt zonder waarschuwing. Zie “TLS” hieronder.

### Verificatie in één overzicht

| Controle | Commando | Verwacht |
| --- | --- | --- |
| Traefik-pod | `kubectl -n traefik get pods` | `1/1 Running` |
| Traefik-service | `kubectl -n traefik get svc traefik` | `NodePort`, `80:30080`, `443:30443` |
| IngressClass | `kubectl get ingressclass` | `traefik` (default) |
| Ingress | `kubectl -n nginx-demo get ingress nginx` | host `nginx-demo.kubernetes.local` |
| Ingress-status | `kubectl -n nginx-demo get ingress nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` | `192.168.0.137` |
| ArgoCD | `kubectl -n argocd get app nginx-demo` | `Synced`, `Healthy` |
| Bridge HTTP | `ss -ltn \| grep ':80 '` (op management) | `192.168.0.137:80` |
| Bridge HTTPS | `ss -ltn \| grep ':443 '` | `192.168.0.137:443` |
| HTTP | `curl -s http://nginx-demo.kubernetes.local/` | bevat `Welkom bij de nginx-demo` |
| HTTPS | `curl -sk https://nginx-demo.kubernetes.local/` | bevat `Welkom bij de nginx-demo` |

## TLS

De HTTPS-bridge werkt, maar Traefik gebruikt nog zijn ingebouwde self-signed
certificaat. Voor een vertrouwde verbinding zijn er twee opties:

1. **cert-manager** met een interne CA of een publieke ACME-uitgever. Voor
   `.local` is publieke ACME (Let's Encrypt) niet mogelijk; gebruik een
   interne CA of een eigen certificaat.
2. Een eigen TLS-Secret en `tls:` in de Ingress. Dat is voor deze demo niet
   gedaan, omdat het certificaat dan niet uit Git hoort te komen en
   cert-manager nog niet is geïnstalleerd.

Voor nu is HTTP de ondersteunde demo-URL. Wil je toch HTTPS zonder
certificaatwaarschuwing, installeer cert-manager en een interne CA, en voeg aan
de Ingress toe:

```yaml
spec:
  tls:
    - hosts:
        - nginx-demo.kubernetes.local
      secretName: nginx-demo-tls
```

## Een tweede applicatie toevoegen

De ingress is herbruikbaar. Voor bijvoorbeeld `whoami.kubernetes.local`:

1. voeg een Ingress toe aan de GitOps-manifests met
   `ingressClassName: traefik` en die host;
2. laat ArgoCD syncen;
3. voeg op het werkstation toe:

   ```text
   192.168.0.137  whoami.kubernetes.local
   ```

4. open `http://whoami.kubernetes.local`.

Er is **geen** nieuwe NodePort, bridge of port-forward nodig. `/etc/hosts` kent
geen wildcards; voor veel hosts kun je lokaal een DNS-server (dnsmasq,
AdGuard Home, Pi-hole) gebruiken met een wildcard `*.kubernetes.local` naar
`192.168.0.137`.

## Beheer en probleemoplossing

### Logs en status

```sh
ssh root@192.168.0.137 \
  "kubectl -n traefik logs deploy/traefik --tail=100"
ssh root@192.168.0.137 \
  "systemctl status traefik-ingress-http.socket traefik-ingress-http.service"
ssh root@192.168.0.137 \
  "journalctl -u traefik-ingress-http.service -n 50 --no-pager"
```

### Veelvoorkomende problemen

| Symptoom | Oorzaak / oplossing |
| --- | --- |
| `404 page not found` | Host-header klopt niet, de `/etc/hosts`-regel ontbreekt, of de Ingress heeft niet de class `traefik`. Controleer `curl -H 'Host: ...'` en de Traefik-logs. |
| `503 Service Unavailable` | De Service heeft geen endpoints. Controleer `kubectl -n nginx-demo get endpoints nginx` en de pod. |
| `502 Bad Gateway` | De pod is niet bereikbaar of de poort in de Ingress klopt niet. |
| `connection refused` op poort 80/443 | De bridge-socket draait niet, of je gebruikt het verkeerde IP. Controleer `ss -ltn` op de managementcontainer. |
| `Address already in use` bij socket-herstart | Stop eerst de proxyservice; zie de waarschuwing bij stap 2. |
| `curl` naar `192.168.0.137:80` werkt, via de naam niet | `/etc/hosts` of DNS-cache; controleer `getent hosts`/`Resolve-DnsName`. |
| `https` geeft certificaatwaarschuwing | Verwacht: Traefik default self-signed. Zie “TLS”. |
| Ingress blijft `Progressing` in ArgoCD | De Ingress-status is leeg. `traefik-values.yaml` zet `ingressEndpoint.ip`; controleer of die waarde is toegepast. |
| Na een IP-wijziging van de managementcontainer werkt niets | Pas `192.168.0.137` aan in `/etc/hosts`, `files/traefik-values.yaml` (`ingressEndpoint.ip`), `traefik.yml` (`traefik_bridge_ip`) en de systemd-units; draai `traefik.yml` opnieuw. |
| `.local`-naam resolveert niet | mDNS-conflict; kies een andere suffix of gebruik een lokale DNS-server. |

### Bridge handmatig herstarten

```sh
ssh root@192.168.0.137
sudo systemctl stop traefik-ingress-http.service
sudo systemctl restart traefik-ingress-http.socket
sudo systemctl stop traefik-ingress-https.service
sudo systemctl restart traefik-ingress-https.socket
```

De service start automatisch bij de eerste nieuwe verbinding.

### Traefik upgraden

Pas `traefik_chart_version` in `traefik.yml` aan (en lees de release notes),
daarna:

```sh
ansible-playbook traefik.yml
```

De waarden staan in `files/traefik-values.yaml`. De bridge hoeft bij een
Traefik-upgrade niet te worden aangepast zolang de NodePorts gelijk blijven.

### Opruimen

```sh
# Traefik verwijderen
ssh root@192.168.0.137 "helm -n traefik uninstall traefik"
ssh root@192.168.0.137 "kubectl delete namespace traefik"

# Bridge verwijderen
ssh root@192.168.0.137 '
  systemctl disable --now traefik-ingress-http.socket traefik-ingress-https.socket
  rm -f /etc/systemd/system/traefik-ingress-http.{socket,service}
  rm -f /etc/systemd/system/traefik-ingress-https.{socket,service}
  systemctl daemon-reload
'

# Ingress uit Git halen: verwijder het Ingress-document uit
# files/gitops/apps/nginx-demo/app.yaml en draai argocd.yml.
```

Verwijder daarna de regel uit `/etc/hosts` op het werkstation.

## Appendix — Helm-waarden

`files/traefik-values.yaml` (essentie):

```yaml
deployment:
  replicas: 1

service:
  spec:
    type: NodePort

ports:
  web:
    nodePort: 30080
  websecure:
    nodePort: 30443

ingressClass:
  enabled: true
  isDefaultClass: true
  name: traefik

providers:
  kubernetesIngress:
    enabled: true
    publishedService:
      enabled: false
    ingressEndpoint:
      ip: 192.168.0.137

tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Traefik draait met de restricted-compatibele defaults van de chart
(non-root, read-only root filesystem, alle capabilities dropped,
`RuntimeDefault`-seccomp). Er is geen PodSecurity-uitzondering nodig.

## Appendix — geverifieerde resultaten

Op 2026-10-26 uitgevoerd op de bestaande single-node cluster:

```text
Traefik:        1/1 Running (chart 42.1.3, app v3.7.16)
Service:        traefik NodePort 80:30080/TCP, 443:30443/TCP
IngressClass:   traefik (default)
Ingress-status: 192.168.0.137
ArgoCD:         nginx-demo Synced/Healthy
Bridge:         192.168.0.137:80 en :443 listening
HTTP:           200, "Welkom bij de nginx-demo"
HTTPS:          200 met TRAEFIK DEFAULT CERT (self-signed)
Test vanaf:     192.168.0.223 (thuisnetwerk, via bridge)
```

De bridge is alleen op het thuisnetwerkadres `192.168.0.137` gebonden, niet op
`0.0.0.0`. De NodePorts staan op het geïsoleerde clusternetwerk. De demo is
bedoeld voor het lokale netwerk; publiceer hem niet zonder TLS en
toegangsbeperking.
