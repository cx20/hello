compile:
```
C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:\> cl hello.cpp ^
         /std:c++20 ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         shell32.lib ^
         vulkan-1.lib ^
         /SUBSYSTEM:WINDOWS
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
