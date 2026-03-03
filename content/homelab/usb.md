---
title: 'Usb'
weight: 140
draft: false
---

# reading data from USB stick

the USB stick is readable from the proxmox host:

(do a dmesg to get the device: in this case /dev/sdb1)
mount /dev/sdb1 /usbdrive

## create a mp on CT (container02)

/dev/mapper/pve-vm–102–disk–1  51290592        28  48652740   1% /container02mp

## transfer to CT (name = container02)

on the host
mkdir /drive_container02
mount /dev/mapper/pve-vm–102–disk–1 /drive_container02/
