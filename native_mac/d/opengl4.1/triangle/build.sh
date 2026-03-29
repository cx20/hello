#!/bin/bash
set -e

cc -DGL_SILENCE_DEPRECATION -c hello_opengl.m -o hello_opengl.o

if command -v dmd >/dev/null 2>&1; then
    dmd -ofhello hello.d hello_opengl.o -L-framework -LCocoa -L-framework -LOpenGL
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d hello_opengl.o -L-framework -LCocoa -L-framework -LOpenGL
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d hello_opengl.o -framework Cocoa -framework OpenGL
else
    echo "No D compiler found (dmd/ldc2/gdc)."
    echo "Install one of the following:"
    echo "  brew install dmd"
    echo "  brew install ldc"
    echo "  brew install gdc"
    exit 1
fi
