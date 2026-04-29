---
title: 'demo-template'
weight: 2000
draft: false
---


helmfile -e demo template


---
# Source: postgresql/templates/primary/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow dns resolution
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    # Allow outbound connections to read-replicas
    - ports:
        - port: 5432
      to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: keycloak-postgresql
              app.kubernetes.io/name: postgresql
              app.kubernetes.io/component: read
  ingress:
    - ports:
        - port: 5432
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: keycloak-postgresql
              app.kubernetes.io/name: postgresql
        - podSelector:
            matchLabels:
              keycloak-cluster-rw-client: "true"
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: keycloak
      ports:
      - port: 5432
        protocol: TCP
---
# Source: postgresql/templates/primary/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
---
# Source: postgresql/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
automountServiceAccountToken: false
---
# Source: postgresql/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
type: Opaque
data:
  postgres-password: "MGY0OTZhZDA2MWNiM2MzOTI3YzMwNmJmOTM4ZTc4NTE4ZWRmOGRkYg=="
  password: "Mjk2MjgyMzk4ZjIyMWU4N2I4MjFkNTdlY2JhZjY1YzcxNzNjZWEwYQ=="
  # We don't auto-generate LDAP password when it's not provided as we do for other passwords
---
# Source: postgresql/templates/primary/svc-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak-cluster-rw-hl
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
  annotations:
spec:
  type: ClusterIP
  clusterIP: None
  # We want all pods in the StatefulSet to have their addresses published for
  # the sake of the other Postgresql pods even before they're ready, since they
  # have to be able to talk to each other in order to become ready.
  publishNotReadyAddresses: true
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
  selector:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/component: primary
---
# Source: postgresql/templates/primary/svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
      nodePort: null
  selector:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/component: primary
---
# Source: postgresql/templates/primary/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  replicas: 1
  serviceName: keycloak-cluster-rw-hl
  updateStrategy:
    rollingUpdate: {}
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
  template:
    metadata:
      name: keycloak-cluster-rw
      labels:
        app.kubernetes.io/instance: keycloak-postgresql
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: postgresql
        app.kubernetes.io/version: 17.5.0
        helm.sh/chart: postgresql-16.7.18
        app.kubernetes.io/component: primary
    spec:
      serviceAccountName: keycloak-cluster-rw
      
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: keycloak-postgresql
                    app.kubernetes.io/name: postgresql
                    app.kubernetes.io/component: primary
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      hostNetwork: false
      hostIPC: false
      containers:
        - name: postgresql
          image: registry-1.docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r4
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: POSTGRESQL_PORT_NUMBER
              value: "5432"
            - name: POSTGRESQL_VOLUME_DIR
              value: "/bitnami/postgresql"
            - name: PGDATA
              value: "/bitnami/postgresql/data"
            # Authentication
            - name: POSTGRES_USER
              value: "keycloak"
            - name: POSTGRES_PASSWORD_FILE
              value: /opt/bitnami/postgresql/secrets/password
            - name: POSTGRES_POSTGRES_PASSWORD_FILE
              value: /opt/bitnami/postgresql/secrets/postgres-password
            - name: POSTGRES_DATABASE
              value: "keycloak"
            # LDAP
            - name: POSTGRESQL_ENABLE_LDAP
              value: "no"
            # TLS
            - name: POSTGRESQL_ENABLE_TLS
              value: "no"
            # Audit
            - name: POSTGRESQL_LOG_HOSTNAME
              value: "false"
            - name: POSTGRESQL_LOG_CONNECTIONS
              value: "false"
            - name: POSTGRESQL_LOG_DISCONNECTIONS
              value: "false"
            - name: POSTGRESQL_PGAUDIT_LOG_CATALOG
              value: "off"
            # Others
            - name: POSTGRESQL_CLIENT_MIN_MESSAGES
              value: "error"
            - name: POSTGRESQL_SHARED_PRELOAD_LIBRARIES
              value: "pgaudit"
          ports:
            - name: tcp-postgresql
              containerPort: 5432
          livenessProbe:
            failureThreshold: 6
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -U "keycloak" -d "dbname=keycloak" -h 127.0.0.1 -p 5432
          readinessProbe:
            failureThreshold: 6
            initialDelaySeconds: 5
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command:
                - /bin/sh
                - -c
                - -e
                - |
                  exec pg_isready -U "keycloak" -d "dbname=keycloak" -h 127.0.0.1 -p 5432
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /opt/bitnami/postgresql/conf
              subPath: app-conf-dir
            - name: empty-dir
              mountPath: /opt/bitnami/postgresql/tmp
              subPath: app-tmp-dir
            - name: postgresql-password
              mountPath: /opt/bitnami/postgresql/secrets/
            - name: dshm
              mountPath: /dev/shm
            - name: data
              mountPath: /bitnami/postgresql
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: postgresql-password
          secret:
            secretName: keycloak-cluster-rw
        - name: dshm
          emptyDir:
            medium: Memory
            sizeLimit: 1Gi
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "1Gi"

---
# Source: keycloak/templates/extra-list.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
    app.kubernetes.io/component: keycloak-keycloak-cli
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak-keycloak-cli
    app.kubernetes.io/version: 1.0.0
  name: keycloak-keycloak-cli
  namespace: null
spec:
  egress:
  - {}
  podSelector:
    matchLabels:
      app.kubernetes.io/component: keycloak-config-cli
  policyTypes:
  - Egress
---
# Source: keycloak/templates/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-keycloak
      app.kubernetes.io/name: keycloak
      app.kubernetes.io/component: keycloak
      app.kubernetes.io/part-of: keycloak
  policyTypes:
    - Ingress
    - Egress
  egress:
    - {}
  ingress:
    - ports:
        - port: 8080
        - port: 7800
    - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: null
      - podSelector:
          matchLabels:
            app.kubernetes.io/component: keycloak-config-cli
            app.kubernetes.io/name: keycloak
      ports:
      - port: 7800
      - port: 8080
---
# Source: keycloak/templates/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-keycloak
      app.kubernetes.io/name: keycloak
      app.kubernetes.io/component: keycloak
      app.kubernetes.io/part-of: keycloak
---
# Source: keycloak/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
automountServiceAccountToken: true
---
# Source: keycloak/templates/secret-external-db.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-keycloak-externaldb
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/part-of: keycloak
type: Opaque
data:
  db-password: "Mjk2MjgyMzk4ZjIyMWU4N2I4MjFkNTdlY2JhZjY1YzcxNzNjZWEwYQ=="
---
# Source: keycloak/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
type: Opaque
data:
  admin-password: "NDMyNDg0MmVkNmNjMjViNTU2ZTZhMDc0MDAxZTE4ODhiZjk5MzkzZA=="
---
# Source: keycloak/templates/configmap-env-vars.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-keycloak-env-vars
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
data:
  BITNAMI_DEBUG: "false"
  KEYCLOAK_PRODUCTION: "true"
  KC_LOG_LEVEL: "INFO"
  KC_LOG_CONSOLE_OUTPUT: "default"
  KC_BOOTSTRAP_ADMIN_USERNAME: "admin"
  KC_BOOTSTRAP_ADMIN_PASSWORD_FILE: /opt/bitnami/keycloak/secrets/admin-password
  KC_HTTP_PORT: "8080"
  KC_HTTP_MANAGEMENT_PORT: "9000"
  KC_HTTP_ENABLED: "true"
  KC_PROXY_HEADERS: "xforwarded"
  KC_HOSTNAME_STRICT: "false"
  KC_HOSTNAME: "https://id.kubernetes.local/"
  KC_METRICS_ENABLED: "false"
  KC_DB_URL: "jdbc:postgresql://keycloak-cluster-rw:5432/keycloak?currentSchema=public"
  KC_DB_SCHEMA: "public"
  KC_DB_PASSWORD_FILE: /opt/bitnami/keycloak/secrets/db-db-password
  KC_DB_USERNAME: "keycloak"
  KC_CACHE: "ispn"
  KC_CACHE_STACK: "jdbc-ping"
  KC_CACHE_CONFIG_FILE: "cache-ispn.xml"
  JAVA_OPTS_APPEND: "-Djgroups.dns.query=keycloak-keycloak-headless.default.svc.cluster.local"
  KC_HTTP_RELATIVE_PATH: "/"
  KC_SPI_ADMIN_REALM: "master"
---
# Source: keycloak/templates/keycloak-config-cli-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-keycloak-keycloak-config-cli-configmap
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak-config-cli
    app.kubernetes.io/part-of: keycloak
data:
  master.json: |
    {
      "realm" : "master",
      "attributes": {
        "frontendUrl": "https://id.kubernetes.local"
      }
    }
    
  mijnbureau.json: |
    {
      "realm" : "mijnbureau",
      "displayName": "Mijn Bureau",
      "displayNameHtml": "<b>Mijn Bureau</b>",
      "defaultSignatureAlgorithm": "RS256",
      "enabled" : true,
      "revokeRefreshToken": true,
      "editUsernameAllowed": false,
      "registrationAllowed": false,
      "duplicateEmailsAllowed": false,
      "rememberMe": true,
      "loginWithEmailAllowed": true,
      "bruteForceProtected": true,
      "permanentLockout": false,
      "maxTemporaryLockouts": 0,
      "bruteForceStrategy": "LINEAR",
      "maxFailureWaitSeconds": 900,
      "minimumQuickLoginWaitSeconds": 60,
      "waitIncrementSeconds": 60,
      "quickLoginCheckMilliSeconds": 1000,
      "maxDeltaTimeSeconds": 43200,
      "failureFactor": 30,
      "clients": [
        {
          "clientId": "grist",
          "name": "Grist",
          "description": "Smart spreadsheets with Grist",
          "rootUrl": "https://grist.kubernetes.local",
          "adminUrl": "https://grist.kubernetes.local/o/docs/admin",
          "baseUrl": "https://grist.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "03e01d1ab0c8afe03849881564009a3cb8bdd33b",
          "redirectUris": [
            "/oauth2/callback"
          ],
          "webOrigins": [
            "https://grist.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.url": "https://grist.kubernetes.local/o/docs/logout?next=/",
            "post.logout.redirect.uris": "https://grist.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        },
        {
          "clientId": "synapse",
          "name": "Chat",
          "description": "Matrix-based chat with Synapse",
          "rootUrl": "https://matrix.kubernetes.local",
          "adminUrl": "https://matrix.kubernetes.local",
          "baseUrl": "https://matrix.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "0213af72e15d5de068a44ed1777b77c87052c047",
          "redirectUris": [
            "/_synapse/client/oidc/callback"
          ],
          "webOrigins": [
            "https://matrix.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": false,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://matrix.kubernetes.local/_synapse/client/oidc/backchannel_logout",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.session.required": "true",
            "post.logout.redirect.uris": "https://matrix.kubernetes.local/*"
          }
        },
        {
          "clientId": "meet",
          "name": "Meet",
          "description": "livekit-based video conferencing with Meet",
          "rootUrl": "https://meet.kubernetes.local",
          "adminUrl": "https://meet.kubernetes.local",
          "baseUrl": "https://meet.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "7e746529a93e74cda76854b174289b0f7d1b77fd",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://meet.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://meet.kubernetes.local/api/v1.0/logout/",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.url": "https://meet.kubernetes.local/api/v1.0/logout/",
            "post.logout.redirect.uris": "https://meet.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        },
        {
          "clientId": "conversations",
          "name": "Conversations",
          "description": "AI assistant with LaSuite conversations",
          "rootUrl": "https://conversations.kubernetes.local",
          "adminUrl": "https://conversations.kubernetes.local",
          "baseUrl": "https://conversations.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "541c3b435d68bfff03675c046cb18d606107f57b",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://conversations.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://conversations.kubernetes.local/api/v1.0/logout/",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.url": "https://conversations.kubernetes.local/api/v1.0/logout/",
            "post.logout.redirect.uris": "https://conversations.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        },
        {
          "clientId": "drive",
          "name": "Drive",
          "description": "AI assistant with LaSuite drive",
          "rootUrl": "https://drive.kubernetes.local",
          "adminUrl": "https://drive.kubernetes.local",
          "baseUrl": "https://drive.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "291eed23b36804b8fea7dfe15171c77c6deab5c3",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://drive.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://drive.kubernetes.local/api/v1.0/logout/",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.url": "https://drive.kubernetes.local/api/v1.0/logout/",
            "post.logout.redirect.uris": "https://drive.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        },
        {
          "clientId": "nextcloud",
          "name": "NextCloud",
          "description": "File storage and collaboration platform",
          "rootUrl": "https://nextcloud.kubernetes.local",
          "adminUrl": "https://nextcloud.kubernetes.local",
          "baseUrl": "https://nextcloud.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "5c1b336790d40b7e6f57a265487a5c2daabf1bc4",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://nextcloud.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": false,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://nextcloud.kubernetes.local/index.php/apps/user_oidc/backchannel-logout/keycloak",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.session.required": "true",
            "post.logout.redirect.uris": "+"
          }
        },
        {
          "clientId": "openproject",
          "name": "OpenProject",
          "description": "File storage and collaboration platform",
          "rootUrl": "https://openproject.kubernetes.local",
          "adminUrl": "https://openproject.kubernetes.local",
          "baseUrl": "https://openproject.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "ae3d966eccd927c79deebc99f8efd33ec0010306",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://openproject.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": false,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://openproject.kubernetes.local/auth/oidc-keycloak/backchannel-logout",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.session.required": "true",
            "post.logout.redirect.uris": "https://openproject.kubernetes.local/*"
          }
        },
        {
          "clientId": "docs",
          "name": "Docs",
          "description": "Docs - Eenvoudig samenwerken aan documenten",
          "rootUrl": "https://docs.kubernetes.local",
          "adminUrl": "https://docs.kubernetes.local",
          "baseUrl": "https://docs.kubernetes.local",
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "bc9973ae28031362a346011edf211a117583dac9",
          "redirectUris": [
            "/*"
          ],
          "webOrigins": [
            "https://docs.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://docs.kubernetes.local/api/v1.0/logout/",
            "standard.token.exchange.enabled": "false",
            "frontchannel.logout.url": "https://docs.kubernetes.local/api/v1.0/logout/",
            "post.logout.redirect.uris": "https://docs.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        },
        {
          "clientId": "bureaublad",
          "name": "bureaublad",
          "description": "Mijn Bureau bureaublad",
          "rootUrl": "https://bureaublad.kubernetes.local",
          "adminUrl": "https://bureaublad.kubernetes.local",
          "baseUrl": "https://bureaublad.kubernetes.local",
          "surrogateAuthRequired": false,
          "enabled": true,
          "alwaysDisplayInConsole": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "079b22102d5c5c847090bf5e25cc37bf995b09cc",
          "redirectUris": [
            "/api/v1/auth/callback"
          ],
          "webOrigins": [
            "https://bureaublad.kubernetes.local"
          ],
          "notBefore": 0,
          "bearerOnly": false,
          "consentRequired": false,
          "standardFlowEnabled": true,
          "implicitFlowEnabled": false,
          "directAccessGrantsEnabled": false,
          "serviceAccountsEnabled": false,
          "publicClient": true,
          "frontchannelLogout": true,
          "protocol": "openid-connect",
          "attributes": {
            "realm_client": "false",
            "oidc.ciba.grant.enabled": "false",
            "client.secret.creation.time": "1759388679",
            "backchannel.logout.session.required": "true",
            "backchannel.logout.url": "https://bureaublad.kubernetes.local/api/v1/auth/logout",
            "standard.token.exchange.enabled": "true",
            "frontchannel.logout.url": "https://bureaublad.kubernetes.local/api/v1/auth/logout",
            "post.logout.redirect.uris": "https://bureaublad.kubernetes.local/*",
            "frontchannel.logout.session.required": "false",
            "oauth2.device.authorization.grant.enabled": "false",
            "display.on.consent.screen": "false",
            "backchannel.logout.revoke.offline.tokens": "false"
          }
        }
      ],
      "defaultRoles": ["offline_access", "uma_authorization", "tokenexchange-role"],
      "roles": {
        "realm": [
          {
            "name": "tokenexchange-role",
            "description": "Allow bureaublad clients to exchange tokens",
            "composite": true,
            "composites": {
              "client": {
                "docs": ["token-exchange-role"],
                "openproject": ["token-exchange-role"],
                "nextcloud": ["token-exchange-role"],
                "drive": ["token-exchange-role"],
                "conversations": ["token-exchange-role"],
                "meet": ["token-exchange-role"],
                "synapse": ["token-exchange-role"],
                "grist": ["token-exchange-role"]
              }
            },
            "clientRole": false,
            "attributes": {}
          }
        ],
        "client": {
          "grist": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "synapse": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "meet": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "conversations": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "drive": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "nextcloud": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "docs": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ],
          "openproject": [
            {
              "name": "token-exchange-role",
              "description": "",
              "composite": false,
              "clientRole": true,
              "attributes": {}
            }
          ]
        }
      },
      "users" : [
        {
          "username" : "johndoe",
          "firstName" : "John",
          "lastName" : "Doe",
          "email" : "johndoe@example.com",
          "emailVerified" : true,
          "credentials" : [ {
            "type" : "password",
            "value": "myStrongPassword123",
            "temporary": false
          } ],
          "enabled" : true
        },
        {
          "username" : "janedoe",
          "firstName" : "Jane",
          "lastName" : "Doe",
          "email" : "janedoe@example.com",
          "emailVerified" : true,
          "credentials" : [ {
            "type" : "password",
            "value": "myStrongPassword123",
            "temporary": false
          } ],
          "enabled" : true
        }
      ],
      "internationalizationEnabled": true,
      "eventsEnabled": true,
      "eventsExpiration": 86400,
      "adminEventsEnabled": true,
      "supportedLocales": [
        "en",
        "nl"
      ],
      "defaultLocale": "nl"
    }
---
# Source: keycloak/templates/headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak-keycloak-headless
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: http
      port: 8080
      protocol: TCP
      targetPort: http
  publishNotReadyAddresses: true
  selector:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
---
# Source: keycloak/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
      nodePort: null
  selector:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
---
# Source: keycloak/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
spec:
  replicas: 1
  revisionHistoryLimit: 10
  podManagementPolicy: Parallel
  serviceName: keycloak-keycloak-headless
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/instance: keycloak-keycloak
      app.kubernetes.io/name: keycloak
      app.kubernetes.io/component: keycloak
      app.kubernetes.io/part-of: keycloak
  template:
    metadata:
      annotations:
        checksum/configmap-env-vars: 221315e7cd8c25d154a472a29fa309cc36a87ee84c1d8347dab1d2039ed578b7
        checksum/secrets: 088f2a882a72274fc14849240be951ef4e7d47ed555d5a40ccaba8c340547d19
      labels:
        app.kubernetes.io/instance: keycloak-keycloak
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/version: 26.3.3
        helm.sh/chart: keycloak-25.2.0
        app.kubernetes.io/component: keycloak
        app.kubernetes.io/part-of: keycloak
    spec:
      serviceAccountName: keycloak-keycloak
      
      automountServiceAccountToken: true
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: keycloak-keycloak
                    app.kubernetes.io/name: keycloak
                    app.kubernetes.io/component: keycloak
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      enableServiceLinks: true
      initContainers:
        - name: prepare-write-dirs
          image: docker.io/bitnamilegacy/keycloak:26.3.3-debian-12-r0
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          command:
            - /bin/bash
          args:
            - -ec
            - |
              . /opt/bitnami/scripts/liblog.sh
        
              info "Copying writable dirs to empty dir"
              # In order to not break the application functionality we need to make some
              # directories writable, so we need to copy it to an empty dir volume
              cp -r --preserve=mode,timestamps /opt/bitnami/keycloak/lib/quarkus /emptydir/app-quarkus-dir
              cp -r --preserve=mode,timestamps /opt/bitnami/keycloak/data /emptydir/app-data-dir
              cp -r --preserve=mode,timestamps /opt/bitnami/keycloak/providers /emptydir/app-providers-dir
              cp -r --preserve=mode,timestamps /opt/bitnami/keycloak/themes /emptydir/app-themes-dir
              info "Copy operation completed"
          volumeMounts:
           - name: empty-dir
             mountPath: /emptydir
      containers:
        - name: keycloak
          image: docker.io/bitnamilegacy/keycloak:26.3.3-debian-12-r0
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            - name: KUBERNETES_NAMESPACE
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
            - name: JAVA_OPTS
              value: -Xms512m -Xmx1024m
          envFrom:
            - configMapRef:
                name: keycloak-keycloak-env-vars
          resources:
            limits:
              memory: 1536Mi
            requests:
              memory: 768Mi
          ports:
            - name: http
              containerPort: 8080
              protocol: TCP
            - name: discovery
              containerPort: 7800
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 120
            periodSeconds: 1
            successThreshold: 1
            timeoutSeconds: 5
            tcpSocket:
              port: http
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
            httpGet:
              path: /realms/master
              port: http
              scheme: HTTP
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /bitnami/keycloak
              subPath: app-volume-dir
            - name: empty-dir
              mountPath: /opt/bitnami/keycloak/conf
              subPath: app-conf-dir
            - name: empty-dir
              mountPath: /opt/bitnami/keycloak/lib/quarkus
              subPath: app-quarkus-dir
            - name: empty-dir
              mountPath: /opt/bitnami/keycloak/data
              subPath: app-data-dir
            - name: empty-dir
              mountPath: /opt/bitnami/keycloak/providers
              subPath: app-providers-dir
            - name: empty-dir
              mountPath: /opt/bitnami/keycloak/themes
              subPath: app-themes-dir
            - name: keycloak-secrets
              mountPath: /opt/bitnami/keycloak/secrets
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: keycloak-secrets
          projected:
            sources:
              - secret:
                  name: keycloak-keycloak
              - secret:
                  name: keycloak-keycloak-externaldb
                  items:
                    - key: db-password
                      path: db-db-password
---
# Source: keycloak/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-keycloak
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak
    app.kubernetes.io/part-of: keycloak
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  rules:
    - host: "id.kubernetes.local"
      http:
        paths:
          - path: "/"
            pathType: ImplementationSpecific
            backend:
              service:
                name: keycloak-keycloak
                port:
                  name: http
---
# Source: keycloak/templates/keycloak-config-cli-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-keycloak-keycloak-config-cli
  namespace: "default"
  labels:
    app.kubernetes.io/instance: keycloak-keycloak
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: keycloak
    app.kubernetes.io/version: 26.3.3
    helm.sh/chart: keycloak-25.2.0
    app.kubernetes.io/component: keycloak-config-cli
    app.kubernetes.io/part-of: keycloak
  annotations:
    helm.sh/hook: post-install,post-upgrade,post-rollback
    helm.sh/hook-delete-policy: hook-succeeded,before-hook-creation
    helm.sh/hook-weight: "5"
spec:
  backoffLimit: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: keycloak-keycloak
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: keycloak
        app.kubernetes.io/version: 26.3.3
        helm.sh/chart: keycloak-25.2.0
        app.kubernetes.io/component: keycloak-config-cli
        app.kubernetes.io/part-of: keycloak
      annotations:
        checksum/configuration: 0493add5618fc82bd647e47ee9f31a78796255fe337ebf8f8eb57459d3b64780
    spec:
      restartPolicy: Never
      serviceAccountName: keycloak-keycloak
      
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      automountServiceAccountToken: true
      containers:
        - name: keycloak-config-cli
          image: docker.io/bitnamilegacy/keycloak-config-cli:6.4.0-debian-12-r9
          imagePullPolicy: Always
          command:
            - java
          args:
            - -jar
            - /opt/bitnami/keycloak-config-cli/keycloak-config-cli.jar
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            # ref: https://github.com/adorsys/keycloak-config-cli?tab=readme-ov-file#configuration
            - name: KEYCLOAK_URL
              value: http://keycloak-keycloak-headless:8080/
            - name: KEYCLOAK_USER
              value: "admin"
            - name: KEYCLOAK_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak-keycloak
                  key: admin-password
            - name: IMPORT_FILES_LOCATIONS
              value: /config/*
            - name: KEYCLOAK_AVAILABILITYCHECK_ENABLED
              value: "true"
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: config-volume
              mountPath: /config
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: config-volume
          configMap:
            name: keycloak-keycloak-keycloak-config-cli-configmap

---
# Source: postgresql/templates/primary/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow dns resolution
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    # Allow outbound connections to read-replicas
    - ports:
        - port: 5432
      to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-postgresql
              app.kubernetes.io/name: postgresql
              app.kubernetes.io/component: read
  ingress:
    - ports:
        - port: 5432
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-postgresql
              app.kubernetes.io/name: postgresql
        - podSelector:
            matchLabels:
              nextcloud-cluster-rw-client: "true"
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: nextcloud
      ports:
      - port: 5432
        protocol: TCP
---
# Source: postgresql/templates/primary/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
---
# Source: postgresql/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
automountServiceAccountToken: false
---
# Source: postgresql/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
type: Opaque
data:
  postgres-password: "YzUxMmZjOGM0MTdjZmYyMTYxNjNmMjExNTc0OTA4M2QzZDA2ODBkZg=="
  password: "MDc2OTUyMWJjZTc1ODE4NmMwYzI4MTQwMjcxMzEyNGNhZTdmNmEyZg=="
  # We don't auto-generate LDAP password when it's not provided as we do for other passwords
---
# Source: postgresql/templates/primary/svc-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-cluster-rw-hl
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
  annotations:
spec:
  type: ClusterIP
  clusterIP: None
  # We want all pods in the StatefulSet to have their addresses published for
  # the sake of the other Postgresql pods even before they're ready, since they
  # have to be able to talk to each other in order to become ready.
  publishNotReadyAddresses: true
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
  selector:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/component: primary
---
# Source: postgresql/templates/primary/svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: tcp-postgresql
      port: 5432
      targetPort: tcp-postgresql
      nodePort: null
  selector:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/component: primary
---
# Source: postgresql/templates/primary/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nextcloud-cluster-rw
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-postgresql
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/version: 17.5.0
    helm.sh/chart: postgresql-16.7.18
    app.kubernetes.io/component: primary
spec:
  replicas: 1
  serviceName: nextcloud-cluster-rw-hl
  updateStrategy:
    rollingUpdate: {}
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-postgresql
      app.kubernetes.io/name: postgresql
      app.kubernetes.io/component: primary
  template:
    metadata:
      name: nextcloud-cluster-rw
      labels:
        app.kubernetes.io/instance: nextcloud-postgresql
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: postgresql
        app.kubernetes.io/version: 17.5.0
        helm.sh/chart: postgresql-16.7.18
        app.kubernetes.io/component: primary
    spec:
      serviceAccountName: nextcloud-cluster-rw
      
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: nextcloud-postgresql
                    app.kubernetes.io/name: postgresql
                    app.kubernetes.io/component: primary
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      hostNetwork: false
      hostIPC: false
      containers:
        - name: postgresql
          image: registry-1.docker.io/bitnamilegacy/postgresql:17.6.0-debian-12-r4
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: POSTGRESQL_PORT_NUMBER
              value: "5432"
            - name: POSTGRESQL_VOLUME_DIR
              value: "/bitnami/postgresql"
            - name: PGDATA
              value: "/bitnami/postgresql/data"
            # Authentication
            - name: POSTGRES_USER
              value: "nextcloud"
            - name: POSTGRES_PASSWORD_FILE
              value: /opt/bitnami/postgresql/secrets/password
            - name: POSTGRES_POSTGRES_PASSWORD_FILE
              value: /opt/bitnami/postgresql/secrets/postgres-password
            - name: POSTGRES_DATABASE
              value: "nextcloud"
            # LDAP
            - name: POSTGRESQL_ENABLE_LDAP
              value: "no"
            # TLS
            - name: POSTGRESQL_ENABLE_TLS
              value: "no"
            # Audit
            - name: POSTGRESQL_LOG_HOSTNAME
              value: "false"
            - name: POSTGRESQL_LOG_CONNECTIONS
              value: "false"
            - name: POSTGRESQL_LOG_DISCONNECTIONS
              value: "false"
            - name: POSTGRESQL_PGAUDIT_LOG_CATALOG
              value: "off"
            # Others
            - name: POSTGRESQL_CLIENT_MIN_MESSAGES
              value: "error"
            - name: POSTGRESQL_SHARED_PRELOAD_LIBRARIES
              value: "pgaudit"
          ports:
            - name: tcp-postgresql
              containerPort: 5432
          livenessProbe:
            failureThreshold: 6
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command:
                - /bin/sh
                - -c
                - exec pg_isready -U "nextcloud" -d "dbname=nextcloud" -h 127.0.0.1 -p 5432
          readinessProbe:
            failureThreshold: 6
            initialDelaySeconds: 5
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            exec:
              command:
                - /bin/sh
                - -c
                - -e
                - |
                  exec pg_isready -U "nextcloud" -d "dbname=nextcloud" -h 127.0.0.1 -p 5432
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /opt/bitnami/postgresql/conf
              subPath: app-conf-dir
            - name: empty-dir
              mountPath: /opt/bitnami/postgresql/tmp
              subPath: app-tmp-dir
            - name: postgresql-password
              mountPath: /opt/bitnami/postgresql/secrets/
            - name: dshm
              mountPath: /dev/shm
            - name: data
              mountPath: /bitnami/postgresql
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: postgresql-password
          secret:
            secretName: nextcloud-cluster-rw
        - name: dshm
          emptyDir:
            medium: Memory
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "1Gi"

---
# Source: redis/templates/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: nextcloud-redis
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-redis
      app.kubernetes.io/name: redis
  policyTypes:
    - Ingress
    - Egress
  egress:
  ingress:
    # Allow inbound connections
    - ports:
        - port: 6379
      from:
        - podSelector:
            matchLabels:
              nextcloud-redis-client: "true"
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-redis
              app.kubernetes.io/name: redis
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: nextcloud
      ports:
      - port: 6379
        protocol: TCP
---
# Source: redis/templates/master/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nextcloud-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-redis
      app.kubernetes.io/name: redis
      app.kubernetes.io/component: master
---
# Source: redis/templates/master/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
automountServiceAccountToken: false
metadata:
  name: nextcloud-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
---
# Source: redis/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-redis
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
type: Opaque
data:
  redis-password: "NmJiYWJlZjQzZDAzNjFiNGUwMDRlNzcyNzk1NDIzNGViYzE4NDMzYw=="
---
# Source: redis/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-redis-configuration
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  redis.conf: |-
    # User-supplied common configuration:
    # Enable AOF https://redis.io/topics/persistence#append-only-file
    appendonly yes
    # Disable RDB persistence, AOF persistence already enabled.
    save ""
    # End of common configuration
  master.conf: |-
    dir /data
    # User-supplied master configuration:
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
    # End of master configuration
  replica.conf: |-
    dir /data
    # User-supplied replica configuration:
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
    # End of replica configuration
  users.acl: |-
---
# Source: redis/templates/health-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-redis-health
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  ping_readiness_local.sh: |-
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    [[ -n "$REDIS_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_local.sh: |-
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    [[ -n "$REDIS_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    responseFirstWord=$(echo $response | head -n1 | awk '{print $1;}')
    if [ "$response" != "PONG" ] && [ "$responseFirstWord" != "LOADING" ] && [ "$responseFirstWord" != "MASTERDOWN" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_master.sh: |-
    #!/bin/bash

    [[ -f $REDIS_MASTER_PASSWORD_FILE ]] && export REDIS_MASTER_PASSWORD="$(< "${REDIS_MASTER_PASSWORD_FILE}")"
    [[ -n "$REDIS_MASTER_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_MASTER_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_master.sh: |-
    #!/bin/bash

    [[ -f $REDIS_MASTER_PASSWORD_FILE ]] && export REDIS_MASTER_PASSWORD="$(< "${REDIS_MASTER_PASSWORD_FILE}")"
    [[ -n "$REDIS_MASTER_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_MASTER_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    responseFirstWord=$(echo $response | head -n1 | awk '{print $1;}')
    if [ "$response" != "PONG" ] && [ "$responseFirstWord" != "LOADING" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_readiness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_readiness_master.sh" $1 || exit_status=$?
    exit $exit_status
  ping_liveness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_liveness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_liveness_master.sh" $1 || exit_status=$?
    exit $exit_status
---
# Source: redis/templates/scripts-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-redis-scripts
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  start-master.sh: |
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    if [[ -f /opt/bitnami/redis/mounted-etc/master.conf ]];then
        cp /opt/bitnami/redis/mounted-etc/master.conf /opt/bitnami/redis/etc/master.conf
    fi
    if [[ -f /opt/bitnami/redis/mounted-etc/redis.conf ]];then
        cp /opt/bitnami/redis/mounted-etc/redis.conf /opt/bitnami/redis/etc/redis.conf
    fi
    if [[ -f /opt/bitnami/redis/mounted-etc/users.acl ]];then
        cp /opt/bitnami/redis/mounted-etc/users.acl /opt/bitnami/redis/etc/users.acl
    fi
    ARGS=("--port" "${REDIS_PORT}")
    ARGS+=("--requirepass" "${REDIS_PASSWORD}")
    ARGS+=("--masterauth" "${REDIS_PASSWORD}")
    ARGS+=("--include" "/opt/bitnami/redis/etc/redis.conf")
    ARGS+=("--include" "/opt/bitnami/redis/etc/master.conf")
    exec redis-server "${ARGS[@]}"
---
# Source: redis/templates/headless-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-redis-headless
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
  selector:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/name: redis
---
# Source: redis/templates/master/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  type: ClusterIP
  internalTrafficPolicy: Cluster
  sessionAffinity: None
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
      nodePort: null
  selector:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
---
# Source: redis/templates/master/application.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nextcloud-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-redis
      app.kubernetes.io/name: redis
      app.kubernetes.io/component: master
  serviceName: nextcloud-redis-headless
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: nextcloud-redis
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: redis
        app.kubernetes.io/version: 8.0.2
        helm.sh/chart: redis-21.2.6
        app.kubernetes.io/component: master
      annotations:
        checksum/configmap: 2a9ab4a5432825504d910f022638674ce88eaefe9f9f595ad8bc107377d104fb
        checksum/health: aff24913d801436ea469d8d374b2ddb3ec4c43ee7ab24663d5f8ff1a1b6991a9
        checksum/scripts: 0717e77fd3bb941f602860e9be4f2ed87b481cddeadf37be463f8512ecde0c3e
        checksum/secret: 955500f679b1657395e3c3f85057197f45074c28ff908d83d45f938779ec2c5e
    spec:
      
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      serviceAccountName: nextcloud-redis-master
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: nextcloud-redis
                    app.kubernetes.io/name: redis
                    app.kubernetes.io/component: master
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      enableServiceLinks: true
      terminationGracePeriodSeconds: 30
      containers:
        - name: redis
          image: registry-1.docker.io/bitnamilegacy/redis:8.2.1-debian-12-r0
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          command:
            - /bin/bash
          args:
            - -ec
            - /opt/bitnami/scripts/start-scripts/start-master.sh
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: REDIS_REPLICATION_MODE
              value: master
            - name: ALLOW_EMPTY_PASSWORD
              value: "no"
            - name: REDIS_PASSWORD_FILE
              value: "/opt/bitnami/redis/secrets/redis-password"
            - name: REDIS_TLS_ENABLED
              value: "no"
            - name: REDIS_PORT
              value: "6379"
          ports:
            - name: redis
              containerPort: 6379
          livenessProbe:
            initialDelaySeconds: 20
            periodSeconds: 5
            # One second longer than command timeout should prevent generation of zombie processes.
            timeoutSeconds: 6
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - /bin/bash
                - -ec
                - "/health/ping_liveness_local.sh 5"
          readinessProbe:
            initialDelaySeconds: 20
            periodSeconds: 5
            timeoutSeconds: 2
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - /bin/bash
                - -ec
                - "/health/ping_readiness_local.sh 1"
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: start-scripts
              mountPath: /opt/bitnami/scripts/start-scripts
            - name: health
              mountPath: /health
            - name: redis-password
              mountPath: /opt/bitnami/redis/secrets/
            - name: redis-data
              mountPath: /data
            - name: config
              mountPath: /opt/bitnami/redis/mounted-etc
            - name: empty-dir
              mountPath: /opt/bitnami/redis/etc/
              subPath: app-conf-dir
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
      volumes:
        - name: start-scripts
          configMap:
            name: nextcloud-redis-scripts
            defaultMode: 0755
        - name: health
          configMap:
            name: nextcloud-redis-health
            defaultMode: 0755
        - name: redis-password
          
          secret:
            secretName: nextcloud-redis
            items:
            - key: redis-password
              path: redis-password
        - name: config
          configMap:
            name: nextcloud-redis-configuration
        - name: empty-dir
          emptyDir: {}
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: redis-data
        labels:
          app.kubernetes.io/instance: nextcloud-redis
          app.kubernetes.io/name: redis
          app.kubernetes.io/component: master
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "1Gi"

---
# Source: minio/templates/console/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: nextcloud-minio-console
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2.0.2
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: console
    app.kubernetes.io/part-of: minio
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: console
      app.kubernetes.io/part-of: minio
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow dns resolution
    - ports:
        - port: 53
          protocol: UDP
    # Allow outbound connections to Minio(R) pods
    - ports:
        - port: 9000
        - port: 9000
      to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-minio
              app.kubernetes.io/name: minio
  ingress:
    # Allow inbound connections
    - ports:
        - port: 9090
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-minio
              app.kubernetes.io/name: minio
        - podSelector:
            matchLabels:
              nextcloud-minio-client: "true"
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/part-of: minio
      ports:
      - port: 9000
        protocol: TCP
---
# Source: minio/templates/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: minio
      app.kubernetes.io/part-of: minio
  policyTypes:
    - Ingress
    - Egress
  egress:
    # Allow dns resolution
    - ports:
        - port: 53
          protocol: UDP
    # Allow outbound connections to other cluster pods
    - ports:
        - port: 9000
        - port: 9000
      to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-minio
              app.kubernetes.io/name: minio
  ingress:
    # Allow inbound connections
    - ports:
        - port: 9000
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud-minio
              app.kubernetes.io/name: minio
        - podSelector:
            matchLabels:
              nextcloud-minio-client: "true"
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: nextcloud
      - podSelector:
          matchLabels:
            app.kubernetes.io/part-of: minio
      ports:
      - port: 9000
        protocol: TCP
---
# Source: minio/templates/provisioning/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: nextcloud-minio-provisioning
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: provisioning
      app.kubernetes.io/part-of: minio
  policyTypes:
    - Ingress
    - Egress
  egress:
    - {}
  ingress:
---
# Source: minio/templates/console/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nextcloud-minio-console
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2.0.2
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: console
    app.kubernetes.io/part-of: minio
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: console
      app.kubernetes.io/part-of: minio
---
# Source: minio/templates/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: minio
      app.kubernetes.io/part-of: minio
---
# Source: minio/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/part-of: minio
automountServiceAccountToken: false
secrets:
  - name: nextcloud-minio
---
# Source: minio/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
type: Opaque
data:
  root-user: "YWRtaW4="
  root-password: "MzFjMzA5ODNmOGFhYjUzNWIzZjYyOTYwYWUwMTg4YmI0MWVjNTk1Yw=="
---
# Source: minio/templates/provisioning/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-minio-provisioning
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: provisioning
    app.kubernetes.io/part-of: minio
data:
---
# Source: minio/templates/pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "1Gi"
---
# Source: minio/templates/console/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-minio-console
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2.0.2
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: console
    app.kubernetes.io/part-of: minio
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 9090
      targetPort: http
      nodePort: null
  selector:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: console
    app.kubernetes.io/part-of: minio
---
# Source: minio/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
spec:
  type: ClusterIP
  ports:
    - name: tcp-api
      port: 9000
      targetPort: api
      nodePort: null
  selector:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/name: minio
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
---
# Source: minio/templates/application.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud-minio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: minio
    app.kubernetes.io/part-of: minio
spec:
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: minio
      app.kubernetes.io/part-of: minio
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: nextcloud-minio
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: minio
        app.kubernetes.io/version: 2025.6.13
        helm.sh/chart: minio-17.0.11
        app.kubernetes.io/component: minio
        app.kubernetes.io/part-of: minio
      annotations:
        checksum/credentials-secret: 61164740edad5283bc318ad901dc9de6b0a8664a0f69f9d56f0afcb408f1a2e9
    spec:
      
      serviceAccountName: nextcloud-minio
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: nextcloud-minio
                    app.kubernetes.io/name: minio
                    app.kubernetes.io/component: minio
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      automountServiceAccountToken: false
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      initContainers:
      containers:
        - name: minio
          image: registry-1.docker.io/bitnamilegacy/minio:2025.7.23-debian-12-r5
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: MINIO_DISTRIBUTED_MODE_ENABLED
              value: "no"
            - name: MINIO_SCHEME
              value: "http"
            - name: MINIO_FORCE_NEW_KEYS
              value: "no"
            - name: MINIO_ROOT_USER_FILE
              value: /opt/bitnami/minio/secrets/root-user
            - name: MINIO_ROOT_PASSWORD_FILE
              value: /opt/bitnami/minio/secrets/root-password
            - name: MINIO_SKIP_CLIENT
              value: "no"
            - name: MINIO_DEFAULT_BUCKETS
              value: nextcloud
            - name: MINIO_API_PORT_NUMBER
              value: "9000"
            - name: MINIO_BROWSER
              value: "off"
            - name: MINIO_PROMETHEUS_AUTH_TYPE
              value: "public"
            - name: MINIO_DATA_DIR
              value: "/bitnami/minio/data"
          ports:
            - name: api
              containerPort: 9000
          livenessProbe:
            httpGet:
              path: /minio/health/live
              port: api
              scheme: "HTTP"
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 5
          readinessProbe:
            tcpSocket:
              port: api
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 1
            successThreshold: 1
            failureThreshold: 5
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /opt/bitnami/minio/tmp
              subPath: app-tmp-dir
            - name: empty-dir
              mountPath: /.mc
              subPath: app-mc-dir
            - name: minio-credentials
              mountPath: /opt/bitnami/minio/secrets/
            - name: data
              mountPath: /bitnami/minio/data
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: minio-credentials
          secret:
            secretName: nextcloud-minio
        - name: data
          persistentVolumeClaim:
            claimName: nextcloud-minio
---
# Source: minio/templates/console/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud-minio-console
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2.0.2
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: console
    app.kubernetes.io/part-of: minio
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud-minio
      app.kubernetes.io/name: minio
      app.kubernetes.io/component: console
      app.kubernetes.io/part-of: minio
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: nextcloud-minio
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: minio
        app.kubernetes.io/version: 2.0.2
        helm.sh/chart: minio-17.0.11
        app.kubernetes.io/component: console
        app.kubernetes.io/part-of: minio
    spec:
      
      serviceAccountName: nextcloud-minio
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: nextcloud-minio
                    app.kubernetes.io/name: minio
                    app.kubernetes.io/component: console
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      containers:
        - name: console
          image: registry-1.docker.io/bitnamilegacy/minio-object-browser:2.0.2-debian-12-r4
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          args:
            - server
            - --host
            - "0.0.0.0"
            - --port
            - "9090"
          env:
            - name: CONSOLE_MINIO_SERVER
              value: "http://nextcloud-minio:9000"
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          ports:
            - name: http
              containerPort: 9090
          livenessProbe:
            failureThreshold: 5
            initialDelaySeconds: 5
            periodSeconds: 5
            successThreshold: 1
            timeoutSeconds: 5
            tcpSocket:
              port: http
          readinessProbe:
            failureThreshold: 5
            initialDelaySeconds: 5
            periodSeconds: 5
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              path: /minio
              port: http
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /.console
              subPath: app-console-dir
      volumes:
        - name: empty-dir
          emptyDir: {}
---
# Source: minio/templates/provisioning/job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: nextcloud-minio-provisioning
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud-minio
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: minio
    app.kubernetes.io/version: 2025.6.13
    helm.sh/chart: minio-17.0.11
    app.kubernetes.io/component: provisioning
    app.kubernetes.io/part-of: minio
  annotations:
    helm.sh/hook: post-install,post-upgrade
    helm.sh/hook-delete-policy: before-hook-creation
spec:
  backoffLimit: 50
  parallelism: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/version: 2025.6.13
        helm.sh/chart: minio-17.0.11
        app.kubernetes.io/component: provisioning
        app.kubernetes.io/part-of: minio
    spec:
      
      restartPolicy: OnFailure
      terminationGracePeriodSeconds: 0
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      serviceAccountName: nextcloud-minio
      initContainers:
        - name: wait-for-available-minio
          image: registry-1.docker.io/bitnamilegacy/os-shell:12-debian-12-r51
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          command:
            - /bin/bash
            - -c
            - |-
              set -e;
              echo "Waiting for Minio";
              wait-for-port \
                --host=nextcloud-minio \
                --state=inuse \
                --timeout=120 \
                9000;
              echo "Minio is available";
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
      containers:
        - name: minio
          image: registry-1.docker.io/bitnamilegacy/minio:2025.7.23-debian-12-r5
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          command:
            - /bin/bash
            - -c
            - |-
              set -e;
              echo "Start Minio provisioning";

              retry_while() {
                local -r cmd="${1:?cmd is missing}"
                local -r retries="${2:-12}"
                local -r sleep_time="${3:-5}"
                local return_value=1

                read -r -a command <<< "$cmd"
                for ((i = 1 ; i <= retries ; i+=1 )); do
                    "${command[@]}" && return_value=0 && break
                    sleep "$sleep_time"
                done
                return $return_value
              }

              function attachPolicy() {
                local tmp=$(mc admin $1 info provisioning $2 | sed -n -e 's/^Policy.*: \(.*\)$/\1/p');
                IFS=',' read -r -a CURRENT_POLICIES <<< "$tmp";
                if [[ ! "${CURRENT_POLICIES[*]}" =~ "$3" ]]; then
                  mc admin policy attach provisioning $3 --$1=$2;
                fi;
              };

              function detachDanglingPolicies() {
                local tmp=$(mc admin $1 info provisioning $2 | sed -n -e 's/^Policy.*: \(.*\)$/\1/p');
                IFS=',' read -r -a CURRENT_POLICIES <<< "$tmp";
                IFS=',' read -r -a DESIRED_POLICIES <<< "$3";
                for current in "${CURRENT_POLICIES[@]}"; do
                  if [[ ! "${DESIRED_POLICIES[*]}" =~ "${current}" ]]; then
                    mc admin policy detach provisioning $current --$1=$2;
                  fi;
                done;
              }

              function addUsersFromFile() {
                local username=$(grep -oP '^username=\K.+' $1);
                local password=$(grep -oP '^password=\K.+' $1);
                local disabled=$(grep -oP '^disabled=\K.+' $1);
                local policies_list=$(grep -oP '^policies=\K.+' $1);
                local set_policies=$(grep -oP '^setPolicies=\K.+' $1);

                mc admin user add provisioning "${username}" "${password}";

                IFS=',' read -r -a POLICIES <<< "${policies_list}";
                for policy in "${POLICIES[@]}"; do
                  attachPolicy user "${username}" "${policy}";
                done;
                if [ "${set_policies}" == "true" ]; then
                  detachDanglingPolicies user "${username}" "${policies_list}";
                fi;

                local user_status="enable";
                if [[ "${disabled}" != "" && "${disabled,,}" == "true" ]]; then
                  user_status="disable";
                fi;

                mc admin user "${user_status}" provisioning "${username}";
              };
              mc alias set provisioning $MINIO_SCHEME://nextcloud-minio:9000 $(<$MINIO_ROOT_USER_FILE) $(<$MINIO_ROOT_PASSWORD_FILE);

              mc admin service restart provisioning --wait --json;

              # Adding a sleep to ensure that the check below does not cause
              # a race condition. We check for the MinIO port because the
              # "mc admin service restart --wait" command is not working as expected
              sleep 5;
              echo "Waiting for Minio to be available after restart";
              if ! retry_while "mc admin info provisioning"; then
                  echo "Error connecting to Minio"
                  exit 1
              fi
              echo "Minio is available. Executing provisioning commands";
              mc mb provisioning/nextcloud --ignore-existing  ;
              mc version enable provisioning/nextcloud;

              echo "End Minio provisioning";
          env:
            - name: MINIO_SCHEME
              value: "http"
            - name: MINIO_ROOT_USER_FILE
              value: /opt/bitnami/minio/secrets/root-user
            - name: MINIO_ROOT_PASSWORD_FILE
              value: /opt/bitnami/minio/secrets/root-password
          envFrom:
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: empty-dir
              mountPath: /.mc
              subPath: app-mc-dir
            - name: empty-dir
              mountPath: /opt/bitnami/minio/tmp
              subPath: app-tmp-dir
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: minio-provisioning
              mountPath: /etc/ilm
            - name: minio-credentials
              mountPath: /opt/bitnami/minio/secrets/
      volumes:
        - name: empty-dir
          emptyDir: {}
        - name: minio-provisioning
          configMap:
            name: nextcloud-minio-provisioning
        - name: minio-credentials
          secret:
            secretName: nextcloud-minio

---
# Source: nextcloud/templates/networkpolicy-cronjob.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nextcloud-cronjob
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud
      app.kubernetes.io/name: nextcloud
      app.kubernetes.io/component: nextcloud-cronjob
  policyTypes:
    - Ingress
    - Egress
  egress:
    - ports:
        # Allow dns resolution
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - ports:
      - port: 8080
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: keycloak
    - ports:
      - port: 5432
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/component: primary
            app.kubernetes.io/name: postgresql
    - ports:
      - port: 6379
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/component: master
            app.kubernetes.io/name: redis
    - ports:
      - port: 9000
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: minio
    - ports:
      - port: 443
        protocol: TCP
      to: []
    - ports:
      - port: 80
        protocol: TCP
      to: []
  ingress:
    - ports:
        - port: 8080
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud
              app.kubernetes.io/name: nextcloud
        - podSelector:
            matchLabels:
              nextcloud-client: "true"
    - ports:
      - port: 8080
        protocol: TCP
---
# Source: nextcloud/templates/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud
      app.kubernetes.io/name: nextcloud
      app.kubernetes.io/component: nextcloud
  policyTypes:
    - Ingress
    - Egress
  egress:
    - ports:
        # Allow dns resolution
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - ports:
      - port: 8080
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: keycloak
    - ports:
      - port: 5432
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/component: primary
            app.kubernetes.io/name: postgresql
    - ports:
      - port: 6379
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/component: master
            app.kubernetes.io/name: redis
    - ports:
      - port: 9000
        protocol: TCP
      to:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: minio
    - ports:
      - port: 443
        protocol: TCP
      to: []
    - ports:
      - port: 80
        protocol: TCP
      to: []
  ingress:
    - ports:
        - port: 8080
      from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: nextcloud
              app.kubernetes.io/name: nextcloud
        - podSelector:
            matchLabels:
              nextcloud-client: "true"
    - ports:
      - port: 8080
        protocol: TCP
---
# Source: nextcloud/templates/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud
      app.kubernetes.io/name: nextcloud
      app.kubernetes.io/component: nextcloud
---
# Source: nextcloud/templates/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
automountServiceAccountToken: true
---
# Source: nextcloud/templates/secret-database.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-externaldatabase
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
type: Opaque
data:
  username: "bmV4dGNsb3Vk"
  password: "MDc2OTUyMWJjZTc1ODE4NmMwYzI4MTQwMjcxMzEyNGNhZTdmNmEyZg=="
---
# Source: nextcloud/templates/secret-minio.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-externalminio
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
type: Opaque
data:
  username: "YWRtaW4="
  password: "MzFjMzA5ODNmOGFhYjUzNWIzZjYyOTYwYWUwMTg4YmI0MWVjNTk1Yw=="
---
# Source: nextcloud/templates/secret-nextcloud.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
type: Opaque
data:
  nextcloud-username: "YWRtaW4="
  nextcloud-password: "ZDgxOTQ4MmNkMzQyMGQzZTZjNWQ0ODE4NGZkNjRiOThmNTM3YzhjMA=="
---
# Source: nextcloud/templates/secret-redis.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-externalredis
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
type: Opaque
data:
  password: "NmJiYWJlZjQzZDAzNjFiNGUwMDRlNzcyNzk1NDIzNGViYzE4NDMzYw=="
---
# Source: nextcloud/templates/apache-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-apache-config
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
data:
  ports.conf: |
    Listen 8080
    
    <IfModule ssl_module>
    	Listen 443
    </IfModule>
    
    <IfModule mod_gnutls.c>
    	Listen 443
    </IfModule>
  
  000-default.conf: |
    <VirtualHost *:8080>
    	ServerName nextcloud.kubernetes.local
    	DocumentRoot /var/www/html
    	
    	<Directory /var/www/html>
    		AllowOverride All
    		Require all granted
    	</Directory>
    	
    	ErrorLog ${APACHE_LOG_DIR}/error.log
    	CustomLog ${APACHE_LOG_DIR}/access.log combined
    </VirtualHost>
---
# Source: nextcloud/templates/configmap-env-vars.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-env-vars
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
data:
  NEXTCLOUD_TRUSTED_DOMAINS: "nextcloud.kubernetes.local"
  TRUSTED_PROXIES: "10.96.0.0/12"
  FORWARDED_FOR_HEADERS: "X-Forwarded-For"
  OVERWRITEPROTOCOL: https
  
  
  REDIS_HOST: "nextcloud-redis-headless"
  REDIS_HOST_PORT: "6379"
  
  OBJECTSTORE_S3_HOST: "nextcloud-minio"
  OBJECTSTORE_S3_PORT: "9000"
  OBJECTSTORE_S3_BUCKET: "nextcloud"
  OBJECTSTORE_S3_SSL: "false"
  OBJECTSTORE_S3_USEPATH_STYLE: "true"
  OBJECTSTORE_S3_LEGACYAUTH: "false"
  OBJECTSTORE_S3_AUTOCREATE: "false"
  OBJECTSTORE_S3_SSE_C_KEY: ""
  
  POSTGRES_HOST: "nextcloud-cluster-rw"
  POSTGRES_DB: "nextcloud"
---
# Source: nextcloud/templates/configmap-script-post-install.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-script-post-install
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud-scripts
data:
  general-settings.sh: |-
    #!/bin/bash

    php /var/www/html/occ background:cron
    php /var/www/html/occ encryption:enable

    php /var/www/html/occ app:disable dashboard
    php /var/www/html/occ app:disable nextcloud_announcements
    php /var/www/html/occ app:disable photos
    php /var/www/html/occ app:disable recommendations
    php /var/www/html/occ app:disable weather_status
    php /var/www/html/occ app:disable firstrunwizard
    php /var/www/html/occ app:disable notifications
    php /var/www/html/occ app:disable survey_client
    php /var/www/html/occ app:disable user_status
    php /var/www/html/occ app:disable files_reminders

    php /var/www/html/occ app:enable admin_audit
    php /var/www/html/occ app:enable encryption

    php /var/www/html/occ config:app:set core shareapi_allow_links --value=no
    php /var/www/html/occ config:app:set core shareapi_default_permissions --value=15

    php /var/www/html/occ config:app:set files_sharing outgoing_server2server_share_enabled --value=no
    php /var/www/html/occ config:app:set files_sharing incoming_server2server_share_enabled --value=no
    php /var/www/html/occ config:app:set files_sharing federatedTrustedShareAutoAccept --value=no

    php /var/www/html/occ config:app:set sharebymail sendpasswordmail --value=no
    php /var/www/html/occ config:app:set sharebymail replyToInitiator --value=no

    php /var/www/html/occ config:app:set files_downloadlimit download --value=10
    php /var/www/html/occ config:app:set theming name --value=MijnBureau
    php /var/www/html/occ config:app:set theming backgroundMime --value=backgroundColor
    php /var/www/html/occ config:app:set theming primary_color --value=#3E3A3A
    php /var/www/html/occ config:app:set theming background_color --value=#F8F7F7
    php /var/www/html/occ config:app:set theming disable-user-theming --value=yes

    php /var/www/html/occ config:system:set maintenance_window_start --type=integer --value=1
    php /var/www/html/occ config:system:set default_phone_region --value=NL

    # Set default quota for new users
    php /var/www/html/occ config:app:set files default_quota --value="10 GB"
  
  user_oidc.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for OIDC Provider setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up OIDC Provider app..."
  
        echo "Installing OIDC Provider app..."
        if ! php /var/www/html/occ app:install user_oidc; then
          echo "WARNING: Failed to install OIDC Provider app (maybe already present)"
        else
          echo "OIDC Provider app installation completed"
        fi
  
        echo "Enabling OIDC Provider app..."
        if ! php /var/www/html/occ app:enable user_oidc; then
          echo "WARNING: Failed to enable OIDC Provider app"
        else
          echo "OIDC Provider app enablement completed"
        fi
        echo "Configuring OIDC provider..."
        if ! php /var/www/html/occ user_oidc:provider keycloak \
          --clientid="nextcloud" \
          --clientsecret="5c1b336790d40b7e6f57a265487a5c2daabf1bc4" \
          --discoveryuri="/.well-known/openid-configuration"; then
          echo "WARNING: Failed to configure OIDC provider"
        else
          echo "OIDC provider configuration completed"
          php /var/www/html/occ config:app:set user_oidc provider-1-checkBearer --value=1
          php /var/www/html/occ config:app:set user_oidc provider-1-bearerProvisioning --value=1
          php /var/www/html/occ config:app:set user_oidc allow_multiple_user_backends  --value=0
        fi
  
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
  
  richdocuments.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for Rich Documents setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up Rich Documents app..."
  
        echo "Installing Rich Documents app..."
        if ! php /var/www/html/occ app:install richdocuments; then
          echo "WARNING: Failed to install Rich Documents app (maybe already present)"
        else
          echo "Rich Documents app installation completed"
        fi
  
        echo "Enabling Rich Documents app..."
        if ! php /var/www/html/occ app:enable richdocuments; then
          echo "WARNING: Failed to enable Rich Documents app"
        else
          echo "Rich Documents app enablement completed"
        fi
        echo "Configuring WOPI URL for richdocuments..."
        if ! php /var/www/html/occ config:app:set richdocuments wopi_url --value="https://collabora.kubernetes.local"; then
          echo "WARNING: Failed to configure WOPI URL"
        else
          echo "WOPI URL configuration completed"
        fi

        echo "Configuring WOPI Allow List for richdocuments..."
        if ! php /var/www/html/occ config:app:set richdocuments wopi_allowlist --value="10.244.0.0/16"; then
            echo "WARNING: Failed to configure WOPI Allow List"
        else
            echo "WOPI Allow List configuration completed"
        fi
  
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done

  # Ref: https://github.com/nextcloud/all-in-one/blob/main/Containers/nextcloud/entrypoint.sh#L870
  
  drawio.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for drawio setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up drawio app..."
  
        echo "Installing drawio app..."
        if ! php /var/www/html/occ app:install drawio; then
          echo "WARNING: Failed to install drawio app (maybe already present)"
        else
          echo "drawio app installation completed"
        fi
  
        echo "Enabling drawio app..."
        if ! php /var/www/html/occ app:enable drawio; then
          echo "WARNING: Failed to enable drawio app"
        else
          echo "drawio app enablement completed"
        fi
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
  
  deck.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for deck setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up deck app..."
  
        echo "Installing deck app..."
        if ! php /var/www/html/occ app:install deck; then
          echo "WARNING: Failed to install deck app (maybe already present)"
        else
          echo "deck app installation completed"
        fi
  
        echo "Enabling deck app..."
        if ! php /var/www/html/occ app:enable deck; then
          echo "WARNING: Failed to enable deck app"
        else
          echo "deck app enablement completed"
        fi
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
  
  groupfolders.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for groupfolders setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up groupfolders app..."
  
        echo "Installing groupfolders app..."
        if ! php /var/www/html/occ app:install groupfolders; then
          echo "WARNING: Failed to install groupfolders app (maybe already present)"
        else
          echo "groupfolders app installation completed"
        fi
  
        echo "Enabling groupfolders app..."
        if ! php /var/www/html/occ app:enable groupfolders; then
          echo "WARNING: Failed to enable groupfolders app"
        else
          echo "groupfolders app enablement completed"
        fi
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
  
  contacts.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for contacts setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up contacts app..."
  
        echo "Installing contacts app..."
        if ! php /var/www/html/occ app:install contacts; then
          echo "WARNING: Failed to install contacts app (maybe already present)"
        else
          echo "contacts app installation completed"
        fi
  
        echo "Enabling contacts app..."
        if ! php /var/www/html/occ app:enable contacts; then
          echo "WARNING: Failed to enable contacts app"
        else
          echo "contacts app enablement completed"
        fi
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
  
  files_accesscontrol.sh: |-
    #!/bin/bash
  
    echo "Waiting for NextCloud to be ready for files access control setup..."
    counter=0
    while [ "$counter" -lt 60 ]; do
      if php /var/www/html/occ status | grep -q "installed: true"; then
        echo "NextCloud is ready, setting up files access control app..."
  
        echo "Installing files access control app..."
        if ! php /var/www/html/occ app:install files_accesscontrol; then
          echo "WARNING: Failed to install files access control app (maybe already present)"
        else
          echo "files access control app installation completed"
        fi
  
        echo "Enabling files access control app..."
        if ! php /var/www/html/occ app:enable files_accesscontrol; then
          echo "WARNING: Failed to enable files access control app"
        else
          echo "files access control app enablement completed"
        fi
        break
      fi
      echo "Waiting for NextCloud... ($counter/60)"
      sleep 5
      counter=$((counter + 5))
    done
---
# Source: nextcloud/templates/nextcloud-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nextcloud-config
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
data:
  .htaccess: |-
    # line below if for Apache 2.4
    <ifModule mod_authz_core.c>
    Require all denied
    </ifModule>
    # line below if for Apache 2.2
    <ifModule !mod_authz_core.c>
    deny from all
    </ifModule>
    # section for Apache 2.2 and 2.4
    <ifModule mod_autoindex.c>
    IndexIgnore *
    </ifModule>
  apache-pretty-urls.config.php: |-
    <?php
    $CONFIG = array (
      'htaccess.RewriteBase' => '/',
    );
  apcu.config.php: |-
    <?php
    $CONFIG = array (
      'memcache.local' => '\OC\Memcache\APCu',
    );
  apps.config.php: |-
    <?php
    $CONFIG = array (
      'apps_paths' => array (
          0 => array (
                  'path'     => OC::$SERVERROOT.'/apps',
                  'url'      => '/apps',
                  'writable' => false,
          ),
          1 => array (
                  'path'     => OC::$SERVERROOT.'/custom_apps',
                  'url'      => '/custom_apps',
                  'writable' => true,
          ),
      ),
    );
  autoconfig.php: |-
    <?php
    $autoconfig_enabled = false;
    if (getenv('SQLITE_DATABASE')) {
        $AUTOCONFIG["dbtype"] = "sqlite";
        $AUTOCONFIG["dbname"] = getenv('SQLITE_DATABASE');
        $autoconfig_enabled = true;
    } elseif (getenv('MYSQL_DATABASE_FILE') && getenv('MYSQL_USER_FILE') && getenv('MYSQL_PASSWORD_FILE') && getenv('MYSQL_HOST')) {
        $AUTOCONFIG['dbtype'] = 'mysql';
        $AUTOCONFIG['dbname'] = trim(file_get_contents(getenv('MYSQL_DATABASE_FILE')));
        $AUTOCONFIG['dbuser'] = trim(file_get_contents(getenv('MYSQL_USER_FILE')));
        $AUTOCONFIG['dbpass'] = trim(file_get_contents(getenv('MYSQL_PASSWORD_FILE')));
        $AUTOCONFIG['dbhost'] = getenv('MYSQL_HOST');
        $autoconfig_enabled = true;
    } elseif (getenv('MYSQL_DATABASE') && getenv('MYSQL_USER') && getenv('MYSQL_PASSWORD') && getenv('MYSQL_HOST')) {
        $AUTOCONFIG["dbtype"] = "mysql";
        $AUTOCONFIG["dbname"] = getenv('MYSQL_DATABASE');
        $AUTOCONFIG["dbuser"] = getenv('MYSQL_USER');
        $AUTOCONFIG["dbpass"] = getenv('MYSQL_PASSWORD');
        $AUTOCONFIG["dbhost"] = getenv('MYSQL_HOST');
        $autoconfig_enabled = true;
    } elseif (getenv('POSTGRES_DB_FILE') && getenv('POSTGRES_USER_FILE') && getenv('POSTGRES_PASSWORD_FILE') && getenv('POSTGRES_HOST')) {
        $AUTOCONFIG['dbtype'] = 'pgsql';
        $AUTOCONFIG['dbname'] = trim(file_get_contents(getenv('POSTGRES_DB_FILE')));
        $AUTOCONFIG['dbuser'] = trim(file_get_contents(getenv('POSTGRES_USER_FILE')));
        $AUTOCONFIG['dbpass'] = trim(file_get_contents(getenv('POSTGRES_PASSWORD_FILE')));
        $AUTOCONFIG['dbhost'] = getenv('POSTGRES_HOST');
        $autoconfig_enabled = true;
    } elseif (getenv('POSTGRES_DB') && getenv('POSTGRES_USER') && getenv('POSTGRES_PASSWORD') && getenv('POSTGRES_HOST')) {
        $AUTOCONFIG["dbtype"] = "pgsql";
        $AUTOCONFIG["dbname"] = getenv('POSTGRES_DB');
        $AUTOCONFIG["dbuser"] = getenv('POSTGRES_USER');
        $AUTOCONFIG["dbpass"] = getenv('POSTGRES_PASSWORD');
        $AUTOCONFIG["dbhost"] = getenv('POSTGRES_HOST');
        $autoconfig_enabled = true;
    }
    if ($autoconfig_enabled) {
        $AUTOCONFIG["directory"] = getenv('NEXTCLOUD_DATA_DIR') ?: "/var/www/html/data";
    }
  redis.config.php: |-
    <?php
    if (getenv('REDIS_HOST')) {
      $CONFIG = array(
        'memcache.distributed' => '\OC\Memcache\Redis',
        'memcache.locking' => '\OC\Memcache\Redis',
        'redis' => array(
          'host' => getenv('REDIS_HOST'),
          'password' => getenv('REDIS_HOST_PASSWORD_FILE') ? trim(file_get_contents(getenv('REDIS_HOST_PASSWORD_FILE'))) : (string) getenv('REDIS_HOST_PASSWORD'),
        ),
      );
    
      if (getenv('REDIS_HOST_PORT') !== false) {
        $CONFIG['redis']['port'] = (int) getenv('REDIS_HOST_PORT');
      } elseif (getenv('REDIS_HOST')[0] != '/') {
        $CONFIG['redis']['port'] = 6379;
      }
    }
  reverse-proxy.config.php: |-
    <?php
    $overwriteHost = getenv('OVERWRITEHOST');
    if ($overwriteHost) {
      $CONFIG['overwritehost'] = $overwriteHost;
    }
    
    $overwriteProtocol = getenv('OVERWRITEPROTOCOL');
    if ($overwriteProtocol) {
      $CONFIG['overwriteprotocol'] = $overwriteProtocol;
    }
    
    $overwriteCliUrl = getenv('OVERWRITECLIURL');
    if ($overwriteCliUrl) {
      $CONFIG['overwrite.cli.url'] = $overwriteCliUrl;
    }
    
    $overwriteWebRoot = getenv('OVERWRITEWEBROOT');
    if ($overwriteWebRoot) {
      $CONFIG['overwritewebroot'] = $overwriteWebRoot;
    }
    
    $overwriteCondAddr = getenv('OVERWRITECONDADDR');
    if ($overwriteCondAddr) {
      $CONFIG['overwritecondaddr'] = $overwriteCondAddr;
    }
    
    $trustedProxies = getenv('TRUSTED_PROXIES');
    if ($trustedProxies) {
      $CONFIG['trusted_proxies'] = array_filter(array_map('trim', explode(' ', $trustedProxies)));
    }
    
    $forwardedForHeaders = getenv('FORWARDED_FOR_HEADERS');
    if ($forwardedForHeaders) {
      $CONFIG['forwarded_for_headers'] = array_filter(array_map('trim', explode(' ', $forwardedForHeaders)));
    }
  s3.config.php: |-
    <?php
    if (getenv('OBJECTSTORE_S3_BUCKET')) {
      $use_ssl = getenv('OBJECTSTORE_S3_SSL');
      $use_path = getenv('OBJECTSTORE_S3_USEPATH_STYLE');
      $use_legacyauth = getenv('OBJECTSTORE_S3_LEGACYAUTH');
      $autocreate = getenv('OBJECTSTORE_S3_AUTOCREATE');
      $CONFIG = array(
        'objectstore' => array(
          'class' => '\OC\Files\ObjectStore\S3',
          'arguments' => array(
            'bucket' => getenv('OBJECTSTORE_S3_BUCKET'),
            'region' => getenv('OBJECTSTORE_S3_REGION') ?: '',
            'hostname' => getenv('OBJECTSTORE_S3_HOST') ?: '',
            'port' => getenv('OBJECTSTORE_S3_PORT') ?: '',
            'storageClass' => getenv('OBJECTSTORE_S3_STORAGE_CLASS') ?: '',
            'objectPrefix' => getenv("OBJECTSTORE_S3_OBJECT_PREFIX") ? getenv("OBJECTSTORE_S3_OBJECT_PREFIX") : "urn:oid:",
            'autocreate' => strtolower($autocreate) !== 'false',
            'use_ssl' => strtolower($use_ssl) !== 'false',
            // required for some non Amazon S3 implementations
            'use_path_style' => strtolower($use_path) !== 'false',
            // required for older protocol versions
            'legacy_auth' => $use_legacyauth == true && strtolower($use_legacyauth) !== 'false'
          )
        )
      );
    
      if (getenv('OBJECTSTORE_S3_KEY_FILE')) {
        $CONFIG['objectstore']['arguments']['key'] = trim(file_get_contents(getenv('OBJECTSTORE_S3_KEY_FILE')));
      } elseif (getenv('OBJECTSTORE_S3_KEY')) {
        $CONFIG['objectstore']['arguments']['key'] = getenv('OBJECTSTORE_S3_KEY');
      } else {
        $CONFIG['objectstore']['arguments']['key'] = '';
      }
    
      if (getenv('OBJECTSTORE_S3_SECRET_FILE')) {
        $CONFIG['objectstore']['arguments']['secret'] = trim(file_get_contents(getenv('OBJECTSTORE_S3_SECRET_FILE')));
      } elseif (getenv('OBJECTSTORE_S3_SECRET')) {
        $CONFIG['objectstore']['arguments']['secret'] = getenv('OBJECTSTORE_S3_SECRET');
      } else {
        $CONFIG['objectstore']['arguments']['secret'] = '';
      }
    
      if (getenv('OBJECTSTORE_S3_SSE_C_KEY_FILE')) {
        $CONFIG['objectstore']['arguments']['sse_c_key'] = trim(file_get_contents(getenv('OBJECTSTORE_S3_SSE_C_KEY_FILE')));
      } elseif (getenv('OBJECTSTORE_S3_SSE_C_KEY')) {
        $CONFIG['objectstore']['arguments']['sse_c_key'] = getenv('OBJECTSTORE_S3_SSE_C_KEY');
      }
    }
  swift.config.php: |-
    <?php
    if (getenv('OBJECTSTORE_SWIFT_URL')) {
        $autocreate = getenv('OBJECTSTORE_SWIFT_AUTOCREATE');
      $CONFIG = array(
        'objectstore' => [
          'class' => 'OC\\Files\\ObjectStore\\Swift',
          'arguments' => [
            'autocreate' => $autocreate == true && strtolower($autocreate) !== 'false',
            'user' => [
              'name' => getenv('OBJECTSTORE_SWIFT_USER_NAME'),
              'password' => getenv('OBJECTSTORE_SWIFT_USER_PASSWORD'),
              'domain' => [
                'name' => (getenv('OBJECTSTORE_SWIFT_USER_DOMAIN')) ?: 'Default',
              ],
            ],
            'scope' => [
              'project' => [
                'name' => getenv('OBJECTSTORE_SWIFT_PROJECT_NAME'),
                'domain' => [
                  'name' => (getenv('OBJECTSTORE_SWIFT_PROJECT_DOMAIN')) ?: 'Default',
                ],
              ],
            ],
            'serviceName' => (getenv('OBJECTSTORE_SWIFT_SERVICE_NAME')) ?: 'swift',
            'region' => getenv('OBJECTSTORE_SWIFT_REGION'),
            'url' => getenv('OBJECTSTORE_SWIFT_URL'),
            'bucket' => getenv('OBJECTSTORE_SWIFT_CONTAINER_NAME'),
          ]
        ]
      );
    }
  smtp.config.php: |-
    <?php
    if (getenv('SMTP_HOST') && getenv('MAIL_FROM_ADDRESS') && getenv('MAIL_DOMAIN')) {
      $CONFIG = array (
        'mail_smtpmode' => 'smtp',
        'mail_smtphost' => getenv('SMTP_HOST'),
        'mail_smtpport' => getenv('SMTP_PORT') ?: (getenv('SMTP_SECURE') ? 465 : 25),
        'mail_smtpsecure' => getenv('SMTP_SECURE') ?: '',
        'mail_smtpauth' => getenv('SMTP_NAME') && (getenv('SMTP_PASSWORD') || getenv('SMTP_PASSWORD_FILE')),
        'mail_smtpauthtype' => getenv('SMTP_AUTHTYPE') ?: 'LOGIN',
        'mail_smtpname' => getenv('SMTP_NAME') ?: '',
        'mail_from_address' => getenv('MAIL_FROM_ADDRESS'),
        'mail_domain' => getenv('MAIL_DOMAIN'),
      );
    
      if (getenv('SMTP_PASSWORD_FILE')) {
          $CONFIG['mail_smtppassword'] = trim(file_get_contents(getenv('SMTP_PASSWORD_FILE')));
      } elseif (getenv('SMTP_PASSWORD')) {
          $CONFIG['mail_smtppassword'] = getenv('SMTP_PASSWORD');
      } else {
          $CONFIG['mail_smtppassword'] = '';
      }
    }
  upgrade-disable-web.config.php: |-
    <?php
    $CONFIG = array (
      'upgrade.disable-web' => true,
    );
  empty-skeleton.config.php: |-
    <?php
    $CONFIG = array (
      'skeletondirectory' => '/var/www/html/empty-skeleton',
    );
---
# Source: nextcloud/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "1Gi"
---
# Source: nextcloud/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: http
      port: 8080
      protocol: TCP
      nodePort: null
  selector:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/component: nextcloud
---
# Source: nextcloud/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/instance: nextcloud
      app.kubernetes.io/name: nextcloud
      app.kubernetes.io/component: nextcloud
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: nextcloud
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: nextcloud
        app.kubernetes.io/version: 33.0.0
        helm.sh/chart: nextcloud-0.1.0
        app.kubernetes.io/component: nextcloud
    spec:
      
      serviceAccountName: nextcloud
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: nextcloud
                    app.kubernetes.io/name: nextcloud
                    app.kubernetes.io/component: nextcloud
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      initContainers:
        - name: "nextcloud-php-provisioning"
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          image: registry-1.docker.io/library/nextcloud:33.0.0-apache
          imagePullPolicy: Always
          command:
            - /bin/bash
            - -ec
            - |
              #!/bin/bash

              echo "Start provisioning"
              cp /usr/local/etc/php/php.ini-production /shared/php.ini
              mkdir -p /shared/conf.d
              echo "Setup default PHP config"
              cp /usr/local/etc/php/conf.d/*.ini /shared/conf.d/
              if [ -d /php-configs ]; then
                echo "Setup custom PHP config"
                cp /php-configs/* /shared/conf.d/
              fi
              echo "Provisioning completed"
          volumeMounts:
            - name: empty-dir
              mountPath: /shared
      containers:
        - name: "nextcloud"
          image: registry-1.docker.io/library/nextcloud:33.0.0-apache
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: NEXTCLOUD_ADMIN_USER
              valueFrom:
                secretKeyRef:
                  name: nextcloud
                  key: nextcloud-username
            - name: NEXTCLOUD_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: nextcloud
                  key: nextcloud-password
            
            - name: REDIS_HOST_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: nextcloud-externalredis
                  key: password
            
            - name: OBJECTSTORE_S3_KEY
              valueFrom:
                secretKeyRef:
                  name: nextcloud-externalminio
                  key: username
            - name: OBJECTSTORE_S3_SECRET
              valueFrom:
                secretKeyRef:
                  name: nextcloud-externalminio
                  key: password
            
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: nextcloud-externaldatabase
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: nextcloud-externaldatabase
                  key: password
          envFrom:
            - configMapRef:
                name: nextcloud-env-vars
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          ports:
            - name: http
              containerPort: 8080
          lifecycle:
          volumeMounts:
            - name: post-install-dir
              mountPath: /docker-entrypoint-hooks.d/post-installation
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - name: empty-dir
              mountPath: /usr/local/etc/php/php.ini
              subPath: php.ini
            - name: empty-dir
              mountPath: /usr/local/etc/php/conf.d
              #subPath: conf.d
            - name: empty-dir
              mountPath: /var/run/apache2
              subPath: apache-run
            - name: nextcloud-data
              mountPath: /var/www/
              subPath: root
            - name: nextcloud-data
              mountPath: /var/www/html
              subPath: html
            - name: nextcloud-data
              mountPath: /var/www/html/config
              subPath: config
            - name: nextcloud-data
              mountPath: /var/www/html/custom_apps
              subPath: custom_apps
            - name: nextcloud-data
              mountPath: /var/www/tmp
              subPath: tmp
            - name: nextcloud-data
              mountPath: /var/www/html/themes
              subPath: themes
            - name: nextcloud-config
              mountPath: /var/www/html/config/.htaccess
              subPath: .htaccess
            - name: nextcloud-config
              mountPath: /var/www/html/config/apache-pretty-urls.config.php
              subPath: apache-pretty-urls.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/apcu.config.php
              subPath: apcu.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/apps.config.php
              subPath: apps.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/autoconfig.php
              subPath: autoconfig.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/empty-skeleton.config.php
              subPath: empty-skeleton.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/redis.config.php
              subPath: redis.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/reverse-proxy.config.php
              subPath: reverse-proxy.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/s3.config.php
              subPath: s3.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/smtp.config.php
              subPath: smtp.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/swift.config.php
              subPath: swift.config.php
            - name: nextcloud-config
              mountPath: /var/www/html/config/upgrade-disable-web.config.php
              subPath: upgrade-disable-web.config.php
            - name: nextcloud-apache-config
              mountPath: /etc/apache2/ports.conf
              subPath: ports.conf
            - name: nextcloud-apache-config
              mountPath: /etc/apache2/sites-available/000-default.conf
              subPath: 000-default.conf
      volumes:
        - name: post-install-dir
          configMap:
            name: nextcloud-script-post-install
            defaultMode: 0755
        - name: empty-dir
          emptyDir: {}
        - name: nextcloud-data
          persistentVolumeClaim:
            claimName: nextcloud
        - name: nextcloud-config
          configMap:
            name: nextcloud-config
        - name: nextcloud-apache-config
          configMap:
            name: nextcloud-apache-config
---
# Source: nextcloud/templates/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nextcloud
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
---
# Source: nextcloud/templates/cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: nextcloud-cronjob
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud-cronjob
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 1
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 60
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 120
      template:
        metadata:
          labels:
            app.kubernetes.io/name: nextcloud
            app.kubernetes.io/instance: nextcloud
            app.kubernetes.io/component: nextcloud-cronjob
        spec:
          
          restartPolicy: OnFailure
          serviceAccountName: nextcloud
          initContainers:
            - name: "nextcloud-php-provisioning"
              image: registry-1.docker.io/library/nextcloud:33.0.0-apache
              imagePullPolicy: Always
              command:
                - /bin/bash
                - -ec
                - |
                  #!/bin/bash

                  echo "Start provisioning"
                  cp /usr/local/etc/php/php.ini-production /shared/php.ini
                  mkdir -p /shared/conf.d
                  echo "Setup default PHP config"
                  cp /usr/local/etc/php/conf.d/*.ini /shared/conf.d/
                  if [ -d /php-configs ]; then
                    echo "Setup custom PHP config"
                    cp /php-configs/* /shared/conf.d/
                  fi
                  echo "Provisioning completed"
              volumeMounts:
                - name: empty-dir
                  mountPath: /shared

          containers:
            - name: nextcloud-cronjob
              image: registry-1.docker.io/library/nextcloud:33.0.0-apache
              imagePullPolicy: Always
              securityContext:
                allowPrivilegeEscalation: false
                capabilities:
                  drop:
                  - ALL
                privileged: false
                readOnlyRootFilesystem: true
                runAsGroup: 1001
                runAsNonRoot: true
                runAsUser: 1001
                seLinuxOptions: {}
                seccompProfile:
                  type: RuntimeDefault
              command:
                - /bin/sh
              args:
                - -c
                - |
                  php -f /var/www/html/cron.php
              resources:
                limits:
                  cpu: 200m
                  memory: 128Mi
                requests:
                  cpu: 100m
                  memory: 64Mi
              env:
                - name: NEXTCLOUD_ADMIN_USER
                  valueFrom:
                    secretKeyRef:
                      name: nextcloud
                      key: nextcloud-username
                - name: NEXTCLOUD_ADMIN_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: nextcloud
                      key: nextcloud-password
                - name: REDIS_HOST_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: nextcloud-externalredis
                      key: password
                - name: POSTGRES_USER
                  valueFrom:
                    secretKeyRef:
                      name: nextcloud-externaldatabase
                      key: username
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: nextcloud-externaldatabase
                      key: password
              envFrom:
                - configMapRef:
                    name: nextcloud-env-vars
              volumeMounts:
                - name: empty-dir
                  mountPath: /tmp
                  subPath: tmp-dir
                - name: empty-dir
                  mountPath: /usr/local/etc/php/php.ini
                  subPath: php.ini
                - name: empty-dir
                  mountPath: /usr/local/etc/php/conf.d
                  subPath: conf.d
                - name: empty-dir
                  mountPath: /var/run/apache2
                  subPath: apache-run
                - name: nextcloud-data
                  mountPath: /var/www/
                  subPath: root
                - name: nextcloud-data
                  mountPath: /var/www/html
                  subPath: html
                - name: nextcloud-data
                  mountPath: /var/www/html/config
                  subPath: config
                - name: nextcloud-data
                  mountPath: /var/www/html/custom_apps
                  subPath: custom_apps
                - name: nextcloud-data
                  mountPath: /var/www/tmp
                  subPath: tmp
                - name: nextcloud-data
                  mountPath: /var/www/html/themes
                  subPath: themes
                - name: nextcloud-config
                  mountPath: /var/www/html/config/.htaccess
                  subPath: .htaccess
                - name: nextcloud-config
                  mountPath: /var/www/html/config/apache-pretty-urls.config.php
                  subPath: apache-pretty-urls.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/apcu.config.php
                  subPath: apcu.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/apps.config.php
                  subPath: apps.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/autoconfig.php
                  subPath: autoconfig.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/empty-skeleton.config.php
                  subPath: empty-skeleton.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/redis.config.php
                  subPath: redis.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/reverse-proxy.config.php
                  subPath: reverse-proxy.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/s3.config.php
                  subPath: s3.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/smtp.config.php
                  subPath: smtp.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/swift.config.php
                  subPath: swift.config.php
                - name: nextcloud-config
                  mountPath: /var/www/html/config/upgrade-disable-web.config.php
                  subPath: upgrade-disable-web.config.php
                - name: nextcloud-apache-config
                  mountPath: /etc/apache2/ports.conf
                  subPath: ports.conf
                - name: nextcloud-apache-config
                  mountPath: /etc/apache2/sites-available/000-default.conf
                  subPath: 000-default.conf
          volumes:
            - name: empty-dir
              emptyDir: {}
            - name: nextcloud-data
              persistentVolumeClaim:
                claimName: nextcloud
            - name: nextcloud-config
              configMap:
                name: nextcloud-config
            - name: nextcloud-apache-config
              configMap:
                name: nextcloud-apache-config
---
# Source: nextcloud/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud
  namespace: "default"
  labels:
    app.kubernetes.io/instance: nextcloud
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: nextcloud
    app.kubernetes.io/version: 33.0.0
    helm.sh/chart: nextcloud-0.1.0
    app.kubernetes.io/component: nextcloud
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  rules:
    - host: nextcloud.kubernetes.local
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: nextcloud
                port:
                  name: http

---
# Source: redis/templates/networkpolicy.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: bureaublad-redis
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad-redis
      app.kubernetes.io/name: redis
  policyTypes:
    - Ingress
    - Egress
  egress:
  ingress:
    # Allow inbound connections
    - ports:
        - port: 6379
      from:
        - podSelector:
            matchLabels:
              bureaublad-redis-client: "true"
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: bureaublad-redis
              app.kubernetes.io/name: redis
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: bureaublad
      ports:
      - port: 6379
        protocol: TCP
---
# Source: redis/templates/master/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: bureaublad-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad-redis
      app.kubernetes.io/name: redis
      app.kubernetes.io/component: master
---
# Source: redis/templates/master/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
automountServiceAccountToken: false
metadata:
  name: bureaublad-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
---
# Source: redis/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: bureaublad-redis
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
type: Opaque
data:
  redis-password: "MjA1YzE0MDUzZDczNmY1MmUxZDMxMDI0ZTU3OGRkODkyYjlkYjhmNg=="
---
# Source: redis/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bureaublad-redis-configuration
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  redis.conf: |-
    # User-supplied common configuration:
    # Enable AOF https://redis.io/topics/persistence#append-only-file
    appendonly yes
    # Disable RDB persistence, AOF persistence already enabled.
    save ""
    # End of common configuration
  master.conf: |-
    dir /data
    # User-supplied master configuration:
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
    # End of master configuration
  replica.conf: |-
    dir /data
    # User-supplied replica configuration:
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
    # End of replica configuration
  users.acl: |-
---
# Source: redis/templates/health-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bureaublad-redis-health
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  ping_readiness_local.sh: |-
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    [[ -n "$REDIS_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_local.sh: |-
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    [[ -n "$REDIS_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    responseFirstWord=$(echo $response | head -n1 | awk '{print $1;}')
    if [ "$response" != "PONG" ] && [ "$responseFirstWord" != "LOADING" ] && [ "$responseFirstWord" != "MASTERDOWN" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_master.sh: |-
    #!/bin/bash

    [[ -f $REDIS_MASTER_PASSWORD_FILE ]] && export REDIS_MASTER_PASSWORD="$(< "${REDIS_MASTER_PASSWORD_FILE}")"
    [[ -n "$REDIS_MASTER_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_MASTER_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_master.sh: |-
    #!/bin/bash

    [[ -f $REDIS_MASTER_PASSWORD_FILE ]] && export REDIS_MASTER_PASSWORD="$(< "${REDIS_MASTER_PASSWORD_FILE}")"
    [[ -n "$REDIS_MASTER_PASSWORD" ]] && export REDISCLI_AUTH="$REDIS_MASTER_PASSWORD"
    response=$(
      timeout -s 15 $1 \
      redis-cli \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$?" -eq "124" ]; then
      echo "Timed out"
      exit 1
    fi
    responseFirstWord=$(echo $response | head -n1 | awk '{print $1;}')
    if [ "$response" != "PONG" ] && [ "$responseFirstWord" != "LOADING" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_readiness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_readiness_master.sh" $1 || exit_status=$?
    exit $exit_status
  ping_liveness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_liveness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_liveness_master.sh" $1 || exit_status=$?
    exit $exit_status
---
# Source: redis/templates/scripts-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bureaublad-redis-scripts
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
data:
  start-master.sh: |
    #!/bin/bash

    [[ -f $REDIS_PASSWORD_FILE ]] && export REDIS_PASSWORD="$(< "${REDIS_PASSWORD_FILE}")"
    if [[ -f /opt/bitnami/redis/mounted-etc/master.conf ]];then
        cp /opt/bitnami/redis/mounted-etc/master.conf /opt/bitnami/redis/etc/master.conf
    fi
    if [[ -f /opt/bitnami/redis/mounted-etc/redis.conf ]];then
        cp /opt/bitnami/redis/mounted-etc/redis.conf /opt/bitnami/redis/etc/redis.conf
    fi
    if [[ -f /opt/bitnami/redis/mounted-etc/users.acl ]];then
        cp /opt/bitnami/redis/mounted-etc/users.acl /opt/bitnami/redis/etc/users.acl
    fi
    ARGS=("--port" "${REDIS_PORT}")
    ARGS+=("--requirepass" "${REDIS_PASSWORD}")
    ARGS+=("--masterauth" "${REDIS_PASSWORD}")
    ARGS+=("--include" "/opt/bitnami/redis/etc/redis.conf")
    ARGS+=("--include" "/opt/bitnami/redis/etc/master.conf")
    exec redis-server "${ARGS[@]}"
---
# Source: redis/templates/headless-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: bureaublad-redis-headless
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
  selector:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/name: redis
---
# Source: redis/templates/master/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: bureaublad-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  type: ClusterIP
  internalTrafficPolicy: Cluster
  sessionAffinity: None
  ports:
    - name: tcp-redis
      port: 6379
      targetPort: redis
      nodePort: null
  selector:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: master
---
# Source: redis/templates/master/application.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: bureaublad-redis-master
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad-redis
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: redis
    app.kubernetes.io/version: 8.0.2
    helm.sh/chart: redis-21.2.6
    app.kubernetes.io/component: master
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad-redis
      app.kubernetes.io/name: redis
      app.kubernetes.io/component: master
  serviceName: bureaublad-redis-headless
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: bureaublad-redis
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: redis
        app.kubernetes.io/version: 8.0.2
        helm.sh/chart: redis-21.2.6
        app.kubernetes.io/component: master
      annotations:
        checksum/configmap: 2a9ab4a5432825504d910f022638674ce88eaefe9f9f595ad8bc107377d104fb
        checksum/health: aff24913d801436ea469d8d374b2ddb3ec4c43ee7ab24663d5f8ff1a1b6991a9
        checksum/scripts: 0717e77fd3bb941f602860e9be4f2ed87b481cddeadf37be463f8512ecde0c3e
        checksum/secret: 7368ce71f33fe766e44d428a087c2e466e0550bcb935c67d2fa57e8474fc6e61
    spec:
      
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      serviceAccountName: bureaublad-redis-master
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: bureaublad-redis
                    app.kubernetes.io/name: redis
                    app.kubernetes.io/component: master
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      enableServiceLinks: true
      terminationGracePeriodSeconds: 30
      containers:
        - name: redis
          image: registry-1.docker.io/bitnamilegacy/redis:8.2.1-debian-12-r0
          imagePullPolicy: "Always"
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          command:
            - /bin/bash
          args:
            - -ec
            - /opt/bitnami/scripts/start-scripts/start-master.sh
          env:
            - name: BITNAMI_DEBUG
              value: "false"
            - name: REDIS_REPLICATION_MODE
              value: master
            - name: ALLOW_EMPTY_PASSWORD
              value: "no"
            - name: REDIS_PASSWORD_FILE
              value: "/opt/bitnami/redis/secrets/redis-password"
            - name: REDIS_TLS_ENABLED
              value: "no"
            - name: REDIS_PORT
              value: "6379"
          ports:
            - name: redis
              containerPort: 6379
          livenessProbe:
            initialDelaySeconds: 20
            periodSeconds: 5
            # One second longer than command timeout should prevent generation of zombie processes.
            timeoutSeconds: 6
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - /bin/bash
                - -ec
                - "/health/ping_liveness_local.sh 5"
          readinessProbe:
            initialDelaySeconds: 20
            periodSeconds: 5
            timeoutSeconds: 2
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - /bin/bash
                - -ec
                - "/health/ping_readiness_local.sh 1"
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          volumeMounts:
            - name: start-scripts
              mountPath: /opt/bitnami/scripts/start-scripts
            - name: health
              mountPath: /health
            - name: redis-password
              mountPath: /opt/bitnami/redis/secrets/
            - name: redis-data
              mountPath: /data
            - name: config
              mountPath: /opt/bitnami/redis/mounted-etc
            - name: empty-dir
              mountPath: /opt/bitnami/redis/etc/
              subPath: app-conf-dir
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
      volumes:
        - name: start-scripts
          configMap:
            name: bureaublad-redis-scripts
            defaultMode: 0755
        - name: health
          configMap:
            name: bureaublad-redis-health
            defaultMode: 0755
        - name: redis-password
          
          secret:
            secretName: bureaublad-redis
            items:
            - key: redis-password
              path: redis-password
        - name: config
          configMap:
            name: bureaublad-redis-configuration
        - name: empty-dir
          emptyDir: {}
  volumeClaimTemplates:
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: redis-data
        labels:
          app.kubernetes.io/instance: bureaublad-redis
          app.kubernetes.io/name: redis
          app.kubernetes.io/component: master
      spec:
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: "1Gi"

---
# Source: bureaublad/templates/frontend-networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: bureaublad-frontend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-frontend
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad
      app.kubernetes.io/name: bureaublad
      app.kubernetes.io/component: bureaublad-frontend
  policyTypes:
    - Ingress
    - Egress
  egress:
    - ports:
        # Allow dns resolution
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
  ingress:
    - ports:
        - port: 8080
---
# Source: bureaublad/templates/backend-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: bureaublad-backend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-backend
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad
      app.kubernetes.io/name: bureaublad
      app.kubernetes.io/component: bureaublad-backend
---
# Source: bureaublad/templates/frontend-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: bureaublad-frontend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-frontend
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad
      app.kubernetes.io/name: bureaublad
      app.kubernetes.io/component: bureaublad-frontend
---
# Source: bureaublad/templates/service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bureaublad
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad
automountServiceAccountToken: true
---
# Source: bureaublad/templates/backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: bureaublad-backend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-backend
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: http
      port: 80
      targetPort: 8000
      protocol: TCP
      nodePort: null
  selector:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/component: bureaublad-backend
---
# Source: bureaublad/templates/frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: bureaublad-frontend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-frontend
spec:
  type: ClusterIP
  sessionAffinity: None
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
      nodePort: null
  selector:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/component: bureaublad-frontend
---
# Source: bureaublad/templates/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bureaublad-backend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-backend
spec:
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad
      app.kubernetes.io/name: bureaublad
      app.kubernetes.io/component: bureaublad-backend
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: bureaublad
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: bureaublad
        app.kubernetes.io/part-of: bureaublad
        app.kubernetes.io/version: 0.9.3
        helm.sh/chart: bureaublad-0.2.0
        app.kubernetes.io/component: bureaublad-backend
    spec:
      
      serviceAccountName: bureaublad
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: bureaublad
                    app.kubernetes.io/name: bureaublad
                    app.kubernetes.io/component: bureaublad
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      initContainers:
      containers:
        - name: backend
          image: ghcr.io/minbzk/bureaublad-api:v0.9.3
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          args:
            - --host
            - 0.0.0.0
            - app.main:app
            - --port
            - "8000"
            - --forwarded-allow-ips
            - '*'
          env:            
            - name: "CORS_ALLOW_CREDENTIALS"
              value: "false"
            - name: "CORS_ALLOW_HEADERS"
              value: "[\"*\"]"
            - name: "CORS_ALLOW_METHODS"
              value: "[\"GET\",\"POST\",\"PUT\",\"DELETE\"]"
            - name: "CORS_ALLOW_ORIGINS"
              value: "[\"https://bureaublad.kubernetes.local\"]"
            - name: "DEBUG"
              value: "false"
            - name: "DOCS_URL"
              value: "https://docs.kubernetes.local"
            - name: "ENVIRONMENT"
              value: "prod"
            - name: "GRIST_URL"
              value: "https://grist.kubernetes.local"
            - name: "LOGGING_LEVEL"
              value: "DEBUG"
            - name: "MATRIX_URL"
              value: "https://element.kubernetes.local"
            - name: "MEET_URL"
              value: "https://meet.kubernetes.local"
            - name: "OCS_URL"
              value: "https://nextcloud.kubernetes.local"
            - name: "OIDC_AUDIENCE"
              value: "bureaublad"
            - name: "OIDC_AUTHORIZATION_ENDPOINT"
              value: 
            - name: "OIDC_CLIENT_ID"
              value: "bureaublad"
            - name: "OIDC_CLIENT_SECRET"
              value: "079b22102d5c5c847090bf5e25cc37bf995b09cc"
            - name: "OIDC_EMAIL_CLAIM"
              value: "email"
            - name: "OIDC_ISSUER"
              value: 
            - name: "OIDC_JWKS_ENDPOINT"
              value: 
            - name: "OIDC_LOGOUT_ENDPOINT"
              value: 
            - name: "OIDC_NAME_CLAIM"
              value: "name"
            - name: "OIDC_POST_LOGIN_REDIRECT_URI"
              value: "https://bureaublad.kubernetes.local"
            - name: "OIDC_POST_LOGOUT_REDIRECT_URI"
              value: "https://bureaublad.kubernetes.local"
            - name: "OIDC_REVOCATION_ENDPOINT"
              value: 
            - name: "OIDC_SCOPES"
              value: "openid email profile"
            - name: "OIDC_SIGNATURE_ALGORITM"
              value: "RS256"
            - name: "OIDC_TOKEN_ENDPOINT"
              value: 
            - name: "OIDC_USERNAME_CLAIM"
              value: "preferred_username"
            - name: "REDIS_URL"
              value: "redis://default:205c14053d736f52e1d31024e578dd892b9db8f6@bureaublad-redis-master:6379/1"
            - name: "SECRET_KEY"
              value: "7608178591a9268097f373ce03babe99ec51cd3e"
            - name: "SESSION_MAX_AGE"
              value: "7200"
            - name: "THEME_CSS_URL"
              value: ""
            - name: "TRUSTED_HOSTS"
              value: "[\"bureaublad.kubernetes.local\"]"
          envFrom:
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          ports:
            - name: http
              containerPort: 8000
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              path: /liveness
              port: 8000
              httpHeaders:
                - name: Host
                  value: bureaublad.kubernetes.local
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              path: /readiness
              port: 8000
              httpHeaders:
                - name: Host
                  value: bureaublad.kubernetes.local
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
      volumes:
        - name: empty-dir
          emptyDir: {}
---
# Source: bureaublad/templates/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bureaublad-frontend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-frontend
spec:
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/instance: bureaublad
      app.kubernetes.io/name: bureaublad
      app.kubernetes.io/component: bureaublad-frontend
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: bureaublad
        app.kubernetes.io/managed-by: Helm
        app.kubernetes.io/name: bureaublad
        app.kubernetes.io/part-of: bureaublad
        app.kubernetes.io/version: 0.9.3
        helm.sh/chart: bureaublad-0.2.0
        app.kubernetes.io/component: bureaublad-frontend
    spec:
      
      serviceAccountName: bureaublad
      automountServiceAccountToken: false
      affinity:
        podAffinity:
          
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/instance: bureaublad
                    app.kubernetes.io/name: bureaublad
                    app.kubernetes.io/component: bureaublad
                topologyKey: kubernetes.io/hostname
              weight: 1
        nodeAffinity:
          
      securityContext:
        fsGroup: 1001
        fsGroupChangePolicy: Always
        supplementalGroups: []
        sysctls: []
      initContainers:
      containers:
        - name: frontend
          image: ghcr.io/minbzk/bureaublad-frontend:v0.6.1
          imagePullPolicy: Always
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsGroup: 1001
            runAsNonRoot: true
            runAsUser: 1001
            seLinuxOptions: {}
            seccompProfile:
              type: RuntimeDefault
          env:            
            - name: "NEXT_PUBLIC_BACKEND_BASE_URL"
              value: "/api"
            - name: "NGINX_PORT"
              value: "8080"
          envFrom:
          resources:
            limits:
              cpu: 750m
              ephemeral-storage: 2Gi
              memory: 768Mi
            requests:
              cpu: 500m
              ephemeral-storage: 50Mi
              memory: 512Mi
          ports:
            - name: http
              containerPort: 8080
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              path: /
              port: 8080
          readinessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 5
            httpGet:
              path: /
              port: 8080
          volumeMounts:
            - name: empty-dir
              mountPath: /tmp
              subPath: tmp-dir
            - mountPath: /var/cache/nginx
              name: empty-dir
            - mountPath: /var/run
              name: empty-dir
      volumes:
        - name: empty-dir
          emptyDir: {}
---
# Source: bureaublad/templates/backend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bureaublad-backend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-backend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bureaublad-backend
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
---
# Source: bureaublad/templates/frontend-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: bureaublad-frontend
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad-frontend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: bureaublad-frontend
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
---
# Source: bureaublad/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bureaublad
  namespace: "default"
  labels:
    app.kubernetes.io/instance: bureaublad
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: bureaublad
    app.kubernetes.io/part-of: bureaublad
    app.kubernetes.io/version: 0.9.3
    helm.sh/chart: bureaublad-0.2.0
    app.kubernetes.io/component: bureaublad
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  rules:
    - host: bureaublad.kubernetes.local
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: bureaublad-frontend
                port:
                  name: http
          - path: /api
            pathType: ImplementationSpecific
            backend:
              service:
                name: bureaublad-backend
                port:
                  name: http

