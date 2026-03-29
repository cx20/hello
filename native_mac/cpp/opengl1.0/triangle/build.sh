#!/bin/sh
c++ -DGL_SILENCE_DEPRECATION -std=c++17 -o hello hello.cpp hello_opengl.mm -framework Cocoa -framework OpenGL
