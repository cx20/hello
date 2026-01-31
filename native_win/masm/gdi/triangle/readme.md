compile:
```
ml hello.asm ^
         /link ^
         user32.lib ^
         gdi32.lib ^
         msimg32.lib ^
        /SUBSYSTEM:WINDOWS
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


Caution:

> This code was generated in `cl /FA hello.c`.
> I am using Visual C++ 2015 cl.exe because generating disassembler with the new cl.exe did not work for unknown reasons.
> The following information may be helpful.
> https://stackoverflow.com/questions/46611550/error-a2008-syntax-error
