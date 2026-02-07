compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native
C:\> SET PATH=%KONAN_HOME%\bin;%PATH%

C:\> kotlinc-native hello.kt -o hello
```
Result:
```
+----------------------------------------+
|Browse For Folder                    [X]|
+----------------------------------------+
| Hello, Win32 API(Kotlin/Native) World! |
|                                        |
| +------------------------------------+ |
| |[Windows]                           | |
| | +[addins]                          | |
| | +[AppCompat]                       | |
| | +[AppPatch]                        | |
| | +[assembly]                        | |
| |     :                              | |
| |     :                              | |
| |     :                              | |
| +------------------------------------+ |
| [Make New Folder]    [  OK  ] [Cancel] |
+----------------------------------------+
```
