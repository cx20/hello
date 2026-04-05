#!/bin/sh
set -e

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

swiftc hello.swift \
    -I c-modules \
    -Xcc -I"${GLFW_PREFIX}/include" \
    -L"${GLFW_PREFIX}/lib" \
    -lglfw \
    -DGL_SILENCE_DEPRECATION \
    -framework OpenGL \
    -framework Cocoa \
    -framework IOKit \
    -framework CoreVideo \
    -o hello
echo "Build complete: hello"
