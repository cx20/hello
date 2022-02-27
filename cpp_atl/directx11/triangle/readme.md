compile:
```
SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
SET INCLUDE=%INCLUDE%;%DXSDK_DIR%\INCLUDE
SET LIB=%LIB%;%DXSDK_DIR%\Lib\x86

cl hello.cpp ^
         /link ^
         dxguid.lib ^
         d3d11.lib ^
         d3dx11.lib
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
