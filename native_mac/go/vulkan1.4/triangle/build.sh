#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"

# go-gl/glfw bundles GLFW source; vulkan-go uses dlopen at runtime.
# Only rpath entries are needed so the Vulkan loader can be found.
export CGO_CFLAGS=""
export CGO_LDFLAGS="-Wl,-rpath,${VULKAN_LOADER_PREFIX}/lib"

go build -o hello .
echo "Build complete: hello"
