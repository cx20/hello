# Hello, World! in Go + Metal

A macOS Metal triangle sample written in Go, using CGo to call an Objective-C++ wrapper around the Metal and MetalKit APIs.

## Requirements

- macOS (Apple Silicon or Intel with Metal support)
- [Go](https://go.dev/) 1.21 or later (`brew install go`)
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
sh build.sh
```

## Run

```bash
./hello
```

## Result

```
+------------------------------------------+
|            Hello, World!        [_][~][X]|
+------------------------------------------+
|                                          |
|                   / \                    |
|                 /     \                  |
|               /         \                |
|             /             \              |
|           /                 \            |
|         /                     \          |
|       /                         \        |
|     /                             \      |
|    - - - - - - - - - - - - - - - - -     |
+------------------------------------------+
```
