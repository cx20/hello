# Web and WebAssembly Agent Guide

This folder contains "Hello, World!" examples for web technologies including JavaScript, TypeScript, and WebAssembly (WASM) compiled from various languages.

## Folder Overview

**Purpose**: This folder contains web platform "Hello, World!" samples demonstrating JavaScript, TypeScript, and WebAssembly technologies across different source languages and runtime environments.

**Folder Structure**:
- `javascript/`: JavaScript samples
- `typescript/`: TypeScript samples (with webpack build)
- `wasm_c/`: WebAssembly compiled from C
- `wasm_cpp/`: WebAssembly compiled from C++
- `wasm_rust/`: WebAssembly compiled from Rust (using wasm-bindgen)
- `wasm_wat/`: WebAssembly Text Format (hand-written WAT)

**Sample Categories**:
- **Console**: Text output to browser console or terminal
- **WASI**: WebAssembly System Interface (command-line execution)
- **WebGL/WebGL2**: Graphics rendering in browser (triangle samples)
- **Browser**: Web page integration with HTML wrappers

## Directory Structure Pattern

Each technology follows this pattern:
```
web/<language>/<runtime_or_api>/<sample_type>/
```

Examples:
- `web/javascript/console/hello/`
- `web/typescript/webgl2/triangle/`
- `web/wasm_c/wasi/hello/`
- `web/wasm_rust/webgl2/triangle/`

## Code Style & Conventions

### General Guidelines

1. **Keep samples minimal**: Focus on demonstrating the specific technology
2. **Self-contained**: Each sample should run independently
3. **Include build scripts**: Use `.bat` files for compilation (Windows)
4. **Browser compatibility**: Test in modern browsers (Chrome, Firefox, Edge)
5. **WASI compatibility**: Ensure WASI samples run in compliant runtimes (wasmtime, wasmer)

### File Naming

- Source files: `.js`, `.ts`, `.c`, `.cpp`, `.rs`, `.wat`
- WebAssembly output: `.wasm`
- HTML wrappers: `index.html`
- Build scripts: `build.bat`, `build_wasm.bat`
- Configuration: `webpack.config.js`, `tsconfig.json`, `Cargo.toml`

### Build Scripts

**JavaScript**: No compilation required (direct execution)

**TypeScript**:
```batch
npx webpack
```

**WASM from C** (Emscripten):
```batch
emcc hello.c -o hello.js
```

**WASM from C++** (Emscripten):
```batch
em++ hello.cpp -o hello.js
```

**WASM from Rust** (wasm-bindgen):
```batch
cargo build --target wasm32-unknown-unknown
wasm-bindgen --target web --out-dir . target\wasm32-unknown-unknown\release\hello.wasm
```

**WAT** (WebAssembly Text Format):
```batch
wat2wasm hello.wat
```

### Technology-Specific Notes

**JavaScript**:
- ES6+ syntax preferred
- Use `console.log()` for output
- Browser APIs for WebGL/canvas

**TypeScript**:
- Strict mode enabled
- Use webpack for bundling
- Type definitions for libraries
- Compile to ES6 target

**WASM from C/C++**:
- Use Emscripten toolchain
- Link with `-s WASM=1` for pure WASM
- For WASI: Use `wasi-sdk` with `clang --target=wasm32-wasi`
- Export functions with `EMSCRIPTEN_KEEPALIVE` or `-s EXPORTED_FUNCTIONS`

**WASM from Rust**:
- Use `wasm-bindgen` for browser integration
- Use `wasm-pack` for full build setup (optional)
- For WASI: Target `wasm32-wasi` without wasm-bindgen
- Use `#[wasm_bindgen]` attribute for exported functions

**WAT**:
- Hand-written WebAssembly text format
- Use `wat2wasm` (from WABT) for compilation
- Minimal examples for understanding WASM structure

## Runtime-Specific Notes

### Console/Browser Samples

**JavaScript/TypeScript**:
- Use browser console (`console.log()`)
- Open Developer Tools to see output

**WASM**:
- Import and call exported functions from JavaScript
- Use `WebAssembly.instantiate()` or `instantiateStreaming()`

### WASI Samples

**Execution**:
```bash
wasmtime hello.wasm
# or
wasmer hello.wasm
```

**Standard I/O**:
- Use `printf()` (C), `std::cout` (C++), `println!()` (Rust)
- Output appears in terminal, not browser

**System Calls**:
- Limited to WASI-defined interfaces
- File I/O, environment variables, command-line args

### WebGL/WebGL2 Samples

**Graphics Pattern**:
1. Create HTML canvas element
2. Get WebGL context (`canvas.getContext('webgl2')`)
3. Compile vertex and fragment shaders (GLSL)
4. Create vertex buffer with triangle data
5. Rendering loop (clear, draw, present)

**Vertex Data** (3 vertices, RGB colors):
```javascript
const vertices = new Float32Array([
     0.0,  0.5, 0.0,  1.0, 0.0, 0.0,  // Top (Red)
    -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // Bottom-left (Green)
     0.5, -0.5, 0.0,  0.0, 0.0, 1.0   // Bottom-right (Blue)
]);
```

**WASM Integration**:
- Export draw functions from WASM
- Call from JavaScript animation loop (`requestAnimationFrame`)
- Pass WebGL context to WASM (Emscripten provides bindings)

## Building and Testing

### Prerequisites

**JavaScript/TypeScript**:
- Node.js and npm
- Webpack (for TypeScript)

**WASM from C/C++**:
- Emscripten SDK (for browser/WebGL)
- WASI SDK (for WASI)

**WASM from Rust**:
- Rust toolchain (`rustup`)
- `wasm32-unknown-unknown` target (browser)
- `wasm32-wasi` target (WASI)
- `wasm-bindgen-cli` (for browser integration)

**WAT**:
- WABT (WebAssembly Binary Toolkit) for `wat2wasm`

### Build Process

Each example includes build scripts:

**TypeScript**:
```bash
cd web/typescript/<sample>
npm install
npm run build
```

**WASM (C/C++/Rust)**:
```bash
cd web/wasm_<lang>/<sample>
build.bat
```

**WAT**:
```bash
cd web/wasm_wat/<sample>
wat2wasm hello.wat
```

### Testing Examples

**Console samples**:
1. Open HTML file in browser
2. Open Developer Tools → Console tab
3. Verify "Hello, World!" output

**WASI samples**:
1. Compile to WASM
2. Run with `wasmtime hello.wasm` or `wasmer hello.wasm`
3. Verify terminal output

**WebGL samples**:
1. Open HTML file in browser
2. Verify colored triangle renders on canvas
3. Check console for any errors

## Adding New Examples

### Adding a New Language/Technology

1. Create directory: `web/<technology>/`
2. Add console sample: `web/<technology>/console/hello/`
3. Include source files, build scripts, and HTML wrapper
4. Document build steps in `readme.md`
5. Test in browser or WASI runtime
6. Update main repository README.md

### Adding a New Sample Type

1. Create sample directory: `web/<technology>/<type>/triangle/`
2. Include all source files (shaders, HTML, JavaScript glue)
3. Provide build script with correct flags
4. Document any dependencies (npm packages, SDKs)
5. Test build and runtime execution

### Modifying Existing Samples

1. **Preserve simplicity**: Keep samples minimal and focused
2. **Maintain compatibility**: Ensure samples run in modern browsers/runtimes
3. **Update documentation**: Reflect changes in readme
4. **Test thoroughly**: Verify build process and runtime behavior
5. **Check WASM size**: Avoid unnecessary bloat in WASM binaries

## Common Patterns

### WASM Import/Export

**Exporting function from WASM (C)**:
```c
#include <emscripten.h>

EMSCRIPTEN_KEEPALIVE
int add(int a, int b) {
    return a + b;
}
```

**Calling from JavaScript**:
```javascript
const wasmInstance = await WebAssembly.instantiateStreaming(fetch('hello.wasm'));
const result = wasmInstance.instance.exports.add(5, 3);
```

### WebGL Shader Setup

**Vertex Shader (GLSL)**:
```glsl
attribute vec3 position;
attribute vec3 color;
varying vec3 vColor;

void main() {
    gl_Position = vec4(position, 1.0);
    vColor = color;
}
```

**Fragment Shader (GLSL)**:
```glsl
precision mediump float;
varying vec3 vColor;

void main() {
    gl_FragColor = vec4(vColor, 1.0);
}
```

### Rust wasm-bindgen Integration

**Rust code**:
```rust
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}
```

**JavaScript usage**:
```javascript
import init, { greet } from './hello.js';

await init();
console.log(greet('World'));
```

## Troubleshooting

### Common Issues

**CORS errors**: 
- Serve files via HTTP server (not `file://`)
- Use `python -m http.server` or similar

**WASM module not found**:
- Check file path in JavaScript
- Ensure WASM file is built and in correct location

**Emscripten errors**:
- Verify Emscripten SDK is activated (`emsdk activate latest`)
- Check environment variables (`EMSDK` path)

**Rust compilation errors**:
- Ensure target is installed: `rustup target add wasm32-unknown-unknown`
- Install `wasm-bindgen-cli`: `cargo install wasm-bindgen-cli`

**WebGL context errors**:
- Check browser support for WebGL/WebGL2
- Verify canvas element exists in HTML
- Check for shader compilation errors in console

### Build Environment Setup

**Emscripten**:
1. Download Emscripten SDK
2. Run `emsdk install latest`
3. Run `emsdk activate latest`
4. Source environment: `emsdk_env.bat`

**Rust**:
1. Install Rust: `rustup`
2. Add WASM target: `rustup target add wasm32-unknown-unknown`
3. Install wasm-bindgen: `cargo install wasm-bindgen-cli`

**WABT** (for WAT):
1. Download WABT from GitHub releases
2. Add `wat2wasm` to PATH

## Additional Resources

- Main repository README: `../README.md`
- Repository-wide AGENTS.md: `../AGENTS.md`
- Emscripten Documentation: https://emscripten.org/docs/
- Rust and WebAssembly Book: https://rustwasm.github.io/docs/book/
- MDN WebAssembly Guide: https://developer.mozilla.org/en-US/docs/WebAssembly
- WebGL Tutorial: https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Tutorial
- WASI Documentation: https://wasi.dev/