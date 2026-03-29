## Build and Run

```bash
$ sh build.sh
$ ./hello
```

## Architecture

- `hello.go`: Go entry point
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
