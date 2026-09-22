Als een component (zoals de Euro-Office Document Server, een geharde Europese fork van ONLYOFFICE) primair als losse container/Docker-container geleverd wordt, maar jouw platform-infrastructuur (zoals MijnBureau) volledig op **Kubernetes** draait, is het zaak om deze container op een **modern, declareerbaar en cloud-agnostisch patroon** uit te rollen op bare-metal/eigen hardware.

Hieronder staat het complete blauwdrukontwerp. Je combineert **OpenStack** (voor het virtuele/fysieke beheer), **OpenTofu/Terraform** (voor de Infrastructure-as-Code) en **Kubernetes (K8s) via Helm** (om van de losse container een hoog-beschikbare service te maken).

---

### De Moderne Deployment Stack (Architectuur)

```
+-------------------------------------------------------------------------------+
| App Layer: Nextcloud Hub <---(HTTPS / JWT)---> Euro-Office Document Server   |
|            (Draait als K8s Pods)               (Draait als K8s StatefulSet)   |
+-------------------------------------------------------------------------------+
| Orchestratie: Kubernetes Cluster (RKE2 / Talos / K3s)                         |
+-------------------------------------------------------------------------------+
| Provisioning: OpenTofu / Terraform                                            |
+-------------------------------------------------------------------------------+
| Cloud/Hardware Layer: OpenStack (Compute: Nova, Storage: Cinder/Ceph)         |
+-------------------------------------------------------------------------------+
| Fysieke Servers (Bare-Metal Nodes)                                            |
+-------------------------------------------------------------------------------+

```

---

### Stap 1: Hardware & OpenStack Provisioning via OpenTofu / Terraform

Eerst definieer je de virtuele machines op je eigen OpenStack-hardware via **OpenTofu** (het open-source alternatief voor Terraform).

Omdat Euro-Office documenten in het geheugen rendert en converteert naar Canvas-elementen, heeft de container relatief veel RAM en CPU nodig bij veel gelijktijdige gebruikers.

#### `main.tf` (OpenTofu)

```hcl
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  auth_url = "https://openstack.jouw-datacenter.local:5000/v3"
  region   = "RegionOne"
}

# Volume voor document-conversie cache en tijdelijke opslag (Cinder/Ceph)
resource "openstack_blockstorage_volume_v3" "eurooffice_cache" {
  name = "eurooffice-cache-vol"
  size = 50 # 50 GB Ceph storage
}

# VM Instance voor de Kubernetes Worker Node die Euro-Office host
resource "openstack_compute_instance_v2" "k8s_worker_app" {
  name            = "k8s-worker-eurooffice-01"
  image_name      = "Ubuntu 24.04 LTS"
  flavor_name     = "m1.xlarge" # bijv. 8 vCPU / 16GB RAM
  key_pair        = "admin-key"
  security_groups = ["default", "k8s-nodes-secgroup"]

  network {
    name = "internal-k8s-net"
  }
}

# Koppel Cinder storage
resource "openstack_compute_volume_attach_v2" "attach_cache" {
  instance_id = openstack_compute_instance_v2.k8s_worker_app.id
  volume_id   = openstack_blockstorage_volume_v3.eurooffice_cache.id
}

```

---

### Stap 2: Containeriseren naar Kubernetes (Helm / K8s Manifest)

Omdat Euro-Office (nog) geleverd wordt als Docker-container, verpakken we deze in een **Kubernetes Deployment / StatefulSet**. Om real-time co-authoring met veel gebruikers mogelijk te maken, koppelen we er **Redis** aan (voor sessie-synchronisatie tussen pod-replicas).

#### `euro-office-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: euro-office-docserver
  namespace: office
  labels:
    app: euro-office
spec:
  replicas: 2 # Schaalbaar over meerdere pods
  selector:
    matchLabels:
      app: euro-office
  template:
    metadata:
      labels:
        app: euro-office
    spec:
      containers:
      - name: euro-office-server
        image: ghcr.io/euro-office/documentserver:latest # Officiële image
        env:
        # JWT Secret is CRUCIAAL: Voorkomt dat vreemden documenten sturen/opvragen
        - name: JWT_ENABLED
          value: "true"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: euro-office-secrets
              key: jwt-secret
        # Redis koppeling voor opschaling over meerdere K8s pods
        - name: REDIS_SERVER_HOST
          value: "redis-cluster.office.svc.cluster.local"
        - name: REDIS_SERVER_PORT
          value: "6379"
        ports:
        - containerPort: 80
          name: http
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "8Gi"
            cpu: "4000m"
        volumeMounts:
        - mountPath: /var/lib/euro-office/documentserver/App_Data/cache
          name: cache-volume
      volumes:
      - name: cache-volume
        persistentVolumeClaim:
          claimName: euro-office-cache-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: euro-office-service
  namespace: office
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: euro-office

```

---

### Stap 3: Netwerk & Beveiliging (Ingress & TLS)

Voor veilige communicatie met Nextcloud/MijnBureau moet Euro-Office via **HTTPS** bereikbaar zijn. Gebruik een Kubernetes Ingress Controller (zoals **NGINX Ingress** of **Traefik**) gecombineerd met **Cert-Manager** voor automatische TLS-certificaten.

#### `ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: euro-office-ingress
  namespace: office
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "500m" # Nodig voor grote documenten
    nginx.ingress.kubernetes.io/websocket-services: "euro-office-service" # Essentieel voor realtime co-authoring!
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - docs.overheid-eigencloud.nl
    secretName: euro-office-tls-cert
  rules:
  - host: docs.overheid-eigencloud.nl
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: euro-office-service
            port:
              number: 80

```

---

### Stap 4: Integratie met Nextcloud / MijnBureau

Zodra de pods op Kubernetes draaien en de Ingress actief is op `[https://docs.overheid-eigencloud.nl](https://docs.overheid-eigencloud.nl)`, koppel je deze aan de Nextcloud-instantie:

1. **Activeer de App:** Ga in Nextcloud naar Apps $\rightarrow$ *Office & text* $\rightarrow$ installeer de **Euro-Office** integratie-app.
2. **Configureer de Server (Beheer):**
* **URL:** `[https://docs.overheid-eigencloud.nl](https://docs.overheid-eigencloud.nl)`
* **Secret:** Geef de exacte `JWT_SECRET` in die ingesteld staat in de Kubernetes Secret.


3. **Intern verkeer optimaliseren:** Als Nextcloud in hetzelfde Kubernetes-cluster draait, kun je bij de geavanceerde instellingen direct het interne Kubernetes DNS-adres opgeven (`[http://euro-office-service.office.svc.cluster.local](http://euro-office-service.office.svc.cluster.local)`) voor het downloaden van bestanden. Dit omzeilt de openbare Ingress en bespaart netwerk-overhead.

---

### Samenvattende Best Practices voor Eigen Hardware

* **Maak de state stateless met S3/Ceph:** Sla geen geconverteerde bestanden of cache op de virtuele schijf van de VM op. Gebruik OpenStack Ceph / S3-storage voor de persistentie.
* **WebSockets zijn verplicht:** Zorg dat alle netwerklagen tussen de browser, Nextcloud en de Euro-Office server **WebSockets** doorlaten. Realtime samenwerken (co-authoring) werkt anders niet.
* **Geheugenmanagement:** Euro-Office start op de achtergrond V8/NodeJS en C++ processen op om `.docx` en `.pptx` te verwerken. Stel strikte Kubernetes `resources.limits` in om te voorkomen dat een reusachtig PowerPoint-bestand de hele server laat crashen (OOM-Killed).
