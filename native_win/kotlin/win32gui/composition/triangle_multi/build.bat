SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET KONAN_HOME=C:\kotlin-native
SET PATH=%VULKAN_SDK%\bin;%KONAN_HOME%\bin;%PATH%
SET JAVA_TOOL_OPTIONS=-XX:ReservedCodeCacheSize=256m

kotlinc-native hello.kt -o hello -linker-options "-lopengl32"

