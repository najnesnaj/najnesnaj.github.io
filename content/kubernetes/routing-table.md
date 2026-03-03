---
title: 'Routing Table'
weight: 1690
draft: false
---

# Kernel IP Routing Table

The following table represents the kernel IP routing table:

#### Kernel IP Routing Table

| Destination     | Gateway     | Genmask         | Flags   |   Metric |   Ref |   Use | Iface   |
|-----------------|-------------|-----------------|---------|----------|-------|-------|---------|
| default         | 192.168.0.1 | 0.0.0.0         | UG      |      100 |     0 |     0 | eth1    |
| default         | 192.168.0.1 | 0.0.0.0         | UG      |     1024 |     0 |     0 | eth1    |
| 10.10.10.0      | 0.0.0.0     | 255.255.255.0   | U       |        0 |     0 |     0 | eth0    |
| 192.168.0.0     | 0.0.0.0     | 255.255.255.0   | U       |     1024 |     0 |     0 | eth1    |
| 192.168.0.1     | 0.0.0.0     | 255.255.255.255 | UH      |     1024 |     0 |     0 | eth1    |
| gent.dnscache01 | 192.168.0.1 | 255.255.255.255 | UGH     |     1024 |     0 |     0 | eth1    |
| gent.dnscache02 | 192.168.0.1 | 255.255.255.255 | UGH     |     1024 |     0 |     0 | eth1    |
