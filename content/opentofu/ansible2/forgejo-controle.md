# Forgejo controleren

Hoe controleer je of Forgejo goed geïnstalleerd is en draait? Onderstaande
checks lopen van "bestaat de Helm-release" tot "antwoordt de applicatie".

Log eerst in op de beheerscontainer:

```sh
ssh root@192.168.0.137
```

## 1. Is de Helm-release geïnstalleerd?

```sh
helm list -n forgejo
```

Verwacht:

```
NAME     NAMESPACE  REVISION  UPDATED                   STATUS    CHART           APP VERSION
forgejo  forgejo    10        ...                       deployed  forgejo-17.3.1  15.0.10
```

Geen regel = niet geïnstalleerd; draai dan `ansible-playbook forgejo.yml`
(vanaf de control node, in `/usr/src/opentofu/ansible`).

## 2. Draaien de Kubernetes-objecten?

```sh
kubectl -n forgejo get deploy,pods,pvc,svc
```

Gezonde uitvoer:

```
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/forgejo   1/1     1            1           ...

NAME                          READY   STATUS    RESTARTS   AGE
pod/forgejo-...               1/1     Running   0          ...

NAME                                         STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
persistentvolumeclaim/gitea-shared-storage   Bound    pvc-...  10Gi       RWO            local-path

NAME                   TYPE        CLUSTER-IP      PORT(S)
service/forgejo-http   ClusterIP   ...             3000/TCP
service/forgejo-ssh    ClusterIP   ...             22/TCP
```

Let op:

- de pod moet `Running` **en** `1/1 READY` zijn;
- de PVC moet `Bound` zijn — anders wacht de pod op opslag;
- `forgejo-http` (3000) is de webinterface, `forgejo-ssh` (22) is Git-over-SSH.

## 3. Antwoordt de applicatie zelf?

```sh
kubectl -n forgejo exec deploy/forgejo -- wget -qO- http://127.0.0.1:3000/api/v1/version
```

Verwacht:

```json
{"version":"15.0.10+gitea-1.22.0"}
```

Dit is de sterkste check: het proces draait, de HTTP-server luistert én de
database werkt.

## 4. De webinterface openen

De service is `ClusterIP`, dus lokaal port-forwarden:

```sh
kubectl -n forgejo port-forward --address 0.0.0.0 svc/forgejo-http 3000:3000
```

Daarna in de browser: `http://192.168.0.137:3000`.

De eerste geregistreerde gebruiker wordt admin (de chart maakt standaard geen
admin-secret aan).

## 5. Als iets niet klopt

```sh
kubectl -n forgejo rollout status deploy/forgejo        # wacht op/rapporteert uitrol
kubectl -n forgejo logs deploy/forgejo --tail=30        # applicatiefouten
kubectl -n forgejo describe pod -l app.kubernetes.io/name=forgejo | tail -20
kubectl -n forgejo get events --sort-by=.lastTimestamp | tail -10
```

Veelvoorkomende signalen:

| Symptoom | Betekenis / actie |
| --- | --- |
| `helm list` leeg | Niet geïnstalleerd → `ansible-playbook forgejo.yml`. |
| Pod `Pending`, PVC `Pending` | Opslagprobleem (StorageClass/provisioner) → controleer `kubectl -n local-path-storage get pods` en `kubectl get sc`. |
| `CrashLoopBackOff` | Applicatiefout → `kubectl -n forgejo logs`. |
| `ImagePullBackOff` | Image niet op te halen → controleer netwerk/registry. |
| `0/1` READY maar wel `Running` | Readiness-probe faalt → logs en `describe pod`. |

## 6. Alles in één keer vanaf de control node

Zonder in te loggen op de container:

```sh
cd /usr/src/opentofu/ansible
ansible k8s-management -m shell -a 'helm list -n forgejo; kubectl -n forgejo get pods,pvc'
```

Of de volledige controle:

```sh
ansible k8s-management -m shell -a '
  helm list -n forgejo;
  kubectl -n forgejo get deploy,pods,pvc,svc;
  kubectl -n forgejo exec deploy/forgejo -- wget -qO- http://127.0.0.1:3000/api/v1/version
'
```

## Status bij laatste controle (2026-10-26)

| Check | Resultaat |
| --- | --- |
| Helm-release | `forgejo`, status `deployed`, chart `forgejo-17.3.1`, app `15.0.10` |
| Deployment | `1/1` beschikbaar |
| Pod | `forgejo-...`, `Running`, `1/1 READY`, 0 restarts |
| PVC | `gitea-shared-storage`, `Bound`, 10Gi, `local-path` |
| Services | `forgejo-http` (3000/TCP), `forgejo-ssh` (22/TCP), beide `ClusterIP` |
| API | `{"version":"15.0.10+gitea-1.22.0"}` |

Conclusie: Forgejo is geïnstalleerd en operationeel.
