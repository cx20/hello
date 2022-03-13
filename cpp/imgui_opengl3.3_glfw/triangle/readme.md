compile:
```
SET GLEW_HOME=C:\Libraries\glew-2.1.0
SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN64
SET IMGUI_HOME=C:\Libraries\imgui
SET INCLUDE=%GLEW_HOME%\include;%GLFW_HOME%\include;%IMGUI_HOME%;%IMGUI_HOME%\backends;%INCLUDE%
SET LIB=%GLEW_HOME%\lib\Release\x64;%GLFW_HOME%\lib-vc2022;%LIB%

cl hello.cpp ^
         %IMGUI_HOME%\imgui.cpp ^
         %IMGUI_HOME%\imgui_draw.cpp ^
         %IMGUI_HOME%\imgui_tables.cpp ^
         %IMGUI_HOME%\imgui_widgets.cpp ^
         %IMGUI_HOME%\backends\imgui_impl_opengl3.cpp ^
         %IMGUI_HOME%\backends\imgui_impl_glfw.cpp ^
         /link ^
         user32.lib ^
         shell32.lib ^
         gdi32.lib ^
         opengl32.lib ^
         glu32.lib ^
         glew32s.lib ^
         glfw3_mt.lib ^
         /SUBSYSTEM:WINDOWS

```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
| +------------------------------+         |
| |▼ Hello, World!              |         |
| +------------------------------+         |
| |Hello, Dear ImGui (C++) World!|         |
| +------------------------------+         |
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
