---
title: 'Local Repository'
weight: 630
draft: false
---

# Steps to Serve the Local Image on the Kubernetes Registry

I’m using several local machines. To avoid pulling the image from Docker Hub every time, I set up a local registry. This allows me to push the image to the local registry and pull it from there.
This is especially useful for testing and development purposes.
This guide outlines the steps to push a local Docker image to a local Kubernetes registry and ensure it can be accessed by your Kubernetes cluster.

## 1. Verify the Local Image

Check that the image exists locally:

```bash
docker images | grep postgres
```

- Expected output:
  ```bash
  postgres    latest    c5df8b5c321e   ...   ...
  ```
- If it’s not there, pull it:
  ```bash
  docker pull postgres:latest
  ```

## 2. Confirm the Registry Service

Ensure your `registryExternal` service is running and accessible:

```bash
microk8s kubectl get svc -n <namespace>
```

- Look for `registryExternal` with `5000:32000/TCP`.
- Get the node’s IP (e.g., `192.168.0.103`):
  ```bash
  microk8s kubectl get nodes -o wide
  ```
- Test connectivity:

```bash
    curl -v http://192.168.0.103:32000/v2/

- Should return ``200 OK`` with ``{}`` if the registry is up.
```

## 3. Tag the Local Image

Re-tag `postgres:latest` to match your registry’s address:

```bash
docker tag postgres:latest 192.168.0.103:32000/postgres:latest
```

- Optionally, use a different name (e.g., for your app):

```bash
docker tag postgres:latest 192.168.0.103:32000/nosql_ana_report:latest
```

- Verify:

```bash
docker images | grep 192.168.0.103
```

## 4. Push the Image to the Registry

Since `192.168.0.103:32000` is HTTP, configure Docker to allow an insecure registry:

- Edit `/etc/docker/daemon.json`:

```json
{
    "insecure-registries": ["192.168.0.103:32000"]
}
```

- Restart Docker:

```bash
sudo systemctl restart docker
```

- Push the image:

```bash
    docker push 192.168.0.103:32000/postgres:latest

- Or, if re-tagged as ``nosql_ana_report``:
```

```bash
docker push 192.168.0.103:32000/nosql_ana_report:latest
```

## 5. Verify the Image in the Registry

Check that it’s available:

```bash
curl -v http://192.168.0.103:32000/v2/postgres/tags/list
```

- Expected:

```json
{"name": "postgres", "tags": ["latest"]}
```

## 6. Update Helm Chart (if Needed)

If you pushed as `192.168.0.103:32000/postgres:latest` but your chart expects `nosql_ana_report`, update `values.yaml`:

```yaml
anaReport:
  image:
    repository: 192.168.0.103:32000/postgres  # Or keep as nosql_ana_report if re-tagged
    tag: latest
  replicaCount: 1
```

- Redeploy:

```bash
microk8s helm uninstall my-report -n default
microk8s helm install my-report ./my-helm-0.1.0.tgz -n default
```

## 7. Ensure MicroK8s Can Pull It

Since MicroK8s uses `containerd`, configure it for the insecure registry:

- Edit `/var/snap/microk8s/current/args/containerd-template.toml`:

```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."192.168.0.103:32000"]
    endpoint = ["http://192.168.0.103:32000"]
```

- Restart:

```bash
microk8s stop
microk8s start
```
