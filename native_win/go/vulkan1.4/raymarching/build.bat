SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET PATH=%PATH%;%VULKAN_SDK%\bin

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

go build -ldflags="-H windowsgui" hello.go
