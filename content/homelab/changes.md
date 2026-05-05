
in values.yaml oicd=true
helmfile -e demo -l name=nextcloud sync -f helmfile.yaml.gotmpl
