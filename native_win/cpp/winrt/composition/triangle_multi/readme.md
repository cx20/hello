compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
C:\> SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
C:\> SET LIB=%LIB%;%VULKAN_SDK%\Lib
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:\> cl /EHsc /std:c++17 hello.cpp ^
        /link vulkan-1.lib ^
        d3d11.lib dxgi.lib d3dcompiler.lib opengl32.lib ^
        user32.lib gdi32.lib RuntimeObject.lib
```
Result:
```
+------------------------------------------------------------+
|Hello, World!                                      [_][~][X]|
+------------------------------------------------------------+
|                                                            |
|         /\                  /\                  /\         |
|        /  \                /  \                /  \        |
|       /    \              /    \              /    \       |
|      /      \            /      \            /      \      |
|     /        \          /        \          /        \     |
|    /          \        /          \        /          \    |
|   /            \      /            \      /            \   |
|  /              \    /              \    /              \  |
|  -----------------   -----------------   ----------------- |
+------------------------------------------------------------+
```
