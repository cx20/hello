#!/bin/sh
set -e

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -o hello hello.m \
    -I"$GLFW_PREFIX/include" -L"$GLFW_PREFIX/lib" -lglfw \
    -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo
