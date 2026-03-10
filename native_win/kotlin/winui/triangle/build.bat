SET KONAN_HOME=C:\kotlin-native
SET PATH=%KONAN_HOME%\bin;%PATH%

SET WINSDK_LIB_DIR=
FOR /D %%D IN ("C:\Program Files (x86)\Windows Kits\10\Lib\*") DO (
    IF EXIST "%%~fD\um\x64\Ole32.Lib" (
        SET "WINSDK_LIB_DIR=%%~fD\um\x64"
        GOTO :build
    )
)

ECHO Windows SDK library path was not found.
EXIT /B 1

:build
ECHO Using Windows SDK libraries: %WINSDK_LIB_DIR%
FOR %%I IN ("%WINSDK_LIB_DIR%") DO SET "WINSDK_LIB_DIR_SHORT=%%~sI"
ECHO Using Windows SDK libraries (short): %WINSDK_LIB_DIR_SHORT%
kotlinc-native hello.kt -o hello -linker-options "-L%WINSDK_LIB_DIR_SHORT% -lole32 -lruntimeobject -lwindowsapp -lCoreMessaging"
