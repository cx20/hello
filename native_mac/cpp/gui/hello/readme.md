# Hello, World! in C++ + Cocoa GUI

This sample demonstrates a "Hello, World!" GUI application in C++ using Cocoa framework. It uses a **C++ wrapper class design pattern** to abstract the Objective-C++ bridge layer.

## Architecture

- **hello.cpp**: Pure C++ implementation with `CocoaApp` wrapper class
- **hello_cocoa_bridge.mm**: Objective-C++ bridge layer that handles Cocoa API calls
- **Bridge pattern**: C++ code calls bridge functions, isolated from Objective-C complexity

## Build

```bash
sh build.sh
```

This will compile `hello.cpp` and `hello_cocoa_bridge.mm` separately, then link them into `Hello.app`.

## Run from Terminal

```bash
./build.sh
open Hello.app
```

Or run directly from the app bundle:

```bash
./Hello.app/Contents/MacOS/Hello
```

## Run from Finder

Double-click `Hello.app` in Finder to launch the application without showing terminal.

## Clean

```bash
rm -rf Hello.app
```

## Description

- **C++ wrapper class** (`CocoaApp`) provides high-level interface
- **Bridge pattern**: Separates C++ logic from Objective-C++ details
- Uses Cocoa framework (NSApplication, NSWindow, NSTextField, via bridge)
- Demonstrates clean C++ design while leveraging macOS-specific APIs
- C++ features: classes, error handling (try-catch), standard library (std::string)
- No external dependencies beyond macOS system frameworks

## Design Pattern

The wrapper class pattern allows:
1. Pure C++ code in `hello.cpp` without Objective-C knowledge
2. Bridge functions (`cocoa_*`) hiding Cocoa implementation details
3. Easy extension: new C++ methods map to new bridge functions
4. Better maintainability and separation of concerns

## Dependencies

- Cocoa framework (macOS system framework)
- Apple Clang C++ compiler (c++ with -std=c++17)
