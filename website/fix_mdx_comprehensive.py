#!/usr/bin/env python3
"""
Comprehensive MDX fixer for Docusaurus.
Escapes angle brackets in markdown content while preserving code blocks.
"""

import re
import os
from pathlib import Path

def fix_mdx_content(content):
    """Fix MDX content by escaping angle brackets outside code blocks."""
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

        # Process line to escape angle brackets
        # Match <word> patterns not in backticks
        parts = []
        last_end = 0

        # First, protect inline code with backticks
        inline_code_pattern = r'`[^`]+`'
        inline_codes = list(re.finditer(inline_code_pattern, line))

        if not inline_codes:
            # No inline code, process the whole line
            # Match <word>, <word-word>, <word_word>, <number>, etc.
            fixed_line = re.sub(
                r'<([a-zA-Z0-9_-]+)>',
                r'`<\1>`',
                line
            )
            result.append(fixed_line)
        else:
            # Has inline code, process sections between inline code
            current_pos = 0
            new_line = ""

            for match in inline_codes:
                # Process text before this inline code
                before = line[current_pos:match.start()]
                before_fixed = re.sub(r'<([a-zA-Z0-9_-]+)>', r'`<\1>`', before)
                new_line += before_fixed

                # Keep inline code as-is
                new_line += match.group(0)
                current_pos = match.end()

            # Process remaining text after last inline code
            after = line[current_pos:]
            after_fixed = re.sub(r'<([a-zA-Z0-9_-]+)>', r'`<\1>`', after)
            new_line += after_fixed

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
