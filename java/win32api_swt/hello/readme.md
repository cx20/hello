compile:
```
C:\> SET SWT_JAR=C:\pleiades\eclipse\plugins\org.eclipse.swt.win32.win32.x86_64_3.116.0.v20210302-1107.jar
C:\> javac -cp %SWT_JAR%;. Hello.java
```
run:
```
C:\> java -cp %SWT_JAR%;. Hello
```
Result:
```
+-----------------------------------+
|Hello, World!                   [X]|
+-----------------------------------+
|                                   |
|  Hello, Win32 API(Java+SWT) World!|
|                                   |
|           [   OK    ]             |
+-----------------------------------+
```
