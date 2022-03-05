Library:
https://wtl.sourceforge.io/

How to compile:
```
C:\> SET WTL_DIR=C:\WTL\WTL10_10320_Release
C:\> SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
C:\> SET INCLUDE=%INCLUDE%;%DXSDK_DIR%\INCLUDE;%WTL_DIR%\INCLUDE
C:\> SET LIB=%LIB%;%DXSDK_DIR%\Lib\%VSCMD_ARG_TGT_ARCH%

C:\> cl hello.cpp ^
         /link ^
         user32.lib ^
         dxguid.lib ^
         d3d9.lib ^
         d3dx9.lib ^
         /SUBSYSTEM:WINDOWS
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|Hello, DirectX(WTL) World!                |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
+------------------------------------------+
```
