#!/usr/bin/env python3
"""
Smart MDX fixer for Docusaurus.
Only escapes angle brackets that are NOT already in backticks.
"""

import re
import os
from pathlib import Path

def fix_mdx_content(content):
    """Fix MDX content by escaping unprotected angle brackets."""
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

        # Now process the line
        # We need to:
        # 1. Find all <word> patterns
        # 2. Check if they're already in backticks
        # 3. Only wrap in backticks if not already wrapped

        new_line = line

        # Find all angle bracket patterns
        # Pattern: <word>, <word-word>, <word_word>, etc.
        pattern = r'<([a-zA-Z0-9_-]+)>'

        # We'll process from right to left to preserve indices
        matches = list(re.finditer(pattern, line))

        for match in reversed(matches):
            start, end = match.span()

            # Check if this match is already inside backticks
            # Look before and after the match
            before = line[:start]
            after = line[end:]

            # Count backticks before this match
            backticks_before = before.count('`')

            # If odd number of backticks before, we're inside a backtick region
            if backticks_before % 2 == 1:
                # Already in backticks, skip
                continue

            # Not in backticks, wrap it
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
