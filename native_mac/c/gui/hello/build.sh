#!/bin/bash

APP_NAME="Hello"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Compile C + Objective-C helper
cc -c hello_cocoa.m -o hello_cocoa.o
cc -o hello hello.c hello_cocoa.o -framework Cocoa

# Create app bundle structure
mkdir -p "${MACOS_DIR}"

# Move executable to app bundle
mv hello "${MACOS_DIR}/${APP_NAME}"

# Clean intermediate object files
rm -f hello_cocoa.o

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
    <string>com.example.hello.c</string>
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
