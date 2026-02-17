#!/bin/bash
# Add a Sphinx-generated markdown documentation to Hugo site
# Usage: ./add-project-docs.sh <source-markdown-dir> <project-name>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <source-markdown-dir> <project-name>"
    echo "Example: $0 /usr/src/dify/build/markdown dify"
    exit 1
fi

SOURCE_DIR="$1"
PROJECT_NAME="$2"
HUGO_ROOT="${HUGO_ROOT:-.}"

echo "Adding documentation for project: $PROJECT_NAME"
echo "Source: $SOURCE_DIR"

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Create content directory
CONTENT_DIR="$HUGO_ROOT/content/$PROJECT_NAME"
mkdir -p "$CONTENT_DIR"

# Create static images directory
STATIC_IMAGES_DIR="$HUGO_ROOT/static/images/$PROJECT_NAME"
mkdir -p "$STATIC_IMAGES_DIR"

# Copy and process markdown files
echo "Processing markdown files..."
for md_file in "$SOURCE_DIR"/*.md; do
    if [ -f "$md_file" ]; then
        filename=$(basename "$md_file")
        
        # Get title from filename (remove extension, replace hyphens with spaces, title case)
        title=$(basename "$filename" .md | sed 's/-/ /g' | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
        
        # Read content
        content=$(cat "$md_file")
        
        # Rewrite image paths: ![alt](images/file.png) -> ![alt](/images/project/file.png)
        content=$(echo "$content" | sed "s|](images/|](/images/$PROJECT_NAME/|g")
        
        # Check if it's index.md and rename to avoid Hugo quirk
        if [ "$filename" = "index.md" ]; then
            filename="index-doc.md"
            title="Index"
        fi
        
        # Add front matter
        {
            echo "---"
            echo "title: '$title'"
            echo "draft: false"
            echo "---"
            echo ""
            echo "$content"
        } > "$CONTENT_DIR/$filename"
        
        echo "  Processed: $filename -> $filename"
    fi
done

# Copy images
echo "Copying images..."
if [ -d "$SOURCE_DIR/images" ]; then
    cp "$SOURCE_DIR/images"/* "$STATIC_IMAGES_DIR/" 2>/dev/null || true
    echo "  Copied images to: $STATIC_IMAGES_DIR"
else
    echo "  Warning: No images directory found in $SOURCE_DIR"
fi

echo ""
echo "Done! Run 'hugo' to build the site."
echo "Project will be available at: /${PROJECT_NAME}/"
