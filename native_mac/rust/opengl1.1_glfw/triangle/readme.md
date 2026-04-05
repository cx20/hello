## Build and Run

```bash
$ sh build.sh
$ ./hello
```

## Dependencies

- GLFW: `brew install glfw`

## Architecture

- `hello.rs`: Rust entry  calls `runSample()` via `extern "C"`point 
- `hello_glfw.c`: C bridge wrapping all GLFW/OpenGL logic in `void runSample(void)`

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
