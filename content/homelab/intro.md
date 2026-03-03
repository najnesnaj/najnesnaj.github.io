---
title: 'Intro'
weight: 30
draft: false
---

# intro

This doc does not belong here, but did not want to create multiple github repo’s.

This is a personal account of venturing into the Proxmox virutualised world:

- running containers
- running local LLM
- no GPU
- cheap

I try to document as much as I can, to avoid solving the same problem twice.

## homelab

I bought hp dl380p g8 (generation8) with 16 cores and 32 threads and 256 GIGA bytes of RAM!! for the price of a raspberry pi.

I plan it on using during winter, so its heat is not lost. During rendering or running a LLM it generates 400 Watt. (or consumes for 400 watt expensive electricity)

It could use a GPU, but I hate to spend more money, and it would need a special riser to give way to PCIe x16 double slot.

results sofar :

- LLM runs at 5 tokens / second (llavafile)
- blender takes half an hour for rendering (CYCLES) a single picture
- using it as a  ramdisk give 1,5G/s readspead!

## software

I choose proxmox as a virtualisation platform, it runs linux containers (LXC), which are kind of cool since they are created quickly, launched quickly. Some problems arise since there are still shared resources with the host… hence the use of the included templates
