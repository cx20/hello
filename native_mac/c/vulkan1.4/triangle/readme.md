compile:
```bash
$ brew install molten-vk vulkan-loader vulkan-headers glfw glslang
$ sh build.sh
```

run:
```bash
$ sh run.sh
```

clean:
```bash
$ sh clean.sh
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
- `hello` and `run.sh` both set Vulkan loader search paths for Homebrew (`/usr/local/lib`, `/opt/homebrew/lib`).
- `./hello` automatically relaunches itself once when needed so `DYLD_FALLBACK_LIBRARY_PATH` takes effect.
- If you still see `GLFW Vulkan surface extensions are unavailable`, ensure `vulkan-loader` and `glfw` are installed and up to date.
