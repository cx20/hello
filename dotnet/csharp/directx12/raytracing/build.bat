@echo off
setlocal

where dxc >nul 2>nul
if errorlevel 1 (
    echo dxc not found. Please run from Developer Command Prompt with Windows SDK.
    exit /b 1
)

dxc -T lib_6_3 -Fo raytracing.dxil hello.hlsl
if errorlevel 1 exit /b 1

csc /target:winexe /platform:x64 Hello.cs
