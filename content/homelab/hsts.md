COMBINED OUTPUT:
  Error: UPGRADE FAILED: Unable to continue with update: Middleware "hsts-header" in namespace "default" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: key "meta.helm.sh/release-name" must equal "bureaublad": current value is "nextcloud"

[root@nixos:/home/nixie/mijn-bureau-infra]# history | grep hsts
  502  find ./ | xargs grep hsts > jj
  526  history | grep hsts

[root@nixos:/home/nixie/mijn-bureau-infra]# kubectl delete middleware hsts-header -n default
middleware.traefik.io "hsts-header" deleted from default namespace

[root@nixos:/home/nixie/mijn-bureau-infra]# helmfile -e demo sync -f helmfile.yaml.gotmpl

