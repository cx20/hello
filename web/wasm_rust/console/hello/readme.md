Compile:
```
cargo build --target=wasm32-unknown-unknown --release
wasm-bindgen --web target/wasm32-unknown-unknown/release/hello.wasm --out-dir .
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
|Hello, WASM(Rust) World!                  |
|                                          |
|                                          |
|                                          |
|                                          |
+------------------------------------------+
```
