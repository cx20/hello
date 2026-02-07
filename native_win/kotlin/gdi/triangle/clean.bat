@echo off
setlocal

del /q hello.exe 2>nul
del /q hello.kexe 2>nul
del /q msimg32.klib 2>nul

rmdir /s /q msimg32-build 2>nul

echo Clean done.
endlocal
