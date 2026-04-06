#!/bin/sh
gcc -c hello_glut.c -o hello_glut.o
fpc -Px86_64 hello.pas -k"-lGL -lglut"
