# Hugo Documentation Site - Usage Guide

## Adding a New Project

Use the `add-project-docs.sh` script to add documentation from a Sphinx-generated markdown source.

```bash
./add-project-docs.sh <source-markdown-dir> <project-name>
```

### Example

```bash
# Add ragflow documentation
./add-project-docs.sh /usr/src/ragtime/ragflow-doc/build/markdown ragflow

# Add dify documentation
./add-project-docs.sh /usr/src/dify/build/markdown dify
```

## Building the Site

```bash
hugo
```

The site will be generated in the `public/` directory.

## Running the Development Server

```bash
hugo server
```

Then open http://localhost:1313 in your browser.

## Project Structure

```
hugo/
├── content/
│   ├── ragflow/          # Ragflow documentation
│   └── dify/             # Dify documentation (if added)
├── static/
│   └── images/
│       ├── ragflow/      # Images for ragflow docs
│       └── dify/         # Images for dify docs (if added)
├── layouts/             # Hugo templates
├── add-project-docs.sh   # Script to add new projects
└── hugo.yaml            # Hugo configuration
```

## Notes

- **index.md issue**: The script automatically renames `index.md` to `index-doc.md` because Hugo has a quirk where having `index.md` in a directory with other `.md` files causes them to be treated as resources instead of pages.
- **Image paths**: The script rewrites image references from `![image](images/file.png)` to `![image](/images/project-name/file.png)`.
