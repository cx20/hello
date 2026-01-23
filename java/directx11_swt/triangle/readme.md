compile:
```
C:\> SET SWT_JAR=C:\pleiades\2025-12\eclipse\plugins\org.eclipse.swt.win32.win32.x86_64_3.132.0.v20251124-0642.jar
C:\> SET JNA_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna_5.18.1.v20251001-0800
C:\> SET JNA_PLATFORM_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna.platform_5.18.1.jar

C:\> javac -cp %SWT_JAR%;%JNA_JAR%;%JNA_PLATFORM_JAR%;. Hello.java
```
run:
```
C:\> java -cp %SWT_JAR%;%JNA_JAR%;%JNA_PLATFORM_JAR%;. Hello
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
