SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
SET LIB=%LIB%;%VULKAN_SDK%\Lib
SET PATH=%PATH%;%VULKAN_SDK%\bin

cl hello.cpp ^
         /clr ^
         /std:c++20 ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         shell32.lib ^
         vulkan-1.lib ^
         shaderc_combined.lib
