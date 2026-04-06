#!/bin/sh
gcc -c hello_glut.c -o hello_glut.o
gdc -o hello hello.d hello_glut.o -lGL -lglut
