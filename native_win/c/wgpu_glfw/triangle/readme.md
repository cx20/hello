preparation:
```
If necessary, obtain the dependent files and place them locally.

build.bat
glfw3webgpu.c   ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/glfw3webgpu/glfw3webgpu.c
glfw3webgpu.h   ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/glfw3webgpu/glfw3webgpu.h
hello.cpp
webgpu.h        ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/webgpu/webgpu.h
wgpu.h          ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/webgpu/wgpu.h
wgpu_native.dll ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/webgpu/windows-x86_64/wgpu_native.dll
wgpu_native.lib ... copy from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/webgpu/windows-x86_64/wgpu_native.lib

```


compile:
```
SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN64
SET INCLUDE=%GLFW_HOME%\include;%CD%;%INCLUDE%
SET LIB=%GLFW_HOME%\lib-vc2022;%LIB%

cl hello.p ^
    glfw3webgpu.c ^
    /link ^
    user32.lib ^
    shell32.lib ^
    gdi32.lib ^
    glfw3_mt.lib ^
    wgpu_native.lib
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|                                          |
|                   / \                    |
|                 /     \                  |
|               /         \                |
|             /             \              |
|           /                 \            |
|         /                     \          |
|       /                         \        |
|     /                             \      |
|    - - - - - - - - - - - - - - - - -     |
+------------------------------------------+
```