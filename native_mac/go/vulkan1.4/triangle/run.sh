#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"
GLFW_PREFIX="$(brew --prefix glfw 2>/dev/null || echo /usr/local/opt/glfw)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"
export DYLD_FALLBACK_LIBRARY_PATH="${VULKAN_LOADER_PREFIX}/lib:${GLFW_PREFIX}/lib:/usr/local/lib:/usr/lib:${DYLD_FALLBACK_LIBRARY_PATH}"

if [ ! -x ./hello ]; then
    echo "./hello was not found. Run 'sh build.sh' first."
    exit 1
fi
exec ./hello
