compile:
```
rustup target add wasm32-wasi
rustc --target wasm32-wasi hello.rs
```
run:
```
wasmer hello.wasm
```
Result:
```
+------------------------------------------------+
|Command Prompt                         [_][~][X]|
+------------------------------------------------+
|C:\hello\wasm_rust\wasi\hello> wasmer Hello.wasm|
|Hello, WASI(Rust) World!                        |
|                                                |
|                                                |
|                                                |
|                                                |
|                                                |
|                                                |
|                                                |
|                                                |
+------------------------------------------------+
```
