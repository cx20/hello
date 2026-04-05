#!/bin/sh
set -e

APP_NAME="Hello"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

if ! command -v rustc >/dev/null 2>&1; then
    echo "Rust compiler was not found."
    echo "Install Rust with:"
    echo "  brew install rust"
    exit 1
fi

# Compile Objective-C bridge and create static library
cc -c hello_cocoa.m -o hello_cocoa.o
ar rcs libhello_cocoa.a hello_cocoa.o

# Compile and link Rust source
rustc hello.rs -o hello \
    -L . \
    -l static=hello_cocoa \
    -C link-arg=-framework \
    -C link-arg=Cocoa

rm -f hello_cocoa.o libhello_cocoa.a

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
    <string>com.example.hello.rust</string>
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
