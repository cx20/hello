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
- Implemented as pure Rust.
- All logic is consolidated in one source file: `src/main.rs`.
- Uses Windows.UI.Composition to composite OpenGL/D3D11/Vulkan triangle panels.
