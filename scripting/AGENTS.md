# AGENTS.md - Scripting Languages Folder

## Folder Overview

**Purpose**: This folder contains "Hello, World!" samples for scripting languages including Perl, PHP, Python, Ruby, and Excel VBA. These samples demonstrate various platforms from console applications to advanced graphics APIs.

**Folder Structure**:
- `perl/`: Perl samples (console, Win32 API, Win32 GUI, COM late binding)
- `php/`: PHP samples (console)
- `python/`: Python samples (console, Win32 API, GDI, COM late binding, DirectX 9/10/11/12, Vulkan 1.4)
- `ruby/`: Ruby samples (console, Win32 API, GDI, COM late binding, DirectX 9/10/11/12)
- `excel_vba/`: Excel VBA samples (DirectX 12 compute shaders)

**Sample Categories**:
- **Console**: Basic text output to command line
- **Win32 API/GUI**: Windows native GUI using ctypes/FFI
- **COM Late Binding**: Windows COM automation (e.g., WScript.Shell)
- **Graphics APIs**: DirectX 9/10/11/12, Vulkan 1.4 (triangle rendering, compute shaders)
- **GDI**: Windows GDI for 2D triangle rendering

## Instructions for AI Agents

### General Guidelines

1. **Language-Specific Idioms**: Each scripting language has its own conventions:
   - **Perl**: Uses Win32::API or Win32::GUI modules for Windows integration
   - **PHP**: Primarily console-based samples
   - **Python**: Uses `ctypes` for FFI (no external dependencies for many samples), or `pywin32` for specific cases
   - **Ruby**: Uses `fiddle` for FFI to call Windows APIs directly
   - **Excel VBA**: Uses COM to interface with DirectX APIs

2. **Consistent Structure**: Each sample follows this structure:
   ```
   <language>/<platform>/<sample_type>/
   ├── hello.<ext>        # Main source file
   ├── run.bat            # Execution script
   ├── install.bat        # (Optional) Dependency installation
   ├── readme.md          # (Optional) Usage and expected output
   └── <shaders>          # (For graphics samples) HLSL, GLSL, or compute shaders
   ```

3. **Self-Contained Samples**: Most Python samples use only `ctypes` (no external packages) to minimize dependencies. Ruby uses `fiddle` from standard library.

4. **Graphics Samples**: Graphics API samples render a colored triangle instead of displaying text. They typically include:
   - Vertex/fragment shaders (HLSL for DirectX, GLSL for Vulkan)
   - Window creation via Win32 API
   - Graphics pipeline setup
   - Rendering loop

### Specific Instructions by Task

#### Adding New Language Support

When adding support for a new scripting language:

1. Create a new subdirectory: `scripting/<language>/`
2. Start with a console sample: `scripting/<language>/console/hello/`
3. Include `run.bat`, `readme.md` with expected output
4. Follow the minimal dependency principle where possible
5. Update the main repository `README.md` table

#### Adding New Platform/API Support

When adding a new platform (e.g., new DirectX version, Vulkan version):

1. Create subdirectory: `scripting/<language>/<platform>/triangle/` or `compute/`
2. Include all necessary shaders in the same directory
3. Provide `run.bat` with any required environment setup (e.g., VULKAN_SDK path)
4. Use ctypes/FFI approach when possible to avoid compiled extensions
5. Document any DLL dependencies or SDK requirements in comments

#### Modifying Existing Samples

When modifying existing samples:

1. **Preserve API Calling Pattern**: Keep the low-level API calling structure intact
2. **Maintain Shader Compatibility**: If updating shaders, test with the target API version
3. **Update Readme**: Reflect any changes in expected output or requirements
4. **Test Execution**: Ensure `run.bat` still works correctly
5. **DLL/SDK Paths**: Use environment variables or relative paths, not hardcoded absolute paths

#### Code Style and Patterns

**Python**:
- Use `ctypes.WinDLL()` for Windows DLLs
- Define structures with `ctypes.Structure`
- Use `WINFUNCTYPE` for callbacks (e.g., window procedures)
- Add missing `wintypes` attributes conditionally (e.g., HICON, HCURSOR)
- For Vulkan samples: Runtime GLSL→SPIR-V compilation using shaderc_shared.dll

**Ruby**:
- Use `Fiddle::Importer` for FFI
- Define structures with `struct([...])`
- Use `typealias` for type definitions
- Declare functions with `extern`

**Perl**:
- Use `Win32::API` or `Win32::GUI` modules
- Follow Win32 naming conventions for handles and structures

**Excel VBA**:
- Use 64-bit declarations (`LongPtr` for pointers)
- Batch COM calls where possible to reduce VBA→Native transitions
- Include profiling constants for performance measurement

#### Graphics API Specifics

**DirectX Samples**:
- Store HLSL shaders in `.hlsl` files
- Use D3DCompile for shader compilation at runtime (or pre-compiled bytecode)
- Follow minimal pipeline setup (vertex buffer, shader, render target)
- Clear to distinct background colors (DirectX samples typically use specific colors)

**Vulkan Samples**:
- Store GLSL shaders in `.vert`, `.frag`, `.comp` files
- Use shaderc for runtime GLSL→SPIR-V compilation
- Set `VULKAN_SDK` environment variable in `run.bat`
- Handle DLL search paths properly (use `os.add_dll_directory()` for Python 3.8+)

**Compute Shader Samples**:
- Implement compute shaders for algorithms (e.g., harmonograph patterns)
- Output to structured buffers
- Use graphics pipeline to visualize compute results (e.g., as LINE_STRIP)

### Common Pitfalls

1. **DLL Loading**: Ensure proper DLL search paths, especially for Vulkan SDK
2. **Structure Packing**: Align structures correctly for API calls (padding matters)
3. **Pointer Types**: Use correct pointer types for 64-bit compatibility
4. **Error Handling**: Check return values for API calls
5. **Resource Cleanup**: Release COM objects, destroy Vulkan handles, close Windows handles

### Testing

Before committing changes:

1. Execute `run.bat` to verify the sample works
2. Check that output matches expected result (console text or rendered triangle)
3. Verify no hardcoded paths (use environment variables or relative paths)
4. Test on Windows (target OS for most samples)
5. For graphics samples: Verify shader compilation and rendering

### External Dependencies

- **Perl**: Win32::API, Win32::GUI (installable via CPAN)
- **Python**: Most samples use only `ctypes` (standard library); some use `pywin32`
- **Ruby**: Uses `fiddle` (standard library)
- **DirectX**: Windows SDK (system DLLs: d3d11.dll, d3d12.dll, dxgi.dll, d3dcompiler_47.dll)
- **Vulkan**: Vulkan SDK (vulkan-1.dll, shaderc_shared.dll)

### Additional Resources

- Main repository README: `../../README.md`
- Repository-wide AGENTS.md: `../../AGENTS.md`
- Asset files (shaders, textures): `../../assets/`

## Contribution Guidelines

1. Keep samples minimal and focused on "Hello, World!" concept
2. Prefer standard library FFI over compiled extensions
3. Include clear comments explaining API calls
4. Document expected output in `readme.md`
5. Test thoroughly before submitting
6. Follow existing naming conventions and directory structure