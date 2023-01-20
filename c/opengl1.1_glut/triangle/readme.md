compile:
```
SET GLUT_HOME=C:\Libraries\glut-3.7.6-bin
SET PATH=%GLUT_HOME%;%PATH%
SET INCLUDE=%GLUT_HOME%;%INCLUDE%
SET LIB=%GLUT_HOME%;%LIB%

cl hello.c ^
         /link ^
         glut32.lib

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

Caution:

> `GLUT` has long been unmaintained, so it is recommended to use `freeglut` or other OpenGL Utility Toolkit.
