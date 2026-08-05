reference URL's : https://github.com/nextcloud/helm/tree/main/charts/nextcloud
https://github.com/Euro-Office/Kubernetes-Docs





Integrating **Euro-Office** with **Nextcloud** on Kubernetes involves deploying two main components onto your cluster and connecting them via the Euro-Office integration app:

1. **Euro-Office Docs (Document Server)**: Renders and edits documents (DOCX, XLSX, PPTX, ODF). Deployed via the [Euro-Office Kubernetes-Docs Helm Chart](https://github.com/Euro-Office/Kubernetes-Docs).
2. **Nextcloud**: Manages files, storage, authentication, and user permissions. Deployed via the [Nextcloud Helm Chart](https://github.com/nextcloud/helm/tree/main/charts/nextcloud).

---

### Prerequisites

* A running Kubernetes cluster.
* **Helm v3** installed locally.
* An **Ingress Controller** (e.g., `ingress-nginx`) with TLS/Cert-Manager configured.
* Two domain names/subdomains pointing to your cluster ingress:
* `nextcloud.example.com` (for Nextcloud)
* `office.example.com` (for Euro-Office Docs)



---

### Step 1: Deploy Euro-Office Docs

Euro-Office Docs requires message queues (RabbitMQ), cache (Redis), and a relational database (PostgreSQL/MariaDB) to function.

#### 1. Add Helm Repository

Add the official Euro-Office Helm repository:

```bash
helm repo add euro-office https://download.euro-office.com/charts/stable
helm repo update

```

*(Alternatively, you can clone the repository directly from [Euro-Office/Kubernetes-Docs](https://github.com/Euro-Office/Kubernetes-Docs).)*

#### 2. Create standard `values-eurooffice.yaml`

Create a custom configuration file for Euro-Office Docs:

```yaml
# values-eurooffice.yaml
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  hosts:
    - host: office.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: office-tls
      hosts:
        - office.example.com

# Enable JWT security token between Nextcloud and Euro-Office
jwt:
  enabled: true
  secret: "YourStrongJWTSecretKey"
  header: "Authorization"

# Enable built-in dependencies or point to external state stores
rabbitmq:
  enabled: true
redis:
  enabled: true
postgresql:
  enabled: true

```

#### 3. Install Euro-Office Docs

If you have a commercial license, create the Kubernetes secret first:

```bash
# Optional: if you have a license file
kubectl create secret generic euro-office-license --from-file=license.lic

```

Deploy the chart using Helm:

```bash
helm install euro-office euro-office/docs \
  --namespace office --create-namespace \
  -f values-eurooffice.yaml

```

---

### Step 2: Deploy Nextcloud

Next, deploy Nextcloud using the official Nextcloud Helm chart.

#### 1. Add Nextcloud Helm Repository

```bash
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

```

#### 2. Create `values-nextcloud.yaml`

Configure Nextcloud to run behind Ingress and automatically install/enable the `eurooffice` integration app on startup:

```yaml
# values-nextcloud.yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "512m"
  hosts:
    - host: nextcloud.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: nextcloud-tls
      hosts:
        - nextcloud.example.com

nextcloud:
  host: nextcloud.example.com
  username: admin
  password: "YourAdminPassword"
  
  # Automatically download and install Euro-Office app upon initialization
  defaultApps:
    - eurooffice

persistence:
  enabled: true
  size: 50Gi

```

#### 3. Install Nextcloud

Deploy Nextcloud into its namespace:

```bash
helm install nextcloud nextcloud/nextcloud \
  --namespace nextcloud --create-namespace \
  -f values-nextcloud.yaml

```

---

### Step 3: Connect Nextcloud to Euro-Office

Once both pods are up and healthy, you must configure the Euro-Office connector app inside Nextcloud to talk to the Euro-Office Document Server.

#### Method A: Using Nextcloud `occ` CLI (Recommended for Automation)

Execute the `occ` command directly inside the running Nextcloud pod:

```bash
# 1. Enable the Euro-Office app (if not automatically enabled)
kubectl exec -n nextcloud -it deployment/nextcloud -- sudo -u www-data php occ app:enable eurooffice

# 2. Set the Euro-Office Document Server URL
kubectl exec -n nextcloud -it deployment/nextcloud -- sudo -u www-data php occ config:app:set eurooffice DocumentServerUrl --value="https://office.example.com/"

# 3. Set the JWT secret (matching the secret in step 1.2)
kubectl exec -n nextcloud -it deployment/nextcloud -- sudo -u www-data php occ config:app:set eurooffice jwt_secret --value="YourStrongJWTSecretKey"

# 4. Set the JWT header name
kubectl exec -n nextcloud -it deployment/nextcloud -- sudo -u www-data php occ config:app:set eurooffice jwt_header --value="Authorization"

```

#### Method B: Via Nextcloud Web UI

1. Log in to your Nextcloud instance at `[https://nextcloud.example.com](https://nextcloud.example.com)` as an administrator.
2. Go to **Apps** and verify that **Euro-Office** is downloaded and enabled.
3. Go to **Administration Settings** -> **Euro-Office**.
4. Enter the **Euro-Office Document Server Address**: `[https://office.example.com/](https://office.example.com/)`.
5. Under **Secret key**, enter `YourStrongJWTSecretKey`.
6. Click **Save**.

---

### Step 4: Verification

1. Go to Nextcloud **Files**.
2. Click the `+` icon and create a new **New Document** (`.docx`), **Spreadsheet** (`.xlsx`), or **Presentation** (`.pptx`).
3. Open the file. It should launch the Euro-Office web-editor interface in your browser.
4. Test editing concurrently in two separate tabs/browsers to confirm real-time collaborative editing.
