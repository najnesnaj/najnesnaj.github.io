# Wijzigingen Forgejo-playbook

Datum: 2026-10-26
Aanleiding: `ansible-playbook forgejo.yml` faalde achtereenvolgens op de
playbook-structuur, een ontbrekende `helm`-binary, een niet-bestaande
chart-URL en een cluster zonder StorageClass.

Eindresultaat: Forgejo draait op de Talos-cluster.

| Onderdeel | Waarde |
| --- | --- |
| Helm-release | `forgejo` in namespace `forgejo`, status `deployed` |
| Chart | `forgejo-17.3.1` (app `15.0.10`) |
| OCI-chart | `oci://code.forgejo.org/forgejo-helm/forgejo` |
| Opslag | PVC `gitea-shared-storage`, `Bound`, 10Gi, `local-path` |
| Pod | `1/1 Running` op `talos-node-3` |
| API-check | `GET /api/v1/version` → `{"version":"15.0.10+gitea-1.22.0"}` |
| helm op de container | `v4.3.1` |
| local-path-provisioner | `v0.0.37` |

## 1. Playbook-structuur (`forgejo.yml`)

**Probleem**

```
[ERROR]: 'ansible.builtin.command' is not a valid attribute for a Play
```

De file bevatte een losse takenlijst. Een playbook moet een lijst van *plays*
zijn; elke play heeft `hosts:` en een `tasks:`-blok.

**Oplossing**

De taken zijn ondergebracht in een play op `k8s_management` met
`become: true` en `gather_facts: false`, plus `environment.KUBECONFIG` op
play-niveau zodat alle taken en rollen dezelfde kubeconfig gebruiken.

## 2. Ontbrekende `helm`-binary (`roles/tools`)

**Probleem**

```
Module failed: Error executing command: [Errno 2] No such file or directory: b'helm'
```

`helm` werd nergens geïnstalleerd; de `tools`-rol deed alleen `talosctl` en
`kubectl`.

**Oplossing — `roles/tools/tasks/main.yml`**

Nieuwe sectie `# --- helm ---` die dezelfde aanpak volgt als `kubectl`:

- nieuwste stabiele versie via GitHub API
  (`https://api.github.com/repos/helm/helm/releases/latest`);
- `stat` + `helm version --short` om de geïnstalleerde versie te bepalen;
- alleen (her)installeren als `helm` ontbreekt of de versie afwijkt;
- download `https://get.helm.sh/helm-v<versie>-linux-<arch>.tar.gz`,
  uitpakken in een tijdelijke map, binary naar `/usr/local/bin/helm`
  (`0755`), daarna opruimen;
- bash-completion in `/etc/bash_completion.d/helm`.

**Oplossing — versie-variabele**

- `group_vars/all.yml`: `helm_version: ""` (leeg = nieuwste stabiel).
- `roles/tools/defaults/main.yml`: fallback `helm_version: ""`.

`forgejo.yml` neemt de `tools`-rol op, zodat een losse run `helm` zelf
installeert.

## 3. Chart-URL bestaat niet (`forgejo.yml`)

**Probleem**

```
helm repo add code-repo https://code.forgejo.org/charts
→ failed to fetch https://code.forgejo.org/charts/index.yaml : 404 Not Found
```

De URL uit het oorspronkelijke playbook is geen chart-repository (meer).
Forgejo publiceert de chart als OCI-artefact.

**Oplossing**

- `helm repo add`-taak verwijderd; geen repo meer nodig.
- Installeren direct vanaf OCI:

  ```yaml
  forgejo_chart: oci://code.forgejo.org/forgejo-helm/forgejo
  ```

- Chartversie optioneel pinbaar met `forgejo_chart_version` (leeg = nieuwste);
  bij een waarde wordt `--version` toegevoegd.

Gecontroleerd: `helm show chart` en `helm template` leveren chart 17.3.1 met
een PVC van 10Gi.

## 4. Geen StorageClass (nieuwe rol `local_path_storage`)

**Probleem**

```
pvc/gitea-shared-storage   Pending   <geen storageclass>
pod/forgejo-...            Pending   unbound immediate PersistentVolumeClaims
```

De cluster heeft één node (`talos-node-3`) en geen dynamische provisioner.

**Oplossing — nieuwe rol `roles/local_path_storage`**

`defaults/main.yml`:

```yaml
local_path_provisioner_version: v0.0.37
local_path_provisioner_namespace: local-path-storage
local_path_storage_class: local-path
local_path_provisioner_data_dir: /var/local-path-provisioner
local_path_provisioner_tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
```

`tasks/main.yml` (idempotent):

1. controleert of StorageClass `local-path` bestaat;
2. installeert zo nodig de upstream-manifest
   (`.../local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml`);
3. zet `pod-security.kubernetes.io/enforce=privileged` op de namespace
   `local-path-storage`;
4. patcht `config.json` van de `local-path-config`-ConfigMap naar
   `/var/local-path-provisioner` (alleen als dat pad nog niet is ingesteld) en
   herstart de deployment;
5. voegt tolerations voor de control-plane-taint toe (alleen als ze ontbreken);
6. wacht met `kubectl rollout status` tot de provisioner gereed is.

### Waarom deze twee extra stappen nodig waren

- **Taint:** de enige node is een control-plane met
  `node-role.kubernetes.io/control-plane:NoSchedule`. De upstream-manifest
  bevat geen tolerations, dus de provisioner bleef `Pending`.
- **PodSecurity:** Talos handhaaft `baseline` in namespaces zonder label. De
  helper-pods van local-path gebruiken een `hostPath`-volume en worden in de
  namespace van de provisioner (`local-path-storage`) aangemaakt:

  ```
  pods "helper-pod-create-pvc-..." is forbidden:
  violates PodSecurity "baseline:latest": hostPath volumes (volume "data")
  ```

  Daarom krijgt alleen `local-path-storage` het label `privileged`; de
  `forgejo`-namespace blijft op `baseline`.

## 5. PVC met afwijkende storageClass (`forgejo.yml`)

`spec.storageClassName` is immutabel. De eerste PVC was aangemaakt zonder
storageClass en kon dus niet naar `local-path` worden omgezet.

**Oplossing**

- `forgejo.yml` leest de bestaande PVC als JSON.
- Alleen als de PVC bestaat, `Pending` is (dus geen data) én een andere
  storageClass heeft, wordt hij verwijderd; Helm maakt hem daarna opnieuw aan
  met `--set persistence.storageClass=local-path`.

## 6. Forgejo-waarden (`forgejo.yml`)

Naast opslag en tolerantie zijn de volgende variabelen toegevoegd:

```yaml
forgejo_namespace: forgejo
forgejo_chart: oci://code.forgejo.org/forgejo-helm/forgejo
forgejo_chart_version: ""           # leeg = nieuwste
forgejo_storage_size: 10Gi
forgejo_storage_class: local-path
forgejo_pvc_name: gitea-shared-storage
forgejo_kubeconfig: /root/.kube/config
```

De install-taak:

```sh
helm upgrade --install forgejo oci://code.forgejo.org/forgejo-helm/forgejo \
  --namespace forgejo --create-namespace \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=local-path \
  --set-json 'tolerations=[
    {"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"},
    {"key":"node-role.kubernetes.io/master","operator":"Exists","effect":"NoSchedule"}
  ]'
```

Verder:

- een assert met duidelijke melding als `/root/.kube/config` ontbreekt
  (wijst naar `ansible-playbook site.yml`);
- de namespace wordt expliciet aangemaakt (idempotent, `AlreadyExists` is ok);
- overrides per run:

  ```sh
  ansible-playbook forgejo.yml \
    -e forgejo_chart_version=17.3.1 -e forgejo_storage_size=20Gi
  ```

## 7. Documentatie (`README.md`)

- `tools`-rol: nu ook `helm` + helm-completion.
- Nieuwe rol `local_path_storage` in de rollentabel en de layout-boom.
- Nieuwe paragraaf **Deploying Forgejo**: OCI-chart, inbegrepen rollen,
  storage/tolerations/PodSecurity, override-variabelen en de opslag-caveat.
- Variabele `helm_version` toegevoegd aan de variabeletabel.
- Verificatiecommando uitgebreid met `helm version --short`.
- Layout aangevuld met `forgejo.yml` en `roles/local_path_storage`.

## 8. Idempotentie en valkuilen

- Een tweede run geeft alleen `Installeer Forgejo in Kubernetes` als
  `changed`; Helm maakt bij elke run een nieuwe revisie aan (tijdens de
  tests opgelopen tot `revision 10`). Alle andere taken zijn `ok`/`skipped`.
- Opgeloste idempotentiebugs tijdens het testen:
  - `set_fact` met een gequote Jinja-expressie levert de string `"False"`
    (truthy) op; vervangen door een directe `when`-conditie.
  - `jsonpath={.data.config\.json}`: de `command`-module strips de backslash,
    waardoor de read leeg terugkwam; nu JSON parsen met `from_json` in plaats
    van jsonpath met escapes.
- De `forgejo`-namespace is **niet** privileged gemaakt; alleen
  `local-path-storage` heeft dat label nodig.

## 9. Openstaande punten / caveats

- **Opslag is niet permanent bij een Talos-upgrade.** De data staat op
  `/var/local-path-provisioner` op de `EPHEMERAL`-partitie. De scsi1-datadisk
  uit `talos.tf` is op deze node niet gemount (`/var/mnt/storage` bestaat
  niet). Voor blijvende opslag: mount de datadisk en zet
  `local_path_provisioner_data_dir: /var/mnt/storage/local-path-provisioner`.
- **Geen ingress.** `forgejo-http` en `forgejo-ssh` zijn `ClusterIP`; extern
  bereikbaar via port-forward:

  ```sh
  ssh root@192.168.0.137 \
    'kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000'
  ```

  Daarna `http://192.168.0.137:3000`; de eerste geregistreerde gebruiker
  wordt admin (de chart maakt standaard geen admin-secret aan).
- **`helm upgrade` is altijd `changed`.** Geen no-op-detectie; acceptabel voor
  deze playbook-opzet.

## 10. Gewijzigde bestanden

| Bestand | Wijziging |
| --- | --- |
| `forgejo.yml` | Herstructureerd naar play; OCI-chart; storageClass, tolerations, kubeconfig-check, namespace, PVC-cleanup, variabelen. |
| `roles/tools/tasks/main.yml` | Helm-sectie toegevoegd. |
| `roles/tools/defaults/main.yml` | `helm_version` fallback. |
| `group_vars/all.yml` | `helm_version: ""`. |
| `roles/local_path_storage/defaults/main.yml` | Nieuw: versie, namespace, class, data-pad, tolerations. |
| `roles/local_path_storage/tasks/main.yml` | Nieuw: installatie + configuratie provisioner. |
| `README.md` | Rol, layout, Forgejo-paragraaf, variabele, verificatie. |
| `forgejo-playbook-wijzigingen.md` | Dit document. |

## 11. Verificatiecommando's

```sh
cd /usr/src/opentofu/ansible
ansible-playbook --syntax-check forgejo.yml
ansible-playbook forgejo.yml

ssh root@192.168.0.137 '
  helm version --short
  helm list -n forgejo
  kubectl -n forgejo get pvc,pods,svc
  kubectl -n local-path-storage get pods
  kubectl -n forgejo exec deploy/forgejo -- wget -qO- http://127.0.0.1:3000/api/v1/version
'
```
