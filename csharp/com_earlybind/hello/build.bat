tlbimp %SystemRoot%\system32\shell32.dll /out:Shell32.dll
csc /r:Shell32.dll Hello.cs
