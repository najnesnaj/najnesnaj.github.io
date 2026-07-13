destroy verwijdert niet alles

kubectl delete pvc data-nextcloud-cluster-rw-0 nextcloud-minio redis-data-nextcloud-redis-master-0


dit duurt enorm lang (blijft hangen)

(afschieten pods)

helmfile -e demo apply --selector name=nextcloud

