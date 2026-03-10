compile:
```
C:\> SET KONAN_HOME=C:\kotlin-native\bin
C:\> SET PATH=%KONAN_HOME%;%PATH%

C:\> SET WINSDK_LIB_DIR=C:\Program Files (x86)\Windows Kits\10\Lib\<version>\um\x64
C:\> FOR %I IN ("%WINSDK_LIB_DIR%") DO SET WINSDK_LIB_DIR_SHORT=%~sI
C:\> kotlinc-native hello.kt -o hello -linker-options "-L%WINSDK_LIB_DIR_SHORT% -lole32 -lruntimeobject -lwindowsapp -lCoreMessaging"
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
