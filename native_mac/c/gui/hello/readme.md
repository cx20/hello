# Hello, World! in C + Cocoa GUI

This sample demonstrates a simple "Hello, World!" GUI application in C using Cocoa framework. The C code calls Objective-C functions to create and manage the Cocoa UI.

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

- C code (`hello.c`) provides the main entry point
- Objective-C helper (`hello_cocoa.m`) implements Cocoa UI creation
- Uses Cocoa framework (NSApplication, NSWindow, NSTextField)
- Displays "Hello, World!" text in a window
- Window can be minimized and closed
- Application bundle format (Hello.app) with Info.plist
- No external dependencies beyond macOS system frameworks

## Dependencies

- Cocoa framework (macOS system framework)
- Apple Clang compiler (cc)
