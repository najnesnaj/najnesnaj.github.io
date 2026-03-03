---
title: 'Fan'
weight: 680
draft: false
---

# modify fan speed in proliant

After inserting a Tesla P100 GPU, which has no fan, I monitored the temperature using “nvtop”. I noticed I went above 78 degrees celcius, causing it to throttle.

There is a method to change the ventilator speed in the BIOS. Switching it to performance is not a pleasent experience, as all fans turn at 100%.

## usefull URL

[https://www.reddit.com/r/homelab/comments/hix44v/silence_of_the_fans_pt_2_hp_ilo_4_273_now_with/](https://www.reddit.com/r/homelab/comments/hix44v/silence_of_the_fans_pt_2_hp_ilo_4_273_now_with/)

[https://www.reddit.com/r/homelab/comments/sx3ldo/hp_ilo4_v277_unlocked_access_to_fan_controls/](https://www.reddit.com/r/homelab/comments/sx3ldo/hp_ilo4_v277_unlocked_access_to_fan_controls/)

## Patch ILO

turn out there is a patched ILO rom. There is a procedure where you have to set switch 1 of the maintenance switch on the systemboard. (next to powersupply)

<!-- code-block::bash:

rmmod hpsa
rmmod -f  hpilo

follow the procedure to install the patched ilo-rom
sudo ./flash_ilo4 --direct
poweroff -->

switch 1 of maintenance switch back to 0

## reset ILO

I had a problem while executing : fan info (nothing showed)
reset /map1 (this resets the ILO)

## set fan speed

<!-- code-block::bash:

ssh -o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=+ssh-rsa -l Administrator 192.168.0.172

fan t 0 adj -14  (this ajusts all fans) -->

Temp seems OK if fans are at 55%

## playing with individuals fans

> “fan p 0 min 10”

“fan p 1 min 10”

“fan p 2 min 10”

“fan p 3 min 10”

“fan p 0 max 70”,

“fan p 1 max 70”,

“fan p 2 max 70”,

“fan p 3 max 70”
