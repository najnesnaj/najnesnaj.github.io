https://id.kubernetes.local/realms/mijnbureau/protocol/openid-connect/auth?response_type=code&client_id=bureaublad&redirect_uri=https%3A%2F%2Fbureaublad.kubernetes.local%2Fapi%2Fv1%2Fauth%2Fcallback&scope=openid+email+profile&state=3lTkRchiyeRYvnMijZCOQ1UIqrniUG&nonce=Tk86IO6EQina05TGIFXd&code_challenge=2vXgtneT11ILKRzZFicYpQCA-ydxv0BxHB621AF2Itc&code_challenge_method=S256

=> login failed (Authentication failed)




https://docs.kubernetes.local/api/v1.0/authenticate/
{"error":"Network is unavailable."}


https://nextcloud.kubernetes.local/
Configuration was not read or initialized correctly, not overwriting /var/www/html/config/config.php


https://id.kubernetes.local/realms/mijnbureau/protocol/openid-connect/auth?response_type=code&client_id=bureaublad&redirect_uri=https%3A%2F%2Fbureaublad.kubernetes.local%2Fapi%2Fv1%2Fauth%2Fcallback&scope=openid+email+profile&state=Natdy0LDmQo0PF5ojJBIVy6SIPjwks&nonce=QeAWbJV2rCCiUWUjiWVp&code_challenge=evZUf9E4BnulhKVViSt_tR5_F6a8jf_UrZ4s4j-zDP0&code_challenge_method=S256

https://id.kubernetes.local/realms/mijnbureau/protocol/openid-connect/auth?response_type=code&client_id=bureaublad&redirect_uri=https%3A%2F%2Fbureaublad.kubernetes.local%2Fapi%2Fv1%2Fauth%2Fcallback&scope=openid+email+profile&state=Natdy0LDmQo0PF5ojJBIVy6SIPjwks&nonce=QeAWbJV2rCCiUWUjiWVp&code_challenge=evZUf9E4BnulhKVViSt_tR5_F6a8jf_UrZ4s4j-zDP0&code_challenge_method=S256
https://bureaublad.kubernetes.local/login?error=authentication_failed
OIDC_AUTHORIZATION_ENDPOINT=https://id.kubernetes.local/realms/mijnbureau/protocol/openid-connect/auth


kubectl annotate middleware hsts-header -n default meta.helm.sh/release-name=nextcloud --overwrite


kubectl edit ingress nextcloud -n default
ingress.networking.k8s.io/nextcloud edited
Verwijder de middleware-annotatie: traefik.ingress.kubernetes.io/router.middlewares: default-hsts-header@kubernetescrd



kubectl get ingress -A
NAMESPACE   NAME                  CLASS     HOSTS                          ADDRESS         PORTS   AGE
default     bureaublad            <none>    bureaublad.kubernetes.local    192.168.0.216   80      15d
default     collabora-online      <none>    collabora.kubernetes.local     192.168.0.216   80      15d
default     docs                  traefik   docs.kubernetes.local          192.168.0.216   80      28h
default     docs-backend-admin    traefik   docs.kubernetes.local          192.168.0.216   80      28h
default     docs-media            traefik   docs.kubernetes.local          192.168.0.216   80      28h
default     docs-static-nginx     <none>    static-docs.kubernetes.local   192.168.0.216   80      15d
default     docs-y-provider-api   traefik   docs.kubernetes.local          192.168.0.216   80      28h
default     docs-y-provider-ws    traefik   docs.kubernetes.local          192.168.0.216   80      28h
default     element-web           <none>    element.kubernetes.local       192.168.0.216   80      15d
default     keycloak-keycloak     <none>    id.kubernetes.local            192.168.0.216   80      28d
default     livekit-server        <none>    livekit.kubernetes.local       192.168.0.216   80      15d
default     meet                  <none>    meet.kubernetes.local          192.168.0.216   80      15d
default     meet-static-nginx     <none>    static-meet.kubernetes.local   192.168.0.216   80      15d
default     nextcloud             <none>    nextcloud.kubernetes.local     192.168.0.216   80      15d
default     synapse               <none>    matrix.kubernetes.local        192.168.0.216   80      15d

Een HSTS-header (HTTP Strict Transport Security) is een beveiligingsinstructie die een webserver naar een browser stuurt. Deze header dwingt de browser om voor een specifieke periode (de max-age) alleen nog maar via een beveiligde HTTPS-verbinding met de website te communiceren

kubectl delete middleware hsts-header -n default

