import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.PAINTSTRUCT;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.win32.StdCallLibrary;
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
    // Globals
    // ----------------------------
    static Callback wndProcCallback;

    // Note: ULONG_PTR is pointer-sized. JNA LongByReference stores a C "long" (4 bytes on Windows),
    // but we only need to keep the token value and pass it back to GdiplusShutdown.
    // We'll store it in a Java long.
    static long g_gdiplusToken = 0;

    // ----------------------------
    // GDI+ (gdiplus.dll) via JNA
    // ----------------------------
    public interface Gdiplus extends StdCallLibrary {
        Gdiplus INSTANCE = Native.load("gdiplus", Gdiplus.class);

        // int GdiplusStartup(ULONG_PTR* token, const GdiplusStartupInput* input, void* output)
        int GdiplusStartup(LongByReference token, GdiplusStartupInput input, Pointer output);

        // void GdiplusShutdown(ULONG_PTR token)
        void GdiplusShutdown(long token);

        int GdipCreateFromHDC(Pointer hdc, PointerByReference graphics);
        int GdipDeleteGraphics(Pointer graphics);

        int GdipCreatePath(int fillMode, PointerByReference path);
        int GdipDeletePath(Pointer path);
        int GdipAddPathLine2I(Pointer path, GpPoint[] points, int count);
        int GdipClosePathFigure(Pointer path);

        int GdipCreatePathGradientFromPath(Pointer path, PointerByReference polyGradient);
        int GdipSetPathGradientCenterColor(Pointer brush, int argb);

        // int GdipSetPathGradientSurroundColorsWithCount(GpPathGradient* brush, ARGB* colors, int* count)
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
    // Main entry
    // ----------------------------
    public static void main(String[] args) {

        // Initialize GDI+ once for the process.
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

        // NOTE: On Windows, C ULONG_PTR is pointer-sized. JNA's LongByReference stores a C "long" (4 bytes),
        // but token is typically small enough to fit. We store it as Java long and pass it back as long.
        g_gdiplusToken = tokenRef.getValue();

        long hInstance = OS.GetModuleHandle(null);

        // Create Win32 window class + window using SWT internal win32 helpers.
        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();

        char[] className = "HelloGdiPlusClass\0".toCharArray();

        WNDCLASS wc = new WNDCLASS();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProcAddress;
        wc.hInstance = hInstance;
        wc.hIcon = OS.LoadIcon(0, IDI_APPLICATION);
        wc.hCursor = OS.LoadCursor(0, IDC_ARROW);
        wc.hbrBackground = OS.GetStockObject(WHITE_BRUSH);

        // Allocate a native UTF-16 buffer for the class name (required by OS.RegisterClass).
        wc.lpszClassName = OS.HeapAlloc(OS.GetProcessHeap(), OS.HEAP_ZERO_MEMORY, className.length * 2);
        OS.MoveMemory(wc.lpszClassName, className, className.length * 2);

        OS.RegisterClass(wc);

        char[] windowName = "GDI+ Triangle (SWT internal + JNA)\0".toCharArray();
        long hWnd = OS.CreateWindowEx(
            0,
            className,
            windowName,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            0, 0, hInstance, null
        );

        OS.ShowWindow(hWnd, SW_SHOWDEFAULT);

        // Message loop
        MSG msg = new MSG();
        boolean bQuit = false;
        while (!bQuit) {
            if (OS.PeekMessage(msg, 0, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    bQuit = true;
                } else {
                    OS.TranslateMessage(msg);
                    OS.DispatchMessage(msg);
                }
            }
        }

        // Cleanup window + callback + allocated class name buffer.
        OS.DestroyWindow(hWnd);
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);

        // Shutdown GDI+ once.
        Gdiplus.INSTANCE.GdiplusShutdown(g_gdiplusToken);
    }

    // ----------------------------
    // Window procedure
    // ----------------------------
    static long WndProc(long hWnd, long uMsg, long wParam, long lParam) {
        switch ((int) uMsg) {
            case WM_CLOSE:
                // DestroyWindow triggers WM_DESTROY.
                OS.DestroyWindow(hWnd);
                return 0;

            case WM_DESTROY:
                // Exit message loop.
                OS.PostMessage(hWnd, WM_QUIT, 0, 0);
                return 0;

            case WM_PAINT: {
                PAINTSTRUCT ps = new PAINTSTRUCT();
                long hdc = OS.BeginPaint(hWnd, ps);

                // Draw with GDI+ using the HDC from BeginPaint.
                drawTriangleGdiPlus(hdc, WIDTH, HEIGHT);

                OS.EndPaint(hWnd, ps);
                return 0;
            }

            default:
                return OS.DefWindowProc(hWnd, (int) uMsg, wParam, lParam);
        }
    }

    // ----------------------------
    // Drawing with GDI+ PathGradientBrush
    // ----------------------------
    static void drawTriangleGdiPlus(long hdc, int width, int height) {
        PointerByReference pGraphics = new PointerByReference();
        PointerByReference pPath = new PointerByReference();
        PointerByReference pBrush = new PointerByReference();

        // Convert HDC -> GDI+ Graphics
        int st = Gdiplus.INSTANCE.GdipCreateFromHDC(new Pointer(hdc), pGraphics);
        if (st != 0) {
            System.err.println("GdipCreateFromHDC status=" + st);
            return;
        }
        Pointer graphics = pGraphics.getValue();

        try {
            // Create a path and define a triangle.
            st = Gdiplus.INSTANCE.GdipCreatePath(FillModeAlternate, pPath);
            if (st != 0) { System.err.println("GdipCreatePath status=" + st); return; }
            Pointer path = pPath.getValue();

            try {
                // Create 3 points (Structure array) in native memory.
                GpPoint[] pts = (GpPoint[]) new GpPoint().toArray(3);
                pts[0].x = width * 1 / 2;  pts[0].y = height * 1 / 4;
                pts[1].x = width * 3 / 4;  pts[1].y = height * 3 / 4;
                pts[2].x = width * 1 / 4;  pts[2].y = height * 3 / 4;

                // Ensure the array content is written to native memory.
                for (GpPoint p : pts) p.write();

                st = Gdiplus.INSTANCE.GdipAddPathLine2I(path, pts, 3);
                if (st != 0) { System.err.println("GdipAddPathLine2I status=" + st); return; }

                st = Gdiplus.INSTANCE.GdipClosePathFigure(path);
                if (st != 0) { System.err.println("GdipClosePathFigure status=" + st); return; }

                // Create a PathGradientBrush from the path.
                st = Gdiplus.INSTANCE.GdipCreatePathGradientFromPath(path, pBrush);
                if (st != 0) { System.err.println("GdipCreatePathGradientFromPath status=" + st); return; }
                Pointer brush = pBrush.getValue();

                try {
                    // Set center color (ARGB).
                    st = Gdiplus.INSTANCE.GdipSetPathGradientCenterColor(brush, 0xFF555555);
                    if (st != 0) { System.err.println("GdipSetPathGradientCenterColor status=" + st); return; }

                    // Set surround colors (ARGB) for the 3 vertices.
                    int[] colors = new int[] { 0xFFFF0000, 0xFF00FF00, 0xFF0000FF };
                    IntByReference count = new IntByReference(3);

                    st = Gdiplus.INSTANCE.GdipSetPathGradientSurroundColorsWithCount(brush, colors, count);
                    if (st != 0) { System.err.println("GdipSetPathGradientSurroundColorsWithCount status=" + st); return; }

                    // Fill the triangle path using the gradient brush.
                    st = Gdiplus.INSTANCE.GdipFillPath(graphics, brush, path);
                    if (st != 0) { System.err.println("GdipFillPath status=" + st); }
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
