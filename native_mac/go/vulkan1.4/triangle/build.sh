#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

export CGO_CFLAGS="-I${MOLTENVK_PREFIX}/libexec/include -I${GLFW_PREFIX}/include"
export CGO_LDFLAGS="-L${MOLTENVK_PREFIX}/libexec/lib -L${VULKAN_LOADER_PREFIX}/lib -L${GLFW_PREFIX}/lib -lglfw -lvulkan"

go build -o hello .
echo "Build complete: hello"
