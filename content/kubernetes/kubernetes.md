---
title: 'Kubernetes'
weight: 410
draft: false
---

# Kubernetes

## activate my own docker image

```bash
docker images | grep nosql_ana_report
 (nosql_ana_report                    latest                 af6498f8153e   18 hours ago    474MB)
(in microk8s the registry is localhost:32000, where 32000 is the nodeport)
docker tag nosql_ana_report:latest localhost:32000/nosql_ana_report:latest
docker push localhost:32000/nosql_ana_report:latest

(check from other machine)
curl http://192.168.0.103:32000/v2/nosql_ana_report/tags/list
```

## Create a Kubernetes Deployment

Create a YAML file to define a Deployment for your image.

```bash
# nosql-ana-report-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: nosql-ana-report
labels:
    app: nosql-ana-report
spec:
replicas: 1  # Adjust as needed
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
        image: localhost:32000/nosql_ana_report:latest  # Replace with your registry address
        env:
        - name: ENVIRONMENT
        value: "DOCKER"
        - name: POSTGRES_HOST
        value: "postgres"  # Use the service name, not the IP
        - name: POSTGRES_PORT
        value: "5432"  # Use the port number, not a URL
        - name: POSTGRES_USER
        value: "myuser"  # Replace with your actual user
        - name: POSTGRES_PASSWORD
        value: "mypassword"  # Replace with your actual password
        - name: POSTGRES_DB
        value: "mydatabase"  # Replace with your actual database name
        ports:
        - containerPort: 8001  # Adjust to your app’s port, if any

---
apiVersion: v1
kind: Service
metadata:
name: nosql-ana-report
spec:
type: ClusterIP
ports:
- port: 8001
    targetPort: 8001
selector:
    app: nosql-ana-report
```

## deploy the image

```bash
sudo microk8s kubectl apply -f nosql-ana-report-deployment.yaml
```

## Expose the Application

```bash
# nosql-ana-report-service.yaml
apiVersion: v1
kind: Service
metadata:
name: nosql-ana-report-service
spec:
selector:
    app: nosql-ana-report
ports:
- protocol: TCP
    port: 8001
    targetPort: 8001  # Match your containerPort
type: NodePort  # Use LoadBalancer for cloud setups
```

```bash
sudo microk8s kubectl apply -f nosql-ana-report-service.yaml
```

## Check the Deployment

```bash
sudo microk8s kubectl get deployments
sudo microk8s kubectl get pods
sudo microk8s kubectl get services
```
