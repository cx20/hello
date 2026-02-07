@echo off
setlocal

set "KONAN_HOME=C:\kotlin-native"
set "PATH=%KONAN_HOME%\bin;%PATH%"

echo === kotlinc-native ===
call kotlinc-native hello.kt -o hello -opt
if errorlevel 1 (
  echo kotlinc-native failed. ERRORLEVEL=%ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo Done.
endlocal
