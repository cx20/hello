SET VULKAN_SDK=C:\VulkanSDK\1.4.304.0
SET PATH=%PATH%;%VULKAN_SDK%\bin

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

rem csc /debug+ /debug:full /define:DEBUG /optimize- Hello.cs
csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe Hello.cs
rem csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe /target:winexe Hello.cs
rem csc /target:winexe Hello.cs
