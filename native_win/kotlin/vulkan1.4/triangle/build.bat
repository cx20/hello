@echo off
setlocal

SET VULKAN_SDK=C:\VulkanSDK\1.4.335.0
SET KONAN_HOME=C:\kotlin-native
SET PATH=%VULKAN_SDK%\bin;%KONAN_HOME%\bin;%PATH%

echo === kotlinc-native ===
call kotlinc-native hello.kt -o hello
if errorlevel 1 exit /b %ERRORLEVEL%

echo Done.
endlocal
