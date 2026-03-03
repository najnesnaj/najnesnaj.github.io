---
title: 'Ramdisk'
weight: 170
draft: false
---

# ramdisk

My dl380p gen8 has 256Gb of RAM

## Can I use RAM as a disk?

mkdir /tmp/ramdisk
chmod 777 /tmp/ramdisk
mount -t tmpfs -o size=1024m myramdisk /tmp/ramdisk

or to get something extra…

sudo mount -t tmpfs -o size=10G myramdisk /tmp/ramdisk

## speedtest

For Write:
dd if=/dev/zero of=/dev/shm/ram bs=1048576 count=4096 oflag=nocache conv=fsync
4096+0 records in
4096+0 records out
4294967296 bytes (4.3 GB, 4.0 GiB) copied, 2.79948 s, 1.5 GB/s

or:
dd if=/dev/zero of=/tmp/ramdisk/blok bs=1048576 count=1024 oflag=nocache conv=fsync
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 0.560324 s, 1.9 GB/s

For Read:

dd if=/tmp/ramdisk/blok of=/dev/null bs=1048576 iflag=nocache,sync conv=nocreat

dd if=/tmp/ramdisk/blok of=/dev/null bs=1048576 iflag=nocache,sync conv=nocreat
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 0.240446 s, 4.5 GB/s

---

modprobe zram
echo 80G | tee /sys/block/zram0/disksize    (80G ramdisk)
mkfs.ext4 /dev/zram0  (make a filesystem)
mkdir /RAM   (create a mountingpoint)
mount /dev/zram0 /RAM

now you can use the /RAM directory (which will be gone after poweroff)
