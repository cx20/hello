compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%KONAN_HOME%\bin;%PATH%

C:\> kotlinc-native hello.kt -o hello -linker-options "-lopengl32"
```

run:
```
C:\> hello
```

Result:
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

- One window with 3 panels composed by `Windows.UI.Composition`:
  - Left: OpenGL triangle
  - Center: Direct3D 11 triangle
  - Right: Vulkan triangle
