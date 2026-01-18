compile:
```
C:\> SET VULKAN_SDK=C:\VulkanSDK\1.4.304.0
C:\> SET PATH=%PATH%;%VULKAN_SDK%\bin

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

Caution:

> validation layer: `setupLoaderTrampPhysDevs`:  Failed during dispatch call of '`vkEnumeratePhysicalDevices`' to lower layers or loader to get count.
> failed to find GPUs with Vulkan support!

If you get the above error at runtime, you may be able to improve it by setting the following environment variables.

```
SET DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
SET DISABLE_LAYER_NV_OPTIMUS_1=1
```
