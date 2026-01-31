SET WTL_DIR=C:\WTL\WTL10_10320_Release
SET INCLUDE=%INCLUDE%;%WTL_DIR%\INCLUDE

cl hello.cpp ^
         /link ^
         dxgi.lib ^
         d3d12.lib ^
         d3dcompiler.lib
