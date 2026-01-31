SET GLUT_HOME=C:\Libraries\glut-3.7.6-bin
SET PATH=%GLUT_HOME%;%PATH%
SET INCLUDE=%GLUT_HOME%;%INCLUDE%
SET LIB=%GLUT_HOME%;%LIB%

cl hello.c ^
         /link ^
         glut32.lib
