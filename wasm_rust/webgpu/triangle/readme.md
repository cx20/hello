Compile:
```
rustup default nightly
cargo install -f wasm-bindgen-cli
SET RUSTFLAGS=--cfg=web_sys_unstable_apis
cargo build --target=wasm32-unknown-unknown --release
wasm-bindgen --web target/wasm32-unknown-unknown/release/hello.wasm --out-dir .
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
[Live Demo](https://cx20.github.io/hello/wasm_rust/webgpu/triangle/)
