from org.eclipse.swt.internal.win32 import OS
from org.eclipse.swt.internal.win32 import TCHAR
 
lpText = TCHAR(0, "Hello, Win32 API(Jython+SWT) World!", True)
lpCaption = TCHAR(0, "Hello, World", True)
OS.MessageBox(0, lpText, lpCaption, OS.MB_OK )
