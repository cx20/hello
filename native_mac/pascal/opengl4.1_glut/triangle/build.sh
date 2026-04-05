#!/bin/bash
set -e

if ! command -v fpc >/dev/null 2>&1; then
    echo "Free Pascal compiler was not found."
    echo "Install Free Pascal with:"
    echo "  brew install fpc"
    exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path)

cc -DGL_SILENCE_DEPRECATION -c hello_glut.c -o hello_glut.o

fpc -XR"${SDK_PATH}" \
    -k-framework -kOpenGL \
    -k-framework -kGLUT \
    hello.pas
echo "Build complete: hello"
