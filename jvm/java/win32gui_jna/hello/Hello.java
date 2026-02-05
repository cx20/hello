import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.Callback;
import com.sun.jna.WString;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;

public class Hello {
    // Constants
    static final int CS_HREDRAW = 0x0002;
    static final int CS_VREDRAW = 0x0001;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT = 0x000F;
    static final int COLOR_WINDOW = 5;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;

    // Structures
    public static class WNDCLASSEX extends Structure {
        public int cbSize;
        public int style;
        public WndProcCallback lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public Pointer hInstance;
        public Pointer hIcon;
        public Pointer hCursor;
        public Pointer hbrBackground;
        public WString lpszMenuName;
        public WString lpszClassName;
        public Pointer hIconSm;

        public WNDCLASSEX() {
            cbSize = size();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                "cbSize", "style", "lpfnWndProc", "cbClsExtra", "cbWndExtra",
                "hInstance", "hIcon", "hCursor", "hbrBackground",
                "lpszMenuName", "lpszClassName", "hIconSm"
            );
        }
    }

    public static class MSG extends Structure {
        public Pointer hWnd;
        public int message;
        public Pointer wParam;
        public Pointer lParam;
        public int time;
        public int x;
        public int y;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("hWnd", "message", "wParam", "lParam", "time", "x", "y");
        }
    }

    public static class PAINTSTRUCT extends Structure {
        public Pointer hdc;
        public boolean fErase;
        public int left;
        public int top;
        public int right;
        public int bottom;
        public boolean fRestore;
        public boolean fIncUpdate;
        public byte[] rgbReserved = new byte[32];

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                "hdc", "fErase", "left", "top", "right", "bottom",
                "fRestore", "fIncUpdate", "rgbReserved"
            );
        }
    }

    public static class RECT extends Structure {
        public int left;
        public int top;
        public int right;
        public int bottom;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("left", "top", "right", "bottom");
        }
    }

    // Callback interface for WndProc
    public interface WndProcCallback extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

    // Kernel32 interface
    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetModuleHandleW(WString lpModuleName);
    }

    // User32 interface
    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class, W32APIOptions.DEFAULT_OPTIONS);

        int RegisterClassExW(WNDCLASSEX lpWndClass);
        Pointer CreateWindowExW(int dwExStyle, WString lpClassName, WString lpWindowName,
                               int dwStyle, int x, int y, int nWidth, int nHeight,
                               Pointer hWndParent, Pointer hMenu, Pointer hInstance, Pointer lpParam);
        boolean ShowWindow(Pointer hWnd, int nCmdShow);
        boolean UpdateWindow(Pointer hWnd);
        int GetMessageW(MSG lpMsg, Pointer hWnd, int wMsgFilterMin, int wMsgFilterMax);
        boolean TranslateMessage(MSG lpMsg);
        Pointer DispatchMessageW(MSG lpMsg);
        Pointer DefWindowProcW(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
        void PostQuitMessage(int nExitCode);
        Pointer BeginPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        boolean EndPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        Pointer LoadIconW(Pointer hInstance, int lpIconName);
        Pointer LoadCursorW(Pointer hInstance, int lpCursorName);
    }

    // GDI32 interface
    public interface GDI32 extends StdCallLibrary {
        GDI32 INSTANCE = Native.load("gdi32", GDI32.class, W32APIOptions.DEFAULT_OPTIONS);

        boolean TextOutW(Pointer hdc, int x, int y, WString lpString, int c);
        Pointer GetStockObject(int i);
    }

    // WndProc implementation
    static WndProcCallback wndProc = new WndProcCallback() {
        @Override
        public Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
            switch (uMsg) {
                case WM_PAINT: {
                    PAINTSTRUCT ps = new PAINTSTRUCT();
                    Pointer hdc = User32.INSTANCE.BeginPaint(hWnd, ps);

                    String text = "Hello, Win32 GUI(Java+JNA) World!";
                    GDI32.INSTANCE.TextOutW(hdc, 10, 10, new WString(text), text.length());

                    User32.INSTANCE.EndPaint(hWnd, ps);
                    return Pointer.createConstant(0);
                }
                case WM_DESTROY:
                    User32.INSTANCE.PostQuitMessage(0);
                    return Pointer.createConstant(0);
                default:
                    return User32.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
            }
        }
    };

    public static void main(String[] args) {
        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        WString className = new WString("HelloClass");

        // Register window class
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = wndProc;
        wc.hInstance = hInstance;
        wc.hIcon = User32.INSTANCE.LoadIconW(null, IDI_APPLICATION);
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = Pointer.createConstant(COLOR_WINDOW + 1);
        wc.lpszClassName = className;

        int atom = User32.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) {
            System.err.println("RegisterClassExW failed");
            return;
        }

        // Create window
        Pointer hWnd = User32.INSTANCE.CreateWindowExW(
            0,
            className,
            new WString("Hello, World!"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            640, 480,
            null, null, hInstance, null
        );

        if (hWnd == null) {
            System.err.println("CreateWindowExW failed");
            return;
        }

        User32.INSTANCE.ShowWindow(hWnd, SW_SHOWDEFAULT);
        User32.INSTANCE.UpdateWindow(hWnd);

        // Message loop
        MSG msg = new MSG();
        while (User32.INSTANCE.GetMessageW(msg, null, 0, 0) > 0) {
            User32.INSTANCE.TranslateMessage(msg);
            User32.INSTANCE.DispatchMessageW(msg);
        }
    }
}