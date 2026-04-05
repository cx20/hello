#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Compile Objective-C++ Metal wrapper
clang++ -fms-extensions -fblocks \
    -c metal_wrapper.mm -o metal_wrapper.o

if command -v dmd >/dev/null 2>&1; then
    dmd -of=hello hello.d metal_wrapper.o \
        -L-framework -LCocoa \
        -L-framework -LMetalKit \
        -L-framework -LMetal \
        -L-framework -LFoundation
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d metal_wrapper.o \
        -L-framework -LCocoa \
        -L-framework -LMetalKit \
        -L-framework -LMetal \
        -L-framework -LFoundation
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d metal_wrapper.o \
        -framework Cocoa \
        -framework MetalKit \
        -framework Metal \
        -framework Foundation
else
    echo "No D compiler (dmd/ldc2/gdc) found. Install with: brew install dmd"
    rm -f metal_wrapper.o
    exit 1
fi

rm -f metal_wrapper.o
echo "Build complete: hello"
