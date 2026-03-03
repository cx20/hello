SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include;C:\Libraries\glm
SET LIB=%LIB%;%VULKAN_SDK%\Lib
SET PATH=%PATH%;%VULKAN_SDK%\bin

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

cl /EHsc ^
   /std:c++20 ^
   hello.cpp ^
   /link ^
   vulkan-1.lib ^
   d3d11.lib ^
   dxgi.lib ^
   d3dcompiler.lib ^
   opengl32.lib ^
   user32.lib ^
   gdi32.lib ^
   shell32.lib ^
   RuntimeObject.lib ^
   /SUBSYSTEM:WINDOWS
