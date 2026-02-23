compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
C:\> SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
C:\> SET LIB=%LIB%;%VULKAN_SDK%\Lib
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

C:\> glslc.exe hello.vert -o hello_vert.spv
C:\> glslc.exe hello.frag -o hello_frag.spv

C:¥> cl hello.c ^
         /MD ^
         /std:c17 ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         vulkan-1.lib ^
         d3d11.lib ^
         dxguid.lib ^
         d3dcompiler.lib ^
         /SUBSYSTEM:WINDOWS
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
Caution:

> validation layer: `setupLoaderTrampPhysDevs`:  Failed during dispatch call of '`vkEnumeratePhysicalDevices`' to lower layers or loader to get count.
> failed to find GPUs with Vulkan support!

If you get the above error at runtime, you may be able to improve it by setting the following environment variables.

```
SET DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
SET DISABLE_LAYER_NV_OPTIMUS_1=1
```