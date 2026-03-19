compile:
```
jsc /target:winexe Hello.js

```
Requirements:
- Windows 8+ (DirectComposition)
- GPU with WGL_NV_DX_interop2 support (NVIDIA/AMD/Intel)
- Vulkan SDK (`shaderc_shared.dll` + `vulkan-1.dll`)
- `hello.vert` / `hello.frag` in the same folder

Result:
```
+------------------------------------------------------------+
|Hello, DirectComposition(JScript.NET) World!       [_][~][X]|
+------------------------------------------------------------+
| OpenGL triangle | DirectX11 triangle | Vulkan triangle     |
| (blue bg)       | (green bg)         | (red bg)            |
|      /\         |        /\          |       /\            |
|     /  \        |       /  \         |      /  \           |
|    / R  \       |      / G  \        |     / B  \          |
|   /      \      |     /      \       |    /      \         |
|  /________\     |    /________\      |   /________\        |
+------------------------------------------------------------+
```
