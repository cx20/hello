cl /std:c++20 /EHsc /DUNICODE /D_UNICODE hello.cpp ^
  /I "%WindowsSdkDir%Include\%WindowsSDKVersion%cppwinrt" ^
  user32.lib gdi32.lib ole32.lib windowsapp.lib ^
  d3d11.lib dxgi.lib d3dcompiler.lib CoreMessaging.lib
