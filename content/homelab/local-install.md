---
title: 'local-install'
weight: 1600
draft: false
---


mijn-bureau-deploy-demo/helmfile/environments/default

adapt /etc/hosts

192.168.0.216  bureaublad.kubernetes.local
192.168.0.216  nextcloud.kubernetes.local
192.168.0.216  id.kubernetes.local
192.168.0.216  matrix.kubernetes.local



"global.yaml.gotmpl"
- allowed values "nano" "micro" "small" "medium" "large" "xlarge" "2xlarge"


  resourcesPreset: "small"
(this as to avoid defining resources for each container)


defaultLocale: "nl": Zorgt ervoor dat apps die dit ondersteunen (zoals Nextcloud of Keycloak) direct in het Nederlands opstarten.



  hostname:
    keycloak: "id"
    element: "element"
    synapse: "matrix"
    grist: "grist"
    collabora: "collabora"
    nextcloud: "nextcloud"
    openproject: "openproject"
    livekit: "livekit"
    meet: "meet"
    conversations: "conversations"
    docs: "docs"
    bureaublad: "bureaublad"
    drive: "drive"



tls:
enabled: true: Dwingt HTTPS af voor alle routes in Traefik.
selfSigned: false: Dit suggereert dat je verwacht dat een andere tool (zoals cert-manager of Traefik zelf via Let's Encrypt) voor geldige certificaten zorgt. Omdat je domein nu op .local staat, zul je hier waarschijnlijk nog een aanpassing moeten doen (bijv. naar true zetten voor test-certificaten) tenzij je een lokaal CA-systeem hebt.




persistant volume claim
-------------------------

mijn-bureau-deploy-demo/helmfile/environments/demo$  mijnbureau.yaml.gotmpl

> dit is oorzaak van installatie - errors

pvc:
  nextcloud:
    nextcloud:
      storageClass: ocs-storagecluster-cephfs
      size: 1Gi
      accessModes:
       - ReadWriteMany
    minio:
      size: 128Gi
  docs:
    minio:
      size: 64Gi
  drive:
    minio:
      size: 128Gi
  grist:
    minio:
      size: 32Gi 




----diskspace vergroot

/home/nixie/mijn-bureau-infra/helmfile/apps/nextcloud/charts/nextcloud/templates]

deployment.yaml

onder volumeMounts:

- empty-dir
  mountPath: /usr/local/etc/php/conf.d
  #subPath: conf.d  (dit tussen commentaar)


het entrypoint-script probeert /usr/local/etc/php/conf.d/redis-session.ini aan te maken en krijgt een Permission denied.
Dit komt omdat je de map /usr/local/etc/php/conf.d hebt gemount als een subPath van een emptyDir. In Kubernetes worden subPath-mounts door de root (kubelet) aangemaakt. Jouw container draait als user 1001, en die heeft geen rechten om nieuwe bestanden aan te maken in een map die door root is gemount, zelfs niet in een emptyDir.




kubectl get ingress -A
NAMESPACE   NAME                CLASS    HOSTS                          ADDRESS   PORTS   AGE
default     bureaublad          <none>   bureaublad.kubernetes.local              80      7d1h
default     collabora-online    <none>   collabora.kubernetes.local               80      7d1h
default     docs-static-nginx   <none>   static-docs.kubernetes.local             80      7d1h
default     element-web         <none>   element.kubernetes.local                 80      7d1h
default     keycloak-keycloak   <none>   id.kubernetes.local                      80      19d
default     livekit-server      <none>   livekit.kubernetes.local                 80      7d1h
default     meet                <none>   meet.kubernetes.local                    80      7d1h
default     meet-static-nginx   <none>   static-meet.kubernetes.local             80      7d1h
default     nextcloud           <none>   nextcloud.kubernetes.local               80      7d1h
default     synapse             <none>   matrix.kubernetes.local                  80      7d1h

