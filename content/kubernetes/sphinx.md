---
title: 'Sphinx'
weight: 450
draft: false
---

# Sphinx

sphinx is used to document the project. It generates HTML documentation from reStructuredText files.
Or even pdfs, if you want to.

```bash
sphinx-quickstart (to install sphinx)
make html (to generate the html files)
make latexpdf (to generate the pdf files)
make clean (to clean the generated files)
make livehtml (to generate the html files and keep updating them as you make changes)
```

#### NOTE
documenting the python code is done using sphinx as well.
there is some extra configuration needed to make this work.
see the conf.py file for more details.

#### NOTE
sphinx version 8.0.0 or higher is required to build the documentation.
you can install it using the following command:
pip install sphinx>=8.0.0

**see modules.rst for more details on the project modules**
