SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
SET INCLUDE=%INCLUDE%;%DXSDK_DIR%\INCLUDE
SET LIB=%LIB%;%DXSDK_DIR%\Lib\x86

cl hello.cpp ^
         /DUNICODE ^
         /link ^
         user32.lib ^
         dxguid.lib ^
         /SUBSYSTEM:WINDOWS
