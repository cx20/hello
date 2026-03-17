@echo off
setlocal enabledelayedexpansion

:: -----------------------------------------------------------
:: build.bat - Compile F# WinRT Toast sample with IL patching
::
:: fsc does not emit the 'windowsruntime' keyword on the
:: '.assembly extern Windows' reference (unlike csc/vbc).
:: This script patches the IL after compilation to add it,
:: so the CLR uses the WinRT type loader at runtime.
:: -----------------------------------------------------------

:: ---- Configurable paths ----
set SDK_VER=10.0.26100.0
set WINMD=C:\Program Files (x86)\Windows Kits\10\UnionMetadata\%SDK_VER%\Windows.winmd
set SYSRT=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll

:: ---- Locate ildasm.exe from the Windows SDK ----
set ILDASM=
for /f "delims=" %%i in ('where ildasm.exe 2^>nul') do set ILDASM=%%i
if "%ILDASM%"=="" (
    for /d %%d in ("C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8.1 Tools\x64") do (
        if exist "%%d\ildasm.exe" set ILDASM=%%d\ildasm.exe
    )
)
if "%ILDASM%"=="" (
    for /d %%d in ("C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\x64") do (
        if exist "%%d\ildasm.exe" set ILDASM=%%d\ildasm.exe
    )
)
if "%ILDASM%"=="" (
    echo ERROR: ildasm.exe not found. Install the .NET Framework SDK or Windows SDK.
    exit /b 1
)

:: ---- Locate ilasm.exe from the .NET Framework ----
set ILASM=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\ilasm.exe
if not exist "%ILASM%" (
    echo ERROR: ilasm.exe not found at %ILASM%.
    exit /b 1
)

echo [1/4] Compiling Hello.fs ...
fsc /nologo /target:exe /platform:x64 ^
    /win32manifest:app.manifest ^
    /r:"%WINMD%" ^
    /r:"%SYSRT%" ^
    Hello.fs
if errorlevel 1 (
    echo ERROR: fsc compilation failed.
    exit /b 1
)

echo [2/4] Disassembling Hello.exe ...
"%ILDASM%" /out=Hello.il Hello.exe >nul
if errorlevel 1 (
    echo ERROR: ildasm failed.
    exit /b 1
)

echo [3/4] Patching IL: adding 'windowsruntime' flag to Windows AssemblyRef ...
powershell -NoProfile -Command ^
    "(Get-Content -Encoding UTF8 Hello.il) -replace '\.assembly extern Windows', '.assembly extern windowsruntime Windows' | Set-Content -Encoding UTF8 Hello.il"
if errorlevel 1 (
    echo ERROR: IL patching failed.
    exit /b 1
)

echo [4/4] Reassembling Hello.exe ...
"%ILASM%" /exe /x64 /output=Hello.exe Hello.il >nul
if errorlevel 1 (
    echo ERROR: ilasm failed.
    exit /b 1
)

:: ---- Cleanup intermediate files ----
del Hello.il 2>nul
del Hello.res 2>nul

echo.
echo Build complete. Run: hello.exe
