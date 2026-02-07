@echo off
setlocal

set "KONAN_HOME=C:\kotlin-native"
set "PATH=%KONAN_HOME%\bin;%PATH%"

echo === kotlinc-native ===
call kotlinc-native hello.kt -o hello -opt -linker-options -lopengl32
if errorlevel 1 exit /b %ERRORLEVEL%

echo Done.
endlocal
