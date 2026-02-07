@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlin.experimental.ExperimentalNativeApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// Debug output function pointer
private typealias PFN_OutputDebugStringW = CFunction<(CValuesRef<UShortVar>?) -> Unit>
private lateinit var outputDebugStringW: CPointer<PFN_OutputDebugStringW>

private fun initDebugOutput() {
    val kernel32 = LoadLibraryW("kernel32.dll") ?: return
    val funcPtr = GetProcAddress(kernel32, "OutputDebugStringW") ?: return
    outputDebugStringW = funcPtr.reinterpret()
}

// Debug helper
private fun debugPrint(msg: String) {
    println(msg)  // Console output
    val debugMsg = msg + "\n"
    outputDebugStringW(debugMsg.wcstr)
}

private const val CLASS_NAME = "WindowClass"
private const val WINDOW_NAME = "Hello OpenGL 2.0 (Kotlin/Native)"

// ---- Minimal GL constants ----
private const val GL_COLOR_BUFFER_BIT: UInt = 0x00004000u
private const val GL_FLOAT: UInt = 0x1406u
private const val GL_FALSE: UByte = 0u

private const val GL_TRIANGLES: UInt = 0x0004u
private const val GL_ARRAY_BUFFER: UInt = 0x8892u
private const val GL_STATIC_DRAW: UInt = 0x88E4u

private const val GL_FRAGMENT_SHADER: UInt = 0x8B30u
private const val GL_VERTEX_SHADER: UInt = 0x8B31u

private const val GL_COMPILE_STATUS: UInt = 0x8B81u
private const val GL_INFO_LOG_LENGTH: UInt = 0x8B84u
private const val GL_LINK_STATUS: UInt = 0x8B82u

// ---- Function pointer types ----
private typealias PFN_glClearColor = CFunction<(Float, Float, Float, Float) -> Unit>
private typealias PFN_glClear = CFunction<(UInt) -> Unit>
private typealias PFN_glDrawArrays = CFunction<(UInt, Int, Int) -> Unit>

private typealias PFN_glGenBuffers = CFunction<(Int, CPointer<UIntVar>?) -> Unit>
private typealias PFN_glBindBuffer = CFunction<(UInt, UInt) -> Unit>
private typealias PFN_glBufferData = CFunction<(UInt, Long, COpaquePointer?, UInt) -> Unit>

private typealias PFN_glCreateShader = CFunction<(UInt) -> UInt>
/*
 * NOTE:
 * glShaderSource signature is:
 *   void glShaderSource(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
 *
 * In Kotlin/Native, representing "const GLchar* const*" cleanly can be annoying.
 * We accept it as COpaquePointer? and pass the address of a "char*" array.
 */
private typealias PFN_glShaderSource = CFunction<(UInt, Int, COpaquePointer?, CPointer<IntVar>?) -> Unit>
private typealias PFN_glCompileShader = CFunction<(UInt) -> Unit>
private typealias PFN_glGetShaderiv = CFunction<(UInt, UInt, CPointer<IntVar>?) -> Unit>
private typealias PFN_glGetShaderInfoLog = CFunction<(UInt, Int, CPointer<IntVar>?, CPointer<ByteVar>?) -> Unit>

private typealias PFN_glCreateProgram = CFunction<() -> UInt>
private typealias PFN_glAttachShader = CFunction<(UInt, UInt) -> Unit>
private typealias PFN_glLinkProgram = CFunction<(UInt) -> Unit>
private typealias PFN_glGetProgramiv = CFunction<(UInt, UInt, CPointer<IntVar>?) -> Unit>
private typealias PFN_glGetProgramInfoLog = CFunction<(UInt, Int, CPointer<IntVar>?, CPointer<ByteVar>?) -> Unit>
private typealias PFN_glUseProgram = CFunction<(UInt) -> Unit>

private typealias PFN_glGetAttribLocation = CFunction<(UInt, CPointer<ByteVar>?) -> Int>
private typealias PFN_glEnableVertexAttribArray = CFunction<(UInt) -> Unit>
private typealias PFN_glVertexAttribPointer = CFunction<(UInt, Int, UInt, UByte, Int, COpaquePointer?) -> Unit>

// ---- Loaded GL entry points ----
private lateinit var glClearColor: CPointer<PFN_glClearColor>
private lateinit var glClear: CPointer<PFN_glClear>
private lateinit var glDrawArrays: CPointer<PFN_glDrawArrays>

private lateinit var glGenBuffers: CPointer<PFN_glGenBuffers>
private lateinit var glBindBuffer: CPointer<PFN_glBindBuffer>
private lateinit var glBufferData: CPointer<PFN_glBufferData>

private lateinit var glCreateShader: CPointer<PFN_glCreateShader>
private lateinit var glShaderSource: CPointer<PFN_glShaderSource>
private lateinit var glCompileShader: CPointer<PFN_glCompileShader>
private lateinit var glGetShaderiv: CPointer<PFN_glGetShaderiv>
private lateinit var glGetShaderInfoLog: CPointer<PFN_glGetShaderInfoLog>

private lateinit var glCreateProgram: CPointer<PFN_glCreateProgram>
private lateinit var glAttachShader: CPointer<PFN_glAttachShader>
private lateinit var glLinkProgram: CPointer<PFN_glLinkProgram>
private lateinit var glGetProgramiv: CPointer<PFN_glGetProgramiv>
private lateinit var glGetProgramInfoLog: CPointer<PFN_glGetProgramInfoLog>
private lateinit var glUseProgram: CPointer<PFN_glUseProgram>

private lateinit var glGetAttribLocation: CPointer<PFN_glGetAttribLocation>
private lateinit var glEnableVertexAttribArray: CPointer<PFN_glEnableVertexAttribArray>
private lateinit var glVertexAttribPointer: CPointer<PFN_glVertexAttribPointer>

// ---- Shader sources ----
private val vertexSource = """
attribute vec3 position;
attribute vec3 color;
varying vec4 vColor;
void main()
{
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}
""".trimIndent()

private val fragmentSource = """
varying vec4 vColor;
void main()
{
  gl_FragColor = vColor;
}
""".trimIndent()

// ---- Global GL objects ----
private val vbo = UIntArray(2)
private var posAttrib: Int = -1
private var colAttrib: Int = -1
private var shaderProgram: UInt = 0u

// ---- Win32 window procedure ----
private fun wndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE -> { PostQuitMessage(0); 0L }
        WM_DESTROY -> 0L
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

// ---- OpenGL context creation ----
private fun enableOpenGL(hdc: HDC?): HGLRC? = memScoped {
    debugPrint("[enableOpenGL] Starting OpenGL context creation...")
    
    val pfd = alloc<PIXELFORMATDESCRIPTOR>().apply {
        nSize = sizeOf<PIXELFORMATDESCRIPTOR>().toUShort()
        nVersion = 1u
        dwFlags = (PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER).toUInt()
        iPixelType = PFD_TYPE_RGBA.toUByte()
        cColorBits = 24u
        cDepthBits = 16u
        iLayerType = PFD_MAIN_PLANE.toUByte()
    }

    val fmt = ChoosePixelFormat(hdc, pfd.ptr)
    if (fmt == 0) {
        debugPrint("[enableOpenGL] ERROR: ChoosePixelFormat failed")
        return@memScoped null
    }
    debugPrint("[enableOpenGL] ChoosePixelFormat succeeded: fmt=$fmt")
    
    if (SetPixelFormat(hdc, fmt, pfd.ptr) == 0) {
        debugPrint("[enableOpenGL] ERROR: SetPixelFormat failed")
        return@memScoped null
    }
    debugPrint("[enableOpenGL] SetPixelFormat succeeded")

    val hrc = wglCreateContext(hdc)
    if (hrc == null) {
        debugPrint("[enableOpenGL] ERROR: wglCreateContext failed")
        return@memScoped null
    }
    debugPrint("[enableOpenGL] wglCreateContext succeeded")
    
    if (wglMakeCurrent(hdc, hrc) == 0) {
        debugPrint("[enableOpenGL] ERROR: wglMakeCurrent failed")
        wglDeleteContext(hrc)
        return@memScoped null
    }
    debugPrint("[enableOpenGL] wglMakeCurrent succeeded - OpenGL context is now active")
    hrc
}

private fun disableOpenGL(hWnd: HWND?, hdc: HDC?, hrc: HGLRC?) {
    debugPrint("[disableOpenGL] Cleaning up OpenGL context...")
    wglMakeCurrent(null, null)
    if (hrc != null) {
        wglDeleteContext(hrc)
        debugPrint("[disableOpenGL] OpenGL context deleted")
    }
    if (hWnd != null && hdc != null) {
        ReleaseDC(hWnd, hdc)
        debugPrint("[disableOpenGL] Device context released")
    }
}

// ---- Load GL functions via wglGetProcAddress (with opengl32 fallback) ----
private fun loadGLFunctions() {
    debugPrint("[loadGLFunctions] Starting to load OpenGL function pointers...")
    
    fun <T : CFunction<*>> load(name: String): CPointer<T> {
        val p1 = wglGetProcAddress(name)
        if (p1 != null) {
            debugPrint("[loadGLFunctions] Loaded '$name' via wglGetProcAddress")
            return p1.reinterpret()
        }

        val dll = LoadLibraryW("opengl32.dll") ?: error("LoadLibraryW(opengl32.dll) failed")
        val p2 = GetProcAddress(dll, name) ?: error("GetProcAddress failed: $name")
        debugPrint("[loadGLFunctions] Loaded '$name' via GetProcAddress(opengl32.dll)")
        return p2.reinterpret()
    }

    glClearColor = load("glClearColor")
    glClear = load("glClear")
    glDrawArrays = load("glDrawArrays")

    glGenBuffers = load("glGenBuffers")
    glBindBuffer = load("glBindBuffer")
    glBufferData = load("glBufferData")

    glCreateShader = load("glCreateShader")
    glShaderSource = load("glShaderSource")
    glCompileShader = load("glCompileShader")
    glGetShaderiv = load("glGetShaderiv")
    glGetShaderInfoLog = load("glGetShaderInfoLog")

    glCreateProgram = load("glCreateProgram")
    glAttachShader = load("glAttachShader")
    glLinkProgram = load("glLinkProgram")
    glGetProgramiv = load("glGetProgramiv")
    glGetProgramInfoLog = load("glGetProgramInfoLog")
    glUseProgram = load("glUseProgram")

    glGetAttribLocation = load("glGetAttribLocation")
    glEnableVertexAttribArray = load("glEnableVertexAttribArray")
    glVertexAttribPointer = load("glVertexAttribPointer")
    
    debugPrint("[loadGLFunctions] All OpenGL functions loaded successfully")
}

// ---- Helper: set shader source (count=1) ----
private fun setShaderSource(shader: UInt, srcText: String) = memScoped {
    val src = srcText.cstr

    // "const GLchar* const* string" -> pointer to an array of (char*)
    val strings = allocArray<CPointerVar<ByteVar>>(1)
    strings[0] = src.ptr

    // IMPORTANT:
    // Do NOT use reinterpret<CPointer<ByteVar>>() here (it doesn't satisfy CPointed bounds).
    // Just pass the address as COpaquePointer?.
    val pp: COpaquePointer? = strings as COpaquePointer?

    glShaderSource(shader, 1, pp, null)
}

// ---- Helper: check shader compilation status ----
private fun checkShaderCompilation(shader: UInt, shaderType: String) = memScoped {
    val status = alloc<IntVar>()
    glGetShaderiv(shader, GL_COMPILE_STATUS, status.ptr)
    
    if (status.value != 1) {  // GL_TRUE = 1
        debugPrint("[checkShaderCompilation] ERROR: $shaderType compilation failed!")
        
        val logLength = alloc<IntVar>()
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, logLength.ptr)
        
        if (logLength.value > 0) {
            val logBuffer = allocArray<ByteVar>(logLength.value)
            glGetShaderInfoLog(shader, logLength.value, null, logBuffer)
            val logString = logBuffer.toKString()
            debugPrint("[checkShaderCompilation] $shaderType error log:\n$logString")
        }
    } else {
        debugPrint("[checkShaderCompilation] $shaderType compiled successfully")
    }
}

// ---- Helper: check program link status ----
private fun checkProgramLink(program: UInt) = memScoped {
    val status = alloc<IntVar>()
    glGetProgramiv(program, GL_LINK_STATUS, status.ptr)
    
    if (status.value != 1) {  // GL_TRUE = 1
        debugPrint("[checkProgramLink] ERROR: Program linking failed!")
        
        val logLength = alloc<IntVar>()
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, logLength.ptr)
        
        if (logLength.value > 0) {
            val logBuffer = allocArray<ByteVar>(logLength.value)
            glGetProgramInfoLog(program, logLength.value, null, logBuffer)
            val logString = logBuffer.toKString()
            debugPrint("[checkProgramLink] Program error log:\n$logString")
        }
    } else {
        debugPrint("[checkProgramLink] Program linked successfully")
    }
}

// ---- Initialize shader + VBOs ----
private fun initShaderAndBuffers() = memScoped {
    debugPrint("[initShaderAndBuffers] Starting shader and buffer initialization...")
    
    // VBO ids
    val tmp = allocArray<UIntVar>(2)
    glGenBuffers(2, tmp)
    vbo[0] = tmp[0]
    vbo[1] = tmp[1]
    debugPrint("[initShaderAndBuffers] Created VBOs: position=${vbo[0]}, color=${vbo[1]}")

    val vertices = floatArrayOf(
        0.0f,  0.5f, 0.0f,
        0.5f, -0.5f, 0.0f,
       -0.5f, -0.5f, 0.0f
    )
    val colors = floatArrayOf(
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f
    )

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    vertices.usePinned { pin ->
        val sizeBytes = (vertices.size * sizeOf<FloatVar>()).toLong()
        glBufferData(GL_ARRAY_BUFFER, sizeBytes, pin.addressOf(0).reinterpret(), GL_STATIC_DRAW)
    }
    debugPrint("[initShaderAndBuffers] Uploaded vertex data to VBO")

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    colors.usePinned { pin ->
        val sizeBytes = (colors.size * sizeOf<FloatVar>()).toLong()
        glBufferData(GL_ARRAY_BUFFER, sizeBytes, pin.addressOf(0).reinterpret(), GL_STATIC_DRAW)
    }
    debugPrint("[initShaderAndBuffers] Uploaded color data to VBO")

    // Compile shaders
    debugPrint("[initShaderAndBuffers] Creating and compiling vertex shader...")
    val vs = glCreateShader(GL_VERTEX_SHADER)
    debugPrint("[initShaderAndBuffers] Vertex shader ID: $vs")
    setShaderSource(vs, vertexSource)
    glCompileShader(vs)
    checkShaderCompilation(vs, "Vertex Shader")

    debugPrint("[initShaderAndBuffers] Creating and compiling fragment shader...")
    val fs = glCreateShader(GL_FRAGMENT_SHADER)
    debugPrint("[initShaderAndBuffers] Fragment shader ID: $fs")
    setShaderSource(fs, fragmentSource)
    glCompileShader(fs)
    checkShaderCompilation(fs, "Fragment Shader")

    // Link program
    debugPrint("[initShaderAndBuffers] Creating and linking shader program...")
    shaderProgram = glCreateProgram()
    debugPrint("[initShaderAndBuffers] Shader program ID: $shaderProgram")
    glAttachShader(shaderProgram, vs)
    glAttachShader(shaderProgram, fs)
    glLinkProgram(shaderProgram)
    checkProgramLink(shaderProgram)
    glUseProgram(shaderProgram)

    // Attributes
    debugPrint("[initShaderAndBuffers] Getting attribute locations...")
    posAttrib = glGetAttribLocation(shaderProgram, "position".cstr.ptr)
    debugPrint("[initShaderAndBuffers] position attribute location: $posAttrib")
    glEnableVertexAttribArray(posAttrib.toUInt())

    colAttrib = glGetAttribLocation(shaderProgram, "color".cstr.ptr)
    debugPrint("[initShaderAndBuffers] color attribute location: $colAttrib")
    glEnableVertexAttribArray(colAttrib.toUInt())
    
    debugPrint("[initShaderAndBuffers] Shader and buffer initialization completed successfully")
}

private fun drawTriangle() {
    glUseProgram(shaderProgram)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glVertexAttribPointer(posAttrib.toUInt(), 3, GL_FLOAT, GL_FALSE, 0, null)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glVertexAttribPointer(colAttrib.toUInt(), 3, GL_FLOAT, GL_FALSE, 0, null)

    glDrawArrays(GL_TRIANGLES, 0, 3)
}

fun main() {
    initDebugOutput()
    debugPrint("[main] ========== Starting Kotlin/Native OpenGL 2.0 Triangle Sample ==========")
    debugPrint("[main] Debug output initialized")
    
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val classNameW = CLASS_NAME.wcstr.ptr

        debugPrint("[main] Registering window class...")
        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = CS_OWNDC.toUInt()
            lpfnWndProc = staticCFunction(::wndProc)
            cbClsExtra = 0
            cbWndExtra = 0
            this.hInstance = hInstance
            hIcon = LoadIconW(null, IDI_APPLICATION)
            hCursor = LoadCursorW(null, IDC_ARROW)
            hbrBackground = GetSysColorBrush(COLOR_WINDOW)
            lpszMenuName = null
            lpszClassName = classNameW
            hIconSm = LoadIconW(null, IDI_APPLICATION)
        }

        if (RegisterClassExW(wcex.ptr) == 0.toUShort()) {
            debugPrint("[main] ERROR: RegisterClassExW failed")
            MessageBoxW(null, "RegisterClassExW failed", "Error", MB_OK.toUInt())
            return
        }
        debugPrint("[main] Window class registered successfully")

        debugPrint("[main] Creating window...")
        val hWnd = CreateWindowExW(
            0u,
            CLASS_NAME,
            WINDOW_NAME,
            WS_OVERLAPPEDWINDOW.toUInt(),
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            null,
            null,
            hInstance,
            null
        ) ?: run {
            debugPrint("[main] ERROR: CreateWindowExW failed")
            MessageBoxW(null, "CreateWindowExW failed", "Error", MB_OK.toUInt())
            return
        }
        debugPrint("[main] Window created successfully")

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        debugPrint("[main] Getting device context...")
        val hdc = GetDC(hWnd) ?: run {
            debugPrint("[main] ERROR: GetDC failed")
            MessageBoxW(null, "GetDC failed", "Error", MB_OK.toUInt())
            return
        }
        debugPrint("[main] Device context obtained")

        debugPrint("[main] Enabling OpenGL...")
        val hrc = enableOpenGL(hdc) ?: run {
            debugPrint("[main] ERROR: enableOpenGL failed")
            MessageBoxW(null, "EnableOpenGL failed", "Error", MB_OK.toUInt())
            disableOpenGL(hWnd, hdc, null)
            return
        }
        debugPrint("[main] OpenGL enabled successfully")

        // Must load after OpenGL context is current
        debugPrint("[main] Loading OpenGL functions...")
        loadGLFunctions()
        
        debugPrint("[main] Initializing shader and buffers...")
        initShaderAndBuffers()
        
        debugPrint("[main] Entering message loop...")
        val msg = alloc<MSG>()
        var quit = false
        var frameCount = 0

        while (!quit) {
            if (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE.toUInt()) != 0) {
                if (msg.message.toInt() == WM_QUIT) {
                    quit = true
                } else {
                    TranslateMessage(msg.ptr)
                    DispatchMessageW(msg.ptr)
                }
            } else {
                glClearColor(0f, 0f, 0f, 0f)
                glClear(GL_COLOR_BUFFER_BIT)

                drawTriangle()
                
                frameCount++
                if (frameCount % 100 == 0) {
                    debugPrint("[main] Rendered frame $frameCount")
                }

                SwapBuffers(hdc)
                Sleep(1u)
            }
        }

        debugPrint("[main] Message loop exited. Cleaning up...")
        disableOpenGL(hWnd, hdc, hrc)
        DestroyWindow(hWnd)
        debugPrint("[main] ========== Application terminated successfully ==========")
    }
}
