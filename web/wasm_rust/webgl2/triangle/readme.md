Compile:
```
cargo rustc --target wasm32-unknown-unknown --release -- -Z strip=symbols
copy target\wasm32-unknown-unknown\release\hello.wasm

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
[Live Demo](https://cx20.github.io/hello/wasm_rust/webgl2/triangle/)
