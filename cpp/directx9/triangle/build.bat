SET DXSDK_DIR=C:\Program Files (x86)\Microsoft DirectX SDK (June 2010)
SET INCLUDE=%DXSDK_DIR%\INCLUDE;%INCLUDE%
SET LIB=%DXSDK_DIR%\Lib\x86;%LIB%

cl hello.cpp ^
         /DUNICODE ^
         /D_UNICODE ^
         /link ^
         user32.lib ^
         /SUBSYSTEM:WINDOWS
