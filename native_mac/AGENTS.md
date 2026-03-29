# Copilot Instructions for native_mac

## Overview
This folder contains native macOS "Hello, World!" examples demonstrating multiple languages and frameworks. Keep each sample minimal and focused on one API or runtime.

## Project Structure
```
native_mac/
├── c/            # C language samples
├── cpp/          # C++ language samples
├── objective-c/  # Objective-C language samples
├── objective-cpp/# Objective-C++ language samples
└── swift/        # Swift language samples
```

Each language directory typically contains:
- `console/hello/` - Command-line "Hello, World!" programs
- `x11gui/hello/` - X11 window-based examples via XQuartz (optional)
- `cocoa/hello/` - Cocoa window-based examples (optional)
- `metal/triangle/` - Metal triangle examples (optional)
- `vulkan1.4/triangle/` - Vulkan triangle examples via MoltenVK (optional)

## Directory Pattern
Use this layout for new samples:
```
native_mac/<language>/<library_or_category>/<sample_type>/
```

Examples:
- `native_mac/c/console/hello/`
- `native_mac/c/gui/hello/` - Cocoa GUI using C + Objective-C helper
- `native_mac/c/x11gui/hello/`
- `native_mac/cpp/gui/hello/` - Cocoa GUI using Objective-C++
- `native_mac/cpp/x11gui/hello/`
- `native_mac/objective-c/console/hello/`
- `native_mac/objective-c/gui/hello/` - Native Cocoa GUI
- `native_mac/objective-c/metal/triangle/`
- `native_mac/objective-cpp/console/hello/`
- `native_mac/objective-cpp/gui/hello/`
- `native_mac/objective-cpp/metal/triangle/`
- `native_mac/swift/console/hello/`
- `native_mac/swift/gui/hello/`
- `native_mac/swift/metal/triangle/`
- `native_mac/objective-c/vulkan1.4/triangle/`
- `native_mac/objective-cpp/vulkan1.4/triangle/`
- `native_mac/c/vulkan1.4/triangle/` - Vulkan via MoltenVK
- `native_mac/cpp/vulkan1.4/triangle/` - Vulkan via MoltenVK

## Conventions
- Keep samples short and beginner-friendly.
- Include `build.sh` for command-line build steps.
- Add a lowercase `readme.md` with compile and run commands.
- Prefer no external dependencies unless required by the API.

## Build Notes
- C: use `cc` (Apple Clang)
- C++: use `c++` (Apple Clang++)
- Objective-C: use `cc` with `.m`
- Objective-C++: use `c++` with `.mm`
- Swift: use `swiftc`

## Adding New Samples
1. Create the directory using the standard pattern.
2. Add source code, `build.sh`, and `readme.md`.
3. Verify build and execution on macOS.
4. Keep behavior consistent with repository style:
   - text samples print `Hello, World!` style output
   - graphics samples render a simple triangle

## Cocoa (GUI) Framework Notes

### C + Cocoa Integration
- **Approach**: C code calls helper Objective-C functions defined in separate `.m` file
- **Files**: `hello.c` (main entry point) + `hello_cocoa.m` (Cocoa implementation)
- **Compilation**: `cc -c hello_cocoa.m` followed by `cc hello.c hello_cocoa.o -framework Cocoa`
- **Advantage**: Pure C entry point with clean separation of concerns
- **Use case**: C programs that need native GUI without full Objective-C rewrite

### C++ + Cocoa Integration
- **Approach**: Objective-C++ (`.mm` files) provides seamless C++ and Cocoa interop
- **File**: Single `hello.mm` file combining Objective-C and C++
- **Compilation**: `c++ -std=c++17 hello.mm -framework Cocoa`
- **Advantage**: Full C++ feature support with Cocoa APIs
- **Use case**: Modern C++ projects requiring native macOS GUI

### Cocoa GUI Sample Template
All Cocoa samples should:
1. Create NSApplication singleton: `[NSApplication sharedApplication]`
2. Set up delegate for app lifecycle events
3. Create centered window with NSWindow
4. Add UI elements (NSTextField, buttons, etc.) to content view
5. Call `[app run]` to start event loop
6. Bundle as `.app` using build script with Info.plist

## Vulkan (MoltenVK) Notes
- Preferred sample layout: `build.sh`, `run.sh`, `clean.sh`, source, shaders, `readme.md`.
- Homebrew dependencies: `molten-vk`, `vulkan-loader`, `vulkan-headers`, `glfw`, `glslang`.
- `run.sh` should export `VK_ICD_FILENAMES` to MoltenVK ICD JSON.
- On macOS, direct execution may need `DYLD_FALLBACK_LIBRARY_PATH` including `/usr/local/lib` and `/opt/homebrew/lib`.
