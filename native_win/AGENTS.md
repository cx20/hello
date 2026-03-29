# Native Windows Agent Guide

This folder contains "Hello, World!" examples for native Windows application development across multiple programming languages and graphics APIs.

## Folder Overview

**Purpose**: This folder contains native Windows "Hello, World!" samples demonstrating low-level Windows programming, graphics APIs, and various programming languages targeting the Win32 platform.

**Folder Structure**:
- `c/`: C language samples
- `cpp/`: C++ samples
- `cpp_atl/`: C++ with Active Template Library (ATL)
- `cpp_mfc/`: C++ with Microsoft Foundation Classes (MFC)
- `cpp_wtl/`: C++ with Windows Template Library (WTL)
- `cpp_import/`: C++ with `#import` directive (COM type library)
- `d/`: D language samples
- `go/`: Go language samples
- `kotlin/`: Kotlin/Native samples
- `masm/`: Microsoft Macro Assembler samples
- `pascal/`: Pascal (Free Pascal) samples
- `rust/`: Rust language samples
- `zig/`: Zig language samples

**Sample Categories**:
- **Console**: Command-line text output (`console/hello/`)
- **GUI**: Win32 API (`win32api/`), Win32 GUI (`win32gui/`), WinRT (`winrt/`), WinUI (`winui/`)
- **COM**: Early binding (`com_earlybind/`) and late binding (`com_latebind/`)
- **2D Graphics**: GDI (`gdi/`), GDI+ (`gdiplus/`), Direct2D (`direct2d/`)
- **3D Graphics**: DirectX 9/10/11/12, OpenGL (1.0–4.6), OpenGL ES 2.0/3.0, Vulkan 1.4, WebGPU
- **Window Libraries**: GLFW (`*_glfw`), GLUT (`*_glut`), SDL (`*_sdl`)
- **UI Framework**: Dear ImGui with OpenGL+GLFW/SDL (`imgui_opengl*`) — cpp only

## Directory Structure Pattern

Each language follows this pattern:
```
native_win/<language>/<platform_or_library>/<sample_type>/
```

Examples:
- `native_win/c/console/hello/`
- `native_win/c/win32gui/hello/`
- `native_win/c/opengl3.3_glfw/triangle/`
- `native_win/cpp/vulkan1.4/triangle/`
- `native_win/cpp/imgui_opengl3.3_glfw/triangle/`
- `native_win/kotlin/vulkan1.4/triangle/`
- `native_win/rust/directx12/triangle/`

### Coverage by language

| Category          | c | cpp | cpp_atl | cpp_mfc | cpp_wtl | d | go | kotlin | masm | pascal | rust | zig |
|-------------------|:-:|:---:|:-------:|:-------:|:-------:|:-:|:--:|:------:|:----:|:------:|:----:|:---:|
| console           | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   | ✅  |
| win32api          | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   | ✅  |
| win32gui          | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| winrt             | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| winui             | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| com_earlybind     | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| com_latebind      | ✅| ✅  |         | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| gdi               | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| gdiplus           | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| direct2d          | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| directx9          | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| directx10         | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| directx11         | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| directx12         | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| opengl1.0–2.0     | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     | ✅   | ✅     | ✅   |     |
| opengl3.3–4.6     | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| opengles2.0/3.0   | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| vulkan1.4         | ✅| ✅  | ✅      | ✅      | ✅      | ✅| ✅ | ✅     |      | ✅     | ✅   |     |
| wgpu/webgpu       | ✅| ✅  |         |         |         |   |    |        |      |        | ✅   |     |
| imgui_opengl      |   | ✅  |         |         |         |   |    |        |      |        |      |     |

## Code Style & Conventions

### General Guidelines

1. **Keep samples minimal**: Focus on demonstrating the specific API/platform
2. **Self-contained**: Each sample should be buildable independently
3. **Include build scripts**: Use `.bat` files for compilation
4. **Document expected output**: Add `readme.md` with instructions
5. **Use Unicode**: Prefer `WCHAR` and wide-string APIs for Win32

### File Naming

- Source files: Use standard extensions (`.c`, `.cpp`, `.d`, `.go`, `.kt`, `.asm`, `.pas`, `.rs`, `.zig`)
- Build scripts: `build.bat` for Windows (also `clean.bat` where needed)
- Shaders: `hello.hlsl`, `hello.vert`/`hello.frag` (GLSL), `hello.wgsl` (WebGPU)
- README: `readme.md` (lowercase)

### Build Scripts

Use Visual Studio Developer Command Prompt tools:
- **C/C++**: `cl.exe` (MSVC compiler), `link.exe` (linker)
- **MASM**: `ml64.exe` (64-bit), `ml.exe` (32-bit)
- **D**: `dmd` or `ldc2`
- **Go**: `go build`
- **Kotlin/Native**: `kotlinc-native` (requires `KONAN_HOME` set to Kotlin/Native install dir)
- **Pascal**: `fpc` (Free Pascal Compiler)
- **Rust**: `cargo build` or `rustc`
- **Zig**: `zig build` or `zig build-exe`

Example C++ build script:
```batch
@echo off
cl /EHsc /D "UNICODE" hello.cpp user32.lib gdi32.lib
```

### Language-Specific Notes

**C/C++**:
- Use MSVC compiler (`cl.exe`)
- Link against appropriate libraries (`user32.lib`, `gdi32.lib`, `d3d11.lib`, etc.)
- For ATL/MFC/WTL: Requires Visual Studio installation
- `cpp/` only: Dear ImGui samples (`imgui_opengl*`) require GLEW, GLFW, and ImGui headers; set `GLEW_HOME`, `GLFW_HOME`, `IMGUI_HOME` env vars

**MASM**:
- Assembly language for x86/x64
- Use Windows API directly via `EXTERN` declarations
- Include appropriate equates for constants

**D**:
- Use `core.sys.windows` for Windows API bindings
- Can call Win32 APIs directly

**Go**:
- Use `syscall` package or `github.com/lxn/win` for Win32 APIs
- CGO not typically required for Win32

**Kotlin/Native**:
- Uses `kotlinc-native` to compile `.kt` files to a native Windows executable
- Requires Kotlin/Native toolchain (`KONAN_HOME=C:\kotlin-native`)
- For Vulkan: also requires `VULKAN_SDK` path set
- Shaders in `.vert`/`.frag` files compiled separately with `glslangValidator`

**Pascal**:
- Free Pascal or Delphi
- Use `Windows` unit for API access

**Rust**:
- Use `windows-rs` crate (official Microsoft bindings)
- Or `winapi` crate (community bindings)

**Zig**:
- Use `@cImport` or manual FFI for Win32 APIs
- Direct C ABI compatibility (currently: console + win32api only)

## Platform-Specific Notes

### Console Applications

Standard "Hello, World!" output to console:
- C: `printf("Hello, World!\n");`
- C++: `std::cout << "Hello, World!" << std::endl;`
- Kotlin: `println("Hello, World!")`
- Rust: `println!("Hello, World!");`
- Zig: `std.debug.print("Hello, World!\n", .{});`

### Win32 GUI Applications

**Window Creation Pattern**:
1. Register window class (`RegisterClass`/`RegisterClassEx`)
2. Create window (`CreateWindow`/`CreateWindowEx`)
3. Message loop (`GetMessage`, `TranslateMessage`, `DispatchMessage`)
4. Window procedure (`WndProc`) for message handling

**Display "Hello, World!" text**:
- Use `TextOut` or `DrawText` in `WM_PAINT` handler

### COM Applications

**Early Binding** (`com_earlybind/`):
- Import type library at compile time
- Use vtable interfaces directly

**Late Binding** (`com_latebind/`):
- Use `IDispatch` and `GetIDsOfNames`/`Invoke`
- Runtime type resolution

### Graphics Applications

**GDI/GDI+**:
- Use `BeginPaint`/`EndPaint` for drawing
- Triangle rendering with `Polygon`, `MoveToEx`, `LineTo`

**Direct2D**:
- Create `ID2D1Factory` and render targets
- Use `ID2D1RenderTarget::DrawLine` for triangle

**DirectX (9/10/11/12)**:
- HLSL shaders (`.hlsl` files compiled with `fxc` or `dxc`)
- Device/context initialization
- Vertex buffer setup
- Rendering loop (clear, draw, present)

**OpenGL**:
- GLSL shaders for modern versions (3.3+)
- Extension loading with GLEW (`glew32s.lib`)
- Window libraries: GLFW (`*_glfw`), GLUT (`*_glut`), SDL (`*_sdl`)
- VAO/VBO buffer management

**OpenGL ES**:
- Mobile/embedded subset of OpenGL
- Use ANGLE for Windows via GLFW

**Vulkan**:
- SPIR-V shaders (compile `.vert`/`.frag` with `glslangValidator -V`)
- Complex initialization (instance, device, swapchain, pipeline)
- Command buffers and synchronization
- Validation layers for debugging

**WebGPU**:
- WGSL shaders (`.wgsl` files)
- Dawn (Chromium): `cpp/webgpu_dawn/`, `cpp/webgpu_dawn_glfw/`
- wgpu-native (Rust): `rust/wgpu/`, `c/wgpu_glfw/`, `cpp/wgpu_glfw/`

**Dear ImGui** (cpp only):
- Requires GLEW, GLFW, ImGui source files
- Backends: `imgui_impl_opengl3` + `imgui_impl_glfw` (or SDL)
- Demonstrates minimal ImGui triangle overlay on OpenGL window

## Building and Testing

### Prerequisites

- **Windows 10/11**
- **Visual Studio** (2019 or later) with "Desktop development with C++"
- **Windows SDK** (included with Visual Studio)
- **Vulkan SDK** (https://vulkan.lunarg.com/) — set `VULKAN_SDK` env var
- **GLFW** — set `GLFW_HOME` env var (e.g. `C:\Libraries\glfw-3.3.6.bin.WIN64`)
- **GLEW** — set `GLEW_HOME` env var (e.g. `C:\Libraries\glew-2.1.0`)
- **Language-specific tools**:
  - D: DMD or LDC2
  - Go: Go toolchain
  - Kotlin/Native: `KONAN_HOME=C:\kotlin-native`
  - Pascal: Free Pascal Compiler (`fpc`)
  - Rust: Rust toolchain (`cargo`)
  - Zig: Zig compiler

### Build Process

Each example includes a `build.bat` script. Run from an **x64 Native Tools Command Prompt for VS**:
```bat
cd native_win\<language>\<platform>\<sample>
build.bat
```

For manual compilation, check `build.bat` for exact compiler flags and libraries.

### Testing Examples

1. Verify compilation succeeds without errors
2. Run the executable
3. For console apps: Check text output
4. For GUI apps: Verify window displays correctly
5. For graphics apps: Ensure triangle renders with correct colors

## Adding New Examples

### Adding a New Language Sample

1. Create language directory: `native_win/<language>/`
2. Add console sample: `native_win/<language>/console/hello/`
3. Include source file, `build.bat`, and `readme.md`
4. Test compilation and execution
5. Update main repository `README.md`

### Adding a New Graphics API

1. Create API directory: `native_win/<language>/<api>/triangle/`
2. Include source files and shaders
3. Provide `build.bat` with correct library linking
4. Document SDK/library path requirements via `SET` statements in `build.bat`
5. Test rendering output

## Common Patterns

### Win32 Window Procedure

```c
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_PAINT: {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            TextOut(hdc, 10, 10, TEXT("Hello, World!"), 13);
            EndPaint(hWnd, &ps);
            return 0;
        }
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}
```

### Graphics Triangle Vertex Data

```c
float vertices[] = {
     0.0f,  0.5f, 0.0f,  1.0f, 0.0f, 0.0f,  // Top (Red)
    -0.5f, -0.5f, 0.0f,  0.0f, 1.0f, 0.0f,  // Bottom-left (Green)
     0.5f, -0.5f, 0.0f,  0.0f, 0.0f, 1.0f   // Bottom-right (Blue)
};
```

**Rendering Loop**:
1. Clear render target
2. Set shaders and buffers
3. Draw triangle (3 vertices)
4. Present/swap buffers

## Troubleshooting

### Common Issues

- **Linker errors (LNK2019)**: Missing `.lib` file in build script
- **Unicode errors**: Use `TCHAR`, `TEXT()`, and Unicode APIs (`CreateWindowW`)
- **DLL not found**: Ensure required DLLs are in `PATH` or same directory as executable
- **Shader compilation errors**: Check HLSL/GLSL syntax and version compatibility
- **Vulkan validation errors**: Enable validation layers and check `VkResult` codes
- **`kotlinc-native` not found**: Set `KONAN_HOME` and add `%KONAN_HOME%\bin` to `PATH`
- **GLFW/GLEW headers not found**: Set `GLFW_HOME` / `GLEW_HOME` env vars before running `build.bat`

### Build Environment Setup

1. Install **Visual Studio** with "Desktop development with C++"
2. Open **x64 Native Tools Command Prompt for VS**
3. Ensure SDKs and library paths are set (Vulkan SDK, GLFW, GLEW)
4. For graphics: Install GPU drivers with development support

## Additional Resources

- Main repository README: `../README.md`
- Repository-wide AGENTS.md: `../AGENTS.md`
- Microsoft Windows API Documentation: https://docs.microsoft.com/windows/win32/
- DirectX Documentation: https://docs.microsoft.com/windows/win32/directx
- Vulkan Tutorial: https://vulkan-tutorial.com/
- WebGPU Specification: https://www.w3.org/TR/webgpu/
- Kotlin/Native: https://kotlinlang.org/docs/native-overview.html
