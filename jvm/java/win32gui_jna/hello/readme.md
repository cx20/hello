compile:
```
C:\>SET JNA_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna_5.18.1.v20251001-0800
C:\>SET JNA_PLATFORM_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna.platform_5.18.1.jar

C:\>javac -cp %JNA_JAR%;%JNA_PLATFORM_JAR%;. Hello.java
```
run:
```
C:\>java -cp %JNA_JAR%;%JNA_PLATFORM_JAR%;. Hello
```
Result:
```
+------------------------------------------+
|Hello, World!                    [_][~][X]|
+------------------------------------------+
|Hello, Win32 GUI(Java+JNA) World!         |
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
