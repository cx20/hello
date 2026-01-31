compile:
```
C:\> tlbimp %SystemRoot%\system32\shell32.dll /out:Shell32.dll
C:\> jsc /r:Shell32.dll Hello.js
```
Result:
```
+----------------------------------------+
|Browse For Folder                    [X]|
+----------------------------------------+
| Hello, COM(JScript.NET) Wolrd!         |
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
