rem csc /debug+ /debug:full /define:DEBUG /optimize- Hello.cs
rem csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe Hello.cs
rem csc /debug+ /debug:full /define:DEBUG /optimize- /unsafe /target:winexe Hello.cs
csc /target:winexe Hello.cs
