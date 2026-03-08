compile:
```
C:\> cl /nologo /W3 /DUNICODE /D_UNICODE ^
      /I"%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.foundation\<version>\include" ^
      /I"%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.runtime\<version>\include" ^
      hello.c ^
      /link /SUBSYSTEM:WINDOWS ^
      /LIBPATH:"%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.foundation\<version>\lib\native\x64" ^
      user32.lib ole32.lib runtimeobject.lib windowsapp.lib CoreMessaging.lib Microsoft.WindowsAppRuntime.Bootstrap.lib

C:\> copy /Y "%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.foundation\<version>\runtimes\win-x64\native\Microsoft.WindowsAppRuntime.Bootstrap.dll" .
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
