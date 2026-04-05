#!/bin/sh
set -e
c++ -DGL_SILENCE_DEPRECATION -std=c++17 -o hello hello.mm -framework OpenGL -framework GLUT
