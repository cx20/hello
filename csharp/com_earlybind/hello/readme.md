This example demonstrates how to COM programming.

Compile:
```
C:\> tlbimp %SystemRoot%\system32\shell32.dll /out:Shell32.dll
C:\> csc /r:Shell32.dll Hello.cs
```
Result:
```
+----------------------------------------+
|Browse For Folder                    [X]|
+----------------------------------------+
| Hello, COM(C#) Wolrd!                  |
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

Caution:

> This sample used to work, but now it doesn't.
> The cause is under investigation.
