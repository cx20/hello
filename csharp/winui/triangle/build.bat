@echo off
setlocal enabledelayedexpansion

REM ============================================
REM WinUI 3 self-contained publish (NOT single-file)
REM ============================================

set CONFIG=Release
set RID=win-x64
set PLATFORM=x64

cd /d "%~dp0"

echo [1/4] dotnet restore
dotnet restore
if errorlevel 1 goto :ERR

echo [2/4] dotnet clean
dotnet clean -c %CONFIG%
if errorlevel 1 goto :ERR

echo [3/4] dotnet build
dotnet build -c %CONFIG% -p:Platform=%PLATFORM% -v:m
if errorlevel 1 goto :ERR

echo [4/4] dotnet publish (self-contained)
dotnet publish -c %CONFIG% -r %RID% --self-contained true ^
  -p:Platform=%PLATFORM% ^
  -v:m
if errorlevel 1 goto :ERR

echo.
echo ============================================
echo Publish succeeded.
echo Output folder:
echo   bin\%PLATFORM%\%CONFIG%\net8.0-windows10.0.19041.0\%RID%\publish\
echo Run:
echo   bin\%PLATFORM%\%CONFIG%\net8.0-windows10.0.19041.0\%RID%\publish\Hello.exe
echo ============================================
echo.
exit /b 0

:ERR
echo.
echo !!! Build failed (errorlevel=%errorlevel%) !!!
exit /b %errorlevel%
