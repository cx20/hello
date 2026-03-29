# Hello, World! in SwiftUI

This sample demonstrates a simple "Hello, World!" GUI application in Swift using SwiftUI framework.

SwiftUI is Apple's modern declarative UI framework (macOS 10.15+) that replaces the traditional AppKit.

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

## Clean up

```bash
sh clean.sh
```

## Description

- Uses SwiftUI framework (modern declarative UI)
- Displays "Hello, World!" text in a window
- Window can be minimized and closed
- Application bundle format (Hello.app) with Info.plist
- Simpler and more concise than traditional Cocoa/AppKit
- No external dependencies beyond macOS system frameworks

## SwiftUI Features

- `@main`: App entry point
- `App` protocol: Application configuration
- `WindowGroup`: Window creation
- `VStack`: Vertical layout
- `Text`: Text display
- `#Preview`: Live preview support in Xcode
