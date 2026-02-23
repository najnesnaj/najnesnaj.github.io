---
title: 'Gitignore'
draft: false
---

# Gitignore tricks

most likely, you would like to avoid some files getting published on github (especially if you are using a public repository). Here are some common files that you might want to ignore:
(files containing api tokens, passwords, etc.)

If you are anything like me, you’ll notice this too late in the process.

## trick:

```bash
git rm -r --cached source/_build
git rm -r --cached source/
git reset HEAD source/
vi .gitignore
git add .gitignore (add the file you do not want to publish)
git commit -m "removed source/_build from git"
git push origin master
```

## Sphinx:

Sphinx has a build directory, in which files are generated. You might want to ignore this directory as well, as it contains many files that change.
