compile:
```
SET SDL_HOME=C:\Libraries\SDL2-devel-2.28.5-VC\SDL2-2.28.5
SET INCLUDE=%SDL_HOME%\include;%INCLUDE%
SET LIB=%SDL_HOME%\lib\x64;%LIB%
SET PATH=%SDL_HOME%\lib\x64;%PATH%

cargo build --release
copy target\release\hello.exe
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
