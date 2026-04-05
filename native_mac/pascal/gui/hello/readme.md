# Hello, World! in Pascal + Cocoa GUI

This sample demonstrates a simple "Hello, World!" GUI application in Free Pascal using the Cocoa framework. The Pascal code calls an Objective-C function to create and manage the Cocoa UI.

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

- Pascal code (`hello.pas`) provides the main entry point
- Objective-C helper (`hello_cocoa.m`) implements Cocoa UI creation
- Uses Cocoa framework (NSApplication, NSWindow, NSTextField)
- Displays "Hello, World!" text in a window
- Window can be minimized and closed
- Application bundle format (Hello.app) with Info.plist
- No external dependencies beyond macOS system frameworks

## Dependencies

- Cocoa framework (macOS system framework)
- Free Pascal compiler (`fpc`)
- Apple Clang compiler (`cc`) for Objective-C bridge
