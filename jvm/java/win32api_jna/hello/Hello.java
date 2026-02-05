import com.sun.jna.Native;
import com.sun.jna.WString;
import com.sun.jna.win32.StdCallLibrary;

public class Hello {
    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class);

        int MB_OK = 0x00000000;

        int MessageBoxW(long hWnd, WString lpText, WString lpCaption, int uType);
    }

    public static void main(String[] args) {
        User32.INSTANCE.MessageBoxW(
            0,
            new WString("Hello, Win32 API(Java+JNA) World!"),
            new WString("Hello, World"),
            User32.MB_OK
        );
    }
}