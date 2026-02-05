import com.sun.jna.*;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;

public class Hello {
    // Win32 constants
    private static final int CS_OWNDC = 0x0020;

    private static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    private static final int CW_USEDEFAULT = 0x80000000;

    private static final int SW_SHOWDEFAULT = 10;

    private static final int WM_DESTROY = 0x0002;
    private static final int WM_CLOSE   = 0x0010;
    private static final int WM_QUIT    = 0x0012;

    private static final int PM_REMOVE  = 0x0001;

    private static final int IDC_ARROW = 32512;
    private static final int IDI_APPLICATION = 32512;
    private static final int BLACK_BRUSH = 4;

    // PIXELFORMATDESCRIPTOR constants
    private static final int PFD_DRAW_TO_WINDOW = 0x00000004;
    private static final int PFD_SUPPORT_OPENGL = 0x00000020;
    private static final int PFD_DOUBLEBUFFER = 0x00000001;
    private static final byte PFD_TYPE_RGBA = 0;
    private static final byte PFD_MAIN_PLANE = 0;

    // WGL context attributes
    private static final int WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    private static final int WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    private static final int WGL_CONTEXT_PROFILE_MASK_ARB  = 0x9126;
    private static final int WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;

    // OpenGL constants
    private static final int GL_COLOR_BUFFER_BIT = 0x00004000;
    private static final int GL_TRIANGLES = 0x0004;
    private static final int GL_FLOAT = 0x1406;
    private static final int GL_FALSE = 0;
    private static final int GL_ARRAY_BUFFER = 0x8892;
    private static final int GL_STATIC_DRAW = 0x88E4;
    private static final int GL_FRAGMENT_SHADER = 0x8B30;
    private static final int GL_VERTEX_SHADER = 0x8B31;
    private static final int GL_COMPILE_STATUS = 0x8B81;
    private static final int GL_LINK_STATUS = 0x8B82;
    private static final int GL_INFO_LOG_LENGTH = 0x8B84;

    private static final int WIDTH = 640;
    private static final int HEIGHT = 480;

    // OpenGL 3.3 functions
    private static Function glGenVertexArrays;
    private static Function glBindVertexArray;
    private static Function glGenBuffers;
    private static Function glBindBuffer;
    private static Function glBufferData;
    private static Function glCreateShader;
    private static Function glShaderSource;
    private static Function glCompileShader;
    private static Function glCreateProgram;
    private static Function glAttachShader;
    private static Function glLinkProgram;
    private static Function glUseProgram;
    private static Function glGetAttribLocation;
    private static Function glEnableVertexAttribArray;
    private static Function glVertexAttribPointer;
    private static Function glGetShaderiv;
    private static Function glGetProgramiv;
    private static Function glGetShaderInfoLog;
    private static Function glGetProgramInfoLog;

    private static int vao;
    private static int[] vbo = new int[2];
    private static int posAttrib;
    private static int colAttrib;

    // Shader sources
    private static final String vertexSource =
            "#version 330 core                            \n" +
            "layout(location = 0) in  vec3 position;      \n" +
            "layout(location = 1) in  vec3 color;         \n" +
            "out vec4 vColor;                             \n" +
            "void main()                                  \n" +
            "{                                            \n" +
            "  vColor = vec4(color, 1.0);                 \n" +
            "  gl_Position = vec4(position, 1.0);         \n" +
            "}                                            \n";

    private static final String fragmentSource =
            "#version 330 core                            \n" +
            "in  vec4 vColor;                             \n" +
            "out vec4 outColor;                           \n" +
            "void main()                                  \n" +
            "{                                            \n" +
            "  outColor = vColor;                         \n" +
            "}                                            \n";

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

        Pointer GetDC(Pointer hWnd);
        int ReleaseDC(Pointer hWnd, Pointer hDC);

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
        Pointer wglGetProcAddress(String name);

        void glClearColor(float red, float green, float blue, float alpha);
        void glClear(int mask);
        void glDrawArrays(int mode, int first, int count);
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
    private static final String CLASS_NAME = "HelloJnaOpenGL33Class";

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

        // Create temporary context to load wglCreateContextAttribsARB
        Pointer temp = OpenGL32.INSTANCE.wglCreateContext(g_hDC);
        if (temp == null) throw new RuntimeException("wglCreateContext (temp) failed");
        if (!OpenGL32.INSTANCE.wglMakeCurrent(g_hDC, temp))
            throw new RuntimeException("wglMakeCurrent (temp) failed");

        Function wglCreateContextAttribsARB = getGLFunction("wglCreateContextAttribsARB");
        if (wglCreateContextAttribsARB == null)
            throw new RuntimeException("wglCreateContextAttribsARB not available");

        Memory attribs = new Memory(7 * 4);
        int offset = 0;
        attribs.setInt(offset, WGL_CONTEXT_MAJOR_VERSION_ARB); offset += 4;
        attribs.setInt(offset, 3); offset += 4;
        attribs.setInt(offset, WGL_CONTEXT_MINOR_VERSION_ARB); offset += 4;
        attribs.setInt(offset, 3); offset += 4;
        attribs.setInt(offset, WGL_CONTEXT_PROFILE_MASK_ARB); offset += 4;
        attribs.setInt(offset, WGL_CONTEXT_CORE_PROFILE_BIT_ARB); offset += 4;
        attribs.setInt(offset, 0);

        g_hGLRC = (Pointer) wglCreateContextAttribsARB.invoke(Pointer.class, new Object[]{ g_hDC, null, attribs });
        if (g_hGLRC == null) throw new RuntimeException("wglCreateContextAttribsARB failed");

        OpenGL32.INSTANCE.wglMakeCurrent(null, null);
        OpenGL32.INSTANCE.wglDeleteContext(temp);

        if (!OpenGL32.INSTANCE.wglMakeCurrent(g_hDC, g_hGLRC))
            throw new RuntimeException("wglMakeCurrent failed");
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

        OpenGL32.INSTANCE.glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        OpenGL32.INSTANCE.glClear(GL_COLOR_BUFFER_BIT);

        drawTriangle();

        Gdi32.INSTANCE.SwapBuffers(g_hDC);
    }

    public static void main(String[] args) {
        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        g_wndProc = (hWnd, uMsg, wParam, lParam) -> {
            switch (uMsg) {
                case WM_CLOSE:
                    User32.INSTANCE.DestroyWindow(hWnd);
                    return Pointer.createConstant(0);
                case WM_DESTROY:
                    User32.INSTANCE.PostQuitMessage(0);
                    return Pointer.createConstant(0);
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
                "Hello, OpenGL 3.3 (JNA only)",
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
        initOpenGLFunctions();
        initShaderAndBuffers();

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

            try { Thread.sleep(1); } catch (InterruptedException ignored) {}
        }

        shutdownOpenGL(g_hWnd);
    }

    private static Function getGLFunction(String name) {
        Pointer addr = OpenGL32.INSTANCE.wglGetProcAddress(name);
        if (addr == null || Pointer.nativeValue(addr) == 0) {
            System.err.println("Failed to get function: " + name);
            return null;
        }
        return Function.getFunction(addr, Function.ALT_CONVENTION);
    }

    private static void initOpenGLFunctions() {
        glGenVertexArrays = getGLFunction("glGenVertexArrays");
        glBindVertexArray = getGLFunction("glBindVertexArray");
        glGenBuffers = getGLFunction("glGenBuffers");
        glBindBuffer = getGLFunction("glBindBuffer");
        glBufferData = getGLFunction("glBufferData");
        glCreateShader = getGLFunction("glCreateShader");
        glShaderSource = getGLFunction("glShaderSource");
        glCompileShader = getGLFunction("glCompileShader");
        glCreateProgram = getGLFunction("glCreateProgram");
        glAttachShader = getGLFunction("glAttachShader");
        glLinkProgram = getGLFunction("glLinkProgram");
        glUseProgram = getGLFunction("glUseProgram");
        glGetAttribLocation = getGLFunction("glGetAttribLocation");
        glEnableVertexAttribArray = getGLFunction("glEnableVertexAttribArray");
        glVertexAttribPointer = getGLFunction("glVertexAttribPointer");
        glGetShaderiv = getGLFunction("glGetShaderiv");
        glGetProgramiv = getGLFunction("glGetProgramiv");
        glGetShaderInfoLog = getGLFunction("glGetShaderInfoLog");
        glGetProgramInfoLog = getGLFunction("glGetProgramInfoLog");
    }

    private static void checkShaderCompileStatus(int shader, String type) {
        Memory status = new Memory(4);
        glGetShaderiv.invoke(void.class, new Object[]{ shader, GL_COMPILE_STATUS, status });
        int compiled = status.getInt(0);

        if (compiled == 0) {
            Memory logLength = new Memory(4);
            glGetShaderiv.invoke(void.class, new Object[]{ shader, GL_INFO_LOG_LENGTH, logLength });
            int len = logLength.getInt(0);
            if (len > 0) {
                Memory log = new Memory(len);
                glGetShaderInfoLog.invoke(void.class, new Object[]{ shader, len, null, log });
                System.err.println(type + " shader error: " + log.getString(0));
            }
        }
    }

    private static void checkProgramLinkStatus(int program) {
        Memory status = new Memory(4);
        glGetProgramiv.invoke(void.class, new Object[]{ program, GL_LINK_STATUS, status });
        int linked = status.getInt(0);

        if (linked == 0) {
            Memory logLength = new Memory(4);
            glGetProgramiv.invoke(void.class, new Object[]{ program, GL_INFO_LOG_LENGTH, logLength });
            int len = logLength.getInt(0);
            if (len > 0) {
                Memory log = new Memory(len);
                glGetProgramInfoLog.invoke(void.class, new Object[]{ program, len, null, log });
                System.err.println("Program link error: " + log.getString(0));
            }
        }
    }

    private static void initShaderAndBuffers() {
        // VAO
        Memory vaoMem = new Memory(4);
        glGenVertexArrays.invoke(void.class, new Object[]{ 1, vaoMem });
        vao = vaoMem.getInt(0);
        glBindVertexArray.invoke(void.class, new Object[]{ vao });

        // VBOs
        Memory vboMem = new Memory(4 * 2);
        glGenBuffers.invoke(void.class, new Object[]{ 2, vboMem });
        vbo[0] = vboMem.getInt(0);
        vbo[1] = vboMem.getInt(4);

        float[] vertices = {
                0.0f,  0.5f, 0.0f,
                0.5f, -0.5f, 0.0f,
                -0.5f, -0.5f, 0.0f
        };
        float[] colors = {
                1.0f, 0.0f, 0.0f,
                0.0f, 1.0f, 0.0f,
                0.0f, 0.0f, 1.0f
        };

        Memory verticesMem = new Memory(vertices.length * 4L);
        for (int i = 0; i < vertices.length; i++) {
            verticesMem.setFloat(i * 4L, vertices[i]);
        }
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[0] });
        glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, (long)(vertices.length * 4), verticesMem, GL_STATIC_DRAW });

        Memory colorsMem = new Memory(colors.length * 4L);
        for (int i = 0; i < colors.length; i++) {
            colorsMem.setFloat(i * 4L, colors[i]);
        }
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[1] });
        glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, (long)(colors.length * 4), colorsMem, GL_STATIC_DRAW });

        int vertexShader = (Integer) glCreateShader.invoke(int.class, new Object[]{ GL_VERTEX_SHADER });
        Memory vertexSourcePtr = new Memory(Native.POINTER_SIZE);
        Memory vertexSourceMem = new Memory(vertexSource.length() + 1L);
        vertexSourceMem.setString(0, vertexSource);
        vertexSourcePtr.setPointer(0, vertexSourceMem);
        glShaderSource.invoke(void.class, new Object[]{ vertexShader, 1, vertexSourcePtr, null });
        glCompileShader.invoke(void.class, new Object[]{ vertexShader });
        checkShaderCompileStatus(vertexShader, "vertex");

        int fragmentShader = (Integer) glCreateShader.invoke(int.class, new Object[]{ GL_FRAGMENT_SHADER });
        Memory fragmentSourcePtr = new Memory(Native.POINTER_SIZE);
        Memory fragmentSourceMem = new Memory(fragmentSource.length() + 1L);
        fragmentSourceMem.setString(0, fragmentSource);
        fragmentSourcePtr.setPointer(0, fragmentSourceMem);
        glShaderSource.invoke(void.class, new Object[]{ fragmentShader, 1, fragmentSourcePtr, null });
        glCompileShader.invoke(void.class, new Object[]{ fragmentShader });
        checkShaderCompileStatus(fragmentShader, "fragment");

        int shaderProgram = (Integer) glCreateProgram.invoke(int.class, new Object[]{});
        glAttachShader.invoke(void.class, new Object[]{ shaderProgram, vertexShader });
        glAttachShader.invoke(void.class, new Object[]{ shaderProgram, fragmentShader });
        glLinkProgram.invoke(void.class, new Object[]{ shaderProgram });
        checkProgramLinkStatus(shaderProgram);
        glUseProgram.invoke(void.class, new Object[]{ shaderProgram });

        Memory positionName = new Memory(16);
        positionName.setString(0, "position");
        posAttrib = (Integer) glGetAttribLocation.invoke(int.class, new Object[]{ shaderProgram, positionName });
        glEnableVertexAttribArray.invoke(void.class, new Object[]{ posAttrib });

        Memory colorName = new Memory(16);
        colorName.setString(0, "color");
        colAttrib = (Integer) glGetAttribLocation.invoke(int.class, new Object[]{ shaderProgram, colorName });
        glEnableVertexAttribArray.invoke(void.class, new Object[]{ colAttrib });

        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[0] });
        glVertexAttribPointer.invoke(void.class, new Object[]{ 0, 3, GL_FLOAT, GL_FALSE, 0, Pointer.createConstant(0) });

        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[1] });
        glVertexAttribPointer.invoke(void.class, new Object[]{ 1, 3, GL_FLOAT, GL_FALSE, 0, Pointer.createConstant(0) });
    }

    private static void drawTriangle() {
        glBindVertexArray.invoke(void.class, new Object[]{ vao });
        OpenGL32.INSTANCE.glDrawArrays(GL_TRIANGLES, 0, 3);
    }
}
