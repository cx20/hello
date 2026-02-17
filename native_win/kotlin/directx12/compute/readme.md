compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%KONAN_HOME%\bin;%PATH%

C:\> kotlinc-native hello.kt -o hello
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

NOTE: This is a minimal DirectX12 framework that creates a device.
Full implementation with command queue, swap chain, pipeline state,
and triangle rendering requires extensive VTable manipulation.

