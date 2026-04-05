## Hello, OpenGL 3.3 World! (GLUT) - Pascal

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

- `hello.pas: Pascal entry calls `runSample()` from the C bridge`
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
