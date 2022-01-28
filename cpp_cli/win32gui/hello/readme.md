compile:
```
C:\> cl ^
         /clr ^
         hello.cpp ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         /SUBSYSTEM:WINDOWS
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|Hello, Win32 GUI(C++/CLI) World!          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
+------------------------------------------+
```
