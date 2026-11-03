#!/bin/sh
set -eu

ip link set eth0 up
ip addr add 192.168.0.224/24 dev eth0 2>/dev/null || true
ip route replace default via 192.168.0.1 dev eth0 2>/dev/null || true

ip link set eth1 up
ip addr add 10.10.50.2/24 dev eth1 2>/dev/null || true

printf 'nameserver 192.168.0.1\nnameserver 1.1.1.1\n' > /etc/resolv.conf

exec /sbin/init
