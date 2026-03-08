@echo off
setlocal EnableExtensions

set "NUGET_ROOT=%USERPROFILE%\.nuget\packages"
set "OUT_DIR=%TEMP%\hello_winui_cppwinrt_generated"
set "KEEP_GENERATED=0"
set "SDK_CPPWINRT="
set "FOUNDATION_INCLUDE="
set "FOUNDATION_LIB="
set "RUNTIME_INCLUDE="

set "CPPWINRT="
if exist "%WindowsSdkBinPath%x64\cppwinrt.exe" set "CPPWINRT=%WindowsSdkBinPath%x64\cppwinrt.exe"
if not defined CPPWINRT if exist "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\cppwinrt.exe" set "CPPWINRT=C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\cppwinrt.exe"
if not defined CPPWINRT (
  echo cppwinrt.exe was not found.
  exit /b 1
)

if defined WindowsSdkDir if defined WindowsSDKVersion set "SDK_CPPWINRT=%WindowsSdkDir%Include\%WindowsSDKVersion%cppwinrt"
if not defined SDK_CPPWINRT if exist "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\cppwinrt" set "SDK_CPPWINRT=C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\cppwinrt"
if not defined SDK_CPPWINRT (
  echo cppwinrt include directory was not found.
  exit /b 1
)

set "WINUI_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.windowsappsdk.winui" 2^>nul') do (
  if not defined WINUI_PKG set "WINUI_PKG=%%d"
)
if not defined WINUI_PKG (
  echo microsoft.windowsappsdk.winui package was not found under %NUGET_ROOT%.
  exit /b 1
)

set "IXP_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.windowsappsdk.interactiveexperiences" 2^>nul') do (
  if not defined IXP_PKG set "IXP_PKG=%%d"
)
if not defined IXP_PKG (
  echo microsoft.windowsappsdk.interactiveexperiences package was not found under %NUGET_ROOT%.
  exit /b 1
)

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

set "WEBVIEW2_PKG="
for /f "delims=" %%d in ('dir /b /ad /o-n "%NUGET_ROOT%\microsoft.web.webview2" 2^>nul') do (
  if not defined WEBVIEW2_PKG set "WEBVIEW2_PKG=%%d"
)
if not defined WEBVIEW2_PKG (
  echo microsoft.web.webview2 package was not found under %NUGET_ROOT%.
  exit /b 1
)

set "WINUI_WINMD_DIR=%NUGET_ROOT%\microsoft.windowsappsdk.winui\%WINUI_PKG%\metadata"
set "IXP_WINMD_DIR=%NUGET_ROOT%\microsoft.windowsappsdk.interactiveexperiences\%IXP_PKG%\metadata\10.0.18362.0"
set "FOUNDATION_WINMD_DIR=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\metadata"
set "FOUNDATION_INCLUDE=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\include"
set "FOUNDATION_LIB=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\lib\native\x64"
set "FOUNDATION_BOOTSTRAP_DLL=%NUGET_ROOT%\microsoft.windowsappsdk.foundation\%FOUNDATION_PKG%\runtimes\win-x64\native\Microsoft.WindowsAppRuntime.Bootstrap.dll"
set "RUNTIME_INCLUDE=%NUGET_ROOT%\microsoft.windowsappsdk.runtime\%RUNTIME_PKG%\include"
set "WEBVIEW2_WINMD=%NUGET_ROOT%\microsoft.web.webview2\%WEBVIEW2_PKG%\lib\Microsoft.Web.WebView2.Core.winmd"

if not exist "%WINUI_WINMD_DIR%\Microsoft.UI.Xaml.winmd" echo Microsoft.UI.Xaml.winmd not found: %WINUI_WINMD_DIR% & exit /b 1
if not exist "%IXP_WINMD_DIR%\Microsoft.UI.winmd" echo Microsoft.UI.winmd not found: %IXP_WINMD_DIR% & exit /b 1
if not exist "%IXP_WINMD_DIR%\Microsoft.Foundation.winmd" echo Microsoft.Foundation.winmd not found: %IXP_WINMD_DIR% & exit /b 1
if not exist "%IXP_WINMD_DIR%\Microsoft.Graphics.winmd" echo Microsoft.Graphics.winmd not found: %IXP_WINMD_DIR% & exit /b 1
if not exist "%FOUNDATION_WINMD_DIR%\Microsoft.Windows.Foundation.winmd" echo Foundation winmd not found: %FOUNDATION_WINMD_DIR% & exit /b 1
if not exist "%WEBVIEW2_WINMD%" echo WebView2 winmd not found: %WEBVIEW2_WINMD% & exit /b 1
if not exist "%FOUNDATION_INCLUDE%\MddBootstrap.h" echo MddBootstrap.h not found: %FOUNDATION_INCLUDE% & exit /b 1
if not exist "%FOUNDATION_LIB%\Microsoft.WindowsAppRuntime.Bootstrap.lib" echo Bootstrap lib not found: %FOUNDATION_LIB% & exit /b 1
if not exist "%FOUNDATION_BOOTSTRAP_DLL%" echo Bootstrap dll not found: %FOUNDATION_BOOTSTRAP_DLL% & exit /b 1
if not exist "%RUNTIME_INCLUDE%\WindowsAppSDK-VersionInfo.h" echo WindowsAppSDK-VersionInfo.h not found: %RUNTIME_INCLUDE% & exit /b 1

if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"

echo [build] "%CPPWINRT%" ^
  -input "%WINUI_WINMD_DIR%" ^
  -input "%IXP_WINMD_DIR%\Microsoft.UI.winmd" ^
  -input "%IXP_WINMD_DIR%\Microsoft.Foundation.winmd" ^
  -input "%IXP_WINMD_DIR%\Microsoft.Graphics.winmd" ^
  -input "%FOUNDATION_WINMD_DIR%" ^
  -input "%WEBVIEW2_WINMD%" ^
  -reference "%FOUNDATION_WINMD_DIR%" ^
  -reference "%WEBVIEW2_WINMD%" ^
  -reference sdk ^
  -include Microsoft.UI ^
  -include Microsoft.Windows.ApplicationModel.Resources ^
  -include Microsoft.Web.WebView2.Core ^
  -output "%OUT_DIR%"
"%CPPWINRT%" ^
  -input "%WINUI_WINMD_DIR%" ^
  -input "%IXP_WINMD_DIR%\Microsoft.UI.winmd" ^
  -input "%IXP_WINMD_DIR%\Microsoft.Foundation.winmd" ^
  -input "%IXP_WINMD_DIR%\Microsoft.Graphics.winmd" ^
  -input "%FOUNDATION_WINMD_DIR%" ^
  -input "%WEBVIEW2_WINMD%" ^
  -reference "%FOUNDATION_WINMD_DIR%" ^
  -reference "%WEBVIEW2_WINMD%" ^
  -reference sdk ^
  -include Microsoft.UI ^
  -include Microsoft.Windows.ApplicationModel.Resources ^
  -include Microsoft.Web.WebView2.Core ^
  -output "%OUT_DIR%"
if errorlevel 1 exit /b %ERRORLEVEL%

echo [build] cl /nologo /std:c++17 /EHsc /I"%SDK_CPPWINRT%" /I"%OUT_DIR%" /I"%FOUNDATION_INCLUDE%" /I"%RUNTIME_INCLUDE%" hello.cpp /link /LIBPATH:"%FOUNDATION_LIB%" runtimeobject.lib ole32.lib oleaut32.lib windowsapp.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
cl /nologo /std:c++17 /EHsc /I"%SDK_CPPWINRT%" /I"%OUT_DIR%" /I"%FOUNDATION_INCLUDE%" /I"%RUNTIME_INCLUDE%" hello.cpp /link /LIBPATH:"%FOUNDATION_LIB%" runtimeobject.lib ole32.lib oleaut32.lib windowsapp.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
set "RET=%ERRORLEVEL%"
if "%RET%"=="0" (
  echo [build] copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll"
  copy /Y "%FOUNDATION_BOOTSTRAP_DLL%" ".\Microsoft.WindowsAppRuntime.Bootstrap.dll" >nul
)

if "%KEEP_GENERATED%"=="0" if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"

exit /b %RET%
