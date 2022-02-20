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
javac -cp ^
    lwjgl.jar; ^
    lwjgl-opengl.jar; ^
    lwjgl-glfw.jar; ^
    . ^
    Hello.java
```
run:
```
java -cp ^
    lwjgl.jar; ^
    lwjgl-opengl.jar; ^
    lwjgl-glfw.jar; ^
    lwjgl-natives-windows.jar; ^
    lwjgl-opengl-natives-windows.jar; ^
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
