compile:
Please compile from `emsdk\emcmdprompt.bat`.
```
emcc hello.c -s WASM=1 -O3 -o index.js

```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|                                          |
|                                          |
+------------------------------------------+
|Elements|Console|Sources|Network| >>  |[X]|
+------------------------------------------+
|Hello, WASM(C) World!                     |
|                                          |
|                                          |
|                                          |
|                                          |
+------------------------------------------+
```
