compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native\bin
C:\> SET PATH=%KONAN_HOME%;%PATH%

C:\> kotlinc-native hello.kt -o hello
```
Result:
```
+--------------------------------------+
|Hello, World!                      [X]|
+--------------------------------------+
|                                      |
|Hello, Win32 API(Kotlin/Native) World!|
|                                      |
|             [   OK    ]              |
+--------------------------------------+
```
