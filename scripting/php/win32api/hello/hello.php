<?php
declare(strict_types=1);

// ------------------------------------------------------------
// Minimal Win32 API call from PHP via FFI:
// - Calls MessageBoxW (Unicode) from user32.dll
// - Uses a safe UTF-16 buffer allocation strategy to avoid AV (0xC0000005)
// ------------------------------------------------------------

// Declare the Win32 function signature we want to call.
$user32 = FFI::cdef('
    int MessageBoxW(void* hWnd, const uint16_t* lpText, const uint16_t* lpCaption, unsigned int uType);
', 'user32.dll');

/**
 * Create a NUL-terminated UTF-16LE buffer (uint16_t[]) from a UTF-8 PHP string.
 *
 * Why this approach:
 * - MessageBoxW expects a pointer to UTF-16 code units (WCHAR / uint16_t).
 * - Allocating a real uint16_t[] buffer avoids risky casts from char[] to uint16_t*,
 *   which can cause access violations in some cases.
 * - Returning the CData buffer keeps its lifetime managed by PHP until it goes out of scope.
 */
function wbuf(string $s): FFI\CData
{
    // Convert UTF-8 -> UTF-16LE and append a wide NUL terminator (2 bytes).
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";

    // Number of UTF-16 code units in the buffer (bytes / 2).
    $len16 = intdiv(strlen($bytes), 2);

    // Allocate a uint16_t[] buffer (not owning any external memory).
    $buf = FFI::new("uint16_t[$len16]", false);

    // Copy the raw bytes into the uint16_t[] buffer.
    FFI::memcpy($buf, $bytes, strlen($bytes));

    // This CData is usable where a "const uint16_t*" is expected.
    return $buf;
}

// Keep buffers in variables so their lifetime is clearly maintained
// across the FFI call.
$text = wbuf("Hello, Win32 (PHP FFI) World!");
$cap  = wbuf("Hello");

// uType = 0 => MB_OK
$ret = $user32->MessageBoxW(null, $text, $cap, 0);

// Print return value for debugging.
// (The message box return value is typically IDOK=1 for MB_OK.)
echo "MessageBoxW ret={$ret}\n";
