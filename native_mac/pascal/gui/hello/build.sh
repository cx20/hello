#!/bin/bash
set -e

if ! command -v fpc >/dev/null 2>&1; then
	echo "Free Pascal compiler was not found."
	echo "Install Free Pascal with:"
	echo "  brew install fpc"
	exit 1
fi

APP_NAME="Hello"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

SDK_PATH=$(xcrun --show-sdk-path)

cc -c hello_cocoa.m -o hello_cocoa.o

fpc -XR"${SDK_PATH}" \
    -k-framework -kCocoa \
    hello.pas

mkdir -p "${MACOS_DIR}"
mv hello "${MACOS_DIR}/${APP_NAME}"
rm -f hello_cocoa.o

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
    <string>com.example.hello.pascal</string>
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
