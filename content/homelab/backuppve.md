---
title: 'Backuppve'
weight: 470
draft: false
---

# Backup pve

Proxmox node now start from a sata m2 in the CDrom slot

A tar copy is made to M2data from /etc directory

In case of crash : reinstall proxmox on sata disk en copy backup.tar to /etc
