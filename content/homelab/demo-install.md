---
title: 'demo-install'
weight: 2000
draft: false
---




helmfile -e demo sync -f helmfile.yaml.gotmpl
Listing releases matching ^gateway$
Building dependency release=keycloak-keycloak, chart=charts/keycloak
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 2 charts
Deleting outdated charts

Building dependency release=keycloak-postgresql, chart=../common/charts/postgresql
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Listing releases matching ^keycloak-cluster-credentials$
Listing releases matching ^keycloak-cluster$
Upgrading release=keycloak-postgresql, chart=../common/charts/postgresql, namespace=
Release "keycloak-postgresql" does not exist. Installing it now.
NAME: keycloak-postgresql
LAST DEPLOYED: Wed Apr 29 13:00:31 2026
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: postgresql
CHART VERSION: 16.7.18
APP VERSION: 17.5.0

** Please be patient while the chart is being deployed **

PostgreSQL can be accessed via port 5432 on the following DNS names from within your cluster:

    keycloak-cluster-rw.default.svc.cluster.local - Read/Write connection

To get the password for "postgres" run:

    export POSTGRES_ADMIN_PASSWORD=$(kubectl get secret --namespace default keycloak-cluster-rw -o jsonpath="{.data.postgres-password}" | base64 -d)

To get the password for "keycloak" run:

    export POSTGRES_PASSWORD=$(kubectl get secret --namespace default keycloak-cluster-rw -o jsonpath="{.data.password}" | base64 -d)

To connect to your database run the following command:

    kubectl run keycloak-cluster-rw-client --rm --tty -i --restart='Never' --namespace default --image registry-1.docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r4 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
      --command -- psql --host keycloak-cluster-rw -U keycloak -d keycloak -p 5432

    > NOTE: If you access the container using bash, make sure that you execute "/opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash" in order to avoid the error "psql: local user with ID 1001} does not exist"

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace default svc/keycloak-cluster-rw 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U keycloak -d keycloak -p 5432

WARNING: The configured password will be ignored on new installation in case when previous PostgreSQL release was deleted through the helm command. In that case, old PVC will have an old password, and setting it through helm won't take effect. Deleting persistent volumes (PVs) will solve the issue.

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - primary.resources
  - readReplicas.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^keycloak-postgresql$
keycloak-postgresql	default  	1       	2026-04-29 13:00:31.776432612 +0000 UTC	deployed	postgresql-16.7.18	17.5.0     

Upgrading release=keycloak-keycloak, chart=charts/keycloak, namespace=
Release "keycloak-keycloak" has been upgraded. Happy Helming!
NAME: keycloak-keycloak
LAST DEPLOYED: Wed Apr 29 13:00:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 11
TEST SUITE: None
NOTES:
CHART NAME: keycloak
CHART VERSION: 25.2.0
APP VERSION: 26.3.3

⚠ WARNING: Since August 28th, 2025, only a limited subset of images/charts are available for free.
    Subscribe to Bitnami Secure Images to receive continued support and security updates.
    More info at https://bitnami.com and https://github.com/bitnami/containers/issues/83267

** Please be patient while the chart is being deployed **

Keycloak can be accessed through the following DNS name from within your cluster:

    keycloak-keycloak.default.svc.cluster.local (port 80)

To access Keycloak from outside the cluster execute the following commands:

1. Get the Keycloak URL and associate its hostname to your cluster external IP:

   export CLUSTER_IP=$(minikube ip) # On Minikube. Use: `kubectl cluster-info` on others K8s clusters
   echo "Keycloak URL: https://id.kubernetes.local/"
   echo "$CLUSTER_IP  id.kubernetes.local" | sudo tee -a /etc/hosts

2. Access Keycloak using the obtained URL.
3. Access the Administration Console using the following credentials:

  echo Username: admin
  echo Password: $(kubectl get secret --namespace default keycloak-keycloak -o jsonpath="{.data.admin-password}" | base64 -d)

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - keycloakConfigCli.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^keycloak-keycloak$
keycloak-keycloak	default  	11      	2026-04-29 13:00:34.361183107 +0000 UTC	deployed	keycloak-25.2.0	26.3.3     


UPDATED RELEASES:
NAME                  NAMESPACE   CHART                         VERSION   DURATION
keycloak-postgresql               ../common/charts/postgresql   16.7.18         2s
keycloak-keycloak                 charts/keycloak               25.2.0         38s

Building dependency release=nextcloud-postgresql, chart=../common/charts/postgresql
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Building dependency release=nextcloud, chart=charts/nextcloud
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Building dependency release=nextcloud-redis, chart=../common/charts/redis
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Building dependency release=nextcloud-minio, chart=../common/charts/minio
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Listing releases matching ^nextcloud-cluster-credentials$
Listing releases matching ^nextcloud-cluster$
Upgrading release=nextcloud-postgresql, chart=../common/charts/postgresql, namespace=
Upgrading release=nextcloud-redis, chart=../common/charts/redis, namespace=
Upgrading release=nextcloud-minio, chart=../common/charts/minio, namespace=
Release "nextcloud-postgresql" has been upgraded. Happy Helming!
NAME: nextcloud-postgresql
LAST DEPLOYED: Wed Apr 29 13:01:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 10
TEST SUITE: None
NOTES:
CHART NAME: postgresql
CHART VERSION: 16.7.18
APP VERSION: 17.5.0

** Please be patient while the chart is being deployed **

PostgreSQL can be accessed via port 5432 on the following DNS names from within your cluster:

    nextcloud-cluster-rw.default.svc.cluster.local - Read/Write connection

To get the password for "postgres" run:

    export POSTGRES_ADMIN_PASSWORD=$(kubectl get secret --namespace default nextcloud-cluster-rw -o jsonpath="{.data.postgres-password}" | base64 -d)

To get the password for "nextcloud" run:

    export POSTGRES_PASSWORD=$(kubectl get secret --namespace default nextcloud-cluster-rw -o jsonpath="{.data.password}" | base64 -d)

To connect to your database run the following command:

    kubectl run nextcloud-cluster-rw-client --rm --tty -i --restart='Never' --namespace default --image registry-1.docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r4 --env="PGPASSWORD=$POSTGRES_PASSWORD" \
      --command -- psql --host nextcloud-cluster-rw -U nextcloud -d nextcloud -p 5432

    > NOTE: If you access the container using bash, make sure that you execute "/opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash" in order to avoid the error "psql: local user with ID 1001} does not exist"

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace default svc/nextcloud-cluster-rw 5432:5432 &
    PGPASSWORD="$POSTGRES_PASSWORD" psql --host 127.0.0.1 -U nextcloud -d nextcloud -p 5432

WARNING: The configured password will be ignored on new installation in case when previous PostgreSQL release was deleted through the helm command. In that case, old PVC will have an old password, and setting it through helm won't take effect. Deleting persistent volumes (PVs) will solve the issue.

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - primary.resources
  - readReplicas.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^nextcloud-postgresql$
Release "nextcloud-redis" has been upgraded. Happy Helming!
NAME: nextcloud-redis
LAST DEPLOYED: Wed Apr 29 13:01:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 10
TEST SUITE: None
NOTES:
CHART NAME: redis
CHART VERSION: 21.2.6
APP VERSION: 8.0.2

** Please be patient while the chart is being deployed **

Redis&reg; can be accessed via port 6379 on the following DNS name from within your cluster:

    nextcloud-redis-master.default.svc.cluster.local



To get your password run:

    export REDIS_PASSWORD=$(kubectl get secret --namespace default nextcloud-redis -o jsonpath="{.data.redis-password}" | base64 -d)

To connect to your Redis&reg; server:

1. Run a Redis&reg; pod that you can use as a client:

   kubectl run --namespace default redis-client --restart='Never'  --env REDIS_PASSWORD=$REDIS_PASSWORD  --image registry-1.docker.io/bitnamilegacy/redis:8.2.1-debian-12-r0 --command -- sleep infinity

   Use the following command to attach to the pod:

   kubectl exec --tty -i redis-client \--labels="nextcloud-redis-client=true" \
   --namespace default -- bash

2. Connect using the Redis&reg; CLI:
   REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h nextcloud-redis-master

Note: Since NetworkPolicy is enabled, only pods with label nextcloud-redis-client=true" will be able to connect to redis.

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - replica.resources
  - master.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^nextcloud-redis$
nextcloud-postgresql	default  	10      	2026-04-29 13:01:34.825518401 +0000 UTC	deployed	postgresql-16.7.18	17.5.0     

nextcloud-redis	default  	10      	2026-04-29 13:01:34.962913836 +0000 UTC	deployed	redis-21.2.6	8.0.2      

Release "nextcloud-minio" has been upgraded. Happy Helming!
NAME: nextcloud-minio
LAST DEPLOYED: Wed Apr 29 13:01:34 2026
NAMESPACE: default
STATUS: deployed
REVISION: 10
TEST SUITE: None
NOTES:
CHART NAME: minio
CHART VERSION: 17.0.11
APP VERSION: 2025.6.13

** Please be patient while the chart is being deployed **

Minio(R) can be accessed via port 9000 on the following DNS name from within your cluster:

   nextcloud-minio.default.svc.cluster.local

To get your credentials run:

   export ROOT_USER=$(kubectl get secret --namespace default nextcloud-minio -o jsonpath="{.data.root-user}" | base64 -d)
   export ROOT_PASSWORD=$(kubectl get secret --namespace default nextcloud-minio -o jsonpath="{.data.root-password}" | base64 -d)

To connect to your Minio(R) server using a client:

- Run a Minio(R) Client pod and append the desired command (e.g. 'admin info'):

   kubectl run --namespace default nextcloud-minio-client \
     --rm --tty -i --restart='Never' \
     --env MINIO_SERVER_ROOT_USER=$ROOT_USER \
     --env MINIO_SERVER_ROOT_PASSWORD=$ROOT_PASSWORD \
     --env MINIO_SERVER_HOST=nextcloud-minio \
     --labels="nextcloud-minio-client=true" \
     --image registry-1.docker.io/bitnami/minio-client:2025.7.16-debian-12-r0 -- admin info minio

   NOTE: Since NetworkPolicy is enabled, only pods with label
   "nextcloud-minio-client=true" will be able to connect to Minio(R).

To access the Minio(R) Console:

- Get the Minio(R) Console URL:

   echo "Minio(R) Console URL: http://127.0.0.1:9090"
   kubectl port-forward --namespace default svc/nextcloud-minio-console 9090:9090

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - resources
  - console.resources
  - provisioning.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^nextcloud-minio$
nextcloud-minio	default  	10      	2026-04-29 13:01:34.753667349 +0000 UTC	deployed	minio-17.0.11	2025.6.13  

Upgrading release=nextcloud, chart=charts/nextcloud, namespace=
Release "nextcloud" has been upgraded. Happy Helming!
NAME: nextcloud
LAST DEPLOYED: Wed Apr 29 13:01:51 2026
NAMESPACE: default
STATUS: deployed
REVISION: 8
TEST SUITE: None
NOTES:
CHART NAME: nextcloud
CHART VERSION: 0.1.0
APP VERSION: 33.0.0

** Please be patient while the chart is being deployed **

%%Instructions to access the application depending on the serviceType and other considerations%%

Listing releases matching ^nextcloud$
nextcloud	default  	8       	2026-04-29 13:01:51.584022814 +0000 UTC	deployed	nextcloud-0.1.0	33.0.0     


UPDATED RELEASES:
NAME                   NAMESPACE   CHART                         VERSION   DURATION
nextcloud-postgresql               ../common/charts/postgresql   16.7.18         3s
nextcloud-redis                    ../common/charts/redis        21.2.6          4s
nextcloud-minio                    ../common/charts/minio        17.0.11        17s
nextcloud                          charts/nextcloud              0.1.0           3s

Listing releases matching ^drive-postgresql$
Listing releases matching ^drive-cluster-credentials$
Listing releases matching ^drive-redis$
Listing releases matching ^drive-minio$
Listing releases matching ^drive-static$
Listing releases matching ^drive-cluster$
Listing releases matching ^drive-nginx$
Building dependency release=bureaublad, chart=charts/bureaublad
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Building dependency release=bureaublad-redis, chart=../common/charts/redis
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "openproject" chart repository
Update Complete. ⎈Happy Helming!⎈
Saving 1 charts
Deleting outdated charts

Upgrading release=bureaublad-redis, chart=../common/charts/redis, namespace=
Release "bureaublad-redis" has been upgraded. Happy Helming!
NAME: bureaublad-redis
LAST DEPLOYED: Wed Apr 29 13:02:42 2026
NAMESPACE: default
STATUS: deployed
REVISION: 8
TEST SUITE: None
NOTES:
CHART NAME: redis
CHART VERSION: 21.2.6
APP VERSION: 8.0.2

** Please be patient while the chart is being deployed **

Redis&reg; can be accessed via port 6379 on the following DNS name from within your cluster:

    bureaublad-redis-master.default.svc.cluster.local



To get your password run:

    export REDIS_PASSWORD=$(kubectl get secret --namespace default bureaublad-redis -o jsonpath="{.data.redis-password}" | base64 -d)

To connect to your Redis&reg; server:

1. Run a Redis&reg; pod that you can use as a client:

   kubectl run --namespace default redis-client --restart='Never'  --env REDIS_PASSWORD=$REDIS_PASSWORD  --image registry-1.docker.io/bitnamilegacy/redis:8.2.1-debian-12-r0 --command -- sleep infinity

   Use the following command to attach to the pod:

   kubectl exec --tty -i redis-client \--labels="bureaublad-redis-client=true" \
   --namespace default -- bash

2. Connect using the Redis&reg; CLI:
   REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli -h bureaublad-redis-master

Note: Since NetworkPolicy is enabled, only pods with label bureaublad-redis-client=true" will be able to connect to redis.

WARNING: There are "resources" sections in the chart not set. Using "resourcesPreset" is not recommended for production. For production installations, please set the following values according to your workload needs:
  - replica.resources
  - master.resources
+info https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

Listing releases matching ^bureaublad-redis$
bureaublad-redis	default  	8       	2026-04-29 13:02:42.745623754 +0000 UTC	deployed	redis-21.2.6	8.0.2      

Upgrading release=bureaublad, chart=charts/bureaublad, namespace=
Release "bureaublad" has been upgraded. Happy Helming!
NAME: bureaublad
LAST DEPLOYED: Wed Apr 29 13:02:45 2026
NAMESPACE: default
STATUS: deployed
REVISION: 9
TEST SUITE: None

Listing releases matching ^bureaublad$
bureaublad	default  	9       	2026-04-29 13:02:45.961959584 +0000 UTC	deployed	bureaublad-0.2.0	0.9.3      


UPDATED RELEASES:
NAME               NAMESPACE   CHART                    VERSION   DURATION
bureaublad-redis               ../common/charts/redis   21.2.6          3s
bureaublad                     charts/bureaublad        0.2.0           3s


[root@nixos:/home/nixie/mijn-bureau-in
