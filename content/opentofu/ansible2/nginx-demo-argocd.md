# nginx-demo via ArgoCD (GitOps)

Deze handleiding beschrijft hoe de **nginx-demo** in Forgejo staat en door
ArgoCD wordt uitgerold. De demo bestaat uit een nginx-Deployment die een eigen
welkomstpagina serveert; de inhoud van die pagina komt uit een Kubernetes
ConfigMap die uit Git wordt gesynchroniseerd.

Eindresultaat:

- ArgoCD-Application `argocd/nginx-demo` staat op **`Synced/Healthy`**;
- in namespace `nginx-demo` draaien een Deployment, Pod, Service, ConfigMap en
  Ingress;
- de pagina is bereikbaar via **Traefik** op
  `http://nginx-demo.kubernetes.local` (zie `traefik.md`);
- een wijziging aan de welkomstpagina in Forgejo komt **zonder podherstart**
  door (de ConfigMap is als map gemount).

## Architectuur

```
Forgejo (gitea_admin/gitops)
  apps/nginx-demo/app.yaml          <- Namespace + ConfigMap + Deployment + Service + Ingress
            |
            |  ArgoCD repo-server (in-cluster Git-URL, read-only token)
            v
ArgoCD Application nginx-demo  --->  namespace nginx-demo
  path: apps/nginx-demo               - Deployment nginx (nginx:1.27-alpine)
  auto-sync: prune + selfHeal         - Service nginx (ClusterIP :80)
                                      - ConfigMap nginx-welcome (index.html)
                                      - Ingress nginx (host nginx-demo.kubernetes.local)
                                              |
                                              v
                                        Traefik (NodePort 30080/30443)
```

De root-Application `argocd/root` blijft alleen de losse demo in `apps/`
beheren. ArgoCD leest een directory standaard **niet recursief**, dus
`apps/nginx-demo/` valt buiten de root-app en wordt uitsluitend door de
Application `nginx-demo` beheerd.

## Bestanden

| Bestand | Doel |
| --- | --- |
| `files/gitops/apps/nginx-demo/app.yaml` | De vijf manifests die in Forgejo worden gezet. |
| `files/gitops/apps/demo.yaml` | Bestaande demo (Namespace + ConfigMap `argocd-demo`). |
| `tasks/forgejo_file.yml` | Zet één bestand idempotent in Forgejo (POST = nieuw, PUT = bijwerken). |
| `argocd.yml` | Seedt de bestanden, maakt beide Applications en wacht op de nieuwste commit. |
| `traefik.yml`, `files/traefik-values.yaml` | Installeren Traefik en de L4-bridge naar de NodePorts. |
| `traefik.md` | Ingress-ontwerp, `/etc/hosts`, verificatie en beheer. |
| `nginx-demo-argocd.md` | Dit document. |

De repo-paden in Forgejo zijn gelijk aan de paden onder `files/gitops/`:

```
apps/
├── demo.yaml
└── nginx-demo/
    └── app.yaml
```

## Vereisten

- `ansible-playbook forgejo.yml` en `ansible-playbook argocd.yml` zijn al eens
  gelukt (Forgejo, ArgoCD en de admin-kubeconfig bestaan).
- De beheercontainer heeft `kubectl` en `helm` (regelt de `tools`-rol).
- De cluster-node heeft egress naar Docker Hub voor `nginx:1.27-alpine`.

## Stap 1 — Demo uitrollen

```sh
cd ansible
ansible-playbook argocd.yml
```

Het playbook doet voor deze demo:

1. leest de adminreferenties uit `forgejo/forgejo-admin`;
2. zet `apps/nginx-demo/app.yaml` in de repo (nieuw bestand via `POST`, gewijzigd
   bestand via `PUT` met de blob-`sha`);
3. bepaalt de nieuwste commit van branch `main`;
4. maakt/actualiseert de Application `argocd/nginx-demo`;
5. zet de refresh-annotatie `argocd.argoproj.io/refresh=hard` op beide
   Applications, zodat ArgoCD niet tot de volgende poll wacht;
6. wacht tot `nginx-demo` **én** `root` op die nieuwste commit `Synced` staan;
   `root` moet `Healthy` zijn. `nginx-demo` mag `Progressing` zijn zolang
   Traefik nog niet is geïnstalleerd: de Ingress wacht dan op een controller.
   Na `ansible-playbook traefik.yml` wordt de health `Healthy`;
7. wacht op de rollout en controleert via HTTP of de welkomsttekst aanwezig is.

Verwacht aan het einde:

```text
Application root: Synced/Healthy (revisie <sha>)
Application nginx-demo: Synced/Healthy (revisie <sha>)          # met Traefik
Application nginx-demo: Synced/Progressing (revisie <sha>)      # vóór traefik.yml
```

Alleen de Helm-taak meldt normaal `changed`; de Git-bestanden en Applications
zijn idempotent. Een tweede run hoort daarom `changed=1` te geven.

### Wat er in de repo komt

`files/gitops/apps/nginx-demo/app.yaml` bevat vijf documenten:

1. **Namespace `nginx-demo`** met labels voor herkenbaarheid.
2. **ConfigMap `nginx-welcome`** met de volledige welkomstpagina onder de key
   `index.html`. De HTML staat als block-scalar in de YAML.
3. **Deployment `nginx`**:
   - image `nginx:1.27-alpine`, één replica;
   - poort `80` (`http`);
   - readiness/liveness-probe op `/`;
   - requests `10m`/`32Mi`, limits `200m`/`128Mi`;
   - **tolerations** voor `node-role.kubernetes.io/control-plane` en
     `node-role.kubernetes.io/master` (de enige node is een control-plane met
     een `NoSchedule`-taint);
   - de ConfigMap wordt als **map** gemount op `/usr/share/nginx/html`
     (geen `subPath`), read-only.
4. **Service `nginx`** van type `ClusterIP`, poort `80` → `http`.
5. **Ingress `nginx`** met `ingressClassName: traefik`, host
   `nginx-demo.kubernetes.local`, path `/` (`Prefix`) en backend
   `nginx:http`. De Service blijft dus `ClusterIP`; Traefik doet de toegang.

De mount als map is bewust: bij een `subPath`-mount werkt de kubelet een
gewijzigde ConfigMap niet bij in een draaiende pod. Zonder `subPath` wel, en
nginx hoeft voor statische bestanden niet te herstarten.

## Stap 2 — Controleren of ArgoCD de demo kent

```sh
ssh root@192.168.0.137 \
  "kubectl -n argocd get application nginx-demo"

ssh root@192.168.0.137 \
  "kubectl -n argocd get application nginx-demo \
   -o jsonpath='{.status.sync.status}/{.status.health.status}/{.status.sync.revision}'; echo"
```

Verwacht: `Synced` en een commit-`sha`. De health is `Healthy` zodra Traefik is
geïnstalleerd; vóór `traefik.yml` staat de Ingress op `Progressing` omdat er nog
geen ingress controller is.

Vergelijk met de nieuwste commit in Forgejo (met het read-only ArgoCD-token):

```sh
ssh root@192.168.0.137 '
  tok=$(kubectl -n argocd get secret repo-forgejo \
        -o jsonpath="{.data.password}" | base64 -d)
  kubectl -n forgejo exec deploy/forgejo -- \
    curl -s -H "Authorization: token $tok" \
    http://127.0.0.1:3000/api/v1/repos/gitea_admin/gitops/commits?limit=1
'
```

De `sha` in de Application moet gelijk zijn aan de bovenste commit.

## Stap 3 — Resources controleren

```sh
ssh root@192.168.0.137 \
  "kubectl -n nginx-demo get deploy,pods,svc,configmap,ingress"

ssh root@192.168.0.137 \
  "kubectl -n nginx-demo rollout status deployment/nginx"
```

Verwacht:

```text
deployment.apps/nginx   1/1     1            1
pod/nginx-...           1/1     Running
service/nginx           ClusterIP   ...   80/TCP
configmap/nginx-welcome 1 ...
ingress.networking.k8s.io/nginx   traefik   nginx-demo.kubernetes.local   80
```

Controleer dat de ConfigMap echt als map gemount is:

```sh
ssh root@192.168.0.137 \
  "kubectl -n nginx-demo exec deploy/nginx -- ls -l /usr/share/nginx/html"
```

Verwacht een symlink `index.html -> ..data/index.html` (het mechanisme waarmee
de kubelet ConfigMap-updates doorvoert).

## Stap 4 — De pagina openen via Traefik

De Service blijft `ClusterIP`; **Traefik** ontsluit de demo via de Ingress. Op
het werkstation is één regel in `/etc/hosts` nodig:

```text
192.168.0.137  nginx-demo.kubernetes.local
```

Open daarna:

```text
http://nginx-demo.kubernetes.local
```

De pagina toont **“Welkom bij de nginx-demo”**, met de verwijzing naar
`apps/nginx-demo/app.yaml` en namespace `nginx-demo`.

Is Traefik nog niet geïnstalleerd, draai dan eerst:

```sh
cd ansible
ansible-playbook traefik.yml
```

Zie `traefik.md` voor de netwerkopzet, de `/etc/hosts`-instructies voor
Linux/macOS/Windows, HTTPS en probleemoplossing.

Controleren zonder `/etc/hosts` aan te passen:

```sh
curl -s --resolve nginx-demo.kubernetes.local:80:192.168.0.137 \
  http://nginx-demo.kubernetes.local/ | grep -o 'Welkom bij de nginx-demo'
```

Rechtstreeks via de Traefik-NodePort vanaf de beheercontainer:

```sh
ssh root@192.168.0.137 \
  "curl -s -H 'Host: nginx-demo.kubernetes.local' http://10.10.50.22:30080/ \
   | grep -o 'Welkom bij de nginx-demo'"
```

Controleren in de pod, zonder ingress of port-forward:

```sh
ssh root@192.168.0.137 \
  "kubectl -n nginx-demo exec deploy/nginx -- wget -qO- http://127.0.0.1/"
```

### Fallback: tijdelijk port-forwarden

Alleen nodig als Traefik of de bridge tijdelijk niet beschikbaar is. Start de
port-forward **op de beheercontainer** (niet op het werkstation):

```sh
ssh root@192.168.0.137 \
  'kubectl -n nginx-demo port-forward --address 0.0.0.0 svc/nginx 8081:80'
# http://192.168.0.137:8081
```

De SSH-sessie moet open blijven. Voor toegang via `localhost:8081` op je eigen
machine kun je daarnaast een SSH-tunnel gebruiken:

```sh
ssh -L 8081:127.0.0.1:8081 root@192.168.0.137
# open daarna http://localhost:8081
```

> **Let op:** op een werkstation zonder kubeconfig meldt `kubectl`
> `The connection to the server localhost:8080 was refused`. Gebruik dan de
> `ssh ... 'kubectl ...'`-vorm hierboven, of log eerst in op de container en
> gebruik `sudo env KUBECONFIG=/root/.kube/config kubectl ...`.

## Stap 5 — De welkomstpagina wijzigen (GitOps)

De pagina staat in de ConfigMap in `apps/nginx-demo/app.yaml`. Wijzigingen gaan
via Git, niet met `kubectl edit`.

1. Start een port-forward naar Forgejo (foreground; tweede shell gebruiken):

   ```sh
   ssh root@192.168.0.137 \
     'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
   ```

2. Open <http://192.168.0.137:3000> en log in als `gitea_admin`. Het wachtwoord:

   ```sh
   ssh root@192.168.0.137 \
     "kubectl -n forgejo get secret forgejo-admin \
      -o jsonpath='{.data.password}' | base64 -d; echo"
   ```

3. Ga naar repository **`gitea_admin/gitops`** → `apps/nginx-demo/app.yaml` →
   bewerken. Pas bijvoorbeeld de `<h1>` of een `<p>` aan en commit op `main`.

4. Laat ArgoCD de nieuwe commit ophalen. Automatische sync pollt elke ~3
   minuten; directer kan met een refresh:

   ```sh
   ssh root@192.168.0.137 \
     "kubectl -n argocd annotate application nginx-demo \
      argocd.argoproj.io/refresh=hard --overwrite"
   ```

   Of gebruik in de ArgoCD-UI de knop **Sync → Synchronize**.

5. Volg de status:

   ```sh
   ssh root@192.168.0.137 \
     "kubectl -n argocd get application nginx-demo -w"
   ```

6. De ConfigMap wordt bijgewerkt. De kubelet ververst de gemounte map
   doorgaans binnen ongeveer een minuut; daarna serveert nginx de nieuwe inhoud
   **zonder podherstart**. Controleer:

   ```sh
   ssh root@192.168.0.137 \
     "kubectl -n nginx-demo get pods"          # AGE blijft gelijk
   ssh root@192.168.0.137 \
     "kubectl -n nginx-demo exec deploy/nginx -- wget -qO- http://127.0.0.1/"
   ```

   Alleen bij wijzigingen aan de **Deployment** (image, probes, resources,
   volumeMounts) rolt ArgoCD de pod wel opnieuw uit.

> **Let op:** de playbook-taken “Controleer de welcome-pagina via HTTP” in
> `argocd.yml` en de NodePort/bridge-controles in `traefik.yml` zoeken naar de
> vaste tekst `Welkom bij de nginx-demo`. Verander je die tekst in de repo, pas
> dan ook de `until`-voorwaarden in beide playbooks aan, of laat die taken
> vervallen.

## Stap 6 — Opruimen

```sh
ssh root@192.168.0.137 \
  "kubectl -n argocd delete application nginx-demo"
```

Door de finalizer `resources-finalizer.argocd.argoproj.io` verwijdert ArgoCD
de bijbehorende resources (inclusief namespace `nginx-demo`). Controleer:

```sh
ssh root@192.168.0.137 "kubectl get namespace nginx-demo"
```

Verwacht: `NotFound`.

De map `apps/nginx-demo/` blijft in Forgejo staan. Wil je de demo definitief
niet meer automatisch uitrollen, verwijder dan ook:

- `files/gitops/apps/nginx-demo/app.yaml`;
- de entry `apps/nginx-demo/app.yaml` uit `argocd_gitops_files` in `argocd.yml`;
- de taak “Maak de nginx-demo Application” (en de bijbehorende wacht/controle).

## Verificatie in één overzicht

| Controle | Commando | Verwacht |
| --- | --- | --- |
| Application | `kubectl -n argocd get app nginx-demo` | `Synced`, `Healthy` |
| Revisie | `kubectl -n argocd get app nginx-demo -o jsonpath='{.status.sync.revision}'` | laatste commit-`sha` |
| Pod | `kubectl -n nginx-demo get pods` | `1/1 Running` |
| Rollout | `kubectl -n nginx-demo rollout status deploy/nginx` | `successfully rolled out` |
| Service | `kubectl -n nginx-demo get svc nginx` | `ClusterIP ... 80/TCP` |
| Mount | `kubectl -n nginx-demo exec deploy/nginx -- ls -l /usr/share/nginx/html` | `index.html -> ..data/index.html` |
| Ingress | `kubectl -n nginx-demo get ingress nginx` | host `nginx-demo.kubernetes.local`, class `traefik` |
| IngressClass | `kubectl get ingressclass` | `traefik` (default) |
| HTTP | `curl -s http://nginx-demo.kubernetes.local/` | bevat `Welkom bij de nginx-demo` |
| Fallback HTTP | `curl -s http://192.168.0.137:8081/` | alleen bij een actieve port-forward |

## Probleemoplossing

| Symptoom | Oorzaak / oplossing |
| --- | --- |
| Pod blijft `Pending`, event `untolerated taint ... control-plane` | De tolerations ontbreken in de Deployment. Ze staan in `app.yaml`; controleer of de nieuwste commit gesynct is. |
| Applicatie blijft lang `Progressing` | `kubectl -n nginx-demo describe pod <pod>` en `get events`. Vaak image-pull of probe. |
| `ImagePullBackOff` | Geen egress naar Docker Hub, of de tag bestaat niet. Controleer de node en/of pin een andere `nginx:...-alpine`-tag. |
| `503`/`connection refused` op de Service | Pod is niet `Ready`; controleer probes en de ConfigMap-mount. |
| Nieuwe welcome-tekst komt niet door | Controleer of de ConfigMap is bijgewerkt en of de mount een **map** is (geen `subPath`). Wacht ~1 minuut; forceer eventueel met `kubectl -n nginx-demo rollout restart deploy/nginx` (geen podherstart nodig bij alleen inhoud). |
| ArgoCD ziet de nieuwe commit niet | Refresh-annotatie zetten (zie stap 5) of wachten op de poll. Het playbook doet dit automatisch en wacht op de nieuwste `sha`. |
| Root-app probeert nginx te beheren | Controleer of `directory.recurse` niet aanstaat; standaard leest de root-app alleen `apps/` en niet `apps/nginx-demo/`. |
| `404 page not found` via de hostnaam | `/etc/hosts` ontbreekt of wijst naar het verkeerde IP; de Ingress heeft niet class `traefik`; of Traefik ziet de Ingress niet. Controleer `curl -H 'Host: ...' http://10.10.50.22:30080/` en de Traefik-logs. |
| `connection refused` op poort 80/443 | De bridge-socket op de managementcontainer draait niet. Controleer `ss -ltn` en `systemctl status traefik-ingress-http.socket`. |
| Poort 8081 bezet (fallback) | Kies een andere lokale poort, bijvoorbeeld `8082:80`. |

## Beveiliging en clusterinstellingen

- De namespace `nginx-demo` gebruikt de clusterbrede PodSecurity-instelling
  (`baseline` op Talos). De officiële nginx-image start als root en bindt poort
  80; dat is onder `baseline` toegestaan. Er is **geen** PSA-uitzondering nodig.
- Zou het cluster ooit `restricted` afdwingen, dan zijn `runAsNonRoot: true`,
  een unprivileged poort (bijv. 8080) en een passend `securityContext` nodig.
- De Service blijft `ClusterIP`; toegang gaat via de Traefik-Ingress. De
  NodePort-plaatsing en L4-bridge zitten in de `traefik`-namespace en de
  managementcontainer, niet in `nginx-demo`. Zie `traefik.md`.
- Het ArgoCD-token heeft alleen `read:repository`; schrijfacties op de repo
  gebeuren in het playbook met de admin-basic-auth en worden niet aan ArgoCD
  gegeven.

## Appendix — Application-manifest

De Application wordt door `argocd.yml` met `kubectl apply` aangemaakt:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-demo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git
    targetRevision: main
    path: apps/nginx-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

De Application staat bewust in het playbook en niet in Git. Een volgende stap
zou een app-of-apps kunnen zijn, waarbij deze Application-manifest zelf in
Forgejo staat en door de root-Application wordt aangemaakt.

## Appendix — Forgejo-API

`tasks/forgejo_file.yml` gebruikt twee endpoints:

| Actie | Endpoint | Bijzonderheid |
| --- | --- | --- |
| Bestand lezen | `GET /repos/{owner}/{repo}/contents/{path}?ref=main` | Levert `content` (base64) en `sha`. |
| Nieuw bestand | `POST /repos/{owner}/{repo}/contents/{path}` | Geen `sha` nodig. |
| Bijwerken | `PUT /repos/{owner}/{repo}/contents/{path}` | `sha` van het bestaande bestand is verplicht. |

Een `PUT` op een nieuw pad geeft Forgejo's `HTTP 422 “[SHA]: Required”`.
Daarom kiest het playbook per bestand tussen `POST` en `PUT` en slaat het de
update over als de inhoud al gelijk is.
