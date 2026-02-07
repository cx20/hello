SET KONAN_HOME=C:\kotlin-native
SET PATH=%KONAN_HOME%\bin;%PATH%

kotlinc-native hello.kt -o hello -linker-option -ld3d9
