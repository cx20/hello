SET WTL_DIR=C:\WTL\WTL10_10320_Release
SET INCLUDE=%INCLUDE%;%WTL_DIR%\INCLUDE

cl hello.cpp ^
         /link ^
         dxguid.lib ^
         d3d11.lib ^
         d3dcompiler.lib
