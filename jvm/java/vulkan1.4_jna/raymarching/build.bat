SET JNA_JAR=C:\pleiades\2025-12\eclipse\plugins\com.sun.jna_5.18.1.v20251001-0800

glslc.exe hello.vert -o hello_vert.spv
glslc.exe hello.frag -o hello_frag.spv

javac -cp %JNA_JAR%;. Hello.java
