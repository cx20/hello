# Copilot Instructions for native_linux

## Overview
This folder contains native Linux "Hello, World!" examples demonstrating various compilers, assemblers, languages, and graphics APIs. The examples showcase different toolchains (GCC, G++, Clang, Clang++, GAS, LLVM, D, Go, Rust) and output types (console, GUI, OpenGL, Vulkan).

## Project Structure
```
native_linux/
├── gcc/          # GCC (GNU C Compiler) examples
├── g++/          # G++ (GNU C++ Compiler) examples
├── clang/        # Clang C compiler examples
├── clang++/      # Clang C++ compiler examples
├── gas/          # GNU Assembler (GAS) examples
├── llvm_as/      # LLVM Assembler examples
├── llvm_ir/      # LLVM IR (Intermediate Representation) examples
├── d/            # D language (DMD) examples
├── go/           # Go language examples
└── rust/         # Rust language examples
```

Each language/compiler directory contains subdirectories for:
- `console/` - Command-line "Hello, World!" programs
- `x11gui/` - X11 window system GUI examples
- `opengl1.0/`, `opengl1.1/`, `opengl2.0/`, `opengl3.3/`, `opengl4.5/` - OpenGL graphics examples
- `vulkan1.4/` - Vulkan 1.4 graphics API examples

### Coverage by language

| Category      | gcc | g++ | clang | clang++ | gas | llvm_as | llvm_ir | d | go | rust |
|---------------|:---:|:---:|:-----:|:-------:|:---:|:-------:|:-------:|:-:|:--:|:----:|
| console       | ✅  | ✅  | ✅   | ✅      | ✅  | ✅      | ✅      | ✅| ✅ | ✅  |
| x11gui        | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| opengl1.0     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| opengl1.1     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| opengl2.0     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| opengl3.3     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| opengl4.5     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |
| vulkan1.4     | ✅  | ✅  | ✅   | ✅      |     |         |         | ✅| ✅ | ✅  |

## Code Style & Conventions

### General Guidelines
- Keep examples minimal and focused on demonstrating the specific compiler/language/technology
- Each example should be self-contained within its subdirectory
- Include build scripts (`build.sh`) for easy compilation
- Provide README files (`readme.md`) with compilation instructions and expected output
- **Important**: `build.sh` files must use LF line endings (enforced by `.gitattributes`). Do NOT use CRLF, which breaks execution on Linux/WSL

### File Naming
- Source files: Use descriptive names like `hello.c`, `hello.cpp`, `hello.s`, `hello.d`, `hello.go`, `main.rs`
- Build scripts: Name as `build.sh` (no shebang to avoid CRLF issues)
- Documentation: Use lowercase `readme.md` for consistency

### Build Scripts
- Should be simple commands without a shebang line (avoids CRLF-on-Windows breakage)
- Example for C: `gcc -o hello hello.c`
- Example for Go: `go build -o hello .`
- Example for Rust: `cargo build --release`
- Example for OpenGL: `gcc -o hello hello.c -lX11 -lGL`
- Example for Vulkan (C): `gcc -o hello hello.c -lvulkan -lglfw` (after compiling shaders with `glslangValidator`)
- **Do NOT include** macOS-specific paths like `-L/usr/X11/lib` or `-I/opt/X11/include`
- **Do NOT include** `-lGLEW` unless the source actually uses GLEW

### Documentation Format
Each example should include:
- Compilation command
- Expected output (preferably in ASCII art console/window format)
- Any dependencies or prerequisites

## Technology-Specific Notes

### Assembly (GAS / LLVM)
- `gas/`: Use AT&T syntax (GAS default), target x86-64
- `llvm_as/`: Provide `.ll` files assembled with `llvm-as`
- `llvm_ir/`: Human-readable LLVM IR syntax
- Include appropriate sections (.text, .data, .rodata)
- Use `puts@PLT` for string output in position-independent code

### C/C++ Examples (gcc, g++, clang, clang++)
- Use standard headers (`<stdio.h>`, `<iostream>`)
- Keep `main()` function simple and readable
- Return 0 for successful execution

### D Language Examples
- Use `dmd` compiler: `dmd -of=hello hello.d`
- For GUI/OpenGL: link `-lX11 -lGL` etc.
- Standard output: `writeln("Hello, World!");`

### Go Examples
- Use `go build -o hello .` in the module directory (each example has its own `go.mod`)
- For X11 GUI: uses `x/exp/shiny` or direct X11 bindings
- For OpenGL: uses `go-gl/gl` and `go-gl/glfw` (pure Go, no CGo shaders)
- For Vulkan: uses `vulkan-go/vulkan` + `go-gl/glfw`; requires `GODEBUG=cgocheck=0` (handled via `init()` re-exec trick)
- SPIR-V shaders compiled with `glslangValidator -V`; binary embedded as `[]uint32`

### Rust Examples
- Uses Cargo: `cargo build --release`, binary at `target/release/hello`
- For X11 GUI: uses `x11rb` crate
- For OpenGL: uses `gl` + `glfw` crates
- For Vulkan: uses `ash` + `winit` crates; **force X11 backend** with `EventLoop::builder().with_x11().build()` (Wayland causes `ERROR_SURFACE_LOST_KHR` on lavapipe/WSL)
- SPIR-V shaders compiled at build time via `build.rs` using `glslangValidator`; embedded with `include_bytes!`

### OpenGL Examples
- Include version number in directory name (e.g., `opengl3.3`)
- Link against `-lX11 -lGL` (Linux; no GLEW unless specifically needed)
- Set up X11 window context with GLX
- GLSL shader code inline in source or in separate `.vert`/`.frag` files

### Vulkan Examples
- Directory: `vulkan1.4/triangle`
- Shaders: compile `.vert`/`.frag` with `glslangValidator -V` before building
- Link against `-lvulkan -lglfw`
- C/C++: shaders loaded from `.spv` files at runtime
- Go/Rust: shaders embedded in binary at build time

## Building and Testing

### Prerequisites (Ubuntu/Debian)
```bash
# C/C++
sudo apt install build-essential clang libx11-dev libgl-dev libvulkan-dev libglfw3-dev glslang-tools

# D language
sudo apt install dmd-compiler

# Go
sudo apt install golang-go

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### Build Process
Each example is buildable independently:
```bash
cd native_linux/<lang>/<type>/<example>
./build.sh
./hello          # or: ./target/release/hello for Rust
```

## Adding New Examples

When adding new examples:
1. Create the subdirectory structure: `native_linux/<lang>/<type>/<example>/`
2. Include minimal source code
3. Add `build.sh` **without a shebang** and with **LF line endings**
4. Create `readme.md` with instructions and expected output
5. Test on Linux/WSL
6. Follow existing conventions for the language

## Common Patterns

### Console Output
```
Hello, World!
```

### README Format
Use ASCII art boxes to show terminal output:
```
+------------------------------------------+
|user@HOSTNAME:~/                 [_][~][X]|
+------------------------------------------+
|$ ./hello                                 |
|Hello, World!                             |
+------------------------------------------+
```

For graphics examples, show a triangle ASCII art instead of text output.

## Troubleshooting

### Common Issues
- **CRLF in build.sh**: Windows `core.autocrlf=true` converts LF→CRLF; `.gitattributes` enforces LF for `*.sh`. Fix existing files with `sed -i 's/\r//' build.sh`
- **Missing libraries**: Install `-dev` packages (e.g., `libvulkan-dev`, `libgl-dev`)
- **Permission denied**: `chmod +x build.sh`
- **Linker errors**: Check all required libraries are in build command
- **Display issues**: Set `DISPLAY=:0` for X11 examples in WSL
- **Vulkan surface lost (lavapipe/WSL)**: Use X11 backend explicitly (winit: `with_x11()`, GLFW: default)
- **Go CGo panic (`cgo argument has Go pointer`)**: Use re-exec trick with `GODEBUG=cgocheck=0` in `init()`

## Goals
- Provide minimal, working examples for each language/compiler/technology
- Demonstrate proper Linux native development practices
- Serve as quick reference for build commands and basic setup
- Maintain consistency across different toolchains