#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
VULKAN_HEADERS_PREFIX="$(brew --prefix vulkan-headers 2>/dev/null || echo /usr/local/opt/vulkan-headers)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

if ! command -v fpc >/dev/null 2>&1; then
    echo "Free Pascal compiler (fpc) not found. Install: brew install fpc"
    exit 1
fi
if ! command -v glslangValidator >/dev/null 2>&1; then
    echo "glslangValidator not found. Install: brew install glslang"
    exit 1
fi

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv

SDK=$(xcrun --show-sdk-path 2>/dev/null)

fpc hello.pas \
    -XR"${SDK}" \
    -Fl"${VULKAN_LOADER_PREFIX}/lib" \
    -Fl"${GLFW_PREFIX}/lib" \
    -k"-lglfw" \
    -k"-lvulkan"

echo "Build complete: hello"
