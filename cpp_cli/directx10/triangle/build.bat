SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
SET INCLUDE=%INCLUDE%;%DXSDK_DIR%\INCLUDE;
SET LIB=%LIB%;%DXSDK_DIR%\Lib\%VSCMD_ARG_TGT_ARCH%;

cl hello.cpp ^
         /clr ^
         /link ^
         user32.lib ^
         d3d10.lib ^
         d3dx10.lib ^
         /SUBSYSTEM:WINDOWS
