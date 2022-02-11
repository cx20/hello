import ctypes

user32 = ctypes.windll.user32
user32.MessageBoxA( 0, b"Hello, Win32 API(Python) World!", b"Hello, World!", 0 )
