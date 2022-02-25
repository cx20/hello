import org.eclipse.swt.internal.win32.OS
import org.eclipse.swt.internal.win32.TCHAR
 
class Hello {
    static void main (args) {
        def lpText = new TCHAR(0, "Hello, Win32 API(Groovy+SWT) World!", true)
        def lpCaption = new TCHAR(0, "Hello, World!", true)
        OS.MessageBox(0, lpText, lpCaption, OS.MB_OK )
    }
}
