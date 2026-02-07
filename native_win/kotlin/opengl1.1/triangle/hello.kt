@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

private const val CLASS_NAME = "WindowClass"
private const val WINDOW_NAME = "Hello, World!"

// ---- Minimal OpenGL 1.1 constants (enough for this sample) ----
private const val GL_COLOR_BUFFER_BIT: UInt = 0x00004000u
private const val GL_FLOAT: UInt = 0x1406u

private const val GL_VERTEX_ARRAY: UInt = 0x8074u
private const val GL_COLOR_ARRAY: UInt = 0x8076u

private const val GL_TRIANGLE_STRIP: UInt = 0x0005u

// ---- Function pointer types ----
private typealias PFN_glClearColor = CFunction<(Float, Float, Float, Float) -> Unit>
private typealias PFN_glClear = CFunction<(UInt) -> Unit>

private typealias PFN_glEnableClientState = CFunction<(UInt) -> Unit>
private typealias PFN_glDisableClientState = CFunction<(UInt) -> Unit>

private typealias PFN_glColorPointer = CFunction<(Int, UInt, Int, COpaquePointer?) -> Unit>
private typealias PFN_glVertexPointer = CFunction<(Int, UInt, Int, COpaquePointer?) -> Unit>

private typealias PFN_glDrawArrays = CFunction<(UInt, Int, Int) -> Unit>

// ---- Resolved OpenGL entry points ----
private lateinit var glClearColor: CPointer<PFN_glClearColor>
private lateinit var glClear: CPointer<PFN_glClear>

private lateinit var glEnableClientState: CPointer<PFN_glEnableClientState>
private lateinit var glDisableClientState: CPointer<PFN_glDisableClientState>

private lateinit var glColorPointer: CPointer<PFN_glColorPointer>
private lateinit var glVertexPointer: CPointer<PFN_glVertexPointer>

private lateinit var glDrawArrays: CPointer<PFN_glDrawArrays>

// ---- Win32 window proc ----
private fun WndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_CLOSE -> { PostQuitMessage(0); 0L }
        WM_DESTROY -> 0L
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

// ---- OpenGL context ----
private fun enableOpenGL(hdc: HDC?): HGLRC? = memScoped {
    val pfd = alloc<PIXELFORMATDESCRIPTOR>().apply {
        nSize = sizeOf<PIXELFORMATDESCRIPTOR>().toUShort()
        nVersion = 1u
        dwFlags = (PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER).toUInt()
        iPixelType = PFD_TYPE_RGBA.toUByte()
        cColorBits = 24u
        cDepthBits = 16u
        iLayerType = PFD_MAIN_PLANE.toUByte()
    }

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

// ---- Load OpenGL 1.1 symbols from opengl32.dll ----
// IMPORTANT: Call this after making a context current.
private fun loadGL11() {
    val dll = LoadLibraryW("opengl32.dll") ?: error("LoadLibraryW(opengl32.dll) failed")

    fun <T : CFunction<*>> proc(name: String): CPointer<T> {
        val p = GetProcAddress(dll, name) ?: error("GetProcAddress failed: $name")
        return p.reinterpret()
    }

    glClearColor = proc("glClearColor")
    glClear = proc("glClear")

    glEnableClientState = proc("glEnableClientState")
    glDisableClientState = proc("glDisableClientState")

    glColorPointer = proc("glColorPointer")
    glVertexPointer = proc("glVertexPointer")

    glDrawArrays = proc("glDrawArrays")
}

// ---- OpenGL 1.1 draw using client-side arrays ----
private fun drawTriangle11() = memScoped {
    // These arrays must stay alive while OpenGL reads them.
    // We keep them inside this memScoped block until after glDrawArrays returns.
    val colors = allocArray<FloatVar>(9)
    colors[0] = 1f; colors[1] = 0f; colors[2] = 0f
    colors[3] = 0f; colors[4] = 1f; colors[5] = 0f
    colors[6] = 0f; colors[7] = 0f; colors[8] = 1f

    val vertices = allocArray<FloatVar>(6)
    vertices[0] = 0.0f;  vertices[1] = 0.5f
    vertices[2] = 0.5f;  vertices[3] = -0.5f
    vertices[4] = -0.5f; vertices[5] = -0.5f

    glEnableClientState(GL_COLOR_ARRAY)
    glEnableClientState(GL_VERTEX_ARRAY)

    glColorPointer(3, GL_FLOAT, 0, colors.reinterpret())
    glVertexPointer(2, GL_FLOAT, 0, vertices.reinterpret())

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3)

    glDisableClientState(GL_VERTEX_ARRAY)
    glDisableClientState(GL_COLOR_ARRAY)
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
            hbrBackground = GetSysColorBrush(COLOR_WINDOW) // safe
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
        ) ?: run {
            MessageBoxW(null, "CreateWindowExW failed", "Error", MB_OK.toUInt())
            return
        }

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        val hdc = GetDC(hWnd) ?: run {
            MessageBoxW(null, "GetDC failed", "Error", MB_OK.toUInt())
            return
        }

        val hrc = enableOpenGL(hdc) ?: run {
            MessageBoxW(null, "EnableOpenGL failed", "Error", MB_OK.toUInt())
            disableOpenGL(hWnd, hdc, null)
            return
        }

        // Must load GL symbols after context is current.
        loadGL11()

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

                drawTriangle11()

                SwapBuffers(hdc)
                Sleep(1u)
            }
        }

        disableOpenGL(hWnd, hdc, hrc)
        DestroyWindow(hWnd)
    }
}
