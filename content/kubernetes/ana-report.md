---
title: 'Ana Report'
weight: 1280
draft: false
---

# ana-report (custom pod/svc)

## deploy-ana-report.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: nosql-ana-report
namespace: default
spec:
replicas: 1
selector:
    matchLabels:
    app: nosql-ana-report
template:
    metadata:
    labels:
        app: nosql-ana-report
    spec:
    containers:
    - name: nosql-ana-report
        image: 10.110.130.109:5000/nosql-ana-report:latest
        imagePullPolicy: Always
        env:
        - name: POSTGRES_HOST
        value: "postgres-postgresql.postgres.svc.cluster.local"
        - name: POSTGRES_PORT
        value: "5432"
        - name: POSTGRES_USER
        value: "myuser"
        - name: POSTGRES_PASSWORD
        value: "mypassword"
        - name: POSTGRES_DB
        value: "mydatabase"
        ports:
        - containerPort: 8001  # Adjust to the port your app uses
        securityContext:
        allowPrivilegeEscalation: false
        capabilities:
            drop: ["ALL"]
        runAsNonRoot: false
        seccompProfile:
            type: RuntimeDefault
```

## service.yaml

## Ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
name: nosql-ana-report-ingress
namespace: default
annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web, websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
rules:
- host: nosql-ana-report.example.com
    http:
    paths:
    - path: /
        pathType: Prefix
        backend:
        service:
            name: nosql-ana-report
            port:
            number: 80
tls:
- hosts:
    - nosql-ana-report.example.com
    secretName: nosql-ana-report-tls
```
