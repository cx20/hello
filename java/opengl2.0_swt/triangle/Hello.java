import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.Memory;
import com.sun.jna.Function;
import com.sun.jna.win32.StdCallLibrary;

import java.util.Arrays;
import java.util.List;

public class Hello {
    // Win32 constants
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

    // PIXELFORMATDESCRIPTOR constants
    static final int PFD_DRAW_TO_WINDOW = 0x00000004;
    static final int PFD_SUPPORT_OPENGL = 0x00000020;
    static final int PFD_DOUBLEBUFFER = 0x00000001;
    static final byte PFD_TYPE_RGBA = 0;
    static final byte PFD_MAIN_PLANE = 0;

    // OpenGL constants
    static final int GL_COLOR_BUFFER_BIT = 0x00004000;
    static final int GL_TRIANGLES = 0x0004;
    static final int GL_FLOAT = 0x1406;
    static final int GL_FALSE = 0;
    static final int GL_ARRAY_BUFFER = 0x8892;
    static final int GL_STATIC_DRAW = 0x88E4;
    static final int GL_FRAGMENT_SHADER = 0x8B30;
    static final int GL_VERTEX_SHADER = 0x8B31;
    static final int GL_COMPILE_STATUS = 0x8B81;
    static final int GL_LINK_STATUS = 0x8B82;
    static final int GL_INFO_LOG_LENGTH = 0x8B84;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    static Callback wndProcCallback;

    // OpenGL 2.0 extension functions
    static Function glGenBuffers;
    static Function glBindBuffer;
    static Function glBufferData;
    static Function glCreateShader;
    static Function glShaderSource;
    static Function glCompileShader;
    static Function glCreateProgram;
    static Function glAttachShader;
    static Function glLinkProgram;
    static Function glUseProgram;
    static Function glGetAttribLocation;
    static Function glEnableVertexAttribArray;
    static Function glVertexAttribPointer;
    static Function glGetShaderiv;
    static Function glGetProgramiv;
    static Function glGetShaderInfoLog;
    static Function glGetProgramInfoLog;

    // Shader program variables
    static int[] vbo = new int[2];
    static int posAttrib;
    static int colAttrib;

    // Shader sources
    static final String vertexSource =
        "attribute vec3 position;                     \n" +
        "attribute vec3 color;                        \n" +
        "varying   vec4 vColor;                       \n" +
        "void main()                                  \n" +
        "{                                            \n" +
        "  vColor = vec4(color, 1.0);                 \n" +
        "  gl_Position = vec4(position, 1.0);         \n" +
        "}                                            \n";

    static final String fragmentSource =
        "varying   vec4 vColor;                       \n" +
        "void main()                                  \n" +
        "{                                            \n" +
        "  gl_FragColor = vColor;                     \n" +
        "}                                            \n";

    // GDI32 interface
    public interface Gdi32 extends StdCallLibrary {
        Gdi32 INSTANCE = Native.load("gdi32", Gdi32.class);

        int ChoosePixelFormat(Pointer hdc, PIXELFORMATDESCRIPTOR ppfd);
        boolean SetPixelFormat(Pointer hdc, int format, PIXELFORMATDESCRIPTOR ppfd);
        boolean SwapBuffers(Pointer hdc);
    }

    // OpenGL32 interface
    public interface OpenGL32 extends StdCallLibrary {
        OpenGL32 INSTANCE = Native.load("opengl32", OpenGL32.class);

        // WGL functions
        Pointer wglCreateContext(Pointer hdc);
        boolean wglMakeCurrent(Pointer hdc, Pointer hglrc);
        boolean wglDeleteContext(Pointer hglrc);
        Pointer wglGetProcAddress(String name);

        // OpenGL 1.0/1.1
        void glClearColor(float red, float green, float blue, float alpha);
        void glClear(int mask);
        void glDrawArrays(int mode, int first, int count);
    }

    // PIXELFORMATDESCRIPTOR structure
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

        // Create callback function
        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();

        // Register window class
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

        // Create window
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

        // Enable OpenGL
        long hDC = OS.GetDC(hWnd);
        Pointer hDCPtr = new Pointer(hDC);
        Pointer hRC = enableOpenGL(hDCPtr);

        // Get OpenGL 2.0 functions
        initOpenGLFunctions();

        // Initialize shaders
        initShader();

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
            } else {
                // Render
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

        // Cleanup
        disableOpenGL(hWnd, hDCPtr, hRC);
        OS.DestroyWindow(hWnd);
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);
    }

    // Window procedure
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

    static Function getGLFunction(String name) {
        Pointer addr = OpenGL32.INSTANCE.wglGetProcAddress(name);
        if (addr == null || Pointer.nativeValue(addr) == 0) {
            System.err.println("Failed to get function: " + name);
            return null;
        }
        System.out.println(name + ": 0x" + Long.toHexString(Pointer.nativeValue(addr)));
        return Function.getFunction(addr, Function.ALT_CONVENTION);
    }

    static void initOpenGLFunctions() {
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

    static void checkShaderCompileStatus(int shader, String type) {
        Memory status = new Memory(4);
        glGetShaderiv.invoke(void.class, new Object[]{ shader, GL_COMPILE_STATUS, status });
        int compiled = status.getInt(0);
        System.out.println(type + " shader compile status: " + compiled);
        
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

    static void checkProgramLinkStatus(int program) {
        Memory status = new Memory(4);
        glGetProgramiv.invoke(void.class, new Object[]{ program, GL_LINK_STATUS, status });
        int linked = status.getInt(0);
        System.out.println("Program link status: " + linked);
        
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

    static void initShader() {
        // Generate VBOs
        Memory vboMem = new Memory(4 * 2);  // 2 x GLuint
        glGenBuffers.invoke(void.class, new Object[]{ 2, vboMem });
        vbo[0] = vboMem.getInt(0);
        vbo[1] = vboMem.getInt(4);
        System.out.println("VBO: " + vbo[0] + ", " + vbo[1]);

        // Vertex data
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

        // Bind vertex buffer and transfer data
        Memory verticesMem = new Memory(vertices.length * 4);
        for (int i = 0; i < vertices.length; i++) {
            verticesMem.setFloat(i * 4, vertices[i]);
        }
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[0] });
        glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, (long)(vertices.length * 4), verticesMem, GL_STATIC_DRAW });

        // Bind color buffer and transfer data
        Memory colorsMem = new Memory(colors.length * 4);
        for (int i = 0; i < colors.length; i++) {
            colorsMem.setFloat(i * 4, colors[i]);
        }
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[1] });
        glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, (long)(colors.length * 4), colorsMem, GL_STATIC_DRAW });

        // Create and compile vertex shader
        int vertexShader = (Integer) glCreateShader.invoke(int.class, new Object[]{ GL_VERTEX_SHADER });
        System.out.println("vertexShader: " + vertexShader);
        
        Memory vertexSourcePtr = new Memory(Native.POINTER_SIZE);
        Memory vertexSourceMem = new Memory(vertexSource.length() + 1);
        vertexSourceMem.setString(0, vertexSource);
        vertexSourcePtr.setPointer(0, vertexSourceMem);
        glShaderSource.invoke(void.class, new Object[]{ vertexShader, 1, vertexSourcePtr, null });
        glCompileShader.invoke(void.class, new Object[]{ vertexShader });
        
        // Check vertex shader compile status
        checkShaderCompileStatus(vertexShader, "vertex");

        // Create and compile fragment shader
        int fragmentShader = (Integer) glCreateShader.invoke(int.class, new Object[]{ GL_FRAGMENT_SHADER });
        System.out.println("fragmentShader: " + fragmentShader);
        
        Memory fragmentSourcePtr = new Memory(Native.POINTER_SIZE);
        Memory fragmentSourceMem = new Memory(fragmentSource.length() + 1);
        fragmentSourceMem.setString(0, fragmentSource);
        fragmentSourcePtr.setPointer(0, fragmentSourceMem);
        glShaderSource.invoke(void.class, new Object[]{ fragmentShader, 1, fragmentSourcePtr, null });
        glCompileShader.invoke(void.class, new Object[]{ fragmentShader });
        
        // Check fragment shader compile status
        checkShaderCompileStatus(fragmentShader, "fragment");

        // Create and link shader program
        int shaderProgram = (Integer) glCreateProgram.invoke(int.class, new Object[]{});
        System.out.println("shaderProgram: " + shaderProgram);
        
        glAttachShader.invoke(void.class, new Object[]{ shaderProgram, vertexShader });
        glAttachShader.invoke(void.class, new Object[]{ shaderProgram, fragmentShader });
        glLinkProgram.invoke(void.class, new Object[]{ shaderProgram });
        
        // Check program link status
        checkProgramLinkStatus(shaderProgram);
        
        glUseProgram.invoke(void.class, new Object[]{ shaderProgram });

        // Get attribute locations
        Memory positionName = new Memory(16);
        positionName.setString(0, "position");
        posAttrib = (Integer) glGetAttribLocation.invoke(int.class, new Object[]{ shaderProgram, positionName });
        System.out.println("posAttrib: " + posAttrib);
        glEnableVertexAttribArray.invoke(void.class, new Object[]{ posAttrib });

        Memory colorName = new Memory(16);
        colorName.setString(0, "color");
        colAttrib = (Integer) glGetAttribLocation.invoke(int.class, new Object[]{ shaderProgram, colorName });
        System.out.println("colAttrib: " + colAttrib);
        glEnableVertexAttribArray.invoke(void.class, new Object[]{ colAttrib });
    }

    static void drawTriangle() {
        // Bind vertex buffer and set attribute pointer
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[0] });
        glVertexAttribPointer.invoke(void.class, new Object[]{ posAttrib, 3, GL_FLOAT, GL_FALSE, 0, Pointer.createConstant(0) });

        // Bind color buffer and set attribute pointer
        glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, vbo[1] });
        glVertexAttribPointer.invoke(void.class, new Object[]{ colAttrib, 3, GL_FLOAT, GL_FALSE, 0, Pointer.createConstant(0) });

        // Draw triangle
        OpenGL32.INSTANCE.glDrawArrays(GL_TRIANGLES, 0, 3);
    }
}