@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

private const val CLASS_NAME = "helloWindow"
private const val WINDOW_NAME = "Hello, World!"
private const val DRAW_TEXT = "Hello, Win32 GUI World!"

private fun WndProc(hWnd: HWND?, uMsg: UINT, wParam: WPARAM, lParam: LPARAM): LRESULT {
    return when (uMsg.toInt()) {
        WM_PAINT -> {
            memScoped {
                val ps = alloc<PAINTSTRUCT>()
                val hdc = BeginPaint(hWnd, ps.ptr)
                TextOutW(hdc, 0, 0, DRAW_TEXT, DRAW_TEXT.length)
                EndPaint(hWnd, ps.ptr)
            }
            0L
        }
        WM_DESTROY -> {
            PostQuitMessage(0)
            0L
        }
        else -> DefWindowProcW(hWnd, uMsg, wParam, lParam)
    }
}

fun main() {
    memScoped {
        val hInstance = GetModuleHandleW(null)

        val classNameW = CLASS_NAME.wcstr.ptr

        val wcex = alloc<WNDCLASSEXW>().apply {
            cbSize = sizeOf<WNDCLASSEXW>().toUInt()
            style = (CS_HREDRAW or CS_VREDRAW).toUInt()
            lpfnWndProc = staticCFunction(::WndProc)
            cbClsExtra = 0
            cbWndExtra = 0
            this.hInstance = hInstance
            hCursor = LoadCursorW(null, IDC_ARROW)
            hbrBackground = GetSysColorBrush(COLOR_WINDOW)
            lpszMenuName = null
            lpszClassName = classNameW
            hIcon = null
            hIconSm = null
        }

        if (RegisterClassExW(wcex.ptr) == 0.toUShort()) {
            MessageBoxW(null, "RegisterClassExW failed", "Error", MB_OK.toUInt())
            return
        }

        val hWnd = CreateWindowExW(
            dwExStyle = 0u,
            lpClassName = CLASS_NAME,
            lpWindowName = WINDOW_NAME,
            dwStyle = WS_OVERLAPPEDWINDOW.toUInt(),
            X = CW_USEDEFAULT,
            Y = CW_USEDEFAULT,
            nWidth = 640,
            nHeight = 480,
            hWndParent = null,
            hMenu = null,
            hInstance = hInstance,
            lpParam = null
        )

        if (hWnd == null) {
            MessageBoxW(null, "CreateWindowExW failed", "Error", MB_OK.toUInt())
            return
        }

        ShowWindow(hWnd, SW_SHOWDEFAULT)
        UpdateWindow(hWnd)

        val msg = alloc<MSG>()
        while (GetMessageW(msg.ptr, null, 0u, 0u) > 0) {
            TranslateMessage(msg.ptr)
            DispatchMessageW(msg.ptr)
        }
    }
}
