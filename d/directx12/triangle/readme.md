
Caution:

> Currently, this sample only shows the background color, not the triangles.
> I think it's probably because the library I'm using hasn't kept up with the DirectX12 spec.
> Anyone who knows an alternative library would be grateful if you could let me know.

compile:
```
dub build --arch=x86_mscoff
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