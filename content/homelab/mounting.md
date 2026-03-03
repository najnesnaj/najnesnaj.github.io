---
title: 'Mounting'
weight: 460
draft: false
---

# mounting

mkdir /SCSIdata for the data on the scsidisk /dev/sdb
mkdir /M2data for the data on the M2 disk /dev/nvme0n1p2

# mount /dev/sdb /SCSIdata

# mount /dev/nvme0n1p2 /M2data

# edit  /etc/fstab

/dev/nvme0n1p2  /M2data  ext4  defaults  0  2
/dev/sdb  /SCSIdata  ext4  defaults  0  2
