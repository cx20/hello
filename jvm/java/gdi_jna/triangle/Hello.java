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
    static final int CS_OWNDC = 0x0020;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_CLOSE = 0x0010;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT = 0x000F;
    static final int WM_QUIT = 0x0012;
    static final int PM_REMOVE = 0x0001;
    static final int BLACK_BRUSH = 4;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;
    static final int GRADIENT_FILL_TRIANGLE = 2;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

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

    public static class TRIVERTEX extends Structure {
        public int x;
        public int y;
        public short Red;
        public short Green;
        public short Blue;
        public short Alpha;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y", "Red", "Green", "Blue", "Alpha");
        }
    }

    public static class GRADIENT_TRIANGLE extends Structure {
        public int Vertex1;
        public int Vertex2;
        public int Vertex3;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("Vertex1", "Vertex2", "Vertex3");
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
        boolean PeekMessageW(MSG lpMsg, Pointer hWnd, int wMsgFilterMin, int wMsgFilterMax, int wRemoveMsg);
        boolean TranslateMessage(MSG lpMsg);
        Pointer DispatchMessageW(MSG lpMsg);
        Pointer DefWindowProcW(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
        boolean PostMessageW(Pointer hWnd, int Msg, Pointer wParam, Pointer lParam);
        boolean DestroyWindow(Pointer hWnd);
        Pointer BeginPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        boolean EndPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        Pointer LoadIconW(Pointer hInstance, int lpIconName);
        Pointer LoadCursorW(Pointer hInstance, int lpCursorName);
    }

    // GDI32 interface
    public interface GDI32 extends StdCallLibrary {
        GDI32 INSTANCE = Native.load("gdi32", GDI32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetStockObject(int i);
    }

    // Msimg32 interface
    public interface Msimg32 extends StdCallLibrary {
        Msimg32 INSTANCE = Native.load("msimg32", Msimg32.class);

        boolean GradientFill(
            Pointer hdc,
            TRIVERTEX[] pVertex,
            int nVertex,
            GRADIENT_TRIANGLE[] pMesh,
            int nMesh,
            int ulMode
        );
    }

    // Store hWnd for use in message loop
    static Pointer hWndGlobal;

    // WndProc implementation
    static WndProcCallback wndProc = new WndProcCallback() {
        @Override
        public Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
            switch (uMsg) {
                case WM_CLOSE:
                    User32.INSTANCE.PostMessageW(hWnd, WM_QUIT, null, null);
                    return Pointer.createConstant(0);
                case WM_DESTROY:
                    return Pointer.createConstant(0);
                case WM_PAINT: {
                    PAINTSTRUCT ps = new PAINTSTRUCT();
                    Pointer hdc = User32.INSTANCE.BeginPaint(hWnd, ps);
                    drawTriangle(hdc);
                    User32.INSTANCE.EndPaint(hWnd, ps);
                    return Pointer.createConstant(0);
                }
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
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProc;
        wc.hInstance = hInstance;
        wc.hIcon = User32.INSTANCE.LoadIconW(null, IDI_APPLICATION);
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = GDI32.INSTANCE.GetStockObject(BLACK_BRUSH);
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
            WIDTH, HEIGHT,
            null, null, hInstance, null
        );

        if (hWnd == null) {
            System.err.println("CreateWindowExW failed");
            return;
        }

        hWndGlobal = hWnd;

        User32.INSTANCE.ShowWindow(hWnd, SW_SHOWDEFAULT);

        // Message loop (PeekMessage style)
        MSG msg = new MSG();
        boolean bQuit = false;
        while (!bQuit) {
            if (User32.INSTANCE.PeekMessageW(msg, null, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    bQuit = true;
                } else {
                    User32.INSTANCE.TranslateMessage(msg);
                    User32.INSTANCE.DispatchMessageW(msg);
                }
            }
        }

        User32.INSTANCE.DestroyWindow(hWnd);
    }

    static void drawTriangle(Pointer hdc) {
        TRIVERTEX[] vertex = (TRIVERTEX[]) new TRIVERTEX().toArray(3);

        // Vertex 0: red (top)
        vertex[0].x = WIDTH / 2;
        vertex[0].y = HEIGHT / 4;
        vertex[0].Red = (short) 0xFFFF;
        vertex[0].Green = 0;
        vertex[0].Blue = 0;
        vertex[0].Alpha = 0;

        // Vertex 1: green (bottom right)
        vertex[1].x = WIDTH * 3 / 4;
        vertex[1].y = HEIGHT * 3 / 4;
        vertex[1].Red = 0;
        vertex[1].Green = (short) 0xFFFF;
        vertex[1].Blue = 0;
        vertex[1].Alpha = 0;

        // Vertex 2: blue (bottom left)
        vertex[2].x = WIDTH / 4;
        vertex[2].y = HEIGHT * 3 / 4;
        vertex[2].Red = 0;
        vertex[2].Green = 0;
        vertex[2].Blue = (short) 0xFFFF;
        vertex[2].Alpha = 0;

        GRADIENT_TRIANGLE[] mesh = (GRADIENT_TRIANGLE[]) new GRADIENT_TRIANGLE().toArray(1);
        mesh[0].Vertex1 = 0;
        mesh[0].Vertex2 = 1;
        mesh[0].Vertex3 = 2;

        boolean result = Msimg32.INSTANCE.GradientFill(
            hdc,
            vertex,
            3,
            mesh,
            1,
            GRADIENT_FILL_TRIANGLE
        );

        System.out.println("GradientFill result: " + result);
    }
}