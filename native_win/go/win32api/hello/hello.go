package main

import (
    "syscall"
    "unsafe"
)

var (
    user32, _          = syscall.LoadLibrary("user32.dll")
    procMessageBoxW, _ = syscall.GetProcAddress(user32, "MessageBoxW")
)

func MessageBox(hwnd uintptr, text string, caption string, style uintptr) (int32) {
    ret, _, _ := syscall.Syscall6(
        uintptr(procMessageBoxW),
        4,
        hwnd,
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(text))),
        uintptr(unsafe.Pointer(syscall.StringToUTF16Ptr(caption))),
        style,
        0,
        0 )
    return int32(ret)
}

func main() {
    defer syscall.FreeLibrary(user32)
    MessageBox( 0, "Hello, Win32 API(Go) World!", "Hello, World!", 0 )
}
