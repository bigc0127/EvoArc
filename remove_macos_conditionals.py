#!/usr/bin/env python3
"""
Script to remove macOS conditional compilation blocks from Swift files.
This script:
1. Removes entire #if os(macOS) ... #endif blocks
2. Converts #if os(iOS) ... #endif blocks to unconditional code
3. Handles #if !os(macOS) ... #endif blocks
"""

import re
import sys
from pathlib import Path

def remove_macos_conditionals(content):
    """Remove macOS-specific conditional compilation blocks."""
    lines = content.split('\n')
    result = []
    skip_depth = 0
    in_ios_block = False
    ios_depth = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check for #if os(macOS)
        if re.match(r'^\s*#if\s+os\(macOS\)', line):
            skip_depth += 1
            i += 1
            continue
        
        # Check for #if os(iOS)
        if re.match(r'^\s*#if\s+os\(iOS\)', line):
            in_ios_block = True
            ios_depth += 1
            i += 1
            continue
        
        # Check for #if !os(macOS)
        if re.match(r'^\s*#if\s+!os\(macOS\)', line):
            # Keep the content, skip the directive
            i += 1
            continue
        
        # Handle #else
        if re.match(r'^\s*#else\s*$', line):
            if skip_depth > 0:
                # We're in a macOS block, start skipping
                i += 1
                continue
            elif in_ios_block:
                # We're in an iOS block, the else is macOS code
                skip_depth += 1
                i += 1
                continue
        
        # Handle #endif
        if re.match(r'^\s*#endif\s*$', line):
            if skip_depth > 0:
                skip_depth -= 1
                i += 1
                continue
            elif in_ios_block and ios_depth > 0:
                ios_depth -= 1
                if ios_depth == 0:
                    in_ios_block = False
                i += 1
                continue
        
        # Add line if we're not skipping
        if skip_depth == 0:
            result.append(line)
        
        i += 1
    
    return '\n'.join(result)

def process_file(file_path):
    """Process a single Swift file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file has conditional compilation
        if '#if' not in content or 'macOS' not in content:
            return False
        
        new_content = remove_macos_conditionals(content)
        
        if new_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"✅ Processed: {file_path}")
            return True
        else:
            print(f"⚠️  No changes: {file_path}")
            return False
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    evoarc_path = Path("/Users/needling0127/Dev/EvoArc/EvoArc")
    
    # Find all Swift files
    swift_files = list(evoarc_path.rglob("*.swift"))
    
    print(f"Found {len(swift_files)} Swift files")
    print("Processing...")
    print()
    
    processed = 0
    for swift_file in sorted(swift_files):
        if process_file(swift_file):
            processed += 1
    
    print()
    print(f"Processed {processed} files")

if __name__ == "__main__":
    main()
