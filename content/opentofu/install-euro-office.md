Here is a comprehensive, step-by-step guide written in English. You can provide these instructions directly to **OpenCode** (or an engineer / AI assistant executing GitOps tasks) to deploy **Euro-Office Document Server** and **Nextcloud** to a Kubernetes cluster using **ArgoCD**.

---

# Step-by-Step Implementation Guide: GitOps Deployment of Euro-Office & Nextcloud via ArgoCD

## Overview & Architecture

This deployment uses a **Declarative GitOps** pattern managed by ArgoCD.

* **Euro-Office Document Server**: Deployed using the official `euro-office/docs` Helm chart (or from the `Euro-Office/Kubernetes-Docs` repository).
* **Nextcloud**: Deployed using the official Nextcloud Helm chart (`nextcloud/nextcloud`).
* **Security & Integration**: Communication between Nextcloud and Euro-Office is authenticated via JWT tokens.

```
                 [ User / Ingress ]
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
[ Nextcloud Pod ]  ◄--- JWT Ops ---> [ Euro-Office Pod ]
  (File Storage)                      (Document Server)

```

---

## Step 1: Create the Git Repository Structure

Create a Git repository (e.g., `git@github.com:your-org/k8s-apps-manifests.git`) with the following directory tree:

```text
k8s-apps-manifests/
├── namespaces/
│   └── namespaces.yaml
├── apps/
│   ├── root-application.yaml
│   ├── euro-office-app.yaml
│   └── nextcloud-app.yaml
└── values/
    ├── euro-office-values.yaml
    └── nextcloud-values.yaml

```

---

## Step 2: Define Namespaces

Create `namespaces/namespaces.yaml` to ensure target namespaces exist before ArgoCD deploys applications:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: euro-office
---
apiVersion: v1
kind: Namespace
metadata:
  name: nextcloud

```

---

## Step 3: Define Helm Values Files

### 3.1 Euro-Office Values (`values/euro-office-values.yaml`)

Configure the JWT secret, persistence, database, and ingress for Euro-Office:

```yaml
# values/euro-office-values.yaml
jwt:
  enabled: true
  secretName: euro-office-jwt
  # Change this to a secure random 32+ character string
  secret: "ChangeMeToASuperSecureJWTSecret32CharsMin"

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  hosts:
    - host: euro-office.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: euro-office-tls
      hosts:
        - euro-office.example.com

persistence:
  enabled: true
  storageClass: "standard" # Replace with your cluster's StorageClass (e.g., gp2, local-path)
  size: 20Gi

# Specify resource limits suitable for document rendering
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "4000m"
    memory: "4Gi"

```

---

### 3.2 Nextcloud Values (`values/nextcloud-values.yaml`)

Configure Nextcloud storage and ingress:

```yaml
# values/nextcloud-values.yaml
nextcloud:
  host: nextcloud.example.com
  username: admin
  password: "ChangeMeAdminPassword"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "10G"
  tls:
    - secretName: nextcloud-tls
      hosts:
        - nextcloud.example.com

persistence:
  enabled: true
  storageClass: "standard"
  size: 50Gi

```

---

## Step 4: Define ArgoCD Application Manifests

### 4.1 Euro-Office Application (`apps/euro-office-app.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: euro-office
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'https://euro-office.github.io/Kubernetes-Docs/' # Official Euro-Office Helm repo
    chart: docs
    targetRevision: 6.0.0 # Pin to preferred chart version
    helm:
      valueFiles:
        - '$values/values/euro-office-values.yaml'
  sources:
    - repoURL: 'https://euro-office.github.io/Kubernetes-Docs/'
      chart: docs
      targetRevision: 6.0.0
    - repoURL: 'https://github.com/your-org/k8s-apps-manifests.git' # Your GitOps repo
      targetRevision: HEAD
      ref: values
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: euro-office
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

```

---

### 4.2 Nextcloud Application (`apps/nextcloud-app.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nextcloud
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: 'https://nextcloud.github.io/helm/'
      chart: nextcloud
      targetRevision: 8.3.0
    - repoURL: 'https://github.com/your-org/k8s-apps-manifests.git'
      targetRevision: HEAD
      ref: values
      helm:
        valueFiles:
          - '$values/values/nextcloud-values.yaml'
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: nextcloud
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

```

---

### 4.3 App-of-Apps Root Pattern (`apps/root-application.yaml`)

This root manifest allows ArgoCD to manage both workloads declaratively in one step:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-office-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/your-org/k8s-apps-manifests.git'
    targetRevision: HEAD
    path: apps
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

```

---

## Step 5: Execution Instructions for OpenCode

Run the following execution steps in OpenCode / terminal:

1. **Apply the namespaces**:
```bash
kubectl apply -f namespaces/namespaces.yaml

```


2. **Commit and Push Manifests**:
```bash
git add .
git commit -m "feat: Add Euro-Office and Nextcloud GitOps manifests for ArgoCD"
git push origin main

```


3. **Deploy the Root Application to ArgoCD**:
```bash
kubectl apply -f apps/root-application.yaml

```


4. **Verify Application Status via ArgoCD CLI**:
```bash
argocd app list
argocd app sync root-office-stack

```



---

## Step 6: Connect Nextcloud to Euro-Office

Once ArgoCD has synced both applications and all pods are `Running`:

1. **Install Euro-Office App in Nextcloud**:
* Log in to Nextcloud (`[https://nextcloud.example.com](https://nextcloud.example.com)`).
* Go to **Apps** -> **Office & text** -> search for **Euro-Office integration** (or Nextcloud Office / Connector) and click **Download and enable**.


2. **Configure Settings**:
* Navigate to **Settings** -> **Administration** -> **Euro-Office** (or Office).
* Set the **Euro-Office Document Server Service Address**:
`[https://euro-office.example.com](https://euro-office.example.com)` (or the internal service URL: `[http://docs.euro-office.svc.cluster.local:8080](http://docs.euro-office.svc.cluster.local:8080)`).
* Enter the **Secret Key (JWT)** configured in `values/euro-office-values.yaml` (`ChangeMeToASuperSecureJWTSecret32CharsMin`).
* Save settings and test opening a `.docx` or `.xlsx` file inside Nextcloud.
