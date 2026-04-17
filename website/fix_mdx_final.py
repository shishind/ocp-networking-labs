#!/usr/bin/env python3
"""
Final MDX fixer for Docusaurus.
Escapes placeholder angle brackets while preserving HTML tags.
"""

import re
import os
from pathlib import Path

# HTML tags that should NOT be escaped
HTML_TAGS = {
    'details', 'summary', 'br', 'hr', 'div', 'span', 'p', 'a', 'img',
    'table', 'tr', 'td', 'th', 'thead', 'tbody', 'ul', 'ol', 'li',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'strong', 'em', 'code', 'pre'
}

def fix_mdx_content(content):
    """Fix MDX content by escaping non-HTML angle brackets."""
    lines = content.split('\n')
    result = []
    in_code_block = False
    code_fence = None

    for line in lines:
        # Check for code fence (``` or ~~~)
        fence_match = re.match(r'^(\s*)(```|~~~)', line)
        if fence_match:
            if not in_code_block:
                in_code_block = True
                code_fence = fence_match.group(2)
            elif line.strip().startswith(code_fence):
                in_code_block = False
                code_fence = None
            result.append(line)
            continue

        # If in code block, don't modify
        if in_code_block:
            result.append(line)
            continue

        # Check if line is indented code block (4 spaces or tab)
        if line.startswith('    ') or line.startswith('\t'):
            result.append(line)
            continue

        # Process the line
        new_line = line

        # Find all angle bracket patterns
        # Pattern: <word>, <word-word>, <word_word>, etc.
        # Also handle closing tags like </word>
        pattern = r'<(/?)([a-zA-Z0-9_-]+)>'

        # Process from right to left to preserve indices
        matches = list(re.finditer(pattern, line))

        for match in reversed(matches):
            start, end = match.span()
            slash = match.group(1)  # '/' for closing tags, '' for opening
            tag_name = match.group(2).lower()

            # Check if this is an HTML tag
            if tag_name in HTML_TAGS:
                # Leave HTML tags as-is
                continue

            # Check if already inside backticks
            before = line[:start]
            backticks_before = before.count('`')

            # If odd number of backticks before, we're inside a backtick region
            if backticks_before % 2 == 1:
                # Already in backticks, skip
                continue

            # Not an HTML tag and not in backticks, wrap it
            matched_text = match.group(0)
            new_line = new_line[:start] + '`' + matched_text + '`' + new_line[end:]

        result.append(new_line)

    return '\n'.join(result)

def process_file(file_path):
    """Process a single markdown file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        fixed_content = fix_mdx_content(content)

        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)

        return True
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    docs_dir = Path('/root/claude/ocp-networking-website/docs')

    # Find all markdown files
    md_files = list(docs_dir.rglob('*.md'))

    print(f"🔧 Processing {len(md_files)} markdown files...")

    success_count = 0
    for md_file in md_files:
        if process_file(md_file):
            success_count += 1
            print(f"✅ Fixed: {md_file.relative_to(docs_dir)}")

    print(f"\n✅ Successfully processed {success_count}/{len(md_files)} files")

if __name__ == '__main__':
    main()
