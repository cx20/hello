#!/bin/sh
set -e
swiftc hello.swift \
    -I c-modules \
    -Xcc -DGL_SILENCE_DEPRECATION \
    -Xfrontend -disable-availability-checking \
    -framework OpenGL \
    -framework GLUT \
    -o hello
echo "Build complete: hello"
