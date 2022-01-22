compile:

C:\> SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
C:\> SET INCLUDE=%DXSDK_DIR%\INCLUDE;%INCLUDE%
C:\> SET LIB=%DXSDK_DIR%\Lib\x86;%LIB%

C:\> cl hello.c ^
         /link ^
         user32.lib ^
         d3d9.lib ^
         /SUBSYSTEM:WINDOWS

Result:
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
