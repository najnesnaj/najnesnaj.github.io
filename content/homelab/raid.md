---
title: 'Raid'
weight: 490
draft: false
---

# RAID

previously 2 600GB SAS disks were in RAID1 in the same volumegroup.

I have no spare disk, nor do I want to spend money on old tech.

Reconfigure : each disk is within own volume group, no more RAID, more (free) space.
Tool would not let me otherwise.

## No more raid :

machine on one disk are backupped to other disk, and vice versa
one disk remains VG (volume group) within proxmox : used for LXC en VM images, backup
other disk contains ext4 filesystem and is a directory
