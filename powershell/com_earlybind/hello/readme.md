run:
```
C:\> tlbimp %SystemRoot%\system32\shell32.dll /out:Shell32.dll
C:\> powershell -file Hello.ps1
```
Result:
```
+----------------------------------------+
|Browse For Folder                    [X]|
+----------------------------------------+
| Hello, COM(PowerShell) Wolrd!          |
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
