#!/bin/bash

echo "Monitoring ShareExtension logs..."
echo "Try using the share sheet now!"
echo ""

xcrun simctl spawn booted log stream --predicate 'process == "ShareExtension"' --style compact 2>&1
