#!/bin/sh

if ! command -v rustc >/dev/null 2>&1; then
    echo "Rust compiler was not found."
    echo "Install Rust with:"
    echo "brew install rust"
    exit 1
fi

cc -DGL_SILENCE_DEPRECATION -c hello_opengl.m -o hello_opengl.o
ar rcs libhello_opengl.a hello_opengl.o

rustc hello.rs -o hello \
    -L . \
    -l static=hello_opengl \
    -C link-arg=-framework \
    -C link-arg=Cocoa \
    -C link-arg=-framework \
    -C link-arg=OpenGL
