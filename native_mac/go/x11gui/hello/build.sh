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

if ! command -v go >/dev/null 2>&1; then
    echo "Go compiler was not found."
    echo "Install Go with:"
    echo "  brew install go"
    exit 1
fi

export CGO_CFLAGS="-I${X11_PREFIX}/include"
export CGO_LDFLAGS="-L${X11_PREFIX}/lib -lX11"
GO111MODULE=off CGO_ENABLED=1 go build -o hello .

echo "Build complete: hello"
