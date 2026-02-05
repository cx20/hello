import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.WString;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

/**
 * Hello Direct2D (Java + JNA only)
 *
 * DPI-aware version for Windows scaling (e.g. 150%).
 */
public final class Hello {

    // ----------------------------
    // Win32 constants
    // ----------------------------
    static final int CS_HREDRAW = 0x0002;
    static final int CS_VREDRAW = 0x0001;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;

    static final int WM_DESTROY = 0x0002;
    static final int WM_SIZE    = 0x0005;
    static final int WM_PAINT   = 0x000F;
    static final int WM_QUIT    = 0x0012;

    static final int WHITE_BRUSH = 0;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;

    static final int WIDTH  = 800;
    static final int HEIGHT = 600;

    static final int COINIT_APARTMENTTHREADED = 0x2;

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

    public static final class RECT extends Structure {
        public int left, top, right, bottom;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("left", "top", "right", "bottom");
        }

        public int width() { return right - left; }
        public int height() { return bottom - top; }
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
        void OutputDebugStringW(String lpOutputString);
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
        boolean UpdateWindow(Pointer hWnd);
        int GetMessageW(MSG lpMsg, Pointer hWnd, int wMsgFilterMin, int wMsgFilterMax);
        boolean TranslateMessage(MSG lpMsg);
        Pointer DispatchMessageW(MSG lpMsg);
        Pointer DefWindowProcW(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
        void PostQuitMessage(int nExitCode);
        boolean DestroyWindow(Pointer hWnd);
        Pointer BeginPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        boolean EndPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        boolean InvalidateRect(Pointer hWnd, Pointer lpRect, boolean bErase);
        Pointer LoadIconW(Pointer hInstance, int lpIconName);
        Pointer LoadCursorW(Pointer hInstance, int lpCursorName);
        boolean GetClientRect(Pointer hWnd, RECT lpRect);
        int GetDpiForWindow(Pointer hWnd);
    }

    // ----------------------------
    // GDI32 interface
    // ----------------------------
    public interface GDI32 extends StdCallLibrary {
        GDI32 INSTANCE = Native.load("gdi32", GDI32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetStockObject(int i);
    }

    // ----------------------------
    // Ole32 interface
    // ----------------------------
    public interface Ole32 extends StdCallLibrary {
        Ole32 INSTANCE = Native.load("ole32", Ole32.class, W32APIOptions.DEFAULT_OPTIONS);

        int CoInitializeEx(Pointer pvReserved, int dwCoInit);
        void CoUninitialize();
    }

    // ----------------------------
    // Direct2D constants
    // ----------------------------
    private static final int D2D1_FACTORY_TYPE_SINGLE_THREADED = 0;
    private static final int D2D1_RENDER_TARGET_TYPE_DEFAULT = 0;
    private static final int DXGI_FORMAT_UNKNOWN = 0;
    private static final int D2D1_ALPHA_MODE_UNKNOWN = 0;
    private static final int D2D1_RENDER_TARGET_USAGE_NONE = 0;
    private static final int D2D1_FEATURE_LEVEL_DEFAULT = 0;
    private static final int D2D1_PRESENT_OPTIONS_NONE = 0;

    // ----------------------------
    // Direct2D interface
    // ----------------------------
    public interface D2D1 extends StdCallLibrary {
        D2D1 INSTANCE = Native.load("d2d1", D2D1.class, W32APIOptions.DEFAULT_OPTIONS);

        int D2D1CreateFactory(int factoryType, GUID riid, Pointer pFactoryOptions, PointerByReference ppFactory);
    }

    // ----------------------------
    // Direct2D structs
    // ----------------------------
    public static final class GUID extends Structure {
        public int Data1;
        public short Data2;
        public short Data3;
        public byte[] Data4 = new byte[8];

        public GUID() {}

        public GUID(UUID uuid) {
            long msb = uuid.getMostSignificantBits();
            long lsb = uuid.getLeastSignificantBits();

            Data1 = (int) (msb >>> 32);
            Data2 = (short) ((msb >>> 16) & 0xFFFF);
            Data3 = (short) (msb & 0xFFFF);
            for (int i = 0; i < 8; i++) {
                Data4[i] = (byte) ((lsb >>> (8 * (7 - i))) & 0xFF);
            }
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("Data1", "Data2", "Data3", "Data4");
        }
    }

    public static class D2D1_COLOR_F extends Structure {
        public float r, g, b, a;

        public D2D1_COLOR_F() {}
        public D2D1_COLOR_F(float r, float g, float b, float a) {
            this.r = r; this.g = g; this.b = b; this.a = a;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("r", "g", "b", "a");
        }

        public static final class ByValue extends D2D1_COLOR_F implements Structure.ByValue {
            public ByValue() {}
            public ByValue(float r, float g, float b, float a) { super(r, g, b, a); }
        }
    }

    public static class D2D1_POINT_2F extends Structure {
        public float x, y;

        public D2D1_POINT_2F() {}
        public D2D1_POINT_2F(float x, float y) {
            this.x = x; this.y = y;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y");
        }

        public static final class ByValue extends D2D1_POINT_2F implements Structure.ByValue {
            public ByValue() {}
            public ByValue(float x, float y) { super(x, y); }
        }
    }

    public static class D2D1_SIZE_U extends Structure {
        public int width;
        public int height;

        public D2D1_SIZE_U() {}
        public D2D1_SIZE_U(int width, int height) {
            this.width = width; this.height = height;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("width", "height");
        }

        public static final class ByValue extends D2D1_SIZE_U implements Structure.ByValue {
            public ByValue() {}
            public ByValue(int width, int height) { super(width, height); }
        }
    }

    public static final class D2D1_PIXEL_FORMAT extends Structure {
        public int format;
        public int alphaMode;

        public D2D1_PIXEL_FORMAT() {}
        public D2D1_PIXEL_FORMAT(int format, int alphaMode) {
            this.format = format;
            this.alphaMode = alphaMode;
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("format", "alphaMode");
        }
    }

    public static final class D2D1_RENDER_TARGET_PROPERTIES extends Structure {
        public int type;
        public D2D1_PIXEL_FORMAT pixelFormat;
        public float dpiX;
        public float dpiY;
        public int usage;
        public int minLevel;

        public D2D1_RENDER_TARGET_PROPERTIES() {
            this.pixelFormat = new D2D1_PIXEL_FORMAT();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("type", "pixelFormat", "dpiX", "dpiY", "usage", "minLevel");
        }
    }

    public static final class D2D1_HWND_RENDER_TARGET_PROPERTIES extends Structure {
        public Pointer hwnd;
        public D2D1_SIZE_U pixelSize;
        public int presentOptions;

        public D2D1_HWND_RENDER_TARGET_PROPERTIES() {
            this.pixelSize = new D2D1_SIZE_U();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("hwnd", "pixelSize", "presentOptions");
        }
    }

    // ----------------------------
    // Direct2D vtable indices
    // ----------------------------
    private static final int VTBL_IUNKNOWN_RELEASE = 2;
    private static final int VTBL_ID2D1FACTORY_CREATEHWNDRENDERTARGET = 14;
    private static final int VTBL_ID2D1RENDERTARGET_CREATESOLIDCOLORBRUSH = 8;
    private static final int VTBL_ID2D1RENDERTARGET_DRAWLINE = 15;
    private static final int VTBL_ID2D1RENDERTARGET_CLEAR = 47;
    private static final int VTBL_ID2D1RENDERTARGET_BEGINDRAW = 48;
    private static final int VTBL_ID2D1RENDERTARGET_ENDDRAW = 49;
    private static final int VTBL_ID2D1HWNDRENDERTARGET_RESIZE = 58;

    // ----------------------------
    // Direct2D COM callbacks
    // ----------------------------
    public interface Fn_CreateHwndRenderTarget extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis,
                   D2D1_RENDER_TARGET_PROPERTIES rtProps,
                   D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps,
                   PointerByReference ppRenderTarget);
    }

    public interface Fn_CreateSolidColorBrush extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, D2D1_COLOR_F.ByValue color, Pointer brushPropsNullable, PointerByReference ppBrush);
    }

    public interface Fn_BeginDraw extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis);
    }

    public interface Fn_EndDraw extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, Pointer tag1Nullable, Pointer tag2Nullable);
    }

    public interface Fn_Clear extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis, D2D1_COLOR_F.ByValue clearColor);
    }

    public interface Fn_DrawLine extends StdCallLibrary.StdCallCallback {
        void invoke(Pointer pThis,
                    D2D1_POINT_2F.ByValue p0,
                    D2D1_POINT_2F.ByValue p1,
                    Pointer brush,
                    float strokeWidth,
                    Pointer strokeStyleNullable);
    }

    public interface Fn_Resize extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis, D2D1_SIZE_U.ByValue size);
    }

    public interface Fn_Release extends StdCallLibrary.StdCallCallback {
        int invoke(Pointer pThis);
    }

    // ----------------------------
    // COM vtable helpers
    // ----------------------------
    private static Pointer vtbl(Pointer comObj) {
        return comObj.getPointer(0);
    }

    private static Pointer vtblEntry(Pointer comObj, int index) {
        return vtbl(comObj).getPointer((long) index * Native.POINTER_SIZE);
    }

    private static <T extends com.sun.jna.Callback> T fn(Pointer comObj, int index, Class<T> type) {
        Pointer pFn = vtblEntry(comObj, index);
        return type.cast(com.sun.jna.CallbackReference.getCallback(type, pFn));
    }

    private static void safeRelease(Pointer comObj) {
        if (comObj == null || Pointer.nativeValue(comObj) == 0) return;
        Fn_Release rel = fn(comObj, VTBL_IUNKNOWN_RELEASE, Fn_Release.class);
        rel.invoke(comObj);
    }

    // ----------------------------
    // Debug logging
    // ----------------------------
    private static void log(String fmt, Object... args) {
        String msg;
        try {
            msg = (args == null || args.length == 0) ? fmt : String.format(fmt, args);
        } catch (Throwable t) {
            msg = fmt + " (formatting failed: " + t + ")";
        }
        String line = String.format("[HelloD2D][%d] %s\n", Thread.currentThread().getId(), msg);
        System.out.print(line);
        try { Kernel32.INSTANCE.OutputDebugStringW(line); } catch (Throwable ignored) {}
    }

    private static void checkHR(String what, int hr) {
        if (hr < 0) {
            log("%s -> FAILED hr=0x%08X", what, hr);
            throw new RuntimeException(String.format("%s failed: HRESULT=0x%08X", what, hr));
        }
        log("%s -> OK hr=0x%08X", what, hr);
    }

    // IID_ID2D1Factory = {06152247-6f50-465a-9245-118bfd3b6007}
    private static final GUID IID_ID2D1Factory = new GUID(UUID.fromString("06152247-6f50-465a-9245-118bfd3b6007"));

    // ----------------------------
    // App state
    // ----------------------------
    private static Pointer g_factory;
    private static Pointer g_hwndRenderTarget;
    private static Pointer g_brush;
    private static int g_dpi = 96;
    private static Pointer g_hWnd;

    private static int getWindowDpi(Pointer hwnd) {
        try {
            int dpi = User32.INSTANCE.GetDpiForWindow(hwnd);
            if (dpi <= 0) return 96;
            return dpi;
        } catch (Throwable t) {
            return 96;
        }
    }

    private static int[] getClientSizePx(Pointer hwnd) {
        RECT rc = new RECT();
        boolean ok = User32.INSTANCE.GetClientRect(hwnd, rc);
        if (!ok) {
            return new int[] { 1, 1 };
        }
        int w = Math.max(1, rc.width());
        int h = Math.max(1, rc.height());
        return new int[] { w, h };
    }

    private static void initD2D(Pointer hwnd) {
        g_dpi = getWindowDpi(hwnd);
        int[] whPx = getClientSizePx(hwnd);
        int wPx = whPx[0];
        int hPx = whPx[1];

        log("initD2D: hwnd=%s dpi=%d clientPx=%dx%d", hwnd, g_dpi, wPx, hPx);

        PointerByReference ppFactory = new PointerByReference();
        int hr = D2D1.INSTANCE.D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, IID_ID2D1Factory, Pointer.NULL, ppFactory);
        checkHR("D2D1CreateFactory", hr);
        g_factory = ppFactory.getValue();

        D2D1_RENDER_TARGET_PROPERTIES rtProps = new D2D1_RENDER_TARGET_PROPERTIES();
        rtProps.type = D2D1_RENDER_TARGET_TYPE_DEFAULT;
        rtProps.pixelFormat = new D2D1_PIXEL_FORMAT(DXGI_FORMAT_UNKNOWN, D2D1_ALPHA_MODE_UNKNOWN);
        rtProps.dpiX = (float) g_dpi;
        rtProps.dpiY = (float) g_dpi;
        rtProps.usage = D2D1_RENDER_TARGET_USAGE_NONE;
        rtProps.minLevel = D2D1_FEATURE_LEVEL_DEFAULT;
        rtProps.write();

        D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps = new D2D1_HWND_RENDER_TARGET_PROPERTIES();
        hwndProps.hwnd = hwnd;
        hwndProps.pixelSize = new D2D1_SIZE_U(wPx, hPx);
        hwndProps.presentOptions = D2D1_PRESENT_OPTIONS_NONE;
        hwndProps.write();

        PointerByReference ppRT = new PointerByReference();
        Fn_CreateHwndRenderTarget createRT = fn(g_factory, VTBL_ID2D1FACTORY_CREATEHWNDRENDERTARGET, Fn_CreateHwndRenderTarget.class);
        hr = createRT.invoke(g_factory, rtProps, hwndProps, ppRT);
        checkHR("ID2D1Factory::CreateHwndRenderTarget", hr);
        g_hwndRenderTarget = ppRT.getValue();

        // Blue brush
        PointerByReference ppBrush = new PointerByReference();
        Fn_CreateSolidColorBrush createBrush = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_CREATESOLIDCOLORBRUSH, Fn_CreateSolidColorBrush.class);
        D2D1_COLOR_F.ByValue blue = new D2D1_COLOR_F.ByValue(0.0f, 0.0f, 1.0f, 1.0f);
        blue.write();
        hr = createBrush.invoke(g_hwndRenderTarget, blue, Pointer.NULL, ppBrush);
        checkHR("ID2D1RenderTarget::CreateSolidColorBrush", hr);
        g_brush = ppBrush.getValue();

        log("initD2D: factory=%s rt=%s brush=%s", g_factory, g_hwndRenderTarget, g_brush);
    }

    private static void resizeD2D(Pointer hwnd) {
        if (g_hwndRenderTarget == null || Pointer.nativeValue(g_hwndRenderTarget) == 0) return;

        g_dpi = getWindowDpi(hwnd);
        int[] whPx = getClientSizePx(hwnd);
        int wPx = whPx[0];
        int hPx = whPx[1];

        Fn_Resize resize = fn(g_hwndRenderTarget, VTBL_ID2D1HWNDRENDERTARGET_RESIZE, Fn_Resize.class);
        D2D1_SIZE_U.ByValue size = new D2D1_SIZE_U.ByValue(wPx, hPx);
        size.write();
        int hr = resize.invoke(g_hwndRenderTarget, size);
        checkHR("ID2D1HwndRenderTarget::Resize", hr);

        log("resizeD2D: dpi=%d clientPx=%dx%d", g_dpi, wPx, hPx);
    }

    private static void drawTriangle(Pointer hwnd) {
        if (g_hwndRenderTarget == null || Pointer.nativeValue(g_hwndRenderTarget) == 0) return;

        int[] whPx = getClientSizePx(hwnd);
        int wPx = whPx[0];
        int hPx = whPx[1];
        int dpi = Math.max(96, g_dpi);

        float wDip = (float) (wPx * 96.0 / dpi);
        float hDip = (float) (hPx * 96.0 / dpi);

        Fn_BeginDraw beginDraw = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_BEGINDRAW, Fn_BeginDraw.class);
        Fn_Clear clear = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_CLEAR, Fn_Clear.class);
        Fn_DrawLine drawLine = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_DRAWLINE, Fn_DrawLine.class);
        Fn_EndDraw endDraw = fn(g_hwndRenderTarget, VTBL_ID2D1RENDERTARGET_ENDDRAW, Fn_EndDraw.class);

        beginDraw.invoke(g_hwndRenderTarget);

        // White background
        D2D1_COLOR_F.ByValue white = new D2D1_COLOR_F.ByValue(1.0f, 1.0f, 1.0f, 1.0f);
        white.write();
        clear.invoke(g_hwndRenderTarget, white);

        // Centered triangle in DIPs
        float cx = wDip * 0.5f;
        float cy = hDip * 0.5f;
        float side = Math.min(wDip, hDip) * 0.65f;
        float triH = (float) (Math.sqrt(3.0) * 0.5 * side);

        D2D1_POINT_2F.ByValue p0 = new D2D1_POINT_2F.ByValue(cx, cy - triH * 0.55f);
        D2D1_POINT_2F.ByValue p1 = new D2D1_POINT_2F.ByValue(cx - side * 0.5f, cy + triH * 0.45f);
        D2D1_POINT_2F.ByValue p2 = new D2D1_POINT_2F.ByValue(cx + side * 0.5f, cy + triH * 0.45f);
        p0.write(); p1.write(); p2.write();

        float stroke = 2.5f;
        drawLine.invoke(g_hwndRenderTarget, p0, p1, g_brush, stroke, Pointer.NULL);
        drawLine.invoke(g_hwndRenderTarget, p1, p2, g_brush, stroke, Pointer.NULL);
        drawLine.invoke(g_hwndRenderTarget, p2, p0, g_brush, stroke, Pointer.NULL);

        int hr = endDraw.invoke(g_hwndRenderTarget, Pointer.NULL, Pointer.NULL);
        checkHR("ID2D1RenderTarget::EndDraw", hr);

        log("draw: dpi=%d px=%dx%d dip=%.1fx%.1f", dpi, wPx, hPx, wDip, hDip);
    }

    private static void cleanup() {
        safeRelease(g_brush);
        g_brush = null;
        safeRelease(g_hwndRenderTarget);
        g_hwndRenderTarget = null;
        safeRelease(g_factory);
        g_factory = null;
    }

    // ----------------------------
    // WndProc implementation
    // ----------------------------
    static WndProcCallback wndProc = new WndProcCallback() {
        @Override
        public Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
            switch (uMsg) {
                case WM_SIZE:
                    resizeD2D(hWnd);
                    User32.INSTANCE.InvalidateRect(hWnd, null, false);
                    return Pointer.createConstant(0);

                case WM_PAINT: {
                    PAINTSTRUCT ps = new PAINTSTRUCT();
                    User32.INSTANCE.BeginPaint(hWnd, ps);
                    drawTriangle(hWnd);
                    User32.INSTANCE.EndPaint(hWnd, ps);
                    return Pointer.createConstant(0);
                }

                case WM_DESTROY:
                    cleanup();
                    User32.INSTANCE.PostQuitMessage(0);
                    return Pointer.createConstant(0);

                default:
                    return User32.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
            }
        }
    };

    // ----------------------------
    // Main entry
    // ----------------------------
    public static void main(String[] args) {
        log("main: start");

        int hr = Ole32.INSTANCE.CoInitializeEx(Pointer.NULL, COINIT_APARTMENTTHREADED);
        checkHR("CoInitializeEx", hr);

        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        WString className = new WString("HelloD2DClass");

        // Register window class
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = wndProc;
        wc.hInstance = hInstance;
        wc.hIcon = User32.INSTANCE.LoadIconW(null, IDI_APPLICATION);
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = GDI32.INSTANCE.GetStockObject(WHITE_BRUSH);
        wc.lpszClassName = className;

        int atom = User32.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) {
            System.err.println("RegisterClassExW failed");
            Ole32.INSTANCE.CoUninitialize();
            return;
        }

        // Create window
        Pointer hWnd = User32.INSTANCE.CreateWindowExW(
            0,
            className,
            new WString("Hello, Direct2D(Java+JNA) World!"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            null, null, hInstance, null
        );

        if (hWnd == null) {
            System.err.println("CreateWindowExW failed");
            Ole32.INSTANCE.CoUninitialize();
            return;
        }

        g_hWnd = hWnd;
        log("main: hwnd=%s", hWnd);

        // Initialize Direct2D
        initD2D(hWnd);

        User32.INSTANCE.ShowWindow(hWnd, SW_SHOWDEFAULT);
        User32.INSTANCE.UpdateWindow(hWnd);

        // Message loop
        MSG msg = new MSG();
        while (User32.INSTANCE.GetMessageW(msg, null, 0, 0) > 0) {
            User32.INSTANCE.TranslateMessage(msg);
            User32.INSTANCE.DispatchMessageW(msg);
        }

        Ole32.INSTANCE.CoUninitialize();
        log("main: loop exited");
    }
}