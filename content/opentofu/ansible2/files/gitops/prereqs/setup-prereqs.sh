#!/bin/bash
set -euo pipefail
export KUBECONFIG=/root/.kube/config
cd /root/office-install
set -a
. ./credentials.env
set +a

kubectl -n euro-office create secret generic postgres-credentials \
  --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  --from-literal=EUROOFFICE_DB_PASSWORD="$EUROOFFICE_DB_PASSWORD" \
  --from-literal=NEXTCLOUD_DB_PASSWORD="$NEXTCLOUD_DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n euro-office create secret generic eurooffice-db \
  --from-literal=password="$EUROOFFICE_DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n euro-office create secret generic redis \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n euro-office create secret generic rabbitmq \
  --from-literal=rabbitmq-password="$RABBITMQ_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n euro-office create secret generic euro-office-jwt \
  --from-literal=JWT_SECRET="$JWT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n nextcloud create secret generic nextcloud-db \
  --from-literal=username=nextcloud \
  --from-literal=password="$NEXTCLOUD_DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n nextcloud create secret generic nextcloud-admin \
  --from-literal=username=admin \
  --from-literal=password="$NEXTCLOUD_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f prereqs-postgres.yaml
kubectl apply -f prereqs-redis.yaml
kubectl apply -f prereqs-rabbitmq.yaml

kubectl -n euro-office rollout status deploy/postgres --timeout=240s
kubectl -n euro-office rollout status deploy/redis --timeout=120s
kubectl -n euro-office rollout status deploy/rabbitmq --timeout=240s

kubectl -n euro-office get pods,pvc,svc
