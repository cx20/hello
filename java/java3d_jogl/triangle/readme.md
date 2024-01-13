environment:
```
\
|  j3dcore.jar
|  j3dutils.jar
|  vecmath.jar
|  gluegen-rt.jar
|  jogl-all.jar
|  Hello.java
|
+-natives
    +-windows-amd64
        gluegen-rt.dll
        jogl_desktop.dll
        nativewindow_awt.dll
        nativewindow_win32.dll
```

compile:
```
C:\> javac -cp .;j3dcore.jar;j3dutils.jar;vecmath.jar Hello.java
```

run:
```
C:\> java -cp .;j3dcore.jar;j3dutils.jar;vecmath.jar;jogl-all.jar;gluegen-rt.jar Hello
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

> Please note that the version of Java 3D available from the Oracle website is around the 2007 version (around the time of Java 5.0) and is no longer supported. For a community version of Java 3D, there is a version maintained by JogAmp, so please refer to that as well. It is also important to note that JogAmp's Java 3D is dependent on JOGL.
