#!/bin/sh
set -e

if ! command -v rustc >/dev/null 2>&1; then
    echo "Rust compiler was not found."
    echo "Install Rust with: brew install rust"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -c hello_glut.c -o hello_glut.o
ar rcs libhello_glut.a hello_glut.o

rustc hello.rs -o hello \
    -L . \
    -l static=hello_glut \
    -C link-arg=-framework \
    -C link-arg=GLUT \
    -C link-arg=-framework \
    -C link-arg=OpenGL
echo "Build complete: hello"
