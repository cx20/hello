@echo off
setlocal

set "KONAN_HOME=C:\kotlin-native"
set "PATH=%KONAN_HOME%\bin;%PATH%"

echo === cinterop ===
call cinterop -def msimg32.def -compiler-options "-DUNICODE -D_UNICODE" -pkg msimg32 -o msimg32
if errorlevel 1 (
  echo cinterop failed. ERRORLEVEL=%ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo === kotlinc-native ===
call kotlinc-native hello.kt -o hello -library msimg32.klib -opt
if errorlevel 1 (
  echo kotlinc-native failed. ERRORLEVEL=%ERRORLEVEL%
  exit /b %ERRORLEVEL%
)

echo Done.
endlocal
