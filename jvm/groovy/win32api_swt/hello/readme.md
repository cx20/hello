compile:
```
SET CLASSPATH=C:\pleiades\eclipse\plugins\org.eclipse.swt.win32.win32.x86_64_3.116.0.v20210302-1107.jar;%CLASSPATH%
groovyc hello.groovy
```
run:
```
groovy hello
```
Result:
```
+--------------------------------------+
|Hello, World!                      [X]|
+--------------------------------------+
|                                      |
|  Hello, Win32 API(Groovy+SWT) World! |
|                                      |
|           [   OK    ]                |
+--------------------------------------+
```