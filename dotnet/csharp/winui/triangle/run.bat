@echo off
setlocal enabledelayedexpansion

rem === config (adjust if you change these) ===
set CONFIG=Release
set PLATFORM=x64
set TF=net8.0-windows10.0.19041.0
set RID=win-x64

rem project root = this bat's directory
set ROOT=%~dp0

rem build output (where .pri is usually present)
set BIN_DIR=%ROOT%bin\%PLATFORM%\%CONFIG%\%TF%

rem publish output (your current run target)
set PUB_DIR=%BIN_DIR%\%RID%\publish

rem executable name (change if different)
set EXE_NAME=Hello.exe

rem if publish output doesn't exist, build/publish first
if not exist "%PUB_DIR%\%EXE_NAME%" (
  call "%ROOT%build.bat"
  if errorlevel 1 exit /b 1
)

rem copy PRI from build output to publish output (workaround for publish missing .pri)
set COPIED=0
for %%F in ("%BIN_DIR%\*.pri") do (
  if exist "%%~fF" (
    echo [run] copy: %%~nxF  ^>  %PUB_DIR%
    copy /y "%%~fF" "%PUB_DIR%\" >nul
    set COPIED=1
  )
)

if "!COPIED!"=="0" (
  echo [run] WARNING: No .pri file found in "%BIN_DIR%".
  echo [run] If the app still fails with XamlParseException, check Release output for *.pri.
)

echo [run] start: "%PUB_DIR%\%EXE_NAME%"
pushd "%PUB_DIR%"
"%EXE_NAME%"
popd

endlocal
