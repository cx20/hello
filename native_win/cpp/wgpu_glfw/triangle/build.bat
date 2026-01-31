SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN64
SET INCLUDE=%GLFW_HOME%\include;%CD%;%INCLUDE%
SET LIB=%GLFW_HOME%\lib-vc2022;%LIB%

cl hello.cpp ^
    glfw3webgpu.c ^
    /link ^
    user32.lib ^
    shell32.lib ^
    gdi32.lib ^
    glfw3_mt.lib ^
    wgpu_native.lib
