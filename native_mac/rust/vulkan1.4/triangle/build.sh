#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
VULKAN_LOADER_PREFIX="$(brew --prefix vulkan-loader 2>/dev/null || echo /usr/local/opt/vulkan-loader)"

export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"
export VULKAN_LIB_DIR="${VULKAN_LOADER_PREFIX}/lib"
export PKG_CONFIG_PATH="${VULKAN_LOADER_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"

cargo build --release
cp target/release/hello .
echo "Build complete: hello"
