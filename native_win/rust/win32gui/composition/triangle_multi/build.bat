@echo off
setlocal

set GLSLANG=%VULKAN_SDK%\Bin\glslangValidator.exe
if exist "%GLSLANG%" (
    "%GLSLANG%" -V hello.vert -o hello_vert.spv
    "%GLSLANG%" -V hello.frag -o hello_frag.spv
) else (
    echo [WARN] glslangValidator.exe not found. Set VULKAN_SDK to generate SPIR-V.
)

cargo build --release
copy target\release\hello.exe
