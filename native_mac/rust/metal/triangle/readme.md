# Hello, World! in Rust + Metal

A macOS Metal triangle sample written in Rust, using FFI to call an Objective-C++ wrapper around the Metal and MetalKit APIs. The `cc` crate compiles the wrapper automatically via `build.rs`.

## Requirements

- macOS (Apple Silicon or Intel with Metal support)
- [Rust](https://rustup.rs/) (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
sh build.sh
```

## Run

```bash
./hello
# or
sh run.sh
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
