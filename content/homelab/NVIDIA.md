---
title: 'Nvidia'
weight: 620
draft: false
---

# Setting up NVIDIA Tesla P100

the P100 was choses for balance between performance and price (second hand ebay)

## Aliexpress

> PCIE 4.0 3.0 16X Riser Kabel 90/180 Graden Mount Video Grafisch

Gpu 10pin Naar 1x8pin Dual 8(6 + 2)Pin Power Adapter Kabel Voor Hp Dl380 Gen8 Gen9 Server

## Cutting the Riser

a special Riser for the HP Proliant gen8 is a good idea because it has a PCIE 16x in the middle which allows for the GPU  to be plugged in. (hard to find and expensive)

I choose the cheap option (evidently) and cut a hole in a riser to extend with a riser cable into this riser. Some more cutting had to be done because the GPU is too long.

For the gen9 there a cheaper riser card options, so no cutting needed…

## Configure the BIOS

(changed IRQ for network card to 11, since conflict)

enter BIOS (F9) and on main bios screen / “Service options” menu item. Under this, enable “PCI Express 64-bit BAR

## configure proxmox host

[https://digitalspaceport.com/proxmox-lxc-gpu-passthru-setup-guide/](https://digitalspaceport.com/proxmox-lxc-gpu-passthru-setup-guide/)

PROXMOX PCI-E GPU passthru

When running proxmox on this hardware, there is more config needed to enable passthru of this GPU to VM.
Enable IOMMU

<!-- code-block::bash:

 Edit /etc/default/grub file, modify variable GRUB_CMDLINE_LINUX_DEFAULT adding intel_iommu=on parameter
 Enable unsafe intremap

 Create file /etc/modprobe.d/iommu_unsafe_interrupts.conf with contents options vfio_iommu_type1 allow_unsafe_interrupts=1
 Blacklist nvidia drivers

 Create file /etc/modprobe.d/nvidia-blacklist.conf with contents

 # blacklist for nvidia gpu passthru
 blacklist nouveau
 blacklist nvidia*

 Apply changes into bootloader

Run proxmox-boot-tool refresh -->

## the idea

the idea is to get nvidia to work on the proxmox host (there will be kernel modules)

for the LXC machines there is no need for kernel drivers!! since already on the host

## Download NVIDIA drivers

<!-- code-block::bash:

NVIDIA-Linux-x86_64-570.133.20.run

https://developer.nvidia.com/cuda-12-8-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Debian&target_version=12&target_type=deb_local

*nvidia is gonna need some kernel (promox) drivers

apt install pve-headers-$(uname -r) build-essential software-properties-common make nvtop htop -y

 ./NVIDIA-Linux-x86_64-570.133.20.run -->

## adapt lxc.conf

/etc/pve/lxc/105.conf

Append these values with the IDs you noted earlier to your file like so. Note the placement of the 195, 234 and 509. This is for a SINGLE gpu also, if you have multiple add additional

<!-- code-block::bash:

lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap1 dev/nvidia-caps/nvidia-cap1 none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-caps/nvidia-cap2 dev/nvidia-caps/nvidia-cap2 none bind,optional,create=file -->

## copy NVIDIA driver to LXC

<!-- code-block::bash:

pct push 100 NVIDIA-Linux-x86_64-570.133.20.run /root/NVIDIA-Linux-x86_64-570.133.20.run

On the LXC no modules are needed !! (they are on the proxmox host (PVE))

--installing the NVIDIA drivers:
./NVIDIA-Linux-x86_64-570.133.20.run --no-kernel-modules -->

## Install the NVIDIA Container Toolkit

<!-- code-block::bash:

apt install gpg curl
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt update
apt install nvidia-container-toolkit

Edit the config.toml and enable the no-cgroups and set it to true from false.

/etc/nvidia-container-runtime/config.toml
#no-cgroups = false
to
no-cgroups = true -->

## install ollama docker container for GPU usage

#in portainer you still need to start ollama this way:

<!-- code-block::yaml:


docker compose up -d

file.yml:

version: "3.3"
services:
  ollama:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities:
                - gpu
    volumes:
      - ollama:/root/.ollama
    ports:
      - 11434:11434
    container_name: ollama
    image: ollama/ollama
    restart: always -->
