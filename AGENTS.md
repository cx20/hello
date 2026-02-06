# AGENTS.md

This document provides guidance for AI coding agents working with the cx20/hello repository.

## Repository Overview

**Purpose**: This repository is a comprehensive collection of "Hello, World!" samples across multiple programming languages, platforms, and graphics libraries. For graphics libraries, samples display a triangle instead of text.

**Repository Structure**:
- `native_win/`: Native Windows applications (MASM, C, C++, D, Go, Pascal, Rust, Zig)
- `native_linux/`: Native Linux applications (GNU AS, GCC, G++, LLVM, Clang)
- `dotnet/`: .NET languages (MSIL, C++/CLI, C#, VB.NET, F#, JScript.NET, PowerShell)
- `jvm/`: Java VM languages (Jasmin, Java, Groovy, Scala, JRuby, Jython, Kotlin)
- `scripting/`: Scripting languages (Perl, PHP, Python, Ruby)
- `web/`: Web and WebAssembly (WASM in WAT/C/C++/Rust, JavaScript, TypeScript)
- `html5/`: HTML5 examples
- `assets/`: Shared assets

## Key Patterns and Conventions

### Directory Structure Pattern
```
<platform>/<language>/<library_or_category>/<sample_type>/
```

Examples:
- `native_win/c/opengl1.0/triangle/`
- `dotnet/csharp/directx11/triangle/`
- `jvm/java/console/hello/`

### Sample Types
1. **Console samples** (`console/hello/`): Display "Hello, World!" text
2. **Graphics samples** (`<graphics_library>/triangle/`): Display a colored triangle
3. **GUI samples** (`win32gui/hello/`, `wpf/hello/`, etc.): Window-based "Hello, World!"

### Common Libraries Covered

**Graphics APIs**:
- GDI, GDI+, Direct2D
- DirectX 9, 10, 11, 12
- OpenGL 1.0, 1.1, 2.0, 3.3, 4.6
- OpenGL ES 2.0, 3.0
- Vulkan 1.2, 1.3, 1.4
- WebGPU (dawn, wgpu)

**Window Frameworks**:
- Win32 API, WinForms, WPF, WinUI, MAUI
- X11 (Linux)
- GLFW, GLUT, SDL
- ImGUI

## Guidelines for AI Agents

### When Adding New Samples

1. **Follow the existing directory structure**:
   - Place samples in the appropriate `<platform>/<language>/<library>/` directory
   - Use `hello/` for console/text samples, `triangle/` for graphics samples

2. **Maintain consistency with existing code**:
   - Study similar examples in the repository before creating new ones
   - Match the coding style and structure of existing samples for that language
   - Keep samples minimal and focused on the core functionality

3. **Include necessary build files**:
   - Add build scripts appropriate for the language (Makefile, CMakeLists.txt, .bat/.sh scripts, etc.)
   - Document compilation/execution steps in README or comments

4. **Graphics samples should render a basic triangle**:
   - Use simple vertex data (3 vertices forming a triangle)
   - Apply basic colors (typically red, green, blue at each vertex)
   - Avoid complex shaders or effects unless required by the API version

5. **Test environment considerations**:
   - Primary test environment: Windows 11
   - Check README.md for current language/tool versions
   - Ensure compatibility with documented versions

### When Modifying Existing Samples

1. **Preserve the "Hello, World!" spirit**:
   - Keep samples simple and beginner-friendly
   - Avoid adding complex features or dependencies
   - Focus on demonstrating the minimal API usage

2. **Update cross-references**:
   - If adding samples to a new language or library, update the tables in README.md
   - Maintain the markdown table format used throughout README.md

3. **Handle WIP samples carefully**:
   - Samples marked `[WIP]` in README.md are work-in-progress
   - Complete or improve WIP samples when possible
   - Remove `[WIP]` marker only when fully functional

### Language-Specific Notes

**Assembly Languages** (MASM, GNU AS, LLVM AS):
- Focus on demonstrating direct system calls or API usage
- Include clear comments explaining each instruction

**.NET Languages**:
- Show both direct API calls and framework abstractions when applicable
- For COM examples, demonstrate both early and late binding

**JVM Languages**:
- For Java, show native API usage via JNA when accessing Windows APIs
- Include SWT and JOGL/LWJGL variants where applicable

**Web/WASM**:
- WASI samples should work in WASI-compatible runtimes
- WebGL/WebGPU samples should include HTML wrappers for browser execution
- Minimize JavaScript/TypeScript dependencies

### Graphics Sample Template

For a new graphics library sample, include:
1. **Vertex data**: 3 vertices forming a visible triangle
2. **Initialization**: Window/context creation, API initialization
3. **Rendering loop**: Clear, draw triangle, present/swap buffers
4. **Cleanup**: Proper resource deallocation
5. **Minimal shaders**: For modern APIs requiring shaders (GLSL, HLSL, WGSL)

### Build System Preferences

- **Windows native (C/C++)**: Visual Studio Developer Command Prompt batch files
- **Linux**: Makefiles with GCC/Clang
- **.NET**: CSC/VBC command-line compilation or MSBuild
- **Java**: Command-line javac/jar
- **Web**: Simple HTML files; minimal build steps

## Common Tasks

### Adding a New Language

1. Determine the appropriate category (native_win, native_linux, dotnet, jvm, scripting, web)
2. Create language directory: `<category>/<language>/`
3. Add at minimum a console/hello sample
4. Add a row to the relevant table in README.md with link to your sample
5. Update Test Environment section if introducing a new tool version

### Adding a New Graphics Library

1. Add samples for at least one representative language in each category
2. Add a new row to relevant tables in README.md
3. Include shader files if required (GLSL, HLSL, WGSL)
4. Document any special setup or dependencies

### Fixing Build Issues

1. Check that file paths and library references are correct
2. Verify tool versions match those in README.md Test Environment section
3. Ensure build scripts use proper command-line flags
4. Test on Windows 11 if possible (primary test platform)

## File Naming Conventions

- **Source files**: Use standard extensions (`.c`, `.cpp`, `.cs`, `.java`, `.py`, etc.)
- **Build scripts**: `build.bat` (Windows), `Makefile` or `build.sh` (Linux)
- **Shaders**: Descriptive names like `vertex.glsl`, `fragment.hlsl`, `shader.wgsl`
- **README files**: Optional per sample; use for complex setup instructions

## Testing and Validation

Before submitting changes:
1. Verify the sample compiles without errors
2. Verify the sample runs and produces expected output (text or triangle)
3. Test with the tool versions documented in README.md
4. Ensure no external dependencies beyond standard libraries/SDKs

## Documentation

- **Code comments**: Use language-appropriate comments to explain key steps
- **README.md updates**: Keep the main README.md tables current
- **Build instructions**: Include in comments or separate README if non-trivial

## Additional Resources

- **README.md**: Contains comprehensive tables of all samples and test environment details
- **GitHub Pages**: Repository may have a live demo site at https://cx20.github.io/hello/
- **Language-specific samples**: Look at existing samples in the same language for patterns

## Questions or Issues

When uncertain about implementation:
1. Review existing samples in the same language
2. Review existing samples for the same library in other languages
3. Keep changes minimal and focused
4. Prioritize simplicity and clarity over advanced features