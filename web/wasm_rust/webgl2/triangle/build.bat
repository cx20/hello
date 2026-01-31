cargo rustc --target wasm32-unknown-unknown --release -- -Z strip=symbols
copy target\wasm32-unknown-unknown\release\hello.wasm
