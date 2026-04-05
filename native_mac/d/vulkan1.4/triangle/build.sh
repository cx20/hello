#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
VULKAN_HEADERS_PREFIX="$(brew --prefix vulkan-headers 2>/dev/null || echo /usr/local/opt/vulkan-headers)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv

INCLUDES="-I${VULKAN_HEADERS_PREFIX}/include -I${MOLTENVK_PREFIX}/libexec/include -I${GLFW_PREFIX}/include"

if command -v dmd >/dev/null 2>&1; then
    # dmd passes linker flags with -L prefix
    dmd -of=hello hello.d $INCLUDES \
        -L-L${VULKAN_LOADER_PREFIX}/lib -L-L${GLFW_PREFIX}/lib \
        -L-lglfw -L-lvulkan
elif command -v ldc2 >/dev/null 2>&1; then
    ldc2 -of=hello hello.d $INCLUDES \
        -L-L${VULKAN_LOADER_PREFIX}/lib -L-L${GLFW_PREFIX}/lib \
        -L-lglfw -L-lvulkan
elif command -v gdc >/dev/null 2>&1; then
    gdc -o hello hello.d \
        -I${VULKAN_HEADERS_PREFIX}/include -I${MOLTENVK_PREFIX}/libexec/include -I${GLFW_PREFIX}/include \
        -L${VULKAN_LOADER_PREFIX}/lib -L${GLFW_PREFIX}/lib -lglfw -lvulkan
else
    echo "No D compiler (dmd/ldc2/gdc) found. Install with: brew install dmd"
    exit 1
fi
echo "Build complete: hello"
