SET SWT_JAR=C:\pleiades\2025-12\eclipse\plugins\org.eclipse.swt.win32.win32.x86_64_3.132.0.v20251124-0642.jar
SET JNA_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna_5.18.1.v20251001-0800
javac -cp %SWT_JAR%;%JNA_JAR%;. Hello.java
