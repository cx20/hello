import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.TCHAR;
 
public class Hello {
    public static void main(String[] args) {
        TCHAR lpText = new TCHAR(0, "Hello, Win32 API(Java+SWT) World!", true);
        TCHAR lpCaption = new TCHAR(0, "Hello, World", true);
        OS.MessageBox(0, lpText, lpCaption, OS.MB_OK );
    }
}
