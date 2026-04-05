#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MOLTENVK_PREFIX="$(brew --prefix molten-vk 2>/dev/null || echo /usr/local/opt/molten-vk)"
export VK_ICD_FILENAMES="${MOLTENVK_PREFIX}/etc/vulkan/icd.d/MoltenVK_icd.json"
export DYLD_FALLBACK_LIBRARY_PATH="/usr/local/lib:/opt/homebrew/lib:/usr/lib:${DYLD_FALLBACK_LIBRARY_PATH}"

if [ ! -x ./hello ]; then
    echo "./hello was not found. Run 'sh build.sh' first."
    exit 1
fi
exec ./hello
