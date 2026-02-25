SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
SET LIB=%LIB%;%VULKAN_SDK%\Lib
SET PATH=%PATH%;%VULKAN_SDK%\bin

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

dmd hello.d ^
     user32.lib ^
     gdi32.lib ^
     opengl32.lib ^
     ole32.lib ^
     d3d11.lib ^
     dxguid.lib ^
     d3dcompiler.lib ^
     dcomp.lib ^
     %VULKAN_SDK%\Lib\vulkan-1.lib
