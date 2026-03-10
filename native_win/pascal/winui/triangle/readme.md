This sample combines Free Pascal and WinUI 3:
- A Win32 window is created using standard Windows API.
- WinUI 3 content is hosted as a XAML Island (`DesktopWindowXamlSource`) via raw COM vtable calls.
- The triangle is drawn with XAML markup loaded via `XamlReader.Load()`.
- `MddBootstrapInitialize2` is called directly with version constants defined in Pascal.
- No C helper, no cppwinrt, no external dependencies beyond FPC and the Windows App SDK runtime.

prerequisites:
- Free Pascal Compiler 3.2+ targeting x86_64-win64 (https://www.freepascal.org/)
- Windows App SDK 1.8 runtime installed
- `Microsoft.WindowsAppRuntime.Bootstrap.dll` placed alongside the executable (the build script copies it automatically from the NuGet package)

compile:
```
C:\> fpc hello.pas -WG -Px86_64
```

run:
```
C:\github\hello\native_win\pascal\winui\triangle> hello.exe
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

notes:
- The Windows App SDK version constants (`WINDOWSAPPSDK_RELEASE_MAJORMINOR` etc.) in `hello.pas`
  correspond to macros in `WindowsAppSDK-VersionInfo.h`. Update them if using a different SDK version.
- `WINDOWSAPPSDK_RUNTIME_VERSION_UINT64 = 0` means "accept any runtime version for this major.minor".
- All COM interfaces are declared as `packed record` with vtable function pointers using `stdcall`.
- The `external 'dllname.dll'` syntax lets FPC link to DLLs at load time without import libraries.
