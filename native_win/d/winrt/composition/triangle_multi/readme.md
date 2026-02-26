compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
C:\> SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
C:\> SET LIB=%LIB%;%VULKAN_SDK%\Lib
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:\> dmd hello.d ^
     user32.lib ^
     gdi32.lib ^
     opengl32.lib ^
     ole32.lib ^
     d3d11.lib ^
     dxguid.lib ^
     d3dcompiler.lib ^
     dcomp.lib ^
     %VULKAN_SDK%\Lib\vulkan-1.lib
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
