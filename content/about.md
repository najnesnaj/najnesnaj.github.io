---
title: About  
author: najnesnaj is my name in reverse, this way I stay clear of big brother
---


# config.yaml

```yaml
permalinks:
  note: "/note/:year/:month/:day/:slug/"
  post: "/post/:year/:month/:day/:slug/"
```

You can define the menu through `menu.main`, e.g.,

```yaml
menu:
  main:
    - name: Home
      url: ""
      weight: 1
    - name: About
      url: "about/"
      weight: 2
    - name: Categories
      url: "categories/"
      weight: 3
    - name: Tags
      url: "tags/"
      weight: 4
    - name: Subscribe
      url: "index.xml"
```

Alternatively, you can add `menu: main` to the YAML metadata of any of your pages, so that these pages will appear in the menu.

The page footer can be defined in `.Params.footer`, and the text is treated as Markdown, e.g.,

```
params:
  footer: "&copy; [najnesnaj](https://najnesnaj.github.io) 2017 -- 2022"
```


# LICENCE 

I think the MIT licence should be OK.
If you use documents I've written in a publication, I'd like to be noticed.
