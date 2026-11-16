# Forgejo update: HTTP service exposed as NodePort

## Modification

Updated [`forgejo.yml`](./forgejo.yml) to expose Forgejo's HTTP service via a fixed Kubernetes `NodePort` instead of the default `ClusterIP`.

```diff
         --set persistence.size={{ forgejo_storage_size }}
         --set persistence.storageClass={{ forgejo_storage_class }}
         --set-json 'tolerations={{ forgejo_tolerations | to_json }}'
+        --set service.http.type=NodePort
+        --set service.http.nodePort=30000
```

- **Service:** `forgejo-http`
- **Type:** `NodePort`
- **Ports:** `3000:30000/TCP` (container/service port `3000`, node port `30000`)

## Applied

Applied the equivalent Helm upgrade on the management host (`k8s-management`, `192.168.0.192`) using the same chart/settings as the playbook:

```bash
KUBECONFIG=/root/.kube/config helm upgrade --install forgejo \
  oci://code.forgejo.org/forgejo-helm/forgejo \
  --namespace forgejo \
  --create-namespace \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=local-path \
  --set-json 'tolerations=[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","operator":"Exists","effect":"NoSchedule"}]' \
  --set service.http.type=NodePort \
  --set service.http.nodePort=30000
```

Result:

- Helm release: `forgejo` (namespace `forgejo`) upgraded to **revision 3**, chart `forgejo-17.3.2` (app `15.0.11`), status `deployed`.
- Deployment rollout: `deployment "forgejo" successfully rolled out`.

> Note: The chart emitted PodSecurity warnings during upgrade (unchanged from chart defaults in this environment); the release deployed successfully.

## Verification

Service state:

```text
$ kubectl -n forgejo get svc -o wide
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
forgejo-http   NodePort    10.97.146.77    <none>        3000:30000/TCP   20d   app.kubernetes.io/instance=forgejo,app.kubernetes.io/name=forgejo
forgejo-ssh    ClusterIP   10.111.46.132   <none>        22/TCP           20d   app.kubernetes.io/instance=forgejo,app.kubernetes.io/name=forgejo
```

Pod state:

```text
$ kubectl -n forgejo get pods -o wide
forgejo-6f47cbccbb-5z8ql   1/1   Running   0   10.244.1.112   talos-node-2
```

HTTP reachability on cluster node IPs (from the management host):

```text
http://10.10.50.10:30000/ -> 200
http://10.10.50.21:30000/ -> 200
http://10.10.50.22:30000/ -> 200
```

## Access notes

- Forgejo HTTP is reachable on **any Kubernetes node** at `http://<talos-node-ip>:30000` (nodes: `10.10.50.10`, `10.10.50.21`, `10.10.50.22`).
- Direct access via `http://192.168.0.192:30000` was not reachable from this environment; exposing the NodePort on the management/LAN address requires appropriate routing or port-forwarding on `192.168.0.192` (unlike ports already forwarded for other services). Configure forwarding/firewall rules if LAN access via that host is required.
- SSH service remains `ClusterIP` (`forgejo-ssh`, port 22) and was not changed.
