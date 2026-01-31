import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.win32.StdCallLibrary;

import java.util.Arrays;
import java.util.List;

public class Hello {
    static final int CS_OWNDC = 0x0020;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_CLOSE = 0x0010;
    static final int WM_DESTROY = 0x0002;
    static final int WM_QUIT = 0x0012;
    static final int PM_REMOVE = 0x0001;
    static final int BLACK_BRUSH = 4;
    static final int IDI_APPLICATION = 32512;
    static final int IDC_ARROW = 32512;

    static final int PFD_DRAW_TO_WINDOW = 0x00000004;
    static final int PFD_SUPPORT_OPENGL = 0x00000020;
    static final int PFD_DOUBLEBUFFER = 0x00000001;
    static final byte PFD_TYPE_RGBA = 0;
    static final byte PFD_MAIN_PLANE = 0;

    static final int GL_COLOR_BUFFER_BIT = 0x00004000;
    static final int GL_TRIANGLES = 0x0004;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    static Callback wndProcCallback;

    public interface Gdi32 extends StdCallLibrary {
        Gdi32 INSTANCE = Native.load("gdi32", Gdi32.class);

        int ChoosePixelFormat(Pointer hdc, PIXELFORMATDESCRIPTOR ppfd);
        boolean SetPixelFormat(Pointer hdc, int format, PIXELFORMATDESCRIPTOR ppfd);
        boolean SwapBuffers(Pointer hdc);
    }

    public interface OpenGL32 extends StdCallLibrary {
        OpenGL32 INSTANCE = Native.load("opengl32", OpenGL32.class);

        Pointer wglCreateContext(Pointer hdc);
        boolean wglMakeCurrent(Pointer hdc, Pointer hglrc);
        boolean wglDeleteContext(Pointer hglrc);

        void glClearColor(float red, float green, float blue, float alpha);
        void glClear(int mask);
        void glBegin(int mode);
        void glEnd();
        void glColor3f(float red, float green, float blue);
        void glVertex2f(float x, float y);
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

        public PIXELFORMATDESCRIPTOR() {
            nSize = (short) size();
        }

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

    public static void main(String[] args) {
        long hInstance = OS.GetModuleHandle(null);

        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();

        char[] className = "HelloClass\0".toCharArray();

        WNDCLASS wc = new WNDCLASS();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProcAddress;
        wc.hInstance = hInstance;
        wc.hIcon = OS.LoadIcon(0, IDI_APPLICATION);
        wc.hCursor = OS.LoadCursor(0, IDC_ARROW);
        wc.hbrBackground = OS.GetStockObject(BLACK_BRUSH);
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
            WIDTH, HEIGHT,
            0, 0, hInstance, null
        );

        OS.ShowWindow(hWnd, SW_SHOWDEFAULT);

        long hDC = OS.GetDC(hWnd);
        Pointer hDCPtr = new Pointer(hDC);
        Pointer hRC = enableOpenGL(hDCPtr);

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
            } else {
                OpenGL32.INSTANCE.glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
                OpenGL32.INSTANCE.glClear(GL_COLOR_BUFFER_BIT);

                drawTriangle();

                Gdi32.INSTANCE.SwapBuffers(hDCPtr);

                try {
                    Thread.sleep(1);
                } catch (InterruptedException e) {
                    // ignore
                }
            }
        }

        disableOpenGL(hWnd, hDCPtr, hRC);
        OS.DestroyWindow(hWnd);
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);
    }

    static long WndProc(long hWnd, long uMsg, long wParam, long lParam) {
        switch ((int) uMsg) {
            case WM_CLOSE:
                OS.PostMessage(hWnd, WM_QUIT, 0, 0);
                return 0;
            case WM_DESTROY:
                return 0;
            default:
                return OS.DefWindowProc(hWnd, (int) uMsg, wParam, lParam);
        }
    }

    static Pointer enableOpenGL(Pointer hDC) {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 24;
        pfd.cDepthBits = 16;
        pfd.iLayerType = PFD_MAIN_PLANE;

        int iFormat = Gdi32.INSTANCE.ChoosePixelFormat(hDC, pfd);
        System.out.println("ChoosePixelFormat: " + iFormat);

        Gdi32.INSTANCE.SetPixelFormat(hDC, iFormat, pfd);

        Pointer hRC = OpenGL32.INSTANCE.wglCreateContext(hDC);
        System.out.println("wglCreateContext: " + hRC);

        OpenGL32.INSTANCE.wglMakeCurrent(hDC, hRC);

        return hRC;
    }

    static void disableOpenGL(long hWnd, Pointer hDC, Pointer hRC) {
        OpenGL32.INSTANCE.wglMakeCurrent(null, null);
        OpenGL32.INSTANCE.wglDeleteContext(hRC);
        OS.ReleaseDC(hWnd, Pointer.nativeValue(hDC));
    }

    static void drawTriangle() {
        OpenGL32.INSTANCE.glBegin(GL_TRIANGLES);

        OpenGL32.INSTANCE.glColor3f(1.0f, 0.0f, 0.0f);
        OpenGL32.INSTANCE.glVertex2f(0.0f, 0.5f);

        OpenGL32.INSTANCE.glColor3f(0.0f, 1.0f, 0.0f);
        OpenGL32.INSTANCE.glVertex2f(0.5f, -0.5f);

        OpenGL32.INSTANCE.glColor3f(0.0f, 0.0f, 1.0f);
        OpenGL32.INSTANCE.glVertex2f(-0.5f, -0.5f);

        OpenGL32.INSTANCE.glEnd();
    }
}
