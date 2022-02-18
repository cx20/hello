compile:
```
SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN64
SET GLEW_HOME=C:\Libraries\glew-2.1.0
SET INCLUDE=%GLFW_HOME%\include;%GLEW_HOME%\include;%INCLUDE%
SET LIB=%GLFW_HOME%\lib-vc2019;%GLEW_HOME%\lib\Release\x64;%LIB%

cl hello.cpp ^
         /link ^
         opengl32.lib ^
         glu32.lib ^
         glew32.lib ^
         glfw3dll.lib
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