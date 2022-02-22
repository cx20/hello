SET GLEW_HOME=C:\Libraries\glew-2.1.0
SET GLFW_HOME=C:\Libraries\glfw-3.3.6.bin.WIN32
SET INCLUDE=%GLEW_HOME%\include;%GLFW_HOME%\include;%INCLUDE%
SET LIB=%GLEW_HOME%\lib\Release\Win32;%GLFW_HOME%\lib-vc2022;%LIB%

cl hello.cpp ^
         /DGLFW_EXPOSE_NATIVE_WIN32 ^
         /link ^
         user32.lib ^
         shell32.lib ^
         gdi32.lib ^
         opengl32.lib ^
         glu32.lib ^
         glew32s.lib ^
         glfw3_mt.lib ^
         /SUBSYSTEM:WINDOWS
