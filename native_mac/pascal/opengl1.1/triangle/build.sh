#!/bin/bash
set -e

if ! command -v fpc >/dev/null 2>&1; then
echo "Free Pascal compiler was not found."
echo "Install Free Pascal with:"
echo "  brew install fpc"
exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path)

cc -DGL_SILENCE_DEPRECATION -c hello_opengl.m -o hello_opengl.o

fpc -XR"${SDK_PATH}" \
    -k-framework -kCocoa \
    -k-framework -kOpenGL \
    hello.pas
