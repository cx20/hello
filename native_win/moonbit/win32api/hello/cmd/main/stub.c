#include <windows.h>

#pragma comment(lib, "user32.lib")

void show_message(void) {
    MessageBoxW(NULL, L"Hello, Win32 API World!", L"Hello, World!", MB_OK);
}
