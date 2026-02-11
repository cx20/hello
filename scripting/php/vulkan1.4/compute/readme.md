compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> php hello.php
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
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

Note:
- This sample uses PHP FFI. Enable it in `php.ini` (e.g. `ffi.enable=1`).
