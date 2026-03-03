---
title: 'Moving'
weight: 210
draft: false
---

# moving a LXC container

I had a container on a logical volume SCSI and I wanted to move it to logical volume M2

Cloning?

The container shared a directory, and cloning and displacing would mess this up.

Solution:
backup & restore from backup on other volume
