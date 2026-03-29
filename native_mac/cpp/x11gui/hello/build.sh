#!/bin/bash
set -e

X11_PREFIX=${X11_PREFIX:-/opt/X11}

if [ ! -d "$X11_PREFIX/include/X11" ] || [ ! -d "$X11_PREFIX/lib" ]; then
    echo "X11/XQuartz headers or libraries were not found under $X11_PREFIX"
    echo "Install XQuartz from https://www.xquartz.org/"
    echo "Or run with: X11_PREFIX=/path/to/X11 sh build.sh"
    exit 1
fi

c++ -o hello hello.cpp -I"$X11_PREFIX/include" -L"$X11_PREFIX/lib" -lX11
