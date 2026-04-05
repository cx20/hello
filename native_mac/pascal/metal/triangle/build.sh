#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v fpc >/dev/null 2>&1; then
    echo "Free Pascal compiler (fpc) not found. Install: brew install fpc"
    exit 1
fi

# Compile Objective-C++ Metal wrapper
clang++ -fms-extensions -fblocks \
    -c metal_wrapper.mm -o metal_wrapper.o

SDK=$(xcrun --show-sdk-path 2>/dev/null)

fpc hello.pas \
    -XR"${SDK}" \
    -k"metal_wrapper.o" \
    -k"-framework" -k"Cocoa" \
    -k"-framework" -k"MetalKit" \
    -k"-framework" -k"Metal" \
    -k"-framework" -k"Foundation"

rm -f metal_wrapper.o hello.o
echo "Build complete: hello"
