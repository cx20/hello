build:
```bash
$ sh build.sh
```

run:
```bash
$ sh run.sh
```

Result:
```txt
+------------------------------------------+
|Hello Vulkan (Objective-C++, MoltenVK)   |
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
- Uses Vulkan on macOS via MoltenVK.
- Requires: `molten-vk`, `vulkan-loader`, `vulkan-headers`, `glfw`, `glslang`.
- `run.sh` sets `VK_ICD_FILENAMES` and loader library search paths.
