compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%KONAN_HOME%\bin;%PATH%

C:\> kotlinc-native hello.kt -o hello
```
Result:
```
+-------------------------------+
|   0123456789ABCDEF          X |
|                               |
| Hello, WinRT(Kotlin) World!   |
|                               |
+-------------------------------+
```
