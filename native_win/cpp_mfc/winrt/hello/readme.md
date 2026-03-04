compile:
```
C:\> cl hello.cpp ^
     /MD ^
     /D_AFXDLL ^
     /DUNICODE ^
     /D_UNICODE ^
     /EHsc ^
     /link ^
     /SUBSYSTEM:WINDOWS ^
     runtimeobject.lib

```
Result:
```
+-------------------------------+
|   0123456789ABCDEF          X |
|                               |
| Hello, WinRT(MFC) World!      |
|                               |
+-------------------------------+
```
