---
title: 'Share'
weight: 200
draft: false
---

# sharing a directory for LXC

on the host (pve node) create a shared directory (jan): (created on M2 storage)
chown -R nobody:nogroup jan
chmod 777 jan

[root@pve](mailto:root@pve):/etc/pve/lxc#

## modify the lxc

create a directory /mnt/shared (which will be the mounting point)

## on PVE modify the lxc config

<!-- code-block::bash:


add this:
(mp0: /mnt/pve/M2P2/jan,mp=/mnt/shared)


arch: amd64
cores: 4
features: nesting=1
hostname: decode
memory: 5120
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:82:79:94,ip=dhcp,type=veth
ostype: ubuntu
rootfs: local-lvm:vm-101-disk-0,size=20G
swap: 512
unprivileged: 1
mp0: /mnt/pve/M2P2/jan,mp=/mnt/shared -->
