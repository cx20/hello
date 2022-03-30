environment:
```
\
|  gluegen-rt.jar
|  jogl-all.jar
|  Hello.j
|
+-native
    +-windows-amd64
        gluegen-rt.dll
        jogl_desktop.dll
        nativewindow_awt.dll
        nativewindow_win32.dll
```
compile:
```
java -jar jasmin.jar Hello.j
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
