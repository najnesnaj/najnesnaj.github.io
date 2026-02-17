# Hugo Multi-Project Documentation Site Plan

## Overview
Create a Hugo-based documentation site that aggregates documentation from multiple projects (e.g., ragflow, dify, haystack, etc.), where each project's docs were generated using Sphinx with `make markdown`.

## Source Structure
- Example source: `/usr/src/ragtime/ragflow-doc/build/markdown/`
- Contains: `.md` files + `images/` subfolder
- Image references in markdown: `![image](images/filename.png)`

## Key Challenge: Hugo Image Handling
Hugo handles images differently than standard markdown:
1. **Page Bundles**: Hugo best practices use page bundles where images are colocated with content
2. **Global Resources**: Images in `assets/` or `static/` folders
3. **Reference Style**: Need to convert relative image paths to Hugo-compatible paths

## Solution Implemented

### 1. Hugo Site Structure
```
hugo/
├── content/
│   └── ragflow/
│       ├── _index.md           # Section definition
│       ├── index-doc.md        # Main index (renamed from index.md)
│       ├── about.md
│       ├── agent-context.md
│       └── ...
├── static/
│   └── images/
│       └── ragflow/
│           ├── agent-context.png
│           ├── chat.png
│           └── ...
├── layouts/
│   ├── _default/
│   │   ├── baseof.html
│   │   ├── single.html
│   │   ├── list.html
│   │   └── _markup/
│   │       └── render-image.html
│   └── index.html
└── hugo.yaml
```

### 2. Content Processing Script
A Python script processes the Sphinx markdown files:
1. Adds YAML front matter with `title` and `draft: false`
2. Renames `index.md` to `index-doc.md` (see issue below)
3. Rewrites image paths from `images/filename.png` to `/images/ragflow/filename.png`

### 3. Image Handling
- Images are copied to `static/images/ragflow/`
- Markdown image references are rewritten to point to the static location
- Hugo serves images from the static folder

### 4. Important Hugo Quirks Discovered

#### Issue: index.md causes other pages not to render
**Problem**: Having `index.md` in a directory with other `.md` files causes Hugo to treat the other files as resources instead of pages.

**Solution**: Rename `index.md` to something else (e.g., `index-doc.md`) OR use `_index.md` for the section index.

#### Issue: Front matter format
**Problem**: Initially, certain front matter formats caused pages not to be detected.

**Solution**: Use single quotes in front matter: `title: 'Page Name'`

## Implementation Steps

### 1. Initialize Hugo Site
```bash
hugo new site docs --format yaml
```

### 2. Process Markdown Files
```python
import re
from pathlib import Path

src_dir = Path("/path/to/sphinx/build/markdown")
dest_dir = Path("content/project-name")

for md_file in src_dir.glob("*.md"):
    title = md_file.stem.replace("-", " ").title()
    content = md_file.read_text()
    
    # Rewrite image paths
    content = re.sub(r'!\[([^\]]*)\]\(images/([^)]+)\)', 
                     r'![\1](/images/project-name/\2)', content)
    
    # Add front matter
    front_matter = f"""---
title: '{title}'
draft: false
---

"""
    (dest_dir / md_file.name).write_text(front_matter + content)
```

### 3. Handle index.md
If your source has an `index.md`, rename it to avoid Hugo's special handling:
```bash
mv content/project-name/index.md content/project-name/index-doc.md
```

### 4. Copy Images
```bash
cp -r source/images static/images/project-name/
```

### 5. Configure hugo.yaml
```yaml
baseURL: https://example.org/
languageCode: en-us
title: Documentation Hub

markup:
  goldmark:
    renderer:
      unsafe: true
```

### 6. Create Basic Layouts
Create minimal templates in `layouts/`:
- `_default/baseof.html` - Base template
- `_default/single.html` - Single page template
- `_default/list.html` - Section list template
- `index.html` - Home page template

## Adding More Projects
To add another project (e.g., dify):
1. Create `content/dify/` directory
2. Process dify markdown files using the same script
3. Copy dify images to `static/images/dify/`
4. Rebuild

## Testing
Run `hugo` to build the site, then check `public/` for output.
