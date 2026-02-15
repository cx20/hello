@echo off
setlocal

set FPC=C:\FPC\3.2.2\bin\i386-win32\fpc.exe

rem --- build Win64 ---
glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv
glslc.exe hello.comp -o hello_comp.spv

"%FPC%" -Px86_64 -Twin64 -Mdelphi -O2 -g -gl hello.pas
if errorlevel 1 exit /b 1

echo OK (Win64)
endlocal
