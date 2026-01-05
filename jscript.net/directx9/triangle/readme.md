compile:
```
C:\> jsc /platform:x86 ^
    /r:"C:\Windows\Microsoft.NET\Framework\v4.0.30319\System.dll" ^
    /r:"C:\Windows\Microsoft.NET\Framework\v4.0.30319\System.Core.dll" ^
    /r:"C:\Windows\Microsoft.NET\Framework\v4.0.30319\System.Drawing.dll" ^
    /r:"C:\Windows\Microsoft.NET\Framework\v4.0.30319\System.Windows.Forms.dll" ^
    /r:"C:\Windows\Microsoft.NET\Framework\v4.0.30319\Accessibility.dll" ^
    Hello.js
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

Caution:

> To run this sample, you need to install/enable the following prerequisites in advance:
> 
> - Install the Microsoft DirectX SDK (June 2010).
> - Enable the .NET Framework 3.5 feature.
