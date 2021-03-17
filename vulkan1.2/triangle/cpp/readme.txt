compile:

C:\> SET VULKAN_SDK=C:\VulkanSDK\1.2.170.0
C:\> SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include;C:\Libraries\glfw-3.3.3.bin.WIN64\include;C:\Libraries\glm
C:\> SET LIB=%LIB%;%VULKAN_SDK%\Lib;C:\Libraries\glfw-3.3.3.bin.WIN64\lib-vc2017
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:\> cl hello.cpp ^
         /MD ^
         /std:c++17 ^
         /DUNICODE ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         shell32.lib ^
         vulkan-1.lib ^
         glfw3.lib

Result:
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
