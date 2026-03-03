---
title: 'Prometheus'
weight: 1770
draft: false
---

# prometheus

2061  helm repo add prometheus-community [https://prometheus-community.github.io/helm-charts](https://prometheus-community.github.io/helm-charts)
: 2062  helm repo update
  2063  kubectl create namespace monitoring
  2064  vi prometeus-values.yaml
  2065  helm install prometheus prometheus-community/kube-prometheus-stack   -n monitoring   –values prometheus-values.yaml
  2066  ls
  2067  mv prometeus-values.yaml prometheus-values.yaml
  2068  helm install prometheus prometheus-community/kube-prometheus-stack   -n monitoring   –values prometheus-values.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:

> name: grafana-ingress
> namespace: monitoring

spec:
: rules:
  - host: grafana.your-domain.com
  <br/>
  > http:
  > : paths:
  >   - path: /
  >   <br/>
  >   > pathType: Prefix
  >   > backend:
  >   <br/>
  >   > > service:
  >   > > : name: prometheus-grafana
  >   > >   port:
  >   > >   <br/>
  >   > >   > number: 80

NOTES:
kube-prometheus-stack has been installed. Check its status by running:

> kubectl –namespace monitoring get pods -l “release=prometheus”

Get Grafana ‘admin’ user password by running:

> kubectl –namespace monitoring get secrets prometheus-grafana -o jsonpath=”{.data.admin-password}” | base64 -d ; echo

Access Grafana local instance:

> export POD_NAME=$(kubectl –namespace monitoring get pod -l “app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus” -oname)
> kubectl –namespace monitoring port-forward $POD_NAME 3000

Visit [https://github.com/prometheus-operator/kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) for instructions on how to create & configure Alertmanager and Prometheus instances using the Operator.

(admin/prom-operator)
