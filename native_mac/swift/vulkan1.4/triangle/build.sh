#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
VULKAN_HEADERS_PREFIX="$(brew --prefix vulkan-headers 2>/dev/null || echo /usr/local/opt/vulkan-headers)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

glslangValidator -V hello.vert -o hello_vert.spv
glslangValidator -V hello.frag -o hello_frag.spv

swiftc hello.swift \
  -I c-modules \
  -Xcc -I"${VULKAN_HEADERS_PREFIX}/include" \
  -Xcc -I"${MOLTENVK_PREFIX}/libexec/include" \
  -Xcc -I"${GLFW_PREFIX}/include" \
  -L"${VULKAN_LOADER_PREFIX}/lib" \
  -L"${GLFW_PREFIX}/lib" \
  -lglfw \
  -lvulkan \
  -o hello