This sample combines Go and WinUI 3:
- A Win32 window is created using Go's `syscall` package.
- WinUI 3 content is hosted as a XAML Island (`DesktopWindowXamlSource`) via raw COM vtable calls.
- The triangle is drawn with XAML markup loaded via `XamlReader.Load()`.
- `MddBootstrapInitialize2` is called directly from Go with version constants defined in the source.
- No CGO or external helper DLL required — all Windows/COM/WinRT calls use `syscall.NewLazyDLL` and `syscall.Syscall`.

prerequisites:
- Go 1.21+ (https://go.dev/dl/)
- Windows App SDK 1.8 runtime installed
- `Microsoft.WindowsAppRuntime.Bootstrap.dll` placed alongside the executable (the build script copies it automatically from the NuGet package)

compile:
```
C:\> go build -ldflags="-H windowsgui" -o hello.exe hello.go
```

run:
```
C:\github\hello\native_win\go\winui\triangle> hello.exe
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

notes:
- The Windows App SDK version constants (`windowsAppSDKReleaseMajorMinor` etc.) in `hello.go`
  correspond to macros in `WindowsAppSDK-VersionInfo.h`. Update them if using a different SDK version.
- `windowsAppSDKRuntimeVersionUint64 = 0` means "accept any runtime version for this major.minor".
  Set the exact packed version if you need a specific minimum runtime.
