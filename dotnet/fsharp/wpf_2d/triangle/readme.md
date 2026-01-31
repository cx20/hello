compile:
```
C:\> SET REFPATH=C:\Windows\Microsoft.NET\Framework\v4.0.30319
C:\> fsc ^
        /r:%REFPATH%\WPF\PresentationCore.dll ^
        /r:%REFPATH%\WPF\PresentationFramework.dll ^
        /r:%REFPATH%\WPF\WindowsBase.dll ^
        /r:%REFPATH%\System.Xaml.dll ^
        /target:winexe ^
        Hello.fs

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
