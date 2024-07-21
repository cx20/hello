Caution:

> Currently, this sample only displays a white window and no triangle is displayed. 
> This is the same as the official sample, so there is no known time for a fix.


compile:
```
cargo build --release
copy target\release\hello.exe
copy src\shaders.hlsl
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
