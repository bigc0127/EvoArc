#!/bin/bash
set -e

PROJECT_FILE="/Users/needling0127/Dev/EvoArc/EvoArc.xcodeproj/project.pbxproj"

echo "Updating Xcode project for iOS/iPadOS only..."

# Remove macOS-specific lines
sed -i '' '/CODE_SIGN_ENTITLEMENTS\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/CODE_SIGN_IDENTITY\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/ENABLE_APP_SANDBOX\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/ENABLE_HARDENED_RUNTIME\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/GCC_TREAT_WARNINGS_AS_ERRORS\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/INFOPLIST_FILE\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/LD_RUNPATH_SEARCH_PATHS\[sdk=macosx\*\]/d' "$PROJECT_FILE"
sed -i '' '/SWIFT_TREAT_WARNINGS_AS_ERRORS\[sdk=macosx\*\]/d' "$PROJECT_FILE"

# Remove MACOSX_DEPLOYMENT_TARGET and XROS_DEPLOYMENT_TARGET lines
sed -i '' '/MACOSX_DEPLOYMENT_TARGET/d' "$PROJECT_FILE"
sed -i '' '/XROS_DEPLOYMENT_TARGET/d' "$PROJECT_FILE"

# Change SDK-specific settings to non-conditional
sed -i '' 's/"CODE_SIGN_ENTITLEMENTS\[sdk=iphone\*\]"/CODE_SIGN_ENTITLEMENTS/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_FILE\[sdk=iphone\*\]"/INFOPLIST_FILE/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIApplicationSceneManifest_Generation\[sdk=iphoneos\*\]"/INFOPLIST_KEY_UIApplicationSceneManifest_Generation/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIApplicationSceneManifest_Generation\[sdk=iphonesimulator\*\]"//g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents\[sdk=iphoneos\*\]"/INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents\[sdk=iphonesimulator\*\]"//g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UILaunchScreen_Generation\[sdk=iphoneos\*\]"/INFOPLIST_KEY_UILaunchScreen_Generation/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UILaunchScreen_Generation\[sdk=iphonesimulator\*\]"//g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIStatusBarStyle\[sdk=iphoneos\*\]"/INFOPLIST_KEY_UIStatusBarStyle/g' "$PROJECT_FILE"
sed -i '' 's/"INFOPLIST_KEY_UIStatusBarStyle\[sdk=iphonesimulator\*\]"//g' "$PROJECT_FILE"

# Remove empty lines with just = YES;
sed -i '' '/^[[:space:]]*= YES;$/d' "$PROJECT_FILE"
sed -i '' '/^[[:space:]]*= UIStatusBarStyleDefault;$/d' "$PROJECT_FILE"

# Update SUPPORTED_PLATFORMS
sed -i '' 's/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator";/SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";/g' "$PROJECT_FILE"

# Update TARGETED_DEVICE_FAMILY  
sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2,7";/TARGETED_DEVICE_FAMILY = "1,2";/g' "$PROJECT_FILE"

# Update SDKROOT
sed -i '' 's/SDKROOT = auto;/SDKROOT = iphoneos;/g' "$PROJECT_FILE"

# Update test bundle identifiers
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = ConnorNeedling.EvoArcTests;/PRODUCT_BUNDLE_IDENTIFIER = com.ConnorNeedling.EvoArcBrowser.EvoArcTests;/g' "$PROJECT_FILE"
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = ConnorNeedling.EvoArcUITests;/PRODUCT_BUNDLE_IDENTIFIER = com.ConnorNeedling.EvoArcBrowser.EvoArcUITests;/g' "$PROJECT_FILE"

echo "✅ Project file updated successfully"
echo "Verifying project..."

xcodebuild -list -project /Users/needling0127/Dev/EvoArc/EvoArc.xcodeproj > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Project file is valid!"
else
    echo "❌ Project file has errors. Restoring backup..."
    cp "$PROJECT_FILE.backup" "$PROJECT_FILE"
    exit 1
fi
