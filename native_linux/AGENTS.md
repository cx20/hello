# Copilot Instructions for native_linux

## Overview
This folder contains native Linux "Hello, World!" examples demonstrating various compilers, assemblers, and graphics APIs. The examples showcase different toolchains (GCC, Clang, GAS, LLVM) and output types (console, GUI, OpenGL, Vulkan).

## Project Structure
```
native_linux/
├── gcc/          # GCC (GNU C Compiler) examples
├── g++/          # G++ (GNU C++ Compiler) examples
├── clang/        # Clang C compiler examples
├── clang++/      # Clang C++ compiler examples
├── gas/          # GNU Assembler (GAS) examples
├── llvm_as/      # LLVM Assembler examples
└── llvm_ir/      # LLVM IR (Intermediate Representation) examples
```

Each compiler directory typically contains subdirectories for:
- `console/` - Command-line "Hello, World!" programs
- `x11gui/` - X11 window system GUI examples
- `opengl*/` - OpenGL graphics examples (versions 1.0, 1.1, 2.0, 3.3, 4.5)
- `vulkan*/` - Vulkan graphics API examples

## Code Style & Conventions

### General Guidelines
- Keep examples minimal and focused on demonstrating the specific compiler/technology
- Each example should be self-contained within its subdirectory
- Include build scripts (`build.sh`) for easy compilation
- Provide README files (`readme.md`) with compilation instructions and expected output

### File Naming
- Source files: Use descriptive names like `hello.c`, `hello.cpp`, `hello.s`
- Build scripts: Name as `build.sh` and make them executable
- Documentation: Use lowercase `readme.md` for consistency

### Build Scripts
- Should be simple one-line commands when possible
- Example: `cc -o hello hello.s` for assembler
- Example: `gcc -o hello hello.c` for C programs
- For OpenGL/Vulkan examples, include necessary library flags (e.g., `-lGL`, `-lX11`, `-lvulkan`)

### Documentation Format
Each example should include:
- Compilation command
- Expected output (preferably in ASCII art console format)
- Any dependencies or prerequisites

## Technology-Specific Notes

### Assembly (GAS)
- Use AT&T syntax (GAS default)
- Target x86-64 architecture
- Include appropriate sections (.text, .data, .rodata)
- Use `puts@PLT` for string output in position-independent code

### C/C++ Examples
- Use standard headers (`<stdio.h>`, `<iostream>`)
- Keep `main()` function simple and readable
- Follow K&R or modern C style consistently
- Return 0 for successful execution

### OpenGL Examples
- Include version number in directory name (e.g., `opengl3.3`)
- Link against appropriate OpenGL libraries
- Set up proper X11 window context for Linux
- Include GLSL shader code inline or in separate files

### Vulkan Examples
- Include version number (e.g., `vulkan1.4`)
- Set up minimal Vulkan instance and device
- Include proper error handling for Vulkan calls
- Document required Vulkan SDK version

### LLVM Examples
- For `llvm_ir/`: Use human-readable LLVM IR syntax
- For `llvm_as/`: Provide `.ll` files that can be assembled with `llvm-as`
- Include compilation instructions for converting to native code

## Building and Testing

### Prerequisites
- GCC/G++ toolchain
- Clang/LLVM toolchain
- X11 development libraries (`libx11-dev`)
- OpenGL development libraries (`libgl-dev`, `libglu-dev`)
- Vulkan SDK (for Vulkan examples)

### Build Process
Each example should be buildable independently:
```bash
cd native_linux/<compiler>/<type>/<example>
chmod +x build.sh
./build.sh
./hello
```

## Adding New Examples

When adding new examples:
1. Create appropriate subdirectory structure
2. Include minimal source code that demonstrates the technology
3. Add `build.sh` with compilation commands
4. Create `readme.md` with instructions and expected output
5. Test on a clean Linux environment
6. Ensure example follows existing conventions

## Common Patterns

### Console Output
Standard format for "Hello, World!" programs:
```
Hello, <Technology> World!
```

Examples:
- C: "Hello, C World!"
- GAS: "Hello, GAS World!"
- Clang: "Hello, Clang World!"

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

## Troubleshooting

### Common Issues
- **Missing libraries**: Install development packages (`-dev` suffix on Ubuntu/Debian)
- **Permission denied**: Make build scripts executable with `chmod +x build.sh`
- **Linker errors**: Ensure all required libraries are linked in build command
- **Display issues**: Set `DISPLAY` environment variable for X11 examples

## Goals
- Provide minimal, working examples for each compiler/technology
- Demonstrate proper Linux native development practices
- Serve as quick reference for build commands and basic setup
- Maintain consistency across different toolchains