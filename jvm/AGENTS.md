# JVM Languages Agent Guide

This folder contains "Hello, World!" examples implemented in various JVM (Java Virtual Machine) languages and frameworks.

## Languages and Technologies

This directory includes examples for:
- **Java** - The primary JVM language with GUI frameworks (AWT, Swing, SWT) and graphics APIs (OpenGL, DirectX)
- **Groovy** - Dynamic JVM language with simplified syntax
- **Kotlin** - Modern statically-typed JVM language
- **Scala** - Functional and object-oriented JVM language
- **JRuby** - Ruby implementation on the JVM
- **Jython** - Python implementation on the JVM
- **Jasmin** - JVM assembler language

## Agent Instructions

When working with this codebase:

### Understanding the Structure

1. **Language-Specific Subdirectories**: Each language has its own subdirectory (e.g., `java/`, `kotlin/`, `groovy/`)
2. **Framework Subdirectories**: Within language directories, examples are organized by framework or library (e.g., `swing/`, `awt/`, `console/`)
3. **Example Projects**: Each example typically contains:
   - Source code files (`.java`, `.kt`, `.groovy`, `.py`, `.rb`, `.scala`, `.j`)
   - Build/run scripts (`.bat` files for Windows)
   - README files with compilation and execution instructions

### Code Patterns

1. **GUI Applications**: Most GUI examples follow this pattern:
   - Create a main window/frame (JFrame, Shell, etc.)
   - Set window properties (size, title, close operation)
   - Add UI components (labels, buttons)
   - Display the window

2. **Console Applications**: Simple "Hello, World!" output to console

3. **Graphics Applications**: OpenGL and DirectX examples demonstrating:
   - Context/device initialization
   - Shader compilation
   - Rendering loops
   - Triangle and compute shader examples

### Building and Running

Each example includes:
- **Compilation steps**: Using language-specific compilers (`javac`, `kotlinc`, `groovyc`, etc.)
- **Execution steps**: Using runtime environments (`java`, `groovy`, `jruby`, `jython`, etc.)
- **Dependencies**: Some examples require specific JAR files (e.g., SWT, LWJGL)

Check individual `readme.md` files in each example directory for specific build instructions.

### Common Tasks

**Adding a new language example:**
1. Create a subdirectory under `jvm/` for the language
2. Create framework-specific subdirectories if needed
3. Add source files following the naming convention
4. Include a `readme.md` with build/run instructions
5. Add run scripts (`.bat` files) for convenience

**Updating existing examples:**
1. Maintain compatibility with the JVM language version
2. Keep GUI frameworks consistent with the existing pattern
3. Update README files if build steps change
4. Test on Windows (based on existing `.bat` files)

**Testing examples:**
1. Verify compilation succeeds
2. Check runtime execution produces expected output
3. For GUI apps, verify window displays correctly
4. For graphics apps, ensure rendering works

### Language-Specific Notes

- **Java**: Supports multiple GUI frameworks and graphics APIs
- **Kotlin**: Modern syntax with Java interoperability
- **Groovy**: Dynamic typing, simplified Swing usage
- **Scala**: Functional programming style available
- **JRuby/Jython**: Access to JVM libraries from Ruby/Python syntax
- **Jasmin**: Low-level JVM bytecode, useful for understanding JVM internals

### Best Practices

1. Keep examples simple and focused on "Hello, World!" functionality
2. Include compilation and execution instructions
3. Use standard JVM conventions for package names and class structure
4. Document required dependencies and classpath settings
5. Maintain consistency across language implementations where applicable