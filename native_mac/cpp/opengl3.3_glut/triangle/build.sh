#!/bin/sh
c++ -DGL_SILENCE_DEPRECATION -std=c++17 -o hello hello.cpp -framework OpenGL -framework GLUT
echo "Build complete: hello"
