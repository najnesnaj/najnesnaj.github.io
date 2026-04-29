---
title: 'redis'
weight: 1900
draft: false
---
Hier is een **duidelijke uitleg** van wat je ziet in de output:

### Samenvatting
Je hebt zojuist een **Helm upgrade** uitgevoerd van je applicatie "bureaublad".  
Als onderdeel van die upgrade is ook de **Redis** dependency geüpdatet (of opnieuw geïnstalleerd).

---

### Stap-voor-stap uitleg

#### 1. Hoe je het Redis-wachtwoord ophaalt
```bash
export REDIS_PASSWORD=$(kubectl get secret --namespace default bureaublad-redis -o jsonpath="{.data.redis-password}" | base64 -d)
```

**Uitleg**:  
Dit commando haalt het gegenereerde wachtwoord van Redis op uit een Kubernetes Secret en zet het in de environment variable `REDIS_PASSWORD`.  
Je moet dit meestal één keer uitvoeren voordat je met Redis gaat verbinden.

#### 2. Hoe je verbinding maakt met Redis

Er wordt een tijdelijke **Redis client pod** aangemaakt:

```bash
kubectl run --namespace default redis-client --restart='Never' \
  --env REDIS_PASSWORD=$REDIS_PASSWORD \
  --image=...redis:8.2.1... \
  --command -- sleep infinity
```

Daarna ga je erin met:
```bash
kubectl exec --tty -i redis-client ... -- bash
```

En binnen die pod verbind je met:
```bash
REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h bureaublad-redis-master
```

**Belangrijke opmerking**:
Omdat er **NetworkPolicy** actief is, mag alleen een pod met de label `bureaublad-redis-client=true` verbinding maken met Redis. Daarom wordt die label expliciet meegegeven.

---

#### 3. Waarschuwing over resources
```
WARNING: There are "resources" sections in the chart not set. 
Using "resourcesPreset" is not recommended for production.
```

**Betekenis**:  
De Redis Helm chart waarschuwt je dat er geen CPU- en geheugenlimieten (resources) zijn ingesteld.  
In productie is dit **niet aanbevolen**. Je zou best `master.resources` en `replica.resources` expliciet instellen zodat Redis niet te veel resources kan gebruiken of juist te weinig krijgt.

---

#### 4. Helm status

```bash
Listing releases matching ^bureaublad-redis$
bureaublad-redis  default  7  2026-04-29 ...  deployed  redis-21.2.6  8.0.2
```

Dit toont de Redis sub-chart (dependency).

Daarna zie je:

```bash
Listing releases matching ^bureaublad$
bureaublad  default  7  2026-04-29 ...  deployed  bureaublad-0.2.0  0.9.3
```

Dit is **jouw eigen applicatie** ("bureaublad").

En tot slot:

```bash
UPDATED RELEASES:
bureaublad-redis          ...   3s
bureaublad                ...   3s
```

→ Beide releases zijn succesvol geüpdatet tijdens deze `helm upgrade`.

---

### Kort samengevat:

- Je hebt succesvol `helm upgrade` uitgevoerd op je "bureaublad" applicatie.
- Redis (de database) is mee geüpdatet naar versie 21.2.6 van de chart (Redis server 8.0.2).
- Je krijgt instructies hoe je veilig met Redis kunt verbinden via een tijdelijke client pod (omdat NetworkPolicy het blokkeert voor andere pods).
- Er is een waarschuwing dat je in productie beter resource limits moet instellen voor Redis.

---

**Wil je dat ik voor je een handig script maak** dat je in één keer het Redis-wachtwoord ophaalt en direct de redis-cli opent?  
Of wil je hulp om de resource limits netjes in te stellen in je `values.yaml`?

Laat maar weten wat je nu nodig hebt.


====================================
in de values.yaml

Nog betere oplossing (aanbevolen op lange termijn)Schakel de NetworkPolicy tijdelijk uit terwijl je aan het ontwikkelen/debuggen bent:yaml

redis:
  networkPolicy:
    enabled: false




helmfile sync --selector name=bureaublad
Building dependency release=bureaublad, chart=charts/bureaublad
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Upgrading release=bureaublad, chart=charts/bureaublad, namespace=
Release "bureaublad" has been upgraded. Happy Helming!
NAME: bureaublad
LAST DEPLOYED: Wed Apr 29 09:29:09 2026
NAMESPACE: default
STATUS: deployed
REVISION: 8
TEST SUITE: None

Listing releases matching ^bureaublad$
bureaublad	default  	8       	2026-04-29 09:29:09.12878126 +0000 UTC	deployed	bureaublad-0.2.0	0.9.3      


UPDATED RELEASES:
NAME         NAMESPACE   CHART               VERSION   DURATION
bureaublad               charts/bureaublad   0.2.0           3s


[root@nixos:/home/nixie/mijn-bureau-infra]# kubectl rollout restart deployment bureaublad-backend -n default
deployment.apps/bureaublad-backend restarted

