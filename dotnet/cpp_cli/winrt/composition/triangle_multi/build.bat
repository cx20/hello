@echo off
REM ============================================================
REM build_clr.bat - Build script for C++/CLI (/clr) compilation
REM
REM Changes from the original build.bat:
REM
REM   1. /EHsc  ->  /EHa
REM        /clr changes the exception model; /EHa is required to
REM        handle both C++ and SEH exceptions correctly under CLR.
REM
REM   2. Added /clr
REM        Instructs MSVC to generate a CLR assembly (.exe).
REM        Because hello.cpp wraps all code with
REM        #pragma managed(push, off) / pop, every instruction is
REM        compiled as native code, but the resulting EXE carries
REM        a CLR header and is a valid managed assembly.
REM
REM   3. /std:c++17 is kept as-is
REM        Combining /clr with /std:c++17 is supported on
REM        VS 2019 16.8 and later.
REM
REM   4. Added /ignore:4248 to the linker options
REM        Suppresses LNK4248 "unresolved typeref token" warnings for
REM        Vulkan opaque handle types (VkInstance_T, VkDevice_T, etc.).
REM        Vulkan defines handles as pointers to forward-declared structs
REM        with no definition (e.g. typedef struct VkInstance_T* VkInstance).
REM        The /clr linker scans all typeref tokens to emit CLR metadata
REM        and warns when it cannot resolve a forward-declared type.
REM        Because these types are only used inside #pragma managed(push,off)
REM        native code, the warning is harmless and the EXE runs correctly.
REM
REM Notes:
REM   - Run from an x64 Developer Command Prompt.
REM   - hello_vert.spv and hello_frag.spv are compiled below;
REM     they do not need to be pre-built.
REM ============================================================

SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET INCLUDE=%INCLUDE%;%VULKAN_SDK%\Include
SET LIB=%LIB%;%VULKAN_SDK%\Lib
SET PATH=%PATH%;%VULKAN_SDK%\bin

echo [1/3] Compiling vertex shader...
glslc.exe hello.vert -o hello_vert.spv
if %ERRORLEVEL% neq 0 ( echo ERROR: glslc vert failed & exit /b 1 )

echo [2/3] Compiling fragment shader...
glslc.exe hello.frag -o hello_frag.spv
if %ERRORLEVEL% neq 0 ( echo ERROR: glslc frag failed & exit /b 1 )

echo [3/3] Compiling C++/CLI (hello.cpp)...
cl /EHa /std:c++17 /clr hello.cpp ^
   /link vulkan-1.lib ^
   d3d11.lib dxgi.lib d3dcompiler.lib opengl32.lib ^
   user32.lib gdi32.lib RuntimeObject.lib ^
   /ignore:4248

if %ERRORLEVEL% neq 0 (
    echo.
    echo BUILD FAILED
    exit /b 1
)

echo.
echo BUILD SUCCEEDED  -^>  hello.exe  (CLR assembly + native code)
