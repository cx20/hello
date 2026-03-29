compile:
```bash
$ brew install molten-vk vulkan-loader glfw glslang
$ sh build.sh
```

run:
```bash
$ sh run.sh
```

Result:
```txt
+------------------------------------------+
|  Hello, Vulkan (C, MoltenVK)   [_][~][X]|
+------------------------------------------+
|                                          |
|                   / \                    |
|                 /     \                  |
|               /         \                |
|             /             \              |
|           /                 \            |
|         /                     \          |
|       /                         \        |
|     /                             \      |
|    - - - - - - - - - - - - - - - - -     |
+------------------------------------------+
```

Notes:
- This sample uses Vulkan on macOS via MoltenVK.
- `run.sh` sets `VK_ICD_FILENAMES` to the MoltenVK ICD JSON.
- If you see `GLFW Vulkan surface extensions are unavailable`, your GLFW build may not include Vulkan surface support.
