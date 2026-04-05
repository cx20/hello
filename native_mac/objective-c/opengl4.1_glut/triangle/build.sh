#!/bin/sh
set -e
cc -DGL_SILENCE_DEPRECATION -o hello hello.m -framework OpenGL -framework GLUT
echo "Build complete: hello"
