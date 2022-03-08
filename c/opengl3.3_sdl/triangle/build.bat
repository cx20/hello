SET SDL_HOME=C:\Libraries\SDL2-devel-2.0.20-VC\SDL2-2.0.20
SET INCLUDE=%SDL_HOME%\include;%INCLUDE%
SET LIB=%SDL_HOME%\lib\x86;%LIB%
SET PATH=%SDL_HOME%\lib\x86;%PATH%

cl hello.c ^
    /link ^
    user32.lib ^
    shell32.lib ^
    opengl32.lib ^
    sdl2.lib ^
    sdl2main.lib ^
    /SUBSYSTEM:WINDOWS
