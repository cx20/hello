@echo off
REM ============================================================
REM  NES hello Build Script (MSVC)
REM  Run from Visual Studio Developer Command Prompt
REM ============================================================

cl /O2 /W3 /D_CRT_SECURE_NO_WARNINGS ^
   hello.c ^
   /Fe:hello.exe ^
   /link user32.lib gdi32.lib

if %ERRORLEVEL% == 0 (
    echo.
    echo Build succeeded: hello.exe
    echo Usage: hello.exe triangle.nes
) else (
    echo.
    echo Build failed!
)
