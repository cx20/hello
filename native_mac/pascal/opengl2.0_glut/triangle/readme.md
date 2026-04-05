## Build and Run

```bash
$ sh build.sh
$ ./hello
```

## Architecture

- `hello.pas`: Free Pascal entry point
- `hello_glut.c`: C bridge implementing the GLUT event loop

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
