This sample combines WTL and WinUI 3:
- WTL `CFrameWindowImpl` is the host window.
- WinUI 3 content is hosted as a XAML Island (`DesktopWindowXamlSource`) in the WTL client area.
- The triangle is drawn with XAML (`Canvas` + `Path`).

compile:
```
C:\> set INCLUDE=C:\WTL\WTL10_10320_Release\Include;%INCLUDE%

C:\> cppwinrt.exe ^
    -input "<WinUI winmd metadata dir>" ^
    -input "<InteractiveExperiences>\Microsoft.UI.winmd" ^
    -input "<InteractiveExperiences>\Microsoft.Foundation.winmd" ^
    -input "<InteractiveExperiences>\Microsoft.Graphics.winmd" ^
    -input "<Foundation winmd metadata dir>" ^
    -input "<WebView2 winmd>" ^
    -reference "<Foundation winmd metadata dir>" ^
    -reference "<WebView2 winmd>" ^
    -reference sdk ^
    -include Microsoft.UI ^
    -include Microsoft.Windows.ApplicationModel.Resources ^
    -include Microsoft.Web.WebView2.Core ^
    -output "<generated headers dir>"

C:\> cl /nologo /std:c++17 /EHsc /DUNICODE /D_UNICODE ^
    /I"<Windows SDK cppwinrt include dir>" ^
    /I"<generated headers dir>" ^
    /I"<Windows App SDK Foundation include dir>" ^
    /I"<Windows App SDK Runtime include dir>" ^
    hello.cpp ^
    /link /SUBSYSTEM:WINDOWS ^
    /LIBPATH:"<Windows App SDK Foundation lib dir>" ^
    runtimeobject.lib ole32.lib oleaut32.lib windowsapp.lib CoreMessaging.lib Microsoft.WindowsAppRuntime.Bootstrap.lib
```

run:
```
C:\github\hello\native_win\cpp_wtl\winui\triangle> hello.exe
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