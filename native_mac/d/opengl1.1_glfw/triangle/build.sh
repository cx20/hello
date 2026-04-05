#!/bin/bash
set -e

if ! command -v dmd >/dev/null 2>&1 && ! command -v ldc2 >/dev/null 2>&1 && ! command -v gdc >/dev/null 2>&1; then
    echo "No D compiler found (dmd/ldc2/gdc)."
    echo "Install one of the following:"
    echo "  brew install dmd"
    echo "  brew install ldc"
    exit 1
fi

GLFW_PREFIX=$(brew --prefix glfw 2>/dev/null)
if [ -z "$GLFW_PREFIX" ]; then
    echo "glfw is required. Install with: brew install glfw"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -c hello_glfw.c -I"${GLFW_PREFIX}/include" -o hello_glfw.o

if command -v dmd >/dev/null 2>&1; then
    dmd -ofhello hello.d hello_glfw.o -L-L"${GLFW_PREFIX}/lib" -L-lglfw \
        -L-framework -LOpenGL -L-framework -LCocoa -L-framework -LIOKit -L-framework -LCoreVideo
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d hello_glfw.o -L-L"${GLFW_PREFIX}/lib" -L-lglfw \
        -L-framework -LOpenGL -L-framework -LCocoa -L-framework -LIOKit -L-framework -LCoreVideo
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d hello_glfw.o -L"${GLFW_PREFIX}/lib" -lglfw \
        -framework OpenGL -framework Cocoa -framework IOKit -framework CoreVideo
fi
