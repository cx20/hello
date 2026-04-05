#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Compile Objective-C++ wrapper and archive into a static library
# (avoids duplicate symbol errors when CGo links the object twice)
clang++ -fms-extensions -fblocks \
    -c metal_wrapper.mm -o "${SCRIPT_DIR}/metal_wrapper.o"
ar rcs "${SCRIPT_DIR}/libmetal_wrapper.a" "${SCRIPT_DIR}/metal_wrapper.o"

# Build the Go binary, linking the static library + frameworks
CGO_ENABLED=1 \
CGO_CFLAGS="-I${SCRIPT_DIR}" \
CGO_LDFLAGS="-L${SCRIPT_DIR} -lmetal_wrapper -framework Cocoa -framework MetalKit -framework Metal -framework Foundation" \
    go build -o hello .

rm -f "${SCRIPT_DIR}/metal_wrapper.o" "${SCRIPT_DIR}/libmetal_wrapper.a"
echo "Build complete: hello"
