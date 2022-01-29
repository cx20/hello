compile:
```
C:\> SET REFPATH=C:\Windows\Microsoft.NET\Framework\v4.0.30319
C:\> vbc ^
    /r:%REFPATH%\WPF\PresentationCore.dll ^
    /r:%REFPATH%\WPF\PresentationFramework.dll ^
    /r:%REFPATH%\WPF\WindowsBase.dll ^
    /r:%REFPATH%\System.Xaml.dll ^
    /target:winexe ^
    Hello.vb

```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|Hello, WPF(VB.NET) World!                 |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
|                                          |
+------------------------------------------+
```
