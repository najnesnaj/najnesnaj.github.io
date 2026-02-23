---
title: 'Helmify'
draft: false
---

# helmify

## create a repository for helm

sudo microk8s helm create my-helm

## export your current resources

microk8s kubectl get all -o yaml > current-state.yaml

## install helmify (and go)

sudo snap install go –classic
go install [github.com/arttor/helmify/cmd/helmify@latest](mailto:github.com/arttor/helmify/cmd/helmify@latest)

this installs under /home/user/go/bin

add to PATH :
nano ~/.bashrc
export PATH=”$PATH:/home/yourusername/go/bin”

cat current-state.yaml | helmify my-helm

(this creates helm templates from the current resources)

## flawless

while it seemed like easy sailing, the helmify command did not work as expected.
I created a script that applied the helmify command to each resource type separately.

**convert_to_helm.sh**
