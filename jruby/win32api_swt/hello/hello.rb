require 'java'

java_import 'org.eclipse.swt.internal.win32.OS'
java_import 'org.eclipse.swt.internal.win32.TCHAR'
 
@lpText = TCHAR.new(0, "Hello, Win32 API(JRuby+SWT) World!", true)
@lpCaption = TCHAR.new(0, "Hello, World", true)
OS::MessageBox(0, @lpText, @lpCaption, OS::MB_OK )
