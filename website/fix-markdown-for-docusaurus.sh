#!/bin/bash

# This script fixes markdown files to be MDX-compatible
# It escapes angle brackets that aren't in code blocks

SOURCE_DIR="/root/claude/ocp-networking-labs"
DEST_DIR="/root/claude/ocp-networking-website/docs"

echo "Copying and fixing markdown files..."

# Clear existing docs except intro.md
find "$DEST_DIR" -type f -name "*.md" ! -name "intro.md" -delete

# Copy week directories
for week in week1-2 week3-4 week5-6 week7; do
    mkdir -p "$DEST_DIR/$week"
    
    # Copy all lab files
    cp -r "$SOURCE_DIR/$week/labs/"*.md "$DEST_DIR/$week/" 2>/dev/null || true
done

# Copy cheat sheets
mkdir -p "$DEST_DIR/cheat-sheets"
cp -r "$SOURCE_DIR/cheat-sheets/"*.md "$DEST_DIR/cheat-sheets/" 2>/dev/null || true

echo "Fixing MDX compatibility issues..."

# Fix all markdown files - escape common placeholders
find "$DEST_DIR" -type f -name "*.md" ! -name "intro.md" | while read file; do
    # Escape common placeholder patterns that aren't already in backticks
    # This regex looks for <word> not preceded by backtick
    sed -i 's/\([^`]\)<none>/\1`<none>`/g' "$file"
    sed -i 's/\([^`]\)<PID>/\1`<PID>`/g' "$file"
    sed -i 's/\([^`]\)<pod>/\1`<pod>`/g' "$file"
    sed -i 's/\([^`]\)<host>/\1`<host>`/g' "$file"
    sed -i 's/\([^`]\)<port>/\1`<port>`/g' "$file"
    sed -i 's/\([^`]\)<node>/\1`<node>`/g' "$file"
    sed -i 's/\([^`]\)<svc>/\1`<svc>`/g' "$file"
    sed -i 's/\([^`]\)<service>/\1`<service>`/g' "$file"
    sed -i 's/\([^`]\)<namespace>/\1`<namespace>`/g' "$file"
    sed -i 's/\([^`]\)<name>/\1`<name>`/g' "$file"
    sed -i 's/\([^`]\)<id>/\1`<id>`/g' "$file"
    sed -i 's/\([^`]\)<IP>/\1`<IP>`/g' "$file"
    sed -i 's/\([^`]\)<URL>/\1`<URL>`/g' "$file"
    sed -i 's/\([^`]\)<route>/\1`<route>`/g' "$file"
    sed -i 's/\([^`]\)<interface>/\1`<interface>`/g' "$file"
    sed -i 's/\([^`]\)<command>/\1`<command>`/g' "$file"
    sed -i 's/\([^`]\)<value>/\1`<value>`/g' "$file"
    sed -i 's/\([^`]\)<ClusterIP>/\1`<ClusterIP>`/g' "$file"
    
    # Also fix standalone ones at start of line
    sed -i 's/^<none>/`<none>`/g' "$file"
    sed -i 's/^<PID>/`<PID>`/g' "$file"
    
    echo "Fixed: $file"
done

echo "✅ Done! Files copied and fixed."
echo "Total files: $(find "$DEST_DIR" -name "*.md" | wc -l)"
