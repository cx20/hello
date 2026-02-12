compile:
```

C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%VULKAN_SDK%\bin;%KONAN_HOME%\bin;%PATH%

C:\> kotlinc-native hello.kt -o hello
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