#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/Cellar/molten-vk/1.4.1)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local)"
VULKAN_HEADERS_PREFIX="$(brew --prefix vulkan-headers 2>/dev/null || echo /usr/local)"

INCLUDE="-I${VULKAN_HEADERS_PREFIX}/include -I${MOLTENVK_PREFIX}/libexec/include -I/usr/local/include"
LIBS="-L${VULKAN_LOADER_PREFIX}/lib -L/usr/local/lib -lglfw -lvulkan"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv
cc -o hello hello.m $INCLUDE $LIBS
