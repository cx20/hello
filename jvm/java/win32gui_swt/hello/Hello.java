import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.PAINTSTRUCT;
import org.eclipse.swt.internal.win32.MSG;

public class Hello {
    static final int CS_HREDRAW = 0x0002;
    static final int CS_VREDRAW = 0x0001;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT = 0x000F;
    static final int WM_QUIT = 0x0012;
    static final int COLOR_WINDOW = 5;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;

    static Callback wndProcCallback;

    public static void main(String[] args) {
        long hInstance = OS.GetModuleHandle(null);
        
        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();
        
        char[] className = "HelloClass\0".toCharArray();
        
        WNDCLASS wc = new WNDCLASS();
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = wndProcAddress;
        wc.hInstance = hInstance;
        wc.hIcon = OS.LoadIcon(0, IDI_APPLICATION);
        wc.hCursor = OS.LoadCursor(0, IDC_ARROW);
        wc.hbrBackground = COLOR_WINDOW + 1;
        wc.lpszClassName = OS.HeapAlloc(OS.GetProcessHeap(), OS.HEAP_ZERO_MEMORY, className.length * 2);
        OS.MoveMemory(wc.lpszClassName, className, className.length * 2);
        
        OS.RegisterClass(wc);
        
        char[] windowName = "Hello, World!\0".toCharArray();
        long hWnd = OS.CreateWindowEx(
            0,
            className,
            windowName,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            640, 480,
            0, 0, hInstance, null
        );
        
        OS.ShowWindow(hWnd, SW_SHOWDEFAULT);
        OS.UpdateWindow(hWnd);
        
        MSG msg = new MSG();
        while (OS.GetMessage(msg, 0, 0, 0)) {
            OS.TranslateMessage(msg);
            OS.DispatchMessage(msg);
        }
        
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);
    }
    
    static long WndProc(long hWnd, long uMsg, long wParam, long lParam) {
        switch ((int) uMsg) {
            case WM_PAINT: {
                PAINTSTRUCT ps = new PAINTSTRUCT();
                long hdc = OS.BeginPaint(hWnd, ps);
                
                char[] text = "Hello, Win32 GUI(Java+SWT) World!".toCharArray();
                OS.ExtTextOut(hdc, 10, 10, 0, null, text, text.length, null);
                
                OS.EndPaint(hWnd, ps);
                return 0;
            }
            case WM_DESTROY:
                OS.PostMessage(hWnd, WM_QUIT, 0, 0);
                return 0;
            default:
                return OS.DefWindowProc(hWnd, (int) uMsg, wParam, lParam);
        }
    }
}