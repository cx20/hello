compile:
```
set VULKAN_SDK=C:\VulkanSDK\1.4.313.0
%VULKAN_SDK%\Bin\glslangValidator -V hello.vert -o hello_vert.spv
%VULKAN_SDK%\Bin\glslangValidator -V hello.frag -o hello_frag.spv

cargo build --release
copy target\release\hello.exe
```

run:
```
hello.exe
```

result:
```
+------------------------------------------------------------+
|Hello, World!                                      [_][~][X]|
+------------------------------------------------------------+
|                                                            |
|         /\                  /\                  /\         |
|        /  \                /  \                /  \        |
|       /    \              /    \              /    \       |
|      /      \            /      \            /      \      |
|     /        \          /        \          /        \     |
|    /          \        /          \        /          \    |
|   /            \      /            \      /            \   |
|  /              \    /              \    /              \  |
|  -----------------   -----------------   ----------------- |
+------------------------------------------------------------+
```

notes:
- This sample composites three panels in one window via DirectComposition.
- Left panel: OpenGL triangle (WGL_NV_DX_interop).
- Center panel: Direct3D 11 triangle.
- Right panel: Vulkan triangle (offscreen + copy to D3D11).