---
title: 'Blender'
weight: 350
draft: false
---

# server for blender

Although the hp dl380 was 5 times faster than my i7 laptop, it is still slow, takes half an hour to render a picture.

One can adjust setting within blender to speed up things a bit, but still …

## howto render?

- download blender 4.2

cd blender-4.2.0-linux-x64/

./blender -b /home/naj/misvormde-donut1.blend -E CYCLES -f 1

## faster / less good

./blender -b /home/naj/misvormde-donut1.blend -E BLENDER_EEVEE_NEXT -f 1

## at the movies

./blender -b /home/naj/misvormde-donut1.blend -E BLENDER_EEVEE_NEXT -s 10 -e 500 -t 2 -a
./blender -b /home/naj/misvormde-donut1.blend -E BLENDER_EEVEE_NEXT -s 1 -e 100 -t 2 -a
