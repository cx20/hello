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

if command -v dmd >/dev/null 2>&1; then
    dmd -ofhello hello.d -I="$X11_PREFIX/include" -L-L"$X11_PREFIX/lib" -L-lX11
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d -I="$X11_PREFIX/include" -L-L"$X11_PREFIX/lib" -L-lX11
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d -I"$X11_PREFIX/include" -L"$X11_PREFIX/lib" -lX11
else
    echo "No D compiler found (dmd/ldc2/gdc)."
    echo "Install one of the following:"
    echo "  brew install dmd"
    echo "  brew install ldc"
    exit 1
fi

echo "Build complete: hello"
