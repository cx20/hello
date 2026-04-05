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

if ! command -v cargo >/dev/null 2>&1; then
    echo "Rust/Cargo was not found."
    echo "Install Rust with:"
    echo "  brew install rust"
    exit 1
fi

X11_LIB_DIR="${X11_PREFIX}/lib" \
PKG_CONFIG_PATH="${X11_PREFIX}/lib/pkgconfig" \
cargo build --release

echo "Build complete: target/release/hello"
