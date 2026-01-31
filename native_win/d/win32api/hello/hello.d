import core.runtime;
import core.sys.windows.windows;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    MessageBoxA( null, "Hello, Win32 API(D) World!", "Hello, World!", MB_OK );
    return 0;
}
