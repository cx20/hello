compile:
```
C:\> cl /O2 /W3 /D_CRT_SECURE_NO_WARNINGS hello.c ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         d3d11.lib ^
         dxguid.lib ^
         d3dcompiler.lib
```

run:
```
hello.exe triangle.nes
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
