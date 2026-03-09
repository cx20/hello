This sample combines D language and WinUI 3:
- A Win32 window is created using D's Windows API bindings.
- WinUI 3 content is hosted as a XAML Island (`DesktopWindowXamlSource`) via raw COM vtable calls.
- The triangle is drawn with XAML markup loaded via `XamlReader.Load()`.
- Windows App SDK bootstrap (`MddBootstrapInitialize2`) is called directly from D code.

prerequisites:
- DMD (D compiler, https://dlang.org/download.html)
- Windows App SDK NuGet packages installed in `%USERPROFILE%\.nuget\packages`

compile:
```
C:\> dmd -m64 hello.d ^
    -of=hello.exe ^
    -L/SUBSYSTEM:WINDOWS ^
    -L/LIBPATH:"<Windows App SDK Foundation lib dir>" ^
    -Luser32.lib -Lole32.lib -Lruntimeobject.lib -Lwindowsapp.lib ^
    -LCoreMessaging.lib -LMicrosoft.WindowsAppRuntime.Bootstrap.lib
```

run:
```
C:\github\hello\native_win\d\winui\triangle> hello.exe
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
|    - - - - - - - - - - - - - - - - -    |
+------------------------------------------+
```
