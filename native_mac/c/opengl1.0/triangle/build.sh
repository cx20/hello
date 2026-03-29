#!/bin/sh
cc -DGL_SILENCE_DEPRECATION -o hello hello.c hello_opengl.m -framework Cocoa -framework OpenGL
