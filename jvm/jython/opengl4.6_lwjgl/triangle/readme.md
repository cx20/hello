environment:
```
\
    hello.py
    lwjgl-glfw-natives-windows.jar
    lwjgl-glfw.jar
    lwjgl-opengl.jar
    lwjgl-vulkan.jar
    lwjgl.jar
    lwjgl.dll
```
run:
```
SET CLASSPATH=lwjgl.jar;lwjgl-glfw.jar;lwjgl-glfw-natives-windows.jar;lwjgl-opengl.jar;lwjgl-opengl.jar;lwjgl-vulkan.jar;.;%CLASSPATH%
jython hello.py
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