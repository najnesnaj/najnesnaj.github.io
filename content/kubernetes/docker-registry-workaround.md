---
title: 'Docker Registry Workaround'
draft: false
---

# Docker registry kubernetes workaround

```bash
# Create a file named insecure-registry.yaml with the following content
# this does contain the registry IP address, since problem on Talos with internal DNS
     machine:
     registries:
         mirrors:
         "10.110.130.109:5000":
             endpoints:
             - "http://10.110.130.109:5000"


     # Apply the configuration to the nodes

     talosctl patch mc -n 10.10.10.173 --patch @insecure-registry.yaml
     talosctl patch mc -n 10.10.10.166 --patch @insecure-registry.yaml
     talosctl patch mc -n 10.10.10.178 --patch @insecure-registry.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: nosql-ana-report
namespace: docker-registry
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
    imagePullSecrets:
    - name: docker-registry-secret
    containers:
    - name: nosql-ana-report
        image: 10.110.130.109:5000/nosql_ana_report:latest
        imagePullPolicy: Always
```
