# Hello, World! in Swift + Cocoa GUI

This sample demonstrates a simple "Hello, World!" GUI application in Swift using Cocoa framework.

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

## Description

- Uses Cocoa framework (NSApplication, NSWindow, NSTextField)
- Displays "Hello, World!" text in a window
- Application bundle format (Hello.app) with Info.plist
- Window can be minimized and closed
- No external dependencies beyond macOS system frameworks
