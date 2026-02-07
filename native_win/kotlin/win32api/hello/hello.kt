import platform.windows.*

fun main() {
    MessageBoxW(
        hWnd = null,
        lpText = "Hello, Win32 API(Kotlin/Native) World!",
        lpCaption = "Hello, World",
        uType = MB_OK.toUInt()
    )
}
