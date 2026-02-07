compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%KONAN_HOME%\bin;%PATH%

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
