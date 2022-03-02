SET DWT_LIB=C:\dwt\org.eclipse.swt.win32.win32.x86\lib
dmd hello.d gdi32.lib %DWT_LIB%\msimg32.lib hello.def
