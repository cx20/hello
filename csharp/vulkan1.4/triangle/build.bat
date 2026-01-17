SET VULKAN_SDK=C:\VulkanSDK\1.4.304.0
SET PATH=%PATH%;%VULKAN_SDK%\bin

rem csc /debug+ /debug:full /define:DEBUG /optimize- Hello.cs
rem csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe Hello.cs
rem csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe /target:winexe Hello.cs
rem csc Hello.cs
csc /target:winexe Hello.cs
