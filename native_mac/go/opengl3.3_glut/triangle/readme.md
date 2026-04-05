## Hello, OpenGL 3.3 World! (GLUT) - Go

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

- `hello.go: Go entry calls `runSample()` via CGo`
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
