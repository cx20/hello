@echo off
REM Build script for hello.d (Windows.UI.Composition + OpenGL + D3D11 + Vulkan)
REM
REM Prerequisites:
REM   - DMD (D compiler) in PATH
REM   - Vulkan SDK installed (for glslangValidator to compile SPIR-V shaders)
REM   - NVIDIA GPU with WGL_NV_DX_interop support (for the OpenGL panel)
REM
REM The Vulkan panel requires hello_vert.spv and hello_frag.spv alongside the exe.

echo === Compiling SPIR-V shaders ===
where glslangValidator >nul 2>&1
if %ERRORLEVEL% equ 0 (
    glslangValidator -V hello.vert -o hello_vert.spv
    glslangValidator -V hello.frag -o hello_frag.spv
) else (
    echo WARNING: glslangValidator not found. Make sure hello_vert.spv and hello_frag.spv exist.
)

echo === Building with DMD ===
dmd hello.d -L/SUBSYSTEM:WINDOWS -of=hello.exe
if %ERRORLEVEL% equ 0 (
    echo Build succeeded: hello.exe
) else (
    echo Build failed.
)