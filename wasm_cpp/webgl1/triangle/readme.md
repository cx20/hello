compile:
Please compile from `emsdk\emcmdprompt.bat`.
```
emcc hello.cpp -std=c++11 -s WASM=1 -O3 -o index.js

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
[Live Demo](https://cx20.github.io/hello/wasm_cpp/webgl1/triangle/)
