compile:
```
SET SDL_HOME=C:\Libraries\SDL2-devel-2.28.5-VC\SDL2-2.28.5
SET IMGUI_HOME=C:\Libraries\imgui
SET INCLUDE=%SDL_HOME%\include;%IMGUI_HOME%;%IMGUI_HOME%\backends;%INCLUDE%
SET LIB=%SDL_HOME%\lib\x64;%LIB%

cl hello.cpp ^
         %IMGUI_HOME%\imgui.cpp ^
         %IMGUI_HOME%\imgui_draw.cpp ^
         %IMGUI_HOME%\imgui_tables.cpp ^
         %IMGUI_HOME%\imgui_widgets.cpp ^
         %IMGUI_HOME%\backends\imgui_impl_opengl3.cpp ^
         %IMGUI_HOME%\backends\imgui_impl_sdl.cpp ^
         /link ^
         user32.lib ^
         shell32.lib ^
         gdi32.lib ^
         opengl32.lib ^
         sdl2.lib ^
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
