compile:
```
C:\> SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
C:\> SET INCLUDE=%DXSDK_DIR%\INCLUDE;%INCLUDE%
C:\> SET LIB=%DXSDK_DIR%\Lib\%VSCMD_ARG_TGT_ARCH%;%LIB%

C:\> cl hello.cpp ^
         /link ^
         dxguid.lib ^
         d3d11.lib ^
         d3dx11.lib ^
        /SUBSYSTEM:WINDOWS
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
