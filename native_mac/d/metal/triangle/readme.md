# Hello, World! in D + Metal

A macOS Metal triangle rendered via D using a C-compatible Objective-C++ wrapper.

## Requirements

- macOS with Metal support
- D compiler: [dmd](https://dlang.org/download.html), [ldc2](https://github.com/ldc-developers/ldc), or [gdc](https://gcc.gnu.org/wiki/GDC)
  ```
  brew install dmd
  # or
  brew install ldc
  ```
- Xcode Command Line Tools (for clang++ and Metal frameworks)

## Build

```bash
sh build.sh
```

## Run

```bash
./hello
```

## Clean

```bash
sh clean.sh
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
