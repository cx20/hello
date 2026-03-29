## Build and Run

```bash
$ sh build.sh
$ ./hello
```

## Architecture

- `hello.rs`: Rust entry point
- `hello_opengl.m`: minimal Objective-C bridge for Cocoa window/event loop and OpenGL context

## Result

```text
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
