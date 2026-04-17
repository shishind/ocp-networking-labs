#!/usr/bin/env python3
import re
import sys
from pathlib import Path

def fix_mdx_file(filepath):
    """Fix MDX compatibility issues in markdown files"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Don't process if already in a code block
    in_code_block = False
    lines = content.split('\n')
    fixed_lines = []
    
    for line in lines:
        # Track code blocks
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            fixed_lines.append(line)
            continue
        
        # Don't modify lines in code blocks
        if in_code_block:
            fixed_lines.append(line)
            continue
        
        # Fix angle brackets outside of backticks
        # Pattern: find <word> that isn't already in backticks
        line = re.sub(r'(?<!`)<(\w+)>(?!`)', r'`<\1>`', line)
        
        fixed_lines.append(line)
    
    # Write back
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(fixed_lines))

if __name__ == '__main__':
    docs_dir = Path('/root/claude/ocp-networking-website/docs')
    
    for md_file in docs_dir.rglob('*.md'):
        if md_file.name != 'intro.md':
            print(f"Fixing: {md_file}")
            fix_mdx_file(md_file)
    
    print("✅ All files fixed!")
