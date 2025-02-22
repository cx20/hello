compile:
```
C:\> jsc /target:winexe Hello.js
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
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

Caution:

Currently, there are the following known issues. PRs for fixes are welcome.

- Memory leak (the memory usage increases over time with continued execution).
- The process does not terminate even when the window is closed.

