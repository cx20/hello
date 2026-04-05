# Hello, World! in Pascal + Metal

A macOS Metal triangle rendered via Free Pascal using a C-compatible Objective-C++ wrapper.

## Requirements

- macOS with Metal support
- [Free Pascal Compiler (fpc)](https://www.freepascal.org/)
  ```
  brew install fpc
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
