---
title: 'Laptop'
weight: 700
draft: false
---

# Laptop (or PC) mods

/etc/hosts

10.10.10.50 nginx.example.com
10.10.10.50 registry.example.com

> ip route add 10.10.10.0/24 via 192.168.0.251

sudo cp ca.crt /usr/local/share/ca-certificates/ca.crt
sudo update-ca-certificates
Updating certificates in /etc/ssl/certs…

## make route permanent

```yaml
sudo nano /etc/netplan/01-netcfg.yaml

network:
version: 2
ethernets:
  wlp0s20f3:
    addresses:
      - 192.168.0.103/24
    gateway4: 192.168.0.1  # Replace with your actual default gateway
    routes:
      - to: 10.10.10.0/24
        via: 192.168.0.251

  sudo netplan apply
```
