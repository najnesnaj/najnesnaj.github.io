---
title: 'Nfs Client'
weight: 270
draft: false
---

# nfs client

apt install nfs-common

mount -t nfs 10.0.0.104:/share /mnt/nfson104

## under node pve

watch out for features

<!-- code-block::bash:

rch: amd64
cores: 32
*features: mount=nfs,nesting=1*
hostname: llama
memory: 64000
net0: name=eth0,bridge=vmbr0,firewall=1,hwaddr=BC:24:11:58:0C:3A,ip=dhcp,type=veth
net1: name=eth5,bridge=vmbr1,firewall=1,hwaddr=BC:24:11:3A:F0:4A,ip=10.0.0.100/24,type=veth
ostype: ubuntu
rootfs: local-lvm:vm-100-disk-0,size=40G
swap: 512 -->
