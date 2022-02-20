environment:
```
\
    Hello.java
    wjgl-glfw.jar 
    lwjgl-natives-windows.jar
    lwjgl-opengl-natives-windows.jar
    lwjgl-opengl.jar
    lwjgl.jar

```
compile:
```
javac -cp ^
    lwjgl-glfw.jar;^
    lwjgl-opengl.jar;^
    lwjgl.jar;^
    . ^
    Hello.java
```
run:
```
java -cp ^
    lwjgl-glfw.jar;^
    lwjgl-opengl.jar;^
    lwjgl-opengl-natives-windows.jar;^
    lwjgl.jar;^
    lwjgl-natives-windows.jar;^
    . ^
    Hello
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
