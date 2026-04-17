#!/bin/bash
# Fix all angle brackets in markdown files that aren't in code blocks

find docs -name "*.md" -type f | while read file; do
    # Replace common patterns outside code blocks
    sed -i 's/\([^`]\)<id>/\1`<id>`/g' "$file"
    sed -i 's/\([^`]\)<name>/\1`<name>`/g' "$file"
    sed -i 's/\([^`]\)<namespace>/\1`<namespace>`/g' "$file"
    sed -i 's/\([^`]\)<service>/\1`<service>`/g' "$file"
    sed -i 's/\([^`]\)<IP>/\1`<IP>`/g' "$file"
    sed -i 's/\([^`]\)<URL>/\1`<URL>`/g' "$file"
    sed -i 's/\([^`]\)<route>/\1`<route>`/g' "$file"
done
