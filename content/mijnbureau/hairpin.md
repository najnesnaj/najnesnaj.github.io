De reden waarom de officiële [Mijn Bureau Deploy Demo](https://github.com/MinBZK/mijn-bureau-deploy-demo) vlekkeloos werkt, is omdat deze vertrouwt op een volledige Ingress-route via HTTPS, waarbij zowel de browser als de interne pods via dezelfde stabiele netwerklaag communiceren.
In K3s is Traefik al ingebouwd. Om dit lokaal werkend te krijgen zonder foute CoreDNS-hacks of /etc/hosts-koppelingen in pods, moet je K3s en Traefik zo inrichten dat verkeer van binnen het cluster naar buiten mag lussen en weer terug (Hairpin NAT) via het IP-adres van je node.
Hier is het stappenplan om dit met een schone lei lokaal op te zetten.
------------------------------
## Stap 1: CoreDNS en Pods volledig herstellen
Breng je cluster eerst terug naar de standaardstaat. Verwijder alle eerdere netwerkhacks.

   1. Herstel CoreDNS: Open kubectl edit configmap coredns -n kube-system en verwijder alle handmatige rewrite-regels die we eerder hebben toegevoegd.
   2. Herstel de Backend Deployment: Open kubectl edit deployment docs-backend en verwijder de hostAliases-sectie die we handmatig in de pod hadden gezet.
   3. Herstart beide:
   
   kubectl rollout restart deployment coredns -n kube-system
   kubectl rollout restart deployment docs-backend
   
   
------------------------------
## Stap 2: K3s / Traefik configureren voor Hairpin NAT
Het hoofdprobleem in jouw setup was dat de docs-backend-pod via HTTPS naar id.kubernetes.local zocht, op de Traefik-service botste, en een Connection refused kreeg. Dit los je op door K3s te vertellen dat pods via het Node-IP naar buiten (en weer direct naar binnen) mogen communiceren.
Zorg dat de ingebouwde Traefik-service van K3s het externe IP-adres van je host/node gebruikt als externalIPs.

   1. Zoek het IP-adres van je K3s-node op (bijvoorbeeld 192.168.0.144 uit je eerdere logs):
   
   kubectl get nodes -o wide
   
   2. Pas de Traefik-service aan:
   
   kubectl edit svc traefik -n kube-system
   
   3. Voeg je Node-IP toe onder spec (vlak onder clusterIP):
   
   spec:
     clusterIP: 10.43.203.109
     externalIPs:
     - 192.168.0.144  # VOEG DIT TOE (Gebruik jouw Node IP)
   
   
------------------------------
## Stap 3: Keycloak Ingress Route opzetten (HTTPS via Traefik)
Keycloak moet via HTTPS worden aangesproken, omdat we KC_PROXY="edge" gaan gebruiken (net als in de demo). Traefik moet het SSL-certificaat afhandelen. Voor een lokale omgeving gebruiken we een self-signed certificaat of de standaard Traefik-default TLS.
Maak een bestand genaamd keycloak-ingress.yaml:

apiVersion: networking.k8s.io/v1kind: Ingressmetadata:
  name: keycloak-ingress
  namespace: default
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"spec:
  rules:
  - host: id.kubernetes.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak-keycloak
            port:
              number: 8080 # Traefik praat intern via HTTP (8080) met de pod

Pas dit toe: kubectl apply -f keycloak-ingress.yaml.
------------------------------
## Stap 4: Keycloak Helm Values (De Demo-standaard)
Zorg dat je Keycloak Helm-installatie exact de parameters krijgt die de applicatie dwingen om te begrijpen dat hij veilig achter Traefik leeft.

keycloak:
  enabled: true
  namespace: default
  extraEnvVars:
    - name: KC_PROXY
      value: "edge" # Vertelt Keycloak dat Traefik SSL/TLS afhandelt
    - name: KC_HOSTNAME
      value: "id.kubernetes.local" # Dwingt de juiste URLs in de OIDC discovery
    - name: KC_HOSTNAME_STRICT
      value: "true"

Voer de helm upgrade uit met deze waarden. De keycloak-keycloak service hoeft niet handmatig aangepast te worden; deze moet gewoon op zijn standaard instellingen blijven staan.
------------------------------
## Stap 5: De Django Backend instellen op OIDC Discovery
In de demo-configuratie zie je dat de applicatie gebruik maakt van OIDC Discovery. Je hoeft niet alle endpoints los te definiëren. Je hoeft Django alleen de basis-URL (de Issuer) te geven via HTTPS. Omdat we Hairpin NAT hebben aangezet in Stap 2, kan de Django-pod nu feilloos via HTTPS de discovery-data ophalen bij Traefik.
Pas de omgevingsvariabelen van docs-backend aan naar de officiële structuur:

OIDC_OP_ISSUER=https://kubernetes.local
OAUTHLIB_INSECURE_TRANSPORT=1

(Verwijder variabelen zoals OIDC_OP_TOKEN_ENDPOINT of userinfo_endpoint als je die handmatig had toegevoegd, zodat Django de discovery-URL's van Keycloak zelf downloadt).
------------------------------
## Waarom dit de definitieve, schone oplossing is:

* Geen DNS-vervuiling: CoreDNS blijft standaard. id.kubernetes.local wordt door het cluster resolvert naar de Ingress controller.
* Traefik doet het werk: Zowel je browser (extern) als de Django-pod (intern) sturen hun verzoeken naar exact hetzelfde HTTPS-endpoint (https://kubernetes.local).
* Keycloak is tevreden: Omdat alle verzoeken (intern én extern) nu via Traefik lopen, krijgt Keycloak altijd de vereiste X-Forwarded-Proto: https header mee. De token-validatie zal slagen.

Zullen we deze schone, officiële Ingress-route configureren om de lokale setup definitief stabiel te maken?


