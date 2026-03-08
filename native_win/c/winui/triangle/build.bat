@echo off
setlocal EnableExtensions

set "NUGET_ROOT=%USERPROFILE%\.nuget\packages"
set "FOUNDATION_INCLUDE="
set "FOUNDATION_LIB="
set "RUNTIME_INCLUDE="
set "FOUNDATION_BOOTSTRAP_DLL="

set "FOUNDATION_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.windowsappsdk.foundation" 2^>nul') do (
  if not defined FOUNDATION_PKG set "FOUNDATION_PKG=%%d"
)
if not defined FOUNDATION_PKG (
  echo microsoft.windowsappsdk.foundation package was not found under %NUGET_ROOT%.
  exit /b 1
)

set "RUNTIME_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.windowsappsdk.runtime" 2^>nul') do (
  if not defined RUNTIME_PKG set "RUNTIME_PKG=%%d"
)
if not defined RUNTIME_PKG (
  echo microsoft.windowsappsdk.runtime package was not found under %NUGET_ROOT%.
  exit /b 1
)

set "FOUNDATION_INCLUDE=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\include"
set "FOUNDATION_LIB=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\lib\native\x64"
set "FOUNDATION_BOOTSTRAP_DLL=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\runtimes\win-x64\native\Microsoft.WindowsAppRuntime.Bootstrap.dll"
set "RUNTIME_INCLUDE=%NUGET_ROOT%\microsoft.windowsappsdk.runtime\%RUNTIME_PKG%\include"

if not exist "%FOUNDATION_INCLUDE%\MddBootstrap.h" echo MddBootstrap.h not found: %FOUNDATION_INCLUDE% & exit /b 1
if not exist "%RUNTIME_INCLUDE%\WindowsAppSDK-VersionInfo.h" echo WindowsAppSDK-VersionInfo.h not found: %RUNTIME_INCLUDE% & exit /b 1
if not exist "%FOUNDATION_LIB%\Microsoft.WindowsAppRuntime.Bootstrap.lib" echo Bootstrap lib not found: %FOUNDATION_LIB% & exit /b 1
if not exist "%FOUNDATION_BOOTSTRAP_DLL%" echo Bootstrap dll not found: %FOUNDATION_BOOTSTRAP_DLL% & exit /b 1

echo [build] cl /nologo /W3 /DUNICODE /D_UNICODE /I"%FOUNDATION_INCLUDE%" /I"%RUNTIME_INCLUDE%" hello.c /link /SUBSYSTEM:WINDOWS /LIBPATH:"%FOUNDATION_LIB%" user32.lib ole32.lib runtimeobject.lib windowsapp.lib CoreMessaging.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
cl /nologo /W3 /DUNICODE /D_UNICODE /I"%FOUNDATION_INCLUDE%" /I"%RUNTIME_INCLUDE%" hello.c /link /SUBSYSTEM:WINDOWS /LIBPATH:"%FOUNDATION_LIB%" user32.lib ole32.lib runtimeobject.lib windowsapp.lib CoreMessaging.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
set "RET=%ERRORLEVEL%"
if "%RET%"=="0" (
  echo [build] copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll"
  copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll" >nul
)

exit /b %RET%
