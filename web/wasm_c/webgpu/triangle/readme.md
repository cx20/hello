compile:
Please compile from `emsdk\emcmdprompt.bat`.
```
emcc hello.c -std=c11 -s WASM=1 -O3 --use-port=emdawnwebgpu -o index.js

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
[Live Demo](https://cx20.github.io/hello/wasm_c/webgpu/triangle/)

Caution:

> Use Emscripten 4.0.10 or higher to compile (the built-in `emdawnwebgpu` port).
> 
> This sample uses Dawn's `--use-port=emdawnwebgpu`, which provides the up-to-date
> `webgpu.h` C API (surface-based rendering, `WGPUStringView`, etc.).
> 
> It runs in any browser with WebGPU enabled (e.g. recent Chrome / Edge).
