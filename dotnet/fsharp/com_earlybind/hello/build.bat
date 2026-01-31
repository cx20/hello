tlbimp %SystemRoot%\system32\shell32.dll /out:Shell32.dll
fsc /r:Shell32.dll Hello.fs
