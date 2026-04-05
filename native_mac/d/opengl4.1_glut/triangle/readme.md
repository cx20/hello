## Hello, OpenGL 4.1 World! (GLUT) - D

### How to build
```
./build.sh
```

### How to run
```
./hello
```

### Dependencies

- GLUT: macOS built-in (`-framework GLUT`)

### Architecture

- `hello.d: D entry calls `runSample()` from the C bridge`
- `hello_glut.c`: C bridge wrapping all GLUT/OpenGL logic in `void runSample(void)`

### Result

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
