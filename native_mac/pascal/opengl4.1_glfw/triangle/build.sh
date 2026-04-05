#!/bin/bash
set -e

if ! command -v fpc >/dev/null 2>&1; then
    echo "Free Pascal compiler was not found."
    echo "Install Free Pascal with:"
    echo "  brew install fpc"
    exit 1
fi

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path)

cc -DGL_SILENCE_DEPRECATION -c hello_glfw.c -I"${GLFW_PREFIX}/include" -o hello_glfw.o

fpc -XR"${SDK_PATH}" \
    -Fl"${GLFW_PREFIX}/lib" \
    -k-lglfw \
    -k-framework -kOpenGL \
    -k-framework -kCocoa \
    -k-framework -kIOKit \
    -k-framework -kCoreVideo \
    hello.pas
