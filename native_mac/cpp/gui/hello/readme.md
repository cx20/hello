# Hello, World! in C++ + Cocoa GUI

This sample demonstrates a simple "Hello, World!" GUI application in C++ using Cocoa framework via Objective-C++. It shows how C++ can interact with Cocoa APIs using Objective-C++.

## Build

```bash
sh build.sh
```

This will create `Hello.app` - a macOS application bundle that can be run from Finder.

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

- Objective-C++ code (`hello.mm`) implements the entire application
- Uses Cocoa framework (NSApplication, NSWindow, NSTextField)
- Displays "Hello, World!" text in a window
- Window can be minimized and closed
- Application bundle format (Hello.app) with Info.plist
- No external dependencies beyond macOS system frameworks

## Dependencies

- Cocoa framework (macOS system framework)
- Apple Clang C++ compiler (c++)
