compile:
```
$ go build -o hello .
```

Prerequisites:
- libvulkan.so.1 (Vulkan ICD loader)
- Hardware GPU with Vulkan driver support
- Note: WSL software rendering (lavapipe) does NOT support Vulkan WSI

Result:
```
+------------------------------------------+
|           Hello, World!         [_][~][X]|
+------------------------------------------+
|                                          |
|                    / \                   |
|                  /     \                 |
|                /         \               |
|              /             \             |
|            /                 \           |
|          /                     \         |
|        /                         \       |
|      /                             \     |
|    - - - - - - - - - - - - - - - - -     |
+------------------------------------------+
```
