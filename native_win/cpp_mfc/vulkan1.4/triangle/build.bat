SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include;C:\Libraries\glfw-3.4.bin.WIN64\include;C:\Libraries\glm
SET LIB=%LIB%;%VULKAN_SDK%\Lib;C:\Libraries\glfw-3.4.bin.WIN64\lib-vc2022
SET PATH=%PATH%;%VULKAN_SDK%\bin

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

cl hello.cpp ^
         /std:c++20 ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         shell32.lib ^
         vulkan-1.lib ^
         /SUBSYSTEM:WINDOWS
