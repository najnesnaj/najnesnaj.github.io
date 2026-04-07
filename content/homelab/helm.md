export MIJNBUREAU_MASTER_PASSWORD=passwoord
helmfile sync -f helmfile.yaml.gotmpl --values $(pwd)/local-values.yaml

helmfile -e demo sync -f helmfile.yaml.gotmpl --values $(pwd)/local-values.yaml

(-e demo specifieren anders wordt postgresql niet geinstalleerd voor keycloak)

local-values.yaml aangepast wegens crashes (memory)

# Essentiële componenten met geheugen-optimalisatie voor Keycloak
keycloak:
  enabled: true
  # Voorkomt OOMKilled: Forceer JVM heap limieten
  extraEnvVars:
    - name: JAVA_OPTS
      value: "-Xms512m -Xmx1024m"
  # Kubernetes resource limieten
  resources:
    limits:
      memory: "1536Mi"
    requests:
      memory: "768Mi"



helmfile -e demo sync -f helmfile.yaml.gotmpl --values $(pwd)/local-values.yaml



probleem blijft bestaan : 
 kubectl describe pod keycloak-keycloak-0 -n default | grep -i "memory:"
      memory:             768Mi
      memory:             512Mi
      memory:             768Mi
      memory:             512Mi

----------aanpassing helmfile/apps/keycloak/helmfile-child.yaml.gotmpl 

    needs:
      - {{ if .Values.application.keycloak.namespace }}{{ .Values.application.keycloak.namespace }}/{{ end }}keycloak-postgresql
    {{- end }}
    values:
      - "../common/values-cluster-ingress.yaml.gotmpl"
      - keycloak.yaml.gotmpl
      # Forceer hogere resources direct in de release
      - resources:
          limits:
            memory: "1536Mi"
          requests:
            memory: "768Mi"
        extraEnvVars:
          - name: JAVA_OPTS
            value: "-Xms512m -Xmx1024m"

