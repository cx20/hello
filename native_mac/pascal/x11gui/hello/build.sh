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

if ! command -v fpc >/dev/null 2>&1; then
    echo "Free Pascal compiler (fpc) was not found."
    echo "Install Free Pascal with:"
    echo "  brew install fpc"
    exit 1
fi

SDK=$(xcrun --show-sdk-path 2>/dev/null)
if [ -n "$SDK" ]; then
    fpc hello.pas -XR"$SDK" -Fl"$X11_PREFIX/lib" -k"-lX11"
else
    fpc hello.pas -Fl"$X11_PREFIX/lib" -k"-lX11"
fi

echo "Build complete: hello"
