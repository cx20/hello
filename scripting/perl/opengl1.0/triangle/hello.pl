use strict;
use warnings;
use Win32::API;
use Encode qw(encode);

print "=== Perl OpenGL 1.0 Triangle (Win32 API) ===\n\n";

# ============================================================
# Constants
# ============================================================
use constant {
    # Window styles
    CS_OWNDC            => 0x0020,
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    CW_USEDEFAULT       => 0x80000000,
    SW_SHOW             => 5,
    
    # Messages
    WM_DESTROY => 0x0002,
    WM_CLOSE   => 0x0010,
    WM_QUIT    => 0x0012,
    PM_REMOVE  => 0x0001,
    
    # IDC/IDI
    IDI_APPLICATION => 32512,
    IDC_ARROW       => 32512,
    
    # Pixel Format Descriptor
    PFD_TYPE_RGBA       => 0,
    PFD_MAIN_PLANE      => 0,
    PFD_DRAW_TO_WINDOW  => 0x00000004,
    PFD_SUPPORT_OPENGL  => 0x00000020,
    PFD_DOUBLEBUFFER    => 0x00000001,
    
    # OpenGL 1.0
    GL_COLOR_BUFFER_BIT => 0x00004000,
    GL_TRIANGLES        => 0x0004,
};

# ============================================================
# Import Windows API functions
# ============================================================
my $GetModuleHandleW = Win32::API->new('kernel32', 'GetModuleHandleW', 'P', 'N');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $DefWindowProcW = Win32::API->new('user32', 'DefWindowProcW', 'NNNN', 'N');
my $LoadIconW = Win32::API->new('user32', 'LoadIconW', 'NN', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $PostQuitMessage = Win32::API->new('user32', 'PostQuitMessage', 'N', 'V');
my $DestroyWindow = Win32::API->new('user32', 'DestroyWindow', 'N', 'I');
my $IsWindow = Win32::API->new('user32', 'IsWindow', 'N', 'I');
my $GetDC = Win32::API->new('user32', 'GetDC', 'N', 'N');
my $ReleaseDC = Win32::API->new('user32', 'ReleaseDC', 'NN', 'I');

my $ChoosePixelFormat = Win32::API->new('gdi32', 'ChoosePixelFormat', 'NP', 'I');
my $SetPixelFormat = Win32::API->new('gdi32', 'SetPixelFormat', 'NIP', 'I');
my $SwapBuffers = Win32::API->new('gdi32', 'SwapBuffers', 'N', 'I');

my $wglCreateContext = Win32::API->new('opengl32', 'wglCreateContext', 'N', 'N');
my $wglMakeCurrent = Win32::API->new('opengl32', 'wglMakeCurrent', 'NN', 'I');
my $wglDeleteContext = Win32::API->new('opengl32', 'wglDeleteContext', 'N', 'I');

my $glClearColor = Win32::API->new('opengl32', 'glClearColor', 'FFFF', 'V');
my $glClear = Win32::API->new('opengl32', 'glClear', 'N', 'V');
my $glBegin = Win32::API->new('opengl32', 'glBegin', 'N', 'V');
my $glEnd = Win32::API->new('opengl32', 'glEnd', [], 'V');
my $glColor3f = Win32::API->new('opengl32', 'glColor3f', 'FFF', 'V');
my $glVertex2f = Win32::API->new('opengl32', 'glVertex2f', 'FF', 'V');

# ============================================================
# Helper functions
# ============================================================
sub encode_utf16 {
    my ($str) = @_;
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";
    return $utf16;
}

# ============================================================
# OpenGL initialization
# ============================================================
my $g_hdc = 0;
my $g_hrc = 0;

sub enable_opengl {
    my ($hdc) = @_;
    
    # PIXELFORMATDESCRIPTOR structure (40 bytes on x64)
    my $pfd = pack('S S L C C C C C C C C C C C C C C C C C C L L L',
        40,                                 # nSize (WORD: 2 bytes)
        1,                                  # nVersion (WORD: 2 bytes)
        PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,  # dwFlags (DWORD: 4 bytes)
        PFD_TYPE_RGBA,                      # iPixelType (BYTE: 1 byte)
        24,                                 # cColorBits (BYTE: 1 byte)
        0, 0, 0, 0, 0, 0,                   # R/G/B bits and shifts (6 BYTEs)
        0, 0,                               # Alpha bits and shift (2 BYTEs)
        0, 0, 0, 0, 0,                      # Accum bits (5 BYTEs)
        16,                                 # cDepthBits (BYTE: 1 byte)
        0,                                  # cStencilBits (BYTE: 1 byte)
        0,                                  # cAuxBuffers (BYTE: 1 byte)
        PFD_MAIN_PLANE,                     # iLayerType (BYTE: 1 byte)
        0,                                  # bReserved (BYTE: 1 byte)
        0, 0, 0                             # Layer masks (3 DWORDs: 12 bytes)
    );
    
    my $fmt = $ChoosePixelFormat->Call($hdc, $pfd);
    unless ($fmt) {
        my $err = $GetLastError->Call();
        die "ChoosePixelFormat failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Pixel format: $fmt\n";
    
    unless ($SetPixelFormat->Call($hdc, $fmt, $pfd)) {
        my $err = $GetLastError->Call();
        die "SetPixelFormat failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "SetPixelFormat succeeded\n";
    
    my $hrc = $wglCreateContext->Call($hdc);
    unless ($hrc) {
        my $err = $GetLastError->Call();
        die "wglCreateContext failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "OpenGL context created: 0x" . sprintf("%X", $hrc) . "\n";
    
    unless ($wglMakeCurrent->Call($hdc, $hrc)) {
        my $err = $GetLastError->Call();
        die "wglMakeCurrent failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "OpenGL context activated\n";
    
    return $hrc;
}

sub disable_opengl {
    my ($hwnd, $hdc, $hrc) = @_;
    
    if ($hrc) {
        $wglMakeCurrent->Call(0, 0);
        $wglDeleteContext->Call($hrc);
    }
    if ($hwnd && $hdc) {
        $ReleaseDC->Call($hwnd, $hdc);
    }
}

sub draw_triangle {
    $glBegin->Call(GL_TRIANGLES);
    
    $glColor3f->Call(1.0, 0.0, 0.0);
    $glVertex2f->Call(0.0, 0.5);
    
    $glColor3f->Call(0.0, 1.0, 0.0);
    $glVertex2f->Call(0.5, -0.5);
    
    $glColor3f->Call(0.0, 0.0, 1.0);
    $glVertex2f->Call(-0.5, -0.5);
    
    $glEnd->Call();
}

# ============================================================
# Window callback placeholder
# Note: Win32::API does not support creating callbacks easily.
# We use DefWindowProcW for all messages.
# ============================================================

# ============================================================
# Main
# ============================================================
eval {
    print "Creating window...\n";
    
    my $hInstance = $GetModuleHandleW->Call(0);
    my $className = encode_utf16("PerlOpenGL10Class");
    
    # Get DefWindowProcW address
    my $defproc = $DefWindowProcW;
    
    # WNDCLASSEXW structure (80 bytes on x64)
    # typedef struct {
    #   UINT      cbSize;         // 4 bytes (offset 0)
    #   UINT      style;          // 4 bytes (offset 4)
    #   WNDPROC   lpfnWndProc;    // 8 bytes (offset 8)
    #   int       cbClsExtra;     // 4 bytes (offset 16)
    #   int       cbWndExtra;     // 4 bytes (offset 20)
    #   HINSTANCE hInstance;      // 8 bytes (offset 24)
    #   HICON     hIcon;          // 8 bytes (offset 32)
    #   HCURSOR   hCursor;        // 8 bytes (offset 40)
    #   HBRUSH    hbrBackground;  // 8 bytes (offset 48)
    #   LPCWSTR   lpszMenuName;   // 8 bytes (offset 56)
    #   LPCWSTR   lpszClassName;  // 8 bytes (offset 64)
    #   HICON     hIconSm;        // 8 bytes (offset 72)
    # } WNDCLASSEXW;              // Total: 80 bytes
    
    my $hIcon = $LoadIconW->Call(0, IDI_APPLICATION);
    my $hCursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    # We need the address of lpfnWndProc (DefWindowProcW)
    # Win32::API doesn't give us function pointers easily, so we use a workaround
    # For now, we'll pack a dummy address and hope the registration works
    # In production code, you'd need a proper callback mechanism
    
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,              # cbSize
        CS_OWNDC,        # style
        0,               # lpfnWndProc (will be fixed below)
        0,               # cbClsExtra
        0,               # cbWndExtra
        $hInstance,      # hInstance
        $hIcon,          # hIcon
        $hCursor,        # hCursor
        0,               # hbrBackground
        0,               # lpszMenuName
        0,               # lpszClassName (will be fixed below)
        $hIcon           # hIconSm
    );
    
    # Since we can't easily get callback addresses in Win32::API,
    # we'll use a simpler approach: store className and use CreateWindowExW directly
    # Actually, let's recreate the structure properly with actual addresses
    
    # Get the address of DefWindowProcW function
    # Unfortunately, Win32::API doesn't expose this easily
    # For this demo, we'll use a workaround
    
    # Alternative: Use Win32::GUI::WindowClass or inline::C
    # For simplicity, let's just try to register with what we have
    
    # Let's try a different approach - use a global buffer for className
    # and get its address using pack/unpack tricks
    
    # Actually, Win32::API lets us pass a packed structure directly
    # Let's allocate memory for className and pass its pointer
    
    use Win32::API::Type;
    my $className_ptr = unpack('Q', pack('P', $className));
    
    # For lpfnWndProc, we need the actual function address
    # This is tricky with Win32::API. Let's use a library trick.
    
    # Import kernel32::GetProcAddress to get DefWindowProcW address
    my $user32_dll = Win32::API->new('kernel32', 'LoadLibraryW', 'P', 'N');
    my $GetProcAddress = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');
    
    my $user32_handle = $user32_dll->Call(encode_utf16('user32.dll'));
    my $defproc_addr = $GetProcAddress->Call($user32_handle, "DefWindowProcW\0");
    
    unless ($defproc_addr) {
        die "Failed to get DefWindowProcW address\n";
    }
    
    print "DefWindowProcW address: 0x" . sprintf("%X", $defproc_addr) . "\n";
    print "ClassName pointer: 0x" . sprintf("%X", $className_ptr) . "\n";
    
    $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,              # cbSize
        CS_OWNDC,        # style
        $defproc_addr,   # lpfnWndProc
        0,               # cbClsExtra
        0,               # cbWndExtra
        $hInstance,      # hInstance
        $hIcon,          # hIcon
        $hCursor,        # hCursor
        0,               # hbrBackground
        0,               # lpszMenuName
        $className_ptr,  # lpszClassName
        $hIcon           # hIconSm
    );
    
    my $atom = $RegisterClassExW->Call($wndclass);
    unless ($atom) {
        my $err = $GetLastError->Call();
        die "RegisterClassExW failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Window class registered: atom = $atom\n";
    
    my $windowTitle = encode_utf16("OpenGL 1.0 Triangle (Perl)");
    
    # Use ClassName string directly (kept in scope)
    my $hwnd = $CreateWindowExW->Call(
        0,                      # dwExStyle
        $className,             # lpClassName (pass string directly)
        $windowTitle,           # lpWindowName (pass string directly)
        WS_OVERLAPPEDWINDOW,    # dwStyle
        100,                    # x
        100,                    # y
        640,                    # width
        480,                    # height
        0,                      # hwndParent
        0,                      # hMenu
        $hInstance,             # hInstance
        0                       # lpParam
    );
    
    unless ($hwnd) {
        my $err = $GetLastError->Call();
        die "CreateWindowExW failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    
    print "Window created: 0x" . sprintf("%X", $hwnd) . "\n";
    
    $ShowWindow->Call($hwnd, SW_SHOW);
    
    $g_hdc = $GetDC->Call($hwnd);
    unless ($g_hdc) {
        my $err = $GetLastError->Call();
        die "GetDC failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Device context obtained: 0x" . sprintf("%X", $g_hdc) . "\n\n";
    
    print "Initializing OpenGL...\n";
    $g_hrc = enable_opengl($g_hdc);
    print "\n";
    
    print "Running render loop...\n";
    my $msg = "\0" x 48;  # MSG structure (48 bytes on x64)
    my $running = 1;
    
    while ($running) {
        # Check if window is still valid
        unless ($IsWindow->Call($hwnd)) {
            print "Window closed by user\n";
            $running = 0;
            last;
        }
        
        if ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            my $msg_id = unpack('L', substr($msg, 8, 4));  # message field at offset 8
            if ($msg_id == WM_QUIT) {
                $running = 0;
            } elsif ($msg_id == WM_CLOSE || $msg_id == WM_DESTROY) {
                # Handle window close/destroy
                print "Received close message\n";
                $running = 0;
            } else {
                $TranslateMessage->Call($msg);
                $DispatchMessageW->Call($msg);
            }
        } else {
            # Render
            $glClearColor->Call(0.0, 0.0, 0.0, 0.0);
            $glClear->Call(GL_COLOR_BUFFER_BIT);
            
            draw_triangle();
            
            $SwapBuffers->Call($g_hdc);
            $Sleep->Call(1);
        }
    }
    
    print "Cleaning up...\n";
    disable_opengl($hwnd, $g_hdc, $g_hrc);
};

if ($@) {
    print "Error: $@\n";
}

print "Done.\n";
