#!/bin/sh
set -e

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

c++ -DGL_SILENCE_DEPRECATION -std=c++17 -o hello hello.mm \
    -I"$GLFW_PREFIX/include" -L"$GLFW_PREFIX/lib" -lglfw \
    -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo
