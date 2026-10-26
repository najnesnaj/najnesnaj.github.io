# ArgoCD met Forgejo als Git-bron

Dit document beschrijft wat `argocd.yml` installeert en hoe je controleert dat
ArgoCD daadwerkelijk uit Forgejo synchroniseert. De nginx-demo die het playbook
meelevert staat beschreven in `nginx-demo-argocd.md`.

## Wat het playbook doet

`argocd.yml` draait op `k8s_management` (net als `forgejo.yml`) en:

1. installeert of upgradet **ArgoCD** met Helm in namespace `argocd`
   (OCI-chart `oci://ghcr.io/argoproj/argo-helm/argo-cd`, standaard de nieuwste
   versie);
2. zet `global.tolerations` zodat alle ArgoCD-componenten op de control-plane
   mogen draaien (de enige node heeft een `NoSchedule`-taint);
3. leest de door de Forgejo-chart beheerde adminreferenties uit Secret
   `forgejo/forgejo-admin` (gebruiker `gitea_admin`);
4. maakt de **private** Forgejo-repo `gitea_admin/gitops` aan en zet de
   manifests uit `files/gitops/` erin: `apps/demo.yaml` (Namespace +
   ConfigMap `argocd-demo`) en `apps/nginx-demo/app.yaml` (de nginx-demo);
5. maakt een **read-only** Forgejo-token (`read:repository`) voor ArgoCD;
6. registreert de repo als ArgoCD repository-secret `repo-forgejo`;
7. maakt de root-Application `root` (pad `apps`) en de nginx-Application
   `nginx-demo` (pad `apps/nginx-demo`);
8. vraagt ArgoCD de nieuwste commit op te halen en wacht tot beide
   Applications daarop `Synced/Healthy` zijn, controleert de demo-ConfigMap en
   test de nginx-welcomepagina via HTTP.

Draaien:

```sh
cd ansible
ansible-playbook argocd.yml
```

`forgejo.yml` moet daarvoor al gedraaid hebben: het playbook stopt met een
duidelijke melding als Forgejo of de admin-Secret ontbreekt. De `tools`-rol
zorgt dat Helm aanwezig is; de admin-kubeconfig (`/root/.kube/config`) moet
bestaan (gemaakt door `site.yml`).

## Koppeling met Forgejo

| Onderdeel | Waarde |
| --- | --- |
| Forgejo-repo | `gitea_admin/gitops` (private, branch `main`) |
| Git-URL voor ArgoCD | `http://forgejo-http.forgejo.svc.cluster.local:3000/gitea_admin/gitops.git` |
| Repository-secret | `argocd/repo-forgejo` (label `argocd.argoproj.io/secret-type=repository`) |
| Token-scope | `read:repository` (alleen lezen) |
| Root-Application | `argocd/root` → pad `apps`, doelnamespace `argocd-demo` |
| nginx-Application | `argocd/nginx-demo` → pad `apps/nginx-demo`, doelnamespace `nginx-demo` |
| Sync-beleid | automated, `prune: true`, `selfHeal: true`, `CreateNamespace=true` |

De URL gebruikt de **in-cluster** servicenaam. Dat is bewust: ArgoCD's
repo-server draait in dezelfde cluster en heeft geen last van de ClusterIP-only
service. Vanaf een werkstation is Forgejo nog steeds alleen via port-forward
bereikbaar.

### Schrijven versus lezen

Forgejo's API staat geen repo-creatie of bestandswijzigingen toe met een
read-only token. Daarom gebruikt het playbook voor schrijfacties de
admin-basic-auth uit `forgejo-admin`; alleen ArgoCD krijgt het beperkte token.
Het token wordt niet in de Forgejo-repo of in de Git-historie opgeslagen, maar
in het ArgoCD-secret.

### Idempotentie

- Het repository-secret gebruikt `data:` (base64), niet `stringData:`.
  `kubectl apply` met `stringData` gaf elke run een diff én zette de token
  leesbaar in de `last-applied-configuration`-annotatie.
- Een bestaand token wordt getest tegen de repo-API en hergebruikt als het
  geldig is; alleen bij een ongeldig/ontbrekend token wordt een nieuwe
  aangemaakt.
- De manifests uit `files/gitops/` worden alleen aangepast als de inhoud
  afwijkt (nieuw bestand via `POST`, wijziging via `PUT` met blob-`sha`).
- Na het seeden vraagt het playbook ArgoCD om een harde refresh en wacht het
  tot de Applications op de **nieuwste commit** staan, niet alleen tot ze
  `Synced/Healthy` zijn. Zo wordt een net geüploade wijziging niet gemist.
- Net als bij `forgejo.yml` meldt de Helm-taak elke run `changed`
  (`helm upgrade` verhoogt de release-revisie), ook als er niets wijzigt.

## Toegang tot de ArgoCD-UI

De ArgoCD-server is een ClusterIP-service. Gebruik een port-forward:

```sh
ssh root@192.168.0.137 \
  'kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443'
```

Open daarna <https://192.168.0.137:8080> en log in als `admin`. Het
initiële wachtwoord staat in een Secret:

```sh
ssh root@192.168.0.137 \
  "kubectl -n argocd get secret argocd-initial-admin-secret \
   -o jsonpath='{.data.password}' | base64 -d; echo"
```

Het ArgoCD-certificaat is zelfondertekend; de browser zal een waarschuwing
geven. Wijzig het admin-wachtwoord na de eerste login; de initiële
`argocd-initial-admin-secret` kan daarna verwijderd worden.

## Controleren

### 1. Playbook en pods

```sh
ansible-playbook argocd.yml          # verwacht: alleen Helm-taak changed
ssh root@192.168.0.137 'kubectl -n argocd get pods'
```

Alle ArgoCD-pods moeten `Running` en `1/1` zijn.

### 2. Application en demo-resources

```sh
ssh root@192.168.0.137 \
  'kubectl -n argocd get application root'
ssh root@192.168.0.137 \
  'kubectl -n argocd get application root \
   -o jsonpath="{.status.sync.status}/{.status.health.status}"; echo'
ssh root@192.168.0.137 \
  'kubectl -n argocd-demo get configmap argocd-demo -o yaml'
```

Verwacht: `Synced` en `Healthy`, en een ConfigMap met de labels
`managed-by: argocd` en `source: forgejo`.

### 3. Repository-secret

```sh
ssh root@192.168.0.137 \
  'kubectl -n argocd get secret repo-forgejo \
   -o jsonpath="{.metadata.labels.argocd\.argoproj\.io/secret-type}"; echo'
ssh root@192.168.0.137 \
  'kubectl -n argocd get secret repo-forgejo \
   -o jsonpath="{.data.url}" | base64 -d; echo'
```

Verwacht: `repository` en de in-cluster Git-URL.

### 4. Token werkt (optioneel)

```sh
ssh root@192.168.0.137 '
  tok=$(kubectl -n argocd get secret repo-forgejo -o jsonpath="{.data.password}" | base64 -d)
  kubectl -n forgejo exec deploy/forgejo -- \
    curl -s -o /dev/null -w "%{http_code}\n" \
    -H "Authorization: token $tok" \
    http://127.0.0.1:3000/api/v1/repos/gitea_admin/gitops
'
```

Verwacht: `200`. (Het token heeft alleen `read:repository`; `/api/v1/user`
geeft daarom terecht `403`.)

### 5. UI-login (optioneel)

Vanaf de beheercontainer, met een port-forward naar `localhost:8080`:

```sh
pw=$(kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d)
curl -sk -o /dev/null -w '%{http_code}\n' \
  -X POST -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$pw\"}" \
  https://127.0.0.1:8080/api/v1/session
```

Verwacht: `200`.

## Aandachtspunten

- **Tokenrotatie:** verwijder je het token in Forgejo, dan maakt de volgende
  playbook-run een nieuw token (naam met tijdstempel). Het oude token blijft
  dan als losse vermelding in Forgejo staan; opruimen kan via de webinterface.
- **Admin-wachtwoord:** het playbook wijzigt dit niet. Alleen als de Secret
  niet meer met de database overeenkomt, zet het playbook het wachtwoord terug
  naar de waarde uit `forgejo-admin` (vangnet).
- **Opslag:** de GitOps-repo en ArgoCD-state staan op de node. De Forgejo-data
  staat op `EPHEMERAL` (`/var/local-path-provisioner`) en overleeft dus geen
  Talos-upgrade of herinstallatie. Zie `forgejo-playbook-wijzigingen.md`.
- **Geen eigen ingress:** ArgoCD is, net als Forgejo, alleen via port-forward
  bereikbaar. De nginx-demo gebruikt sinds `traefik.yml` wel Traefik; zie
  `traefik.md`. Voor de ArgoCD-UI zijn nog steeds extra wijzigingen nodig.
- **Forgejo-URL:** de Application gebruikt de in-cluster DNS-naam. Verandert de
  servicenaam of namespace van Forgejo, pas `forgejo_git_url` boven in
  `argocd.yml` aan (en draai het playbook opnieuw).
- **Wachtwoorden in logs:** taken met tokens of adminreferenties gebruiken
  `no_log: true`; draai het playbook niet met `-vvv` als je dat wilt vermijden.

## Bestanden

- `argocd.yml` — installatie en Forgejo-koppeling.
- `roles/tools` — zorgt voor Helm op de beheercontainer.
- `forgejo.yml` — moet eerst gedraaid hebben (Forgejo + admin-Secret).
- `forgejo-controle.md` — controle van Forgejo zelf.
