# .NET Languages Agent Guide

This folder contains "Hello, World!" examples implemented in various .NET languages and frameworks.

## Folder Overview

**Purpose**: This folder contains .NET "Hello, World!" samples across multiple languages (C#, VB.NET, F#, C++/CLI, JScript.NET, PowerShell, MSIL) and platforms (console, GUI frameworks, graphics APIs).

**Folder Structure**:
- `csharp/`: C# samples
- `vb.net/`: VB.NET samples
- `fsharp/`: F# samples
- `cpp_cli/`: C++/CLI (mixed native/managed) samples
- `jscript.net/`: JScript.NET samples
- `powershell/`: PowerShell samples
- `msil/`: MSIL (IL assembly) samples

**Sample Categories**:
- **Console**: Basic text output (`console/hello/`)
- **COM**: Early and late binding COM automation
- **GUI**: WinForms, WPF, WinUI, MAUI
- **2D Graphics**: GDI, GDI+, Direct2D
- **3D Graphics**: DirectX 9/10/11/12, OpenGL, OpenGL ES, Vulkan

## Directory Structure Pattern

Each language follows this pattern:
```
dotnet/<language>/<platform_or_library>/<sample_type>/
```

Examples:
- `dotnet/csharp/console/hello/`
- `dotnet/csharp/wpf/hello/`
- `dotnet/csharp/directx11/triangle/`
- `dotnet/fsharp/vulkan1.4/triangle/`

## Code Style & Conventions

### General Guidelines

1. **Keep samples minimal**: Focus on demonstrating the specific platform/API
2. **Self-contained**: Each sample should be buildable independently
3. **Include build scripts**: Use `.bat` files for command-line compilation
4. **Document expected output**: Add `readme.md` with compilation steps and output

### File Naming

- Source files: Use standard extensions (`.cs`, `.vb`, `.fs`, `.cpp`, `.ps1`, `.il`)
- Build scripts: `build.bat` for Windows
- XAML files: `app.xaml`, `MainWindow.xaml` for GUI applications
- Shaders: `vertex.hlsl`, `fragment.glsl`, `shader.wgsl`

### Build Scripts

Use command-line compilers:
- **C#**: `csc.exe` (C# compiler)
- **VB.NET**: `vbc.exe` (VB compiler)
- **F#**: `fsc.exe` (F# compiler)
- **C++/CLI**: `cl.exe` with `/clr` flag
- **JScript.NET**: `jsc.exe`
- **MSIL**: `ilasm.exe` (IL assembler)

Example build script structure:
```batch
@echo off
csc /target:winexe /reference:PresentationCore.dll /reference:PresentationFramework.dll hello.cs
```

### Language-Specific Notes

**C#**:
- Use modern C# syntax where appropriate
- For graphics APIs, use P/Invoke or wrapper libraries (SharpDX, OpenTK, Silk.NET)
- XAML for WPF/WinUI applications

**VB.NET**:
- Follow VB.NET naming conventions
- Use `Sub Main()` for entry points
- XAML for WPF applications

**F#**:
- Functional style preferred
- Use `[<EntryPoint>]` attribute for main function
- Can use XAML or code-behind for GUI

**C++/CLI**:
- Mixed-mode assemblies (native + managed)
- Use `#using` for .NET assemblies
- Can directly call Win32/DirectX APIs

**PowerShell**:
- Use `Add-Type` for inline C# code
- Demonstrate P/Invoke patterns
- Keep script self-contained

**MSIL**:
- Raw IL assembly code
- Use `.assembly`, `.class`, `.method` directives
- Compile with `ilasm.exe`

## Platform-Specific Notes

### Console Applications

Standard "Hello, World!" pattern:
- C#: `Console.WriteLine("Hello, World!");`
- VB.NET: `Console.WriteLine("Hello, World!")`
- F#: `printfn "Hello, World!"`

### GUI Applications

**WinForms**:
- Use `System.Windows.Forms` namespace
- Create `Form` with `Label` control
- Set title and size

**WPF**:
- XAML-based UI definition
- Code-behind in `.cs`/`.vb`/`.fs`
- Reference `PresentationCore` and `PresentationFramework`

**WinUI/MAUI**:
- Modern .NET UI frameworks
- NuGet package references required
- XAML-based UI

### Graphics Applications

**DirectX (9/10/11/12)**:
- Use P/Invoke or SharpDX for API access
- HLSL shaders (`.hlsl` files)
- Triangle rendering for graphics samples

**OpenGL**:
- Use P/Invoke, OpenTK, or Silk.NET
- GLSL shaders
- Version-specific samples (1.0, 1.1, 2.0, 3.3, 4.6)

**Vulkan**:
- Use Vulkan.NET or P/Invoke
- GLSL shaders compiled to SPIR-V
- Complex initialization sequence

## Building and Testing

### Prerequisites

- .NET SDK or .NET Framework SDK
- Windows SDK (for DirectX/Vulkan samples)
- Visual Studio Developer Command Prompt (for build tools)

### Build Process

Each example includes a `build.bat` script:
```bash
cd dotnet/<language>/<platform>/<sample>
build.bat
```

For manual compilation, check the `build.bat` file for exact compiler flags and assembly references.

### Testing Examples

1. Verify compilation succeeds without errors
2. Check runtime execution produces expected output
3. For GUI apps, verify window displays correctly
4. For graphics apps, ensure triangle renders properly

## Adding New Examples

### Adding a New Language Sample

1. Create language directory if needed: `dotnet/<language>/`
2. Add at minimum a console sample: `dotnet/<language>/console/hello/`
3. Include source file, `build.bat`, and `readme.md`
4. Test compilation and execution
5. Update main repository README.md

### Adding a New Platform/Graphics API

1. Create platform directory: `dotnet/<language>/<platform>/triangle/`
2. Include all necessary source files and shaders
3. Provide `build.bat` with correct assembly references
4. Document any SDK dependencies in comments or readme
5. Test on Windows (primary target platform)

### Modifying Existing Samples

1. **Preserve simplicity**: Keep samples focused on core functionality
2. **Maintain compatibility**: Ensure samples still build with documented tools
3. **Update documentation**: Reflect changes in readme files
4. **Test thoroughly**: Verify compilation and runtime behavior

## Common Patterns

### P/Invoke Pattern

```csharp
[DllImport("user32.dll")]
static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);
```

### COM Interop

**Early Binding**:
```csharp
Excel.Application app = new Excel.Application();
```

**Late Binding**:
```csharp
Type excelType = Type.GetTypeFromProgID("Excel.Application");
dynamic excel = Activator.CreateInstance(excelType);
```

### Graphics Pipeline Setup

1. Window/context creation
2. API initialization (device, swapchain)
3. Shader compilation
4. Vertex buffer setup
5. Rendering loop (clear, draw, present)
6. Cleanup

## Troubleshooting

### Common Issues

- **Missing assembly references**: Add `/reference:<assembly>.dll` to build script
- **Platform target mismatch**: Use `/platform:x64` or `/platform:x86` as needed
- **XAML compilation errors**: Ensure UI framework assemblies are referenced
- **Graphics API not found**: Check SDK installation and DLL availability

### Build Environment

- Use **Visual Studio Developer Command Prompt** for access to compilers
- Ensure .NET SDK or .NET Framework SDK is installed
- For DirectX/Vulkan: Install appropriate SDKs
- For OpenTK/SharpDX: Download NuGet packages or DLLs

## Additional Resources

- Main repository README: `../README.md`
- Repository-wide AGENTS.md: `../AGENTS.md`
- Microsoft .NET Documentation: https://docs.microsoft.com/dotnet/
- DirectX Documentation: https://docs.microsoft.com/windows/win32/directx