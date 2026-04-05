#!/bin/sh
set -e

if ! command -v rustc >/dev/null 2>&1; then
    echo "Rust compiler was not found."
    echo "Install Rust with: brew install rust"
    exit 1
fi

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -c hello_glfw.c -I"${GLFW_PREFIX}/include" -o hello_glfw.o
ar rcs libhello_glfw.a hello_glfw.o

rustc hello.rs -o hello \
    -L . \
    -l static=hello_glfw \
    -L "${GLFW_PREFIX}/lib" \
    -l glfw \
    -C link-arg=-framework \
    -C link-arg=OpenGL \
    -C link-arg=-framework \
    -C link-arg=Cocoa \
    -C link-arg=-framework \
    -C link-arg=IOKit \
    -C link-arg=-framework \
    -C link-arg=CoreVideo
