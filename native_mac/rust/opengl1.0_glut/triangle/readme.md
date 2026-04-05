## Build and Run

```bash
$ sh build.sh
$ ./hello
```

## Dependencies

- GLUT: macOS built-in (`-framework GLUT`)

## Architecture

- `hello.rs`: Rust entry  calls `runSample()` via `extern "C"`point 
- `hello_glut.c`: C bridge wrapping all GLUT/OpenGL logic in `void runSample(void)`

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
