#!/bin/bash
set -e

APP_NAME="Hello"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Compile Objective-C bridge
cc -c hello_cocoa.m -o hello_cocoa.o -framework Cocoa

# Compile and link D source
if command -v dmd >/dev/null 2>&1; then
    dmd -ofhello hello.d hello_cocoa.o -L-framework -LCocoa
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d hello_cocoa.o -L-framework -LCocoa
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d hello_cocoa.o -framework Cocoa
else
    echo "No D compiler found (dmd/ldc2/gdc)."
    echo "Install one of the following:"
    echo "  brew install dmd"
    echo "  brew install ldc"
    exit 1
fi

rm -f hello_cocoa.o

# Create app bundle
mkdir -p "${MACOS_DIR}"
mv hello "${MACOS_DIR}/${APP_NAME}"

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
    <string>com.example.hello.d</string>
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
