install:
```
go mod download github.com/go-gl/gl
go mod download github.com/go-gl/glfw/v3.3/glfw
```
compile:
```
go build -ldflags="-H windowsgui" hello.go
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
