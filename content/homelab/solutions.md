---
title: 'solutions'
weight: 1700
draft: false
---

mijn-bureau-deploy-demo/helmfile/environments/default


bureaublad:
    host: "bureaublad-redis-master"
    port: 6379
    isInternal: true
    password: {{ derivePassword 1 "long" (env "MIJNBUREAU_MASTER_PASSWORD" | default "mijn-bureau") "bureaublad" "password" | sha1sum | quote }} 



=> isInternal: false to allow egress to any Redis on port 6379



===========================================================================

 grep bureaublad *
application.yaml.gotmpl:  bureaublad:
application.yaml.gotmpl:      secretKey: {{ derivePassword 1 "long" (requiredEnv "MIJNBUREAU_MASTER_PASSWORD") "bureaublad" "secretkey" | sha1sum | quote }}
authentication.yaml.gotmpl:    bureaublad:
authentication.yaml.gotmpl:      client_id: "bureaublad"
authentication.yaml.gotmpl:      client_secret: {{ derivePassword 1 "long" ( requiredEnv "MIJNBUREAU_MASTER_PASSWORD" ) "keycloak" "bureaublad_client_secret" | sha1sum | quote }}
autoscaling.yaml.gotmpl:    bureaublad:
cache.yaml.gotmpl:  bureaublad:
cache.yaml.gotmpl:    host: "bureaublad-redis-master"
cache.yaml.gotmpl:    password: {{ derivePassword 1 "long" (env "MIJNBUREAU_MASTER_PASSWORD" | default "mijn-bureau") "bureaublad" "password" | sha1sum | quote }}
container.yaml.gotmpl:  bureaublad:
container.yaml.gotmpl:      repository: "minbzk/bureaublad-api"
container.yaml.gotmpl:      repository: "minbzk/bureaublad-frontend"
global.yaml.gotmpl:    bureaublad: "bureaublad"
pdb.yaml.gotmpl:  bureaublad:
pvc.yaml.gotmpl:  bureaublad:
resource.yaml.gotmpl:  bureaublad:
tls.yaml.gotmpl:  bureaublad:


====================================================================================

To deploy MijnBureau to your Kubernetes cluster, execute the following command:

helmfile -e <environment> apply


export MIJNBUREAU_MASTER_PASSWORD="your-very-secure-password"


Check your current context with:

kubectl config get-contexts


inspect installation : 

helmfile -e <environment> template
helmfile -e demo template



