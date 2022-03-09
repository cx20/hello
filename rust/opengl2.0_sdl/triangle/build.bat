SET SDL_HOME=C:\Libraries\SDL2-devel-2.0.20-VC\SDL2-2.0.20
SET INCLUDE=%SDL_HOME%\include;%INCLUDE%
SET LIB=%SDL_HOME%\lib\x64;%LIB%
SET PATH=%SDL_HOME%\lib\x64;%PATH%

cargo build --release
copy target\release\hello.exe
