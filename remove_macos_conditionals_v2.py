#!/usr/bin/env python3
"""
Improved script to remove macOS conditional compilation from Swift files.
"""

import re
from pathlib import Path

def remove_macos_blocks(content):
    """Remove macOS conditional compilation blocks more carefully."""
    lines = content.split('\n')
    result = []
    stack = []  # Stack to track conditional blocks
    skip_until_endif = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Track #if blocks
        if re.match(r'^\s*#if\s+os\(macOS\)', line):
            skip_until_endif += 1
            i += 1
            continue
        
        # Remove lines within macOS blocks
        if skip_until_endif > 0:
            if re.match(r'^\s*#if', line):
                skip_until_endif += 1
            elif re.match(r'^\s*#endif', line):
                skip_until_endif -= 1
            i += 1
            continue
        
        # Handle #if os(iOS) - remove the directive but keep the content
        if re.match(r'^\s*#if\s+os\(iOS\)', line):
            stack.append('ios')
            i += 1
            continue
        
        # Handle #elseif os(macOS) - skip content
        if re.match(r'^\s*#elseif\s+os\(macOS\)', line):
            if stack and stack[-1] == 'ios':
                skip_until_endif = 1
            i += 1
            continue
        
        # Handle #else after iOS block (macOS code)
        if re.match(r'^\s*#else\s*$', line):
            if stack and stack[-1] == 'ios':
                skip_until_endif = 1
            i += 1
            continue
        
        # Handle #endif
        if re.match(r'^\s*#endif', line):
            if stack and stack[-1] == 'ios':
                stack.pop()
            i += 1
            continue
        
        # Keep the line
        result.append(line)
        i += 1
    
    return '\n'.join(result)

def process_file(file_path):
    """Process a single Swift file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file has macOS conditional compilation
        if 'os(macOS)' not in content:
            return False
        
        new_content = remove_macos_blocks(content)
        
        # Remove any orphaned imports
        new_content = re.sub(r'import\s+AppKit\s*\n', '', new_content)
        
        if new_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"✅ Processed: {file_path.name}")
            return True
        else:
            return False
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        return False

def main():
    evoarc_path = Path("/Users/needling0127/Dev/EvoArc/EvoArc")
    
    # Process specific files that need macOS removal
    files_to_process = [
        "Views/SettingsView.swift",
        "Views/ScrollDetectingWebView.swift",
        "Views/WebView.swift",
        "Views/ChromiumWebView.swift",
        "Utilities/ThumbnailManager.swift",
    ]
    
    print("Processing Swift files for macOS removal...")
    print()
    
    processed = 0
    for file_rel_path in files_to_process:
        file_path = evoarc_path / file_rel_path
        if file_path.exists():
            if process_file(file_path):
                processed += 1
        else:
            print(f"⚠️  File not found: {file_path}")
    
    print()
    print(f"Processed {processed} files")

if __name__ == "__main__":
    main()
