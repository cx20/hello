compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.304.0
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:\> csc /target:winexe Hello.cs
```
Result:
```
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
```

Caution #1:

The current version is WIP. The triangle is barely visible only in the debug build. Please note that it contains many bugs such as memory corruption.

Caution #2:

> validation layer: `setupLoaderTrampPhysDevs`:  Failed during dispatch call of '`vkEnumeratePhysicalDevices`' to lower layers or loader to get count.
> failed to find GPUs with Vulkan support!

If you get the above error at runtime, you may be able to improve it by setting the following environment variables.

```
SET DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
SET DISABLE_LAYER_NV_OPTIMUS_1=1
```
