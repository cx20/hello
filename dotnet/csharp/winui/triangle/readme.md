compile:
```
C:\> dotnet build -c Release -p:Platform=x64 -v:m

C:\> dotnet publish -c Release -r win-x64 --self-contained true ^
      -p:Platform=x64 ^
      -v:m

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
