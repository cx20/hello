const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;
const HWND = windows.HWND;
const UINT = windows.UINT;
const LPCWSTR = windows.LPCWSTR;

extern "user32" fn MessageBoxW(
    hWnd: ?HWND,
    lpText: LPCWSTR,
    lpCaption: LPCWSTR,
    uType: UINT,
) callconv(WINAPI) c_int;

pub fn main() !void {
    const message = std.unicode.utf8ToUtf16LeStringLiteral("Hello, Win32 API(Zig) World!");
    const caption = std.unicode.utf8ToUtf16LeStringLiteral("Hello, World!");

    _ = MessageBoxW(
        null,
        message,
        caption,
        0,
    );
}