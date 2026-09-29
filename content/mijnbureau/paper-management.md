---
title: 'Management overview — MijnBureau'
weight: 100
draft: false
---

# Management Paper: MijnBureau — Ervaringen en Aandachtspunten

## 1. Inleiding

Deze paper beschrijft de installatie-ervaringen met **MijnBureau**, een applicatiesuite ontwikkeld in opdracht van het Ministerie van Binnenlandse Zaken (MinBZK). De broncode is beschikbaar via [github.com/MinBZK/mijn-bureau-deploy-demo](https://github.com/MinBZK/mijn-bureau-deploy-demo). Het doel is om een overzicht te geven van de technische opzet, de knelpunten tijdens installatie en configuratie, en de lessen die hieruit getrokken kunnen worden.

## 2. Architectuuroverzicht

MijnBureau is een verzameling containerapplicaties die draaien op Kubernetes. De suite omvat onder andere:

- **Bureaublad** — centrale portaal/startpagina (vgl. een overzichtsapplicatie van de overheid)
- **Keycloak** — centraal authenticatie- en autorisatieplatform (OIDC/OAuth2)
- **Docs** — documentbeheer (backend: Django, frontend: lasuite/impress)
- **Nextcloud** — bestandsopslag en synchronisatie
- **Drive** — bestandsbeheer met share-functionaliteit
- **Meet** — videoconferencing
- **Grist** — spreadsheet-toepassing
- **Conversations** — AI-chat/gesprekken
- **Element** — (Matrix) chatclient
- **Collabora** — online kantoorbewerking
- **OpenProject** — projectmanagement

De applicaties worden ontsloten via een centrale ingress-controller en delen één Keycloak-authenticatie.

## 3. Installatietraject

### 3.1 Eerste poging: Volledige Kubernetes + Traefik

Initieel is geprobeerd om MijnBureau te installeren op een handmatig geconfigureerde Kubernetes-cluster met Traefik als ingress-controller. Dit traject kende aanzienlijke problemen:

- **Complexe configuratie**: Traefik moest handmatig worden afgestemd op de OIDC-stroom (HSTS-headers, TLS-certificaten, routering).
- **HSTS-middleware-conflicten**: Meerdere Helm-charts (Keycloak, Nextcloud) creëerden dezelfde `hsts-header` Middleware-CRD, wat leidde tot Helm-eigendomsconflicten.
- **Netwerkbeleid**: NetworkPolicies blokkeerden interne podcommunicatie, vooral voor OIDC-backchannel-verkeer (Keycloak op poort 8080).
- **CoreDNS-hacks**: Handmatige rewrite-regels in CoreDNS waren nodig voor DNS-resolutie, wat leidde tot een broze configuratie.

Het gebrek aan reproduceerbaarheid en de vele handmatige ingrepen maakten deze aanpak onhoudbaar.

De installatie werd uitgevoerd op Nixos, het grote voordeel van deze linux-variant is een centraal configuratiebestand.
Dus in theorie zou je dan aan 2 scripts voldoende hebben om mijnbureau op te zetten.


### 3.2 Tweede poging: KIND (Kubernetes in Docker)

Na de problemen met de volledige Kubernetes-setup is overgestapt op **KIND** (Kubernetes in Docker). KIND biedt een lichtgewicht Kubernetes-omgeving die eenvoudig lokaal op te zetten en te verwijderen is. Dit verlaagde de drempel aanzienlijk.

- **Laptop**: Eerste installatie en testen vonden plaats op een Linux Mint 22.3 laptop (met Podman i.p.v. Docker). Hier zijn de meeste configuratie-uitdagingen in kaart gebracht.
- **Server**: Vervolgens is de setup overgezet naar een serveromgeving (NixOS op Proxmox), waar dezelfde configuratiemethode werd toegepast.

### 3.3 Centraal Installatiescript (Go Template)

Een belangrijk kenmerk van MijnBureau is het **centrale installatiescript** op basis van Go-templates (`mijnbureau.yaml.gotmpl`). In dit script kan men specificeren welke modules worden geactiveerd. Het script haalt vervolgens zelfstandig alle benodigde componenten van het internet en installeert deze.

#### Voordelen
- **Eenvoudige selectie**: Modules in- of uitschakelen via een boolean (`enabled: true/false`).
- **Centrale beveiliging**: Secrets en wachtwoorden worden deterministisch gegenereerd uit één `MIJNBUREAU_MASTER_PASSWORD`-omgevingsvariabele, waardoor een consistent beveiligingsbeleid ontstaat.
- **Gestandaardiseerde installatie**: Alle applicaties worden via Helmfile geïnstalleerd met Bitnami-charts (professioneel).

#### Nadelen
- **Herinstallatieproblemen**: Bij herinstallatie worden oude wachtwoorden en Kubernetes-pods niet altijd correct opgeruimd. Omdat wachtwoorden deterministisch worden gegenereerd, kunnen bij gewijzigde `MIJNBUREAU_MASTER_PASSWORD` credential-drift ontstaan tussen wat de database verwacht en wat de applicatie gebruikt.
- **Geen propere uninstall**: Een `helmfile destroy` verwijdert niet alle resources. PersistentVolumeClaims, Secrets en ConfigMaps blijven vaak achter, wat bij herinstallatie tot conflicten leidt.
- **Bitnami-beperkingen**: Hoewel Bitnami-charts professioneel ogen, hebben ze eigenaardigheden (bv. `helm upgrade` roteert soms wachtwoorden in Secrets zonder de database te updaten).

## 4. Technische Knelpunten en Oplossingen

Tijdens het installatie- en configuratietraject zijn talrijke problemen ondervonden. Hieronder een samenvatting.

### 4.1 OIDC/Authenticatie

De centrale uitdaging was het werkend krijgen van OIDC-authenticatie. Het principe is:

1. **Browser** redirect naar Keycloak (HTTPS, extern)
2. **Backend** (server-side) wisselt autorisatiecode om voor tokens (HTTP, intern)

Dit bracht meerdere problemen met zich mee:

| Probleem | Oorzaak | Oplossing |
|---|---|---|
| **OIDC callback 500** | Backchannel-endpoints gebruikten HTTPS via externe hostname die van binnenuit niet bereikbaar was | Backchannel-endpoints gewijzigd naar interne HTTP (`http://keycloak-keycloak/...`) |
| **NetworkPolicy blokkeert Keycloak** | Egress-regel stond poort 80 toe, maar Keycloak luistert op 8080 | Poort gewijzigd naar 8080 (post-DNAT) |
| **Self-signed certificate fouten** | mkcert-CA niet vertrouwd in containers | `NODE_TLS_REJECT_UNAUTHORIZED=0` (Grist) of interne HTTP gebruiken |
| **Keycloak frontend/backchannel gemengd** | Keycloak genereert URLs op basis van binnenkomend verzoek | `KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true` ingesteld |
| **Nextcloud OIDC faalt** | Discovery-URL gebruikte HTTPS, pod vertrouwt cert niet | Discovery via interne HTTP (`http://keycloak-keycloak/...`) |

### 4.2 Resourcebeheer

Diverse pods vielen in `CrashLoopBackOff` door ontoereikende resources:

| Applicatie | Probleem | Oplossing |
|---|---|---|
| **Conversations-backend** | OOMKilled (384Mi limiet) | Resource preset `micro` → `small` (768Mi) |
| **Drive-backend-celery** | Liveness/Readiness timeout (2s) | `timeoutSeconds` verhoogd naar 15s, meer geheugen |
| **Docs-backend** | Liveness-probe startup te traag | `startupProbe` toegevoegd met 120s window |
| **Docs-celery** | OOMKilled (384Mi) | Limiet verhoogd naar 720Mi |

### 4.3 Database Credential Drift

Een structureel probleem: elke `helmfile sync` kan de database-Secrets regenereren, maar de database zelf behoudt het oude wachtwoord. Dit leidde tot herhaaldelijke `password authentication failed`-fouten. De oplossing was steeds handmatig `ALTER USER` uitvoeren of Secrets patchen.

### 4.4 Gestripte Functionaliteit

Sommige applicaties bieden **minder functionaliteit** dan de originele versie. Nextcloud is hiervan het duidelijkste voorbeeld:
- Geen eigen authenticatie (alleen via Keycloak OIDC)
- Geen eigen Redis/S3-configuratie via de standaard Nextcloud-admin
- Specifieke Bitnami-beperkingen (bv. `user_oidc` app moet via `occ` worden geconfigureerd, niet via de webinterface)

## 5. Beoordeling

### Sterke punten

- **Centrale configuratie**: Het template-systeem maakt het mogelijk om in één bestand de volledige suite te beheren.
- **Professionaliteit**: Gebruik van Bitnami-charts, Helmfile en gestandaardiseerde Kubernetes-manifesten.
- **Uitgebreide suite**: Dekking van kantoortoepassingen (docs, spreadsheets), communicatie (meet, chat) en AI (conversations).
- **Moderne architectuur**: OIDC-gebaseerde authenticatie, microservices, containerized.

### Zwakke punten

- **Installatie werkt niet out-of-the-box**: Elke applicatie vereist maatwerk, patches en configuratie-aanpassingen.
- **Broos credential management**: Deterministische wachtwoordgeneratie zonder proper lifecycle management leidt tot credential drift.
- **Beperkte uninstall**: Herinstallatie is risicovol door achterblijvende resources.
- **Gestripte functionaliteit**: Sommige apps hebben minder mogelijkheden dan hun standalone tegenhangers.
- **Documentatie**: De officiële documentatie gaat uit van een `demo`-omgeving; voor `local` of `production` zijn aanpassingen in de broncode van de charts nodig (bv. `helmfile-child.yaml.gotmpl`).
- **heb in nextcloud geen kantoortoepassing gevonden, dit zou nuttig zijn om een M365 ervaring te krijgen. De meegeleverde spreadsheet en editor zijn denkelijk beperkt.

### Aanbevelingen

1. **Vast pinnen van wachtwoorden**: Gebruik een statisch, eenmalig gegenereerd wachtwoord per applicatie in plaats van deterministische afleiding, zodat herinstallatie veilig is.
2. **Uninstall-script**: Ontwikkel een script dat alle resources (PVCs, Secrets, ConfigMaps) volledig opschoont.
3. **Gestandaardiseerde netwerkpolicy**: Ontwerp één generieke policy per namespace in plaats van per-app policies.
4. **Productieklare TLS**: Vervang mkcert door een echte PKI (Let's Encrypt of interne CA) met automatische certificaatvernieuwing.
5. **Bitnami-alternatieven**: Overweeg voor productie andere PostgreSQL-opties (bv. CloudNativePG) die beter omgaan met wachtwoordrotatie.

## 6. Conclusie

MijnBureau is een **ambitieuze en professioneel opgezette applicatiesuite** die een breed scala aan functionaliteit biedt. De gekozen architectuur (Kubernetes, Keycloak, microservices) is modern en schaalbaar. Het centrale installatiescript met Go-templates is een krachtig concept voor het beheren van een complexe multi-applicatieomgeving.

Tegelijkertijd is de **installatie- en configuratie-ervaring weerbarstig**. Het product is niet "plug-and-play": elke component vereist aanpassingen, debugging en maatwerk. Het deterministische credential-systeem, hoewel elegant in theorie, veroorzaakt in de praktijk problemen bij herinstallatie. De afhankelijkheid van Bitnami-charts brengt eigen beperkingen met zich mee.

**Voor organisaties die MijnBureau overwegen**: reserveer voldoende tijd en expertise voor de initiële installatie. Een team met Kubernetes-ervaring is essentieel. Het product is veelbelovend maar bevindt zich nog in een fase waarin aanzienlijk technisch maatwerk nodig is.
