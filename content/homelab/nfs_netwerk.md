---
title: 'Nfs Netwerk'
weight: 240
draft: false
---

# nfs network between linux containers

## set up a bridge

A Linux bridge interface (commonly called vmbrX) is needed to connect guests to the underlying physical network. It can be thought of as a virtual switch which the guests and physical interfaces are connected to.

## define an extra network interface in range 10.0.0.X

<!-- image::images/network-nfs.png -->
