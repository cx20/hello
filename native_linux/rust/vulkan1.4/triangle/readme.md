prerequisites:
- Hardware GPU with Vulkan 1.4 driver support
- Note: Software renderers (e.g. Mesa lavapipe on WSL) do not support Vulkan WSI and will fail at runtime

compile:
```
$ cargo build --release
```
Result:
```
+------------------------------------------+
|            Hello, World!        [_][~][X]|
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