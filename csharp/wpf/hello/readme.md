compile:
```
C:\> SET REFPATH=C:\Windows\Microsoft.NET\Framework\v4.0.30319
C:\> csc ^
    /r:%REFPATH%\WPF\PresentationCore.dll ^
    /r:%REFPATH%\WPF\PresentationFramework.dll ^
    /r:%REFPATH%\WPF\WindowsBase.dll ^
    /r:%REFPATH%\System.Xaml.dll ^
    /target:winexe ^
    Hello.cs

```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|Hello, WPF(C#) World!                     |
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
