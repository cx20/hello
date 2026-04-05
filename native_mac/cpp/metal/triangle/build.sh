#!/bin/bash
set -e

# Compile Objective-C++ wrapper
clang++ -fms-extensions -fblocks \
    -c metal_wrapper.mm -o metal_wrapper.o

# Compile C++ main
clang++ -std=c++17 -c hello.cpp -o hello.o

# Link with clang++ to handle Objective-C++
clang++ -o hello hello.o metal_wrapper.o \
    -framework Cocoa \
    -framework MetalKit \
    -framework Metal \
    -framework Foundation

rm -f hello.o metal_wrapper.o
echo "✓ Built hello"
