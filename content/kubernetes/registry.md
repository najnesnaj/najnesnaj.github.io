---
title: 'Registry'
weight: 1140
draft: false
---

# registry

> kubectl apply -f registry.yaml
```yaml
apiVersion: v1
kind: Pod
metadata:
name: registry
labels:
    app: registry
spec:
containers:
    - name: registry
    image: registry:2
    ports:
        - containerPort: 5000
    volumeMounts:
        - name: registry-storage
        mountPath: /var/lib/registry
volumes:
    - name: registry-storage
    emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
name: registry
spec:
selector:
    app: registry
ports:
    - protocol: TCP
    port: 5000
    targetPort: 5000
```

registry ingress
: kubectl apply -f registry_plain_ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: registry
annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
rules:
    - host: registry.example.com
    http:
        paths:
        - path: /
            pathType: Prefix
            backend:
            service:
                name: registry
                port:
                number: 5000
```

## second try

> kubectl apply -f registry_ingress.yaml
```yaml
```

## pushing to the registry

docker tag my-postgres-db:latest registry.example.com/my-postgres-db:latest
