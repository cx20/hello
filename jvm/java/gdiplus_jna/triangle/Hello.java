import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.WString;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.LongByReference;

import java.util.Arrays;
import java.util.List;

public class Hello {

    // ----------------------------
    // Win32 constants
    // ----------------------------
    static final int CS_OWNDC = 0x0020;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;

    static final int WM_CLOSE   = 0x0010;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT   = 0x000F;
    static final int WM_QUIT    = 0x0012;
    static final int PM_REMOVE  = 0x0001;

    static final int WHITE_BRUSH = 0;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;

    static final int WIDTH  = 640;
    static final int HEIGHT = 480;

    // GDI+ FillMode
    static final int FillModeAlternate = 0;

    // ----------------------------
    // Win32 Structures
    // ----------------------------
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

    // ----------------------------
    // Callback interface for WndProc
    // ----------------------------
    public interface WndProcCallback extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

    // ----------------------------
    // Kernel32 interface
    // ----------------------------
    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetModuleHandleW(WString lpModuleName);
    }

    // ----------------------------
    // User32 interface
    // ----------------------------
    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class, W32APIOptions.DEFAULT_OPTIONS);

        int RegisterClassExW(WNDCLASSEX lpWndClass);
        Pointer CreateWindowExW(int dwExStyle, WString lpClassName, WString lpWindowName,
                               int dwStyle, int x, int y, int nWidth, int nHeight,
                               Pointer hWndParent, Pointer hMenu, Pointer hInstance, Pointer lpParam);
        boolean ShowWindow(Pointer hWnd, int nCmdShow);
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

    // ----------------------------
    // GDI32 interface
    // ----------------------------
    public interface GDI32 extends StdCallLibrary {
        GDI32 INSTANCE = Native.load("gdi32", GDI32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetStockObject(int i);
    }

    // ----------------------------
    // GDI+ (gdiplus.dll) via JNA
    // ----------------------------
    public interface Gdiplus extends StdCallLibrary {
        Gdiplus INSTANCE = Native.load("gdiplus", Gdiplus.class);

        int GdiplusStartup(LongByReference token, GdiplusStartupInput input, Pointer output);
        void GdiplusShutdown(long token);

        int GdipCreateFromHDC(Pointer hdc, PointerByReference graphics);
        int GdipDeleteGraphics(Pointer graphics);

        int GdipCreatePath(int fillMode, PointerByReference path);
        int GdipDeletePath(Pointer path);
        int GdipAddPathLine2I(Pointer path, GpPoint[] points, int count);
        int GdipClosePathFigure(Pointer path);

        int GdipCreatePathGradientFromPath(Pointer path, PointerByReference polyGradient);
        int GdipSetPathGradientCenterColor(Pointer brush, int argb);
        int GdipSetPathGradientSurroundColorsWithCount(Pointer brush, int[] argbColors, IntByReference count);

        int GdipDeleteBrush(Pointer brush);
        int GdipFillPath(Pointer graphics, Pointer brush, Pointer path);
    }

    public static class GdiplusStartupInput extends Structure {
        public int GdiplusVersion;
        public Pointer DebugEventCallback;
        public boolean SuppressBackgroundThread;
        public boolean SuppressExternalCodecs;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                "GdiplusVersion",
                "DebugEventCallback",
                "SuppressBackgroundThread",
                "SuppressExternalCodecs"
            );
        }
    }

    public static class GpPoint extends Structure {
        public int x;
        public int y;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y");
        }
    }

    // ----------------------------
    // Globals
    // ----------------------------
    static long g_gdiplusToken = 0;

    // ----------------------------
    // WndProc implementation
    // ----------------------------
    static WndProcCallback wndProc = new WndProcCallback() {
        @Override
        public Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
            switch (uMsg) {
                case WM_CLOSE:
                    User32.INSTANCE.DestroyWindow(hWnd);
                    return Pointer.createConstant(0);

                case WM_DESTROY:
                    User32.INSTANCE.PostMessageW(hWnd, WM_QUIT, null, null);
                    return Pointer.createConstant(0);

                case WM_PAINT: {
                    PAINTSTRUCT ps = new PAINTSTRUCT();
                    Pointer hdc = User32.INSTANCE.BeginPaint(hWnd, ps);

                    drawTriangleGdiPlus(hdc, WIDTH, HEIGHT);

                    User32.INSTANCE.EndPaint(hWnd, ps);
                    return Pointer.createConstant(0);
                }

                default:
                    return User32.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
            }
        }
    };

    // ----------------------------
    // Main entry
    // ----------------------------
    public static void main(String[] args) {

        // Initialize GDI+
        LongByReference tokenRef = new LongByReference();
        GdiplusStartupInput si = new GdiplusStartupInput();
        si.GdiplusVersion = 1;
        si.DebugEventCallback = null;
        si.SuppressBackgroundThread = false;
        si.SuppressExternalCodecs = false;
        si.write();

        int st = Gdiplus.INSTANCE.GdiplusStartup(tokenRef, si, null);
        if (st != 0) {
            System.err.println("GdiplusStartup failed: status=" + st);
            return;
        }
        g_gdiplusToken = tokenRef.getValue();

        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        WString className = new WString("HelloGdiPlusClass");

        // Register window class
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProc;
        wc.hInstance = hInstance;
        wc.hIcon = User32.INSTANCE.LoadIconW(null, IDI_APPLICATION);
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = GDI32.INSTANCE.GetStockObject(WHITE_BRUSH);
        wc.lpszClassName = className;

        int atom = User32.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) {
            System.err.println("RegisterClassExW failed");
            Gdiplus.INSTANCE.GdiplusShutdown(g_gdiplusToken);
            return;
        }

        // Create window
        Pointer hWnd = User32.INSTANCE.CreateWindowExW(
            0,
            className,
            new WString("GDI+ Triangle (Java + JNA)"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            null, null, hInstance, null
        );

        if (hWnd == null) {
            System.err.println("CreateWindowExW failed");
            Gdiplus.INSTANCE.GdiplusShutdown(g_gdiplusToken);
            return;
        }

        User32.INSTANCE.ShowWindow(hWnd, SW_SHOWDEFAULT);

        // Message loop
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

        // Cleanup
        User32.INSTANCE.DestroyWindow(hWnd);

        // Shutdown GDI+
        Gdiplus.INSTANCE.GdiplusShutdown(g_gdiplusToken);
    }

    // ----------------------------
    // Drawing with GDI+ PathGradientBrush
    // ----------------------------
    static void drawTriangleGdiPlus(Pointer hdc, int width, int height) {
        PointerByReference pGraphics = new PointerByReference();
        PointerByReference pPath = new PointerByReference();
        PointerByReference pBrush = new PointerByReference();

        // Convert HDC -> GDI+ Graphics
        int st = Gdiplus.INSTANCE.GdipCreateFromHDC(hdc, pGraphics);
        if (st != 0) {
            System.err.println("GdipCreateFromHDC status=" + st);
            return;
        }
        Pointer graphics = pGraphics.getValue();

        try {
            // Create a path and define a triangle
            st = Gdiplus.INSTANCE.GdipCreatePath(FillModeAlternate, pPath);
            if (st != 0) {
                System.err.println("GdipCreatePath status=" + st);
                return;
            }
            Pointer path = pPath.getValue();

            try {
                // Create 3 points
                GpPoint[] pts = (GpPoint[]) new GpPoint().toArray(3);
                pts[0].x = width * 1 / 2;  pts[0].y = height * 1 / 4;
                pts[1].x = width * 3 / 4;  pts[1].y = height * 3 / 4;
                pts[2].x = width * 1 / 4;  pts[2].y = height * 3 / 4;

                for (GpPoint p : pts) p.write();

                st = Gdiplus.INSTANCE.GdipAddPathLine2I(path, pts, 3);
                if (st != 0) {
                    System.err.println("GdipAddPathLine2I status=" + st);
                    return;
                }

                st = Gdiplus.INSTANCE.GdipClosePathFigure(path);
                if (st != 0) {
                    System.err.println("GdipClosePathFigure status=" + st);
                    return;
                }

                // Create a PathGradientBrush from the path
                st = Gdiplus.INSTANCE.GdipCreatePathGradientFromPath(path, pBrush);
                if (st != 0) {
                    System.err.println("GdipCreatePathGradientFromPath status=" + st);
                    return;
                }
                Pointer brush = pBrush.getValue();

                try {
                    // Set center color (ARGB)
                    st = Gdiplus.INSTANCE.GdipSetPathGradientCenterColor(brush, 0xFF555555);
                    if (st != 0) {
                        System.err.println("GdipSetPathGradientCenterColor status=" + st);
                        return;
                    }

                    // Set surround colors (ARGB) for the 3 vertices
                    int[] colors = new int[] { 0xFFFF0000, 0xFF00FF00, 0xFF0000FF };
                    IntByReference count = new IntByReference(3);

                    st = Gdiplus.INSTANCE.GdipSetPathGradientSurroundColorsWithCount(brush, colors, count);
                    if (st != 0) {
                        System.err.println("GdipSetPathGradientSurroundColorsWithCount status=" + st);
                        return;
                    }

                    // Fill the triangle path using the gradient brush
                    st = Gdiplus.INSTANCE.GdipFillPath(graphics, brush, path);
                    if (st != 0) {
                        System.err.println("GdipFillPath status=" + st);
                    }
                } finally {
                    if (pBrush.getValue() != null) {
                        Gdiplus.INSTANCE.GdipDeleteBrush(pBrush.getValue());
                    }
                }
            } finally {
                if (pPath.getValue() != null) {
                    Gdiplus.INSTANCE.GdipDeletePath(pPath.getValue());
                }
            }
        } finally {
            if (graphics != null) {
                Gdiplus.INSTANCE.GdipDeleteGraphics(graphics);
            }
        }
    }
}