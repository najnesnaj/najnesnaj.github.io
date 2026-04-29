keycloak-login 
admin
kubectl get secret keycloak-keycloak -n default -o jsonpath="{.data.admin-password}" | base64 -d
4324842ed6cc25b556e6a074001e1888bf99393d

