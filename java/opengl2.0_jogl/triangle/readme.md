environment:
```
\
|  gluegen-rt.jar
|  jogl-all.jar
|  Hello.java
|
+-natives
    +-windows-amd64
        gluegen-rt.dll
        jogl_desktop.dll
        nativewindow_awt.dll
        nativewindow_win32.dll
```
compile:
```
javac -cp gluegen-rt.jar;jogl-all.jar;. Hello.java
```
run:
```
java -cp gluegen-rt.jar;jogl-all.jar;. Hello
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
