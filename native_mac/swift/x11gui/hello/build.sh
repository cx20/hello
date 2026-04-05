#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

X11_PREFIX=${X11_PREFIX:-/opt/X11}

if [ ! -d "$X11_PREFIX/include/X11" ] || [ ! -d "$X11_PREFIX/lib" ]; then
    echo "X11/XQuartz headers or libraries were not found under $X11_PREFIX"
    echo "Install XQuartz from https://www.xquartz.org/"
    echo "Or run with: X11_PREFIX=/path/to/X11 sh build.sh"
    exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Swift compiler was not found."
    echo "Install Xcode or the Swift toolchain from https://swift.org/download/"
    exit 1
fi

swiftc hello.swift \
    -I . \
    -Xcc "-I${X11_PREFIX}/include" \
    -L "${X11_PREFIX}/lib" \
    -lX11 \
    -module-cache-path /tmp/swiftmodule-cache \
    -o hello

echo "Build complete: hello"
