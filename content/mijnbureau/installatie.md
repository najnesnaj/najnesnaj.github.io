
helmfile -e demo sync (De "forceer" optie)Dit commando dwingt een volledige synchronisatie af, ongeacht de huidige status van het cluster.

helmfile -e demo apply (Aanbevolen voor dagelijks gebruik)

1 module sync 

helmfile -e demo sync --selector name=keycloak

selectief alles verwijderen van 1 module

helmfile -e demo destroy --selector name=keycloak-keycloak



persistant volume
------------------
kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                          STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-09eb4e06-d07c-4248-bac4-8862ad5bd3d4   1Gi        RWO            Delete           Bound    default/redis-data-meet-redis-master-0         local-path     <unset>                          19d
pvc-39a8ea06-8a41-4bb7-9405-acfd927ba2a8   1Gi        RWO            Delete           Bound    default/data-element-cluster-rw-0              local-path     <unset>                          19d
pvc-3ed6dbc6-c667-4291-906d-d3d0ed271a48   1Gi        RWO            Delete           Bound    default/data-meet-cluster-rw-0                 local-path     <unset>                          19d
pvc-49185773-204f-471a-bf48-3c6293ffddc8   10Gi       RWO            Delete           Bound    default/data-nextcloud-cluster-rw-0            local-path     <unset>                          19d


keycloak
----------
 Access the Administration Console using the following credentials:

  echo Username: admin
  echo Password: $(kubectl get secret --namespace default keycloak-keycloak -o jsonpath="{.data.admin-password}" | base64 -d)

Listing releases matching ^keycloak-keycloak$



