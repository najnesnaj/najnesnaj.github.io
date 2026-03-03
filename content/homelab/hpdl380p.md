---
title: 'Hpdl380p'
weight: 80
draft: false
---

# Upgrading homelab HP DL 380p

## latest BIOS

- download latest firmware (BIOS) for linux in RPM format
- firmware-system-p70-2019.05.24-1.1
- on ubuntu (unpack with Ark)
- look for CPQP7013.6B8 (4MB in size)
- use ilo to upload firmware (update)

## M2 disk drive

- M.2 NGFF SSD naar PCI-E 3.0 X16 High-Speed SSD  (ashata = 5euro)
- need MVME (one notch) m2 card
- it shows up in BIOS / PCI devices
- on linux :#lsblk it should show up

## Sata

- m2 to sata adapter case (aliexpress)
- cable female sata to female Slimline 13pin 7 + 6 (aliexpress)
- m2 sata disk 128G

## Bootconfig

there is a
- SAS controller
- SATA controller (cdrom)

the controllor has a bootorder as well !!!!
In order to boot from sata, the sata controller has to boot first!!!

```
**
```

this is the way to boot an expensive hp server from a simple 2,5 inch sata disk (laptop 5V) ,using the onboard slimline cd-rom connector
