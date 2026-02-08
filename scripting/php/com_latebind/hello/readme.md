compile:
```
C:\> php hello.php
```
Result:
```
+----------------------------------------+
|Browse For Folder                    [X]|
+----------------------------------------+
| Hello, COM Wolrd!                      |
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

Note:
- This sample uses PHP FFI. Enable it in `php.ini` (e.g. `extension=com_dotnet`).
