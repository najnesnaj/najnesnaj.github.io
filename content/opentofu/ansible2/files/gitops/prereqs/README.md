# Prerequisite services

These manifests create the PostgreSQL, Redis and RabbitMQ instances that the
Euro-Office and Nextcloud charts expect. They are applied **manually** before
Argo CD syncs the application charts; they are not part of the Argo CD root
Application (which only watches `apps/`).

See [`../../../installation-steps.md`](../../../installation-steps.md) for the
full installation record, including the NFS provisioner and the Argo CD
Applications.

## Usage

1. Create the namespaces and the NFS provisioner as described in
   `installation-steps.md` sections 2 and 3.
2. Create `credentials.env` next to this README (never commit it):

   ```bash
   umask 077
   {
     echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
     echo "EUROOFFICE_DB_PASSWORD=$(openssl rand -hex 16)"
     echo "NEXTCLOUD_DB_PASSWORD=$(openssl rand -hex 16)"
     echo "REDIS_PASSWORD=$(openssl rand -hex 16)"
     echo "RABBITMQ_PASSWORD=$(openssl rand -hex 16)"
     echo "JWT_SECRET=$(openssl rand -hex 32)"
     echo "NEXTCLOUD_ADMIN_PASSWORD=$(openssl rand -hex 16)"
   } > credentials.env
   ```

3. Apply the secrets and services:

   ```bash
   bash setup-prereqs.sh
   ```

`setup-prereqs.sh` creates the Kubernetes Secrets, applies the three
manifests, and waits for the Deployments. It expects `credentials.env` in the
current directory.

## Notes

* PostgreSQL creates both the `eurooffice` and `nextcloud` databases and
  roles on first start.
* The Redis Service is named `redis-master` because that is the name the
  Euro-Office chart expects.
* RabbitMQ's readiness probe uses `timeoutSeconds: 15`; the default 1 second
  is too short for `rabbitmq-diagnostics -q ping`.
