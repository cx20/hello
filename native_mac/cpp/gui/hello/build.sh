#!/bin/bash

APP_NAME="Hello"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Compile Objective-C++ bridge (needs Cocoa framework headers)
c++ -std=c++17 -c hello_cocoa_bridge.mm -o hello_cocoa_bridge.o

# Compile C++ main
c++ -std=c++17 -c hello.cpp -o hello.o

# Link
c++ -std=c++17 -o hello hello.o hello_cocoa_bridge.o -framework Cocoa

# Clean intermediate object files
rm -f hello.o hello_cocoa_bridge.o

# Create app bundle structure
mkdir -p "${MACOS_DIR}"

# Move executable to app bundle
mv hello "${MACOS_DIR}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Hello</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.hello.cpp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Hello</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSMainNibFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Build complete: ${BUNDLE_DIR}"
