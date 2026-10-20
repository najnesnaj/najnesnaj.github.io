Om dit volledig te automatiseren zonder handmatige tussenkomst, kun je de kracht van ArgoCD en Forgejo combineren via een **App-of-Apps patroon** of een standaard geautomatiseerde ArgoCD Application.

Omdat je geen handmatige handelingen wilt verrichten in de webinterfaces, laat je ArgoCD direct naar je lokale Forgejo-repository wijzen en zet je `automated: { prune: true, selfHeal: true }` aan. Hierdoor rolt ArgoCD alles zelf uit én herstelt het automatisch eventuele afwijkingen.

Dit is het stappenplan om dit volledig geautomatiseerd in te richten via een Ansible-playbook:

### 1. Wat leg je vast in je Git-repository (Forgejo)?

Voordat ArgoCD het kan ophalen, moet de demo-applicatie (nginx) als manifest in je Forgejo-repository staan. In jouw geautomatiseerde pipeline kun je dit door Ansible (of een script) laten pushen, of je zet het vooraf in je standaard template-repo.

Voor een simpele nginx-demo maak je een map `apps/demo-nginx/` in je Git-repo aan met twee bestanden:

* **`namespace.yaml`**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app

```

* **`deployment.yaml`**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-demo-svc
  namespace: demo-app
spec:
  type: ClusterIP
  selector:
    app: nginx-demo
  ports:
  - port: 80
    targetPort: 80

```

### 2. Laat ArgoCD de applicatie automatisch deployen via Ansible

In plaats van de applicatie handmatig toe te voegen in de ArgoCD-UI, laat je Ansible een `Application`-manifest toepassen op je Kubernetes-cluster. ArgoCD pikt dit op en zorgt dat nginx direct op de cluster komt te staan.

Voeg dit toe aan je Ansible-workflow (bijvoorbeeld in je `argocd.yml` of een nieuwe `gitops-demo.yml`):

```yaml
- name: Automatische Nginx Demo deployen via ArgoCD
  hosts: k8s_management
  become: true
  gather_facts: false
  tasks:
    - name: Maak de ArgoCD Application aan voor de demo
      ansible.builtin.shell: |
        cat <<EOF | kubectl apply -f -
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: demo-nginx
          namespace: argocd
          finalizers:
            - resources-finalizer.argocd.argoproj.io
        spec:
          project: default
          source:
            repoURL: 'http://forgejo-http.forgejo.svc.cluster.local:3000/jouw-gebruiker/jouw-repo.git' # Pas aan naar jouw interne Forgejo service URL
            targetRevision: HEAD
            path: apps/demo-nginx
          destination:
            server: 'https://kubernetes.default.svc'
            namespace: demo-app
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
        EOF
      environment:
        KUBECONFIG: /root/.kube/config

```

### Waarom is dit "Zero Maintenance"?

1. **Volledig geautomatiseerd:** Zodra je Ansible-playbook draait, maakt ArgoCD de verbinding met je lokale Forgejo en wordt nginx uitgerold.
2. **Self-Healing:** Als iemand of iets handmatig de nginx-pods verwijdert of aanpast op de cluster (`kubectl delete pod...`), merkt ArgoCD dit binnen enkele seconden en start hij automatisch nieuwe pods op die exact matchen met wat er in Forgejo staat.
3. **Geen UI nodig:** Je hoeft nooit meer in te loggen op ArgoCD of Proxmox om applicaties te beheren; alles gebeurt via Git en je automatiseringstools.
