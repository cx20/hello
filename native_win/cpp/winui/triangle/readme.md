compile:
```
C:\> cppwinrt.exe ^
    -input "<WinUI winmd metadata dir>" ^
    -input "<InteractiveExperiences winmd files>" ^
    -input "<Foundation winmd metadata dir>" ^
    -reference sdk ^
    -output "<generated headers dir>"

C:\> cl /std:c++17 /EHsc ^
    /I"<Windows SDK cppwinrt include dir>" ^
    /I"<generated headers dir>" ^
    /I"<Windows App SDK include dirs>" ^
    hello.cpp ^
    /link runtimeobject.lib ole32.lib oleaut32.lib windowsapp.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
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
