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
