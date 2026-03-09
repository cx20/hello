@echo off
setlocal EnableExtensions

set "NUGET_ROOT=%USERPROFILE%\.nuget\packages"

rem --- Locate Go compiler ---
where go >nul 2>nul
if errorlevel 1 (
  echo go.exe was not found. Please add Go to your PATH.
  exit /b 1
)

rem --- Locate NuGet packages ---
set "FOUNDATION_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.windowsappsdk.foundation" 2^>nul') do (
  if not defined FOUNDATION_PKG set "FOUNDATION_PKG=%%d"
)
if not defined FOUNDATION_PKG (
  echo microsoft.windowsappsdk.foundation package was not found under %NUGET_ROOT%.
  exit /b 1
)

set "FOUNDATION_BOOTSTRAP_DLL=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\runtimes\win-x64\native\Microsoft.WindowsAppRuntime.Bootstrap.dll"

if not exist "%FOUNDATION_BOOTSTRAP_DLL%" echo Bootstrap dll not found: %FOUNDATION_BOOTSTRAP_DLL% & exit /b 1

rem --- Build Go executable ---
echo [build] go build -ldflags="-H windowsgui" -o hello.exe hello.go
go build -ldflags="-H windowsgui" -o hello.exe hello.go
set "RET=%ERRORLEVEL%"

if "%RET%"=="0" (
  echo [build] copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll"
  copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll" >nul
)

exit /b %RET%
