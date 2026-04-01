#!/bin/sh

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

if [ ! -f "$GLFW_PREFIX/include/GLFW/glfw3.h" ]; then
    echo "GLFW header not found under $GLFW_PREFIX/include"
    echo "Install with: brew install glfw"
    exit 1
fi

if [ ! -d "$GLFW_PREFIX/lib" ]; then
    echo "GLFW library directory not found under $GLFW_PREFIX/lib"
    exit 1
fi

c++ -DGL_SILENCE_DEPRECATION -std=c++17 -o hello hello.cpp -I"$GLFW_PREFIX/include" -L"$GLFW_PREFIX/lib" -lglfw -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo