#!/bin/bash
set -e

if ! command -v dmd >/dev/null 2>&1 && ! command -v ldc2 >/dev/null 2>&1 && ! command -v gdc >/dev/null 2>&1; then
    echo "No D compiler found (dmd/ldc2/gdc)."
    echo "Install one of the following:"
    echo "  brew install dmd"
    echo "  brew install ldc"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -c hello_glut.c -o hello_glut.o

if command -v dmd >/dev/null 2>&1; then
    dmd -ofhello hello.d hello_glut.o -L-framework -LGLUT -L-framework -LOpenGL
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d hello_glut.o -L-framework -LGLUT -L-framework -LOpenGL
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d hello_glut.o -framework GLUT -framework OpenGL
fi
echo "Build complete: hello"
