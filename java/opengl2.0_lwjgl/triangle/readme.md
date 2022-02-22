environment:
```
\
    Hello.java
    lwjgl.jar
    lwjgl-opengl.jar
    lwjgl-glfw.jar 
    lwjgl-natives-windows.jar
    lwjgl-opengl-natives-windows.jar

```
compile:
```
SET LWJGL_CLASSPATH=lwjgl.jar;lwjgl-opengl.jar;lwjgl-glfw.jar
javac -cp %LWJGL_CLASSPATH%;. Hello.java
```
run:
```
SET LWJGL_CLASSPATH=lwjgl.jar;lwjgl-opengl.jar;lwjgl-glfw.jar;lwjgl-natives-windows.jar;lwjgl-opengl-natives-windows.jar
java -cp %LWJGL_CLASSPATH%;. Hello
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
