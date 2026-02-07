@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

private const val CLASS_NAME = "WindowClass"
private const val WINDOW_NAME = "Hello, World!"

// OpenGL constants (minimal)
private const val GL_TRIANGLES: UInt = 0x0004u
private const val GL_COLOR_BUFFER_BIT: UInt = 0x00004000u

// Function pointer types
private typealias PFN_glBegin = CFunction<(UInt) -> Unit>
private typealias PFN_glEnd = CFunction<() -> Unit>
private typealias PFN_glColor3f = CFunction<(Float, Float, Float) -> Unit>
private typealias PFN_glVertex2f = CFunction<(Float, Float) -> Unit>
private typealias PFN_glClearColor = CFunction<(Float, Float, Float, Float) -> Unit>
private typealias PFN_glClear = CFunction<(UInt) -> Unit>

// Resolved OpenGL entry points
private lateinit var glBegin: CPointer<PFN_glBegin>
private lateinit var glEnd: CPointer<PFN_glEnd>
private lateinit var glColor3f: CPointer<PFN_glColor3f>
private lateinit var glVertex2f: CPointer<PFN_glVertex2f>
private lateinit var glClearColor: CPointer<PFN_glClearColor>
private lateinit var glClear: CPointer<PFN_glClear>

private fun WndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE -> { PostQuitMessage(0); 0L }
        WM_DESTROY -> 0L
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

private fun enableOpenGL(hdc: HDC?): HGLRC? = memScoped {
    val pfd = alloc<PIXELFORMATDESCRIPTOR>()
    pfd.nSize = sizeOf<PIXELFORMATDESCRIPTOR>().toUShort()
    pfd.nVersion = 1u
    pfd.dwFlags = (PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER).toUInt()
    pfd.iPixelType = PFD_TYPE_RGBA.toUByte()
    pfd.cColorBits = 24u
    pfd.cDepthBits = 16u
    pfd.iLayerType = PFD_MAIN_PLANE.toUByte()

    val iFormat = ChoosePixelFormat(hdc, pfd.ptr)
    if (iFormat == 0) return null
    if (SetPixelFormat(hdc, iFormat, pfd.ptr) == 0) return null

    val hrc = wglCreateContext(hdc) ?: return null
    if (wglMakeCurrent(hdc, hrc) == 0) {
        wglDeleteContext(hrc)
        return null
    }
    hrc
}

private fun disableOpenGL(hWnd: HWND?, hdc: HDC?, hrc: HGLRC?) {
    wglMakeCurrent(null, null)
    if (hrc != null) wglDeleteContext(hrc)
    if (hWnd != null && hdc != null) ReleaseDC(hWnd, hdc)
}

private fun loadGLFunctions() {
    val dll = LoadLibraryW("opengl32.dll")
        ?: error("LoadLibraryW(opengl32.dll) failed")

    fun <T : CFunction<*>> proc(name: String): CPointer<T> {
        val p = GetProcAddress(dll, name)
            ?: error("GetProcAddress failed: $name")
        return p.reinterpret()
    }

    glBegin = proc("glBegin")
    glEnd = proc("glEnd")
    glColor3f = proc("glColor3f")
    glVertex2f = proc("glVertex2f")
    glClearColor = proc("glClearColor")
    glClear = proc("glClear")
}

private fun drawTriangle() {
    glBegin(GL_TRIANGLES)
    glColor3f(1f, 0f, 0f); glVertex2f( 0.0f,  0.50f)
    glColor3f(0f, 1f, 0f); glVertex2f( 0.5f, -0.50f)
    glColor3f(0f, 0f, 1f); glVertex2f(-0.5f, -0.50f)
    glEnd()
}

fun main() {
    memScoped {
        val hInstance = GetModuleHandleW(null)
        val classNameW = CLASS_NAME.wcstr.ptr

        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = CS_OWNDC.toUInt()
            lpfnWndProc = staticCFunction(::WndProc)
            cbClsExtra = 0
            cbWndExtra = 0
            this.hInstance = hInstance
            hIcon = LoadIconW(null, IDI_APPLICATION)
            hCursor = LoadCursorW(null, IDC_ARROW)
            hbrBackground = GetSysColorBrush(COLOR_WINDOW) // safe (no casts)
            lpszMenuName = null
            lpszClassName = classNameW
            hIconSm = LoadIconW(null, IDI_APPLICATION)
        }

        if (RegisterClassExW(wcex.ptr) == 0.toUShort()) {
            MessageBoxW(null, "RegisterClassExW failed", "Error", MB_OK.toUInt())
            return
        }

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
        )

        if (hWnd == null) {
            MessageBoxW(null, "CreateWindowExW failed", "Error", MB_OK.toUInt())
            return
        }

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        val hdc = GetDC(hWnd)
        if (hdc == null) {
            MessageBoxW(null, "GetDC failed", "Error", MB_OK.toUInt())
            return
        }

        val hrc = enableOpenGL(hdc)
        if (hrc == null) {
            MessageBoxW(null, "EnableOpenGL failed", "Error", MB_OK.toUInt())
            disableOpenGL(hWnd, hdc, null)
            return
        }

        // Must load GL function pointers AFTER the context is current.
        loadGLFunctions()

        val msg = alloc<MSG>()
        var quit = false

        while (!quit) {
            if (PeekMessageW(msg.ptr, null, 0u, 0u, PM_REMOVE.toUInt()) != 0) {
                if (msg.message.toInt() == WM_QUIT) quit = true
                else {
                    TranslateMessage(msg.ptr)
                    DispatchMessageW(msg.ptr)
                }
            } else {
                glClearColor(0f, 0f, 0f, 0f)
                glClear(GL_COLOR_BUFFER_BIT)

                drawTriangle()

                SwapBuffers(hdc)
                Sleep(1u)
            }
        }

        disableOpenGL(hWnd, hdc, hrc)
        DestroyWindow(hWnd)
    }
}

