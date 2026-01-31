import win32api, win32con, win32gui
from ctypes import *

TextOut = windll.gdi32.TextOutA

class HelloWindow:

    def __init__(self):
        win32gui.InitCommonControls()
        self.hinst = win32api.GetModuleHandle(None)
        className = 'helloWorld'
        message_map = {
            win32con.WM_PAINT:   self.OnPaint,
            win32con.WM_DESTROY: self.OnDestroy,
        }
        wc = win32gui.WNDCLASS()
        wc.style         = win32con.CS_HREDRAW | win32con.CS_VREDRAW
        wc.lpfnWndProc   = message_map
        wc.lpszClassName = className
        win32gui.RegisterClass(wc)
        style = win32con.WS_OVERLAPPEDWINDOW
        self.hwnd = win32gui.CreateWindow(
            className,
            'Hello, World!',
            style,
            win32con.CW_USEDEFAULT,
            win32con.CW_USEDEFAULT,
            640,
            480,
            0,
            0,
            self.hinst,
            None
        )
        win32gui.UpdateWindow(self.hwnd)
        win32gui.ShowWindow(self.hwnd, win32con.SW_SHOW)

    def OnPaint(self, hwnd, message, wparam, lparam):
        hdc, ps = win32gui.BeginPaint(hwnd)
        strMessage = b"Hello, Win32 GUI(Python) World!"
        TextOut(hdc, 0, 0, strMessage, len(strMessage))
        win32gui.EndPaint(hwnd, ps)
        return 0

    def OnDestroy(self, hwnd, message, wparam, lparam):
        win32gui.PostQuitMessage(0)
        return 0

w = HelloWindow()
win32gui.PumpMessages()
