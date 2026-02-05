import com.sun.jna.*;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;

public class Hello {

    // -----------------------------
    // Win32 constants
    // -----------------------------
    private static final int CS_OWNDC = 0x0020;

    private static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    private static final int CW_USEDEFAULT = 0x80000000;

    private static final int SW_SHOWDEFAULT = 10;

    private static final int WM_DESTROY = 0x0002;
    private static final int WM_PAINT   = 0x000F;
    private static final int WM_CLOSE   = 0x0010;
    private static final int WM_QUIT    = 0x0012;

    private static final int PM_REMOVE  = 0x0001;

    private static final int IDC_ARROW = 32512;
    private static final int IDI_APPLICATION = 32512;
    private static final int BLACK_BRUSH = 4;

    // Pixel format flags
    private static final int PFD_DRAW_TO_WINDOW = 0x00000004;
    private static final int PFD_SUPPORT_OPENGL = 0x00000020;
    private static final int PFD_DOUBLEBUFFER   = 0x00000001;

    private static final byte PFD_TYPE_RGBA  = 0;
    private static final byte PFD_MAIN_PLANE = 0;

    // OpenGL constants
    private static final int GL_COLOR_BUFFER_BIT = 0x00004000;
    private static final int GL_TRIANGLES        = 0x0004;

    // OpenGL matrix modes
    private static final int GL_PROJECTION = 0x1701;
    private static final int GL_MODELVIEW  = 0x1700;

    private static final int WIDTH  = 640;
    private static final int HEIGHT = 480;

    // -----------------------------
    // JNA: Win32 API (minimal)
    // -----------------------------
    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.UNICODE_OPTIONS);
        Pointer GetModuleHandleW(String lpModuleName);
        int GetLastError();
    }

    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class, W32APIOptions.UNICODE_OPTIONS);

        short RegisterClassExW(WNDCLASSEXW lpwcx);

        Pointer CreateWindowExW(
                int dwExStyle,
                String lpClassName,
                String lpWindowName,
                int dwStyle,
                int X, int Y,
                int nWidth, int nHeight,
                Pointer hWndParent,
                Pointer hMenu,
                Pointer hInstance,
                Pointer lpParam
        );

        boolean ShowWindow(Pointer hWnd, int nCmdShow);
        boolean UpdateWindow(Pointer hWnd);

        Pointer DefWindowProcW(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);

        boolean PeekMessageW(MSG lpMsg, Pointer hWnd, int wMsgFilterMin, int wMsgFilterMax, int wRemoveMsg);
        boolean TranslateMessage(MSG lpMsg);
        Pointer DispatchMessageW(MSG lpMsg);

        void PostQuitMessage(int nExitCode);

        Pointer LoadCursorW(Pointer hInstance, Pointer lpCursorName);
        Pointer LoadIconW(Pointer hInstance, Pointer lpIconName);

        Pointer BeginPaint(Pointer hWnd, PAINTSTRUCT lpPaint);
        boolean EndPaint(Pointer hWnd, PAINTSTRUCT lpPaint);

        Pointer GetDC(Pointer hWnd);
        int ReleaseDC(Pointer hWnd, Pointer hDC);

        boolean InvalidateRect(Pointer hWnd, Pointer lpRect, boolean bErase);
        boolean DestroyWindow(Pointer hWnd);
    }

    public interface Gdi32 extends StdCallLibrary {
        Gdi32 INSTANCE = Native.load("gdi32", Gdi32.class, W32APIOptions.UNICODE_OPTIONS);

        Pointer GetStockObject(int fnObject);

        int ChoosePixelFormat(Pointer hdc, PIXELFORMATDESCRIPTOR ppfd);
        boolean SetPixelFormat(Pointer hdc, int format, PIXELFORMATDESCRIPTOR ppfd);
        boolean SwapBuffers(Pointer hdc);
    }

    public interface OpenGL32 extends StdCallLibrary {
        OpenGL32 INSTANCE = Native.load("opengl32", OpenGL32.class);

        Pointer wglCreateContext(Pointer hdc);
        boolean wglMakeCurrent(Pointer hdc, Pointer hglrc);
        boolean wglDeleteContext(Pointer hglrc);

        void glClearColor(float r, float g, float b, float a);
        void glClear(int mask);

        void glBegin(int mode);
        void glEnd();

        void glColor3f(float r, float g, float b);
        void glVertex2f(float x, float y);

        void glViewport(int x, int y, int width, int height);
        void glMatrixMode(int mode);
        void glLoadIdentity();
        void glOrtho(double left, double right, double bottom, double top, double zNear, double zFar);
    }

    // -----------------------------
    // Structures
    // -----------------------------
    public static class WNDCLASSEXW extends Structure {
        public int cbSize;
        public int style;
        public WindowProc lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public Pointer hInstance;
        public Pointer hIcon;
        public Pointer hCursor;
        public Pointer hbrBackground;
        public WString lpszMenuName;
        public WString lpszClassName;
        public Pointer hIconSm;

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList(
                    "cbSize", "style", "lpfnWndProc", "cbClsExtra", "cbWndExtra",
                    "hInstance", "hIcon", "hCursor", "hbrBackground",
                    "lpszMenuName", "lpszClassName", "hIconSm"
            );
        }
    }

    public static class POINT extends Structure {
        public int x;
        public int y;

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("x", "y");
        }
    }

    public static class MSG extends Structure {
        public Pointer hWnd;
        public int message;
        public Pointer wParam;
        public Pointer lParam;
        public int time;
        public POINT pt;

        public MSG() { pt = new POINT(); }

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("hWnd", "message", "wParam", "lParam", "time", "pt");
        }
    }

    public static class RECT extends Structure {
        public int left, top, right, bottom;

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("left", "top", "right", "bottom");
        }
    }

    public static class PAINTSTRUCT extends Structure {
        public Pointer hdc;
        public boolean fErase;
        public RECT rcPaint;
        public boolean fRestore;
        public boolean fIncUpdate;
        public byte[] rgbReserved = new byte[32];

        public PAINTSTRUCT() { rcPaint = new RECT(); }

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("hdc", "fErase", "rcPaint", "fRestore", "fIncUpdate", "rgbReserved");
        }
    }

    public static class PIXELFORMATDESCRIPTOR extends Structure {
        public short nSize;
        public short nVersion;
        public int dwFlags;
        public byte iPixelType;
        public byte cColorBits;
        public byte cRedBits;
        public byte cRedShift;
        public byte cGreenBits;
        public byte cGreenShift;
        public byte cBlueBits;
        public byte cBlueShift;
        public byte cAlphaBits;
        public byte cAlphaShift;
        public byte cAccumBits;
        public byte cAccumRedBits;
        public byte cAccumGreenBits;
        public byte cAccumBlueBits;
        public byte cAccumAlphaBits;
        public byte cDepthBits;
        public byte cStencilBits;
        public byte cAuxBuffers;
        public byte iLayerType;
        public byte bReserved;
        public int dwLayerMask;
        public int dwVisibleMask;
        public int dwDamageMask;

        public PIXELFORMATDESCRIPTOR() { nSize = (short) size(); }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                    "nSize", "nVersion", "dwFlags", "iPixelType", "cColorBits",
                    "cRedBits", "cRedShift", "cGreenBits", "cGreenShift",
                    "cBlueBits", "cBlueShift", "cAlphaBits", "cAlphaShift",
                    "cAccumBits", "cAccumRedBits", "cAccumGreenBits",
                    "cAccumBlueBits", "cAccumAlphaBits", "cDepthBits",
                    "cStencilBits", "cAuxBuffers", "iLayerType", "bReserved",
                    "dwLayerMask", "dwVisibleMask", "dwDamageMask"
            );
        }
    }

    // -----------------------------
    // Window procedure callback
    // -----------------------------
    public interface WindowProc extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

    // -----------------------------
    // Globals
    // -----------------------------
    private static final String CLASS_NAME = "HelloJnaOpenGLClass";

    private static Pointer g_hWnd;
    private static Pointer g_hDC;
    private static Pointer g_hGLRC;
    private static WindowProc g_wndProc;

    private static void setupPixelFormat(Pointer hDC) {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 24;
        pfd.cDepthBits = 16;
        pfd.iLayerType = PFD_MAIN_PLANE;

        int fmt = Gdi32.INSTANCE.ChoosePixelFormat(hDC, pfd);
        if (fmt == 0) throw new RuntimeException("ChoosePixelFormat failed");
        if (!Gdi32.INSTANCE.SetPixelFormat(hDC, fmt, pfd)) throw new RuntimeException("SetPixelFormat failed");
    }

    private static void initOpenGL(Pointer hWnd) {
        g_hDC = User32.INSTANCE.GetDC(hWnd);
        if (g_hDC == null) throw new RuntimeException("GetDC failed");

        setupPixelFormat(g_hDC);

        g_hGLRC = OpenGL32.INSTANCE.wglCreateContext(g_hDC);
        if (g_hGLRC == null) throw new RuntimeException("wglCreateContext failed");

        if (!OpenGL32.INSTANCE.wglMakeCurrent(g_hDC, g_hGLRC))
            throw new RuntimeException("wglMakeCurrent failed");

        // Basic 2D view
        OpenGL32.INSTANCE.glViewport(0, 0, WIDTH, HEIGHT);

        OpenGL32.INSTANCE.glMatrixMode(GL_PROJECTION);
        OpenGL32.INSTANCE.glLoadIdentity();
        OpenGL32.INSTANCE.glOrtho(-1, 1, -1, 1, -1, 1);

        OpenGL32.INSTANCE.glMatrixMode(GL_MODELVIEW);
        OpenGL32.INSTANCE.glLoadIdentity();
    }

    private static void shutdownOpenGL(Pointer hWnd) {
        if (g_hGLRC != null) {
            OpenGL32.INSTANCE.wglMakeCurrent(null, null);
            OpenGL32.INSTANCE.wglDeleteContext(g_hGLRC);
            g_hGLRC = null;
        }
        if (g_hDC != null) {
            User32.INSTANCE.ReleaseDC(hWnd, g_hDC);
            g_hDC = null;
        }
    }

    private static void renderFrame() {
        if (g_hDC == null || g_hGLRC == null) return;

        OpenGL32.INSTANCE.glClearColor(0f, 0f, 0f, 0f);
        OpenGL32.INSTANCE.glClear(GL_COLOR_BUFFER_BIT);

        OpenGL32.INSTANCE.glBegin(GL_TRIANGLES);

        OpenGL32.INSTANCE.glColor3f(1f, 0f, 0f);
        OpenGL32.INSTANCE.glVertex2f(0.0f, 0.5f);

        OpenGL32.INSTANCE.glColor3f(0f, 1f, 0f);
        OpenGL32.INSTANCE.glVertex2f(0.5f, -0.5f);

        OpenGL32.INSTANCE.glColor3f(0f, 0f, 1f);
        OpenGL32.INSTANCE.glVertex2f(-0.5f, -0.5f);

        OpenGL32.INSTANCE.glEnd();

        Gdi32.INSTANCE.SwapBuffers(g_hDC);
    }

    public static void main(String[] args) {
        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        // Keep strong ref to avoid GC
        g_wndProc = (hWnd, uMsg, wParam, lParam) -> {
            switch (uMsg) {
                case WM_PAINT: {
                    PAINTSTRUCT ps = new PAINTSTRUCT();
                    User32.INSTANCE.BeginPaint(hWnd, ps);
                    User32.INSTANCE.EndPaint(hWnd, ps);
                    return Pointer.createConstant(0);
                }
                case WM_CLOSE: {
                    User32.INSTANCE.DestroyWindow(hWnd);
                    return Pointer.createConstant(0);
                }
                case WM_DESTROY: {
                    User32.INSTANCE.PostQuitMessage(0);
                    return Pointer.createConstant(0);
                }
                default:
                    return User32.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
            }
        };

        WNDCLASSEXW wc = new WNDCLASSEXW();
        wc.cbSize = wc.size();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = g_wndProc;
        wc.hInstance = hInstance;
        wc.hIcon = User32.INSTANCE.LoadIconW(null, Pointer.createConstant(IDI_APPLICATION));
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, Pointer.createConstant(IDC_ARROW));

        wc.hbrBackground = Gdi32.INSTANCE.GetStockObject(BLACK_BRUSH);

        wc.lpszMenuName = null;
        wc.lpszClassName = new WString(CLASS_NAME);
        wc.hIconSm = null;

        short atom = User32.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) {
            int lastError = Kernel32.INSTANCE.GetLastError();
            throw new RuntimeException("RegisterClassExW failed. GetLastError=" + lastError);
        }

        g_hWnd = User32.INSTANCE.CreateWindowExW(
                0,
                CLASS_NAME,
                "Hello, OpenGL (JNA only)",
                WS_OVERLAPPEDWINDOW,
                CW_USEDEFAULT, CW_USEDEFAULT,
                WIDTH, HEIGHT,
                null, null,
                hInstance,
                null
        );
        if (g_hWnd == null) throw new RuntimeException("CreateWindowExW failed");

        User32.INSTANCE.ShowWindow(g_hWnd, SW_SHOWDEFAULT);
        User32.INSTANCE.UpdateWindow(g_hWnd);

        initOpenGL(g_hWnd);

        MSG msg = new MSG();
        boolean running = true;
        while (running) {
            while (User32.INSTANCE.PeekMessageW(msg, null, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    running = false;
                    break;
                }
                User32.INSTANCE.TranslateMessage(msg);
                User32.INSTANCE.DispatchMessageW(msg);
            }
            if (!running) break;

            renderFrame();
            User32.INSTANCE.InvalidateRect(g_hWnd, null, false);

            try { Thread.sleep(1); } catch (InterruptedException ignored) {}
        }

        shutdownOpenGL(g_hWnd);
    }
}
