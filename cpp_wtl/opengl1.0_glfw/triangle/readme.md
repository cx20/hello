compile:
```
SET GLEW_HOME=C:\Libraries\glew-2.1.0
SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN64
SET INCLUDE=C:\WTL\WTL10_10320_Release\Include;%INCLUDE%
SET INCLUDE=%GLEW_HOME%\include;%GLFW_HOME%\include;%INCLUDE%
SET LIB=%GLEW_HOME%\lib\Release\x64;%GLFW_HOME%\lib-vc2022;%LIB%

cl hello.cpp ^
         /DGLFW_EXPOSE_NATIVE_WIN32 ^
         /link ^
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
