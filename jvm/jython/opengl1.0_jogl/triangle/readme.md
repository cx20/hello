environment:
```
\
|  hello.py
|  gluegen-rt.jar
|  jogl-all.jar
|
+-native
    +-windows-amd64
        gluegen-rt.dll
        jogl_desktop.dll
        nativewindow_awt.dll
        nativewindow_win32.dll
```
run:
```
SET CLASSPATH=gluegen-rt.jar;jogl-all.jar;%CLASSPATH%
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
