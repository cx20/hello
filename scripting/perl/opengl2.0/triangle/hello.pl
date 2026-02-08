use strict;
use warnings;
use Win32::API;
use FFI::Platypus 2.00;
use Encode qw(encode);

print "=== Perl OpenGL 2.0 Triangle (Shaders + VBO) ===\n\n";

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
    
    # OpenGL 2.0
    GL_COLOR_BUFFER_BIT => 0x00004000,
    GL_FLOAT            => 0x1406,
    GL_TRIANGLES        => 0x0004,
    GL_ARRAY_BUFFER     => 0x8892,
    GL_STATIC_DRAW      => 0x88E4,
    GL_FRAGMENT_SHADER  => 0x8B30,
    GL_VERTEX_SHADER    => 0x8B31,
    GL_FALSE            => 0,
    GL_COMPILE_STATUS   => 0x8B81,
    GL_LINK_STATUS      => 0x8B82,
    GL_INFO_LOG_LENGTH  => 0x8B84,
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
my $wglGetProcAddress = Win32::API->new('opengl32', 'wglGetProcAddress', 'P', 'N');

my $glClearColor = Win32::API->new('opengl32', 'glClearColor', 'FFFF', 'V');
my $glClear = Win32::API->new('opengl32', 'glClear', 'N', 'V');

# OpenGL 2.0 extension functions (loaded via wglGetProcAddress)
my $ffi;
my ($glGenBuffers, $glBindBuffer, $glBufferData);
my ($glCreateShader, $glShaderSource, $glCompileShader);
my ($glGetShaderiv, $glGetShaderInfoLog);
my ($glCreateProgram, $glAttachShader, $glLinkProgram, $glUseProgram);
my ($glGetProgramiv, $glGetProgramInfoLog);
my ($glGetAttribLocation, $glEnableVertexAttribArray, $glVertexAttribPointer);
my ($glDrawArrays);

# ============================================================
# Helper functions
# ============================================================
sub encode_utf16 {
    my ($str) = @_;
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";
    return $utf16;
}

sub get_gl_func {
    my ($name, $ret_type, @arg_types) = @_;
    my $addr = $wglGetProcAddress->Call($name . "\0");
    unless ($addr) {
        die "Failed to get OpenGL function: $name\n";
    }
    return $ffi->function($addr => \@arg_types => $ret_type);
}

# ============================================================
# OpenGL initialization
# ============================================================
my $g_hdc = 0;
my $g_hrc = 0;
my @vbo = (0, 0);
my $posAttrib = -1;
my $colAttrib = -1;
my $shaderProgram = 0;

# Shader sources
my $vertexSource = <<'GLSL';
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;
void main()
{
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}
GLSL

my $fragmentSource = <<'GLSL';
varying   vec4 vColor;
void main()
{
  gl_FragColor = vColor;
}
GLSL

sub enable_opengl {
    my ($hdc) = @_;
    
    my $pfd = pack('S S L C C C C C C C C C C C C C C C C C C L L L',
        40,                                 # nSize
        1,                                  # nVersion
        PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        PFD_TYPE_RGBA,                      # iPixelType
        24,                                 # cColorBits
        0, 0, 0, 0, 0, 0,                   # R/G/B bits and shifts
        0, 0,                               # Alpha bits and shift
        0, 0, 0, 0, 0,                      # Accum bits
        16,                                 # cDepthBits
        0,                                  # cStencilBits
        0,                                  # cAuxBuffers
        PFD_MAIN_PLANE,                     # iLayerType
        0,                                  # bReserved
        0, 0, 0                             # Layer masks
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

sub init_gl2_functions {
    print "Loading OpenGL 2.0 functions...\n";
    
    # Initialize FFI
    $ffi = FFI::Platypus->new(api => 2);
    
    # VBO functions
    $glGenBuffers = get_gl_func('glGenBuffers', 'void', 'sint32', 'opaque');
    $glBindBuffer = get_gl_func('glBindBuffer', 'void', 'uint32', 'uint32');
    $glBufferData = get_gl_func('glBufferData', 'void', 'uint32', 'size_t', 'opaque', 'uint32');
    
    # Shader functions
    $glCreateShader = get_gl_func('glCreateShader', 'uint32', 'uint32');
    # Note: glShaderSource needs special handling for string arrays
    my $glShaderSource_addr = $wglGetProcAddress->Call("glShaderSource\0");
    unless ($glShaderSource_addr) {
        die "Failed to get OpenGL function: glShaderSource\n";
    }
    $glShaderSource = $ffi->function($glShaderSource_addr => ['uint32', 'sint32', 'string[]', 'sint32*'] => 'void');
    $glCompileShader = get_gl_func('glCompileShader', 'void', 'uint32');
    $glGetShaderiv = get_gl_func('glGetShaderiv', 'void', 'uint32', 'uint32', 'sint32*');
    $glGetShaderInfoLog = get_gl_func('glGetShaderInfoLog', 'void', 'uint32', 'sint32', 'sint32*', 'opaque');
    
    # Program functions
    $glCreateProgram = get_gl_func('glCreateProgram', 'uint32');
    $glAttachShader = get_gl_func('glAttachShader', 'void', 'uint32', 'uint32');
    $glLinkProgram = get_gl_func('glLinkProgram', 'void', 'uint32');
    $glGetProgramiv = get_gl_func('glGetProgramiv', 'void', 'uint32', 'uint32', 'sint32*');
    $glGetProgramInfoLog = get_gl_func('glGetProgramInfoLog', 'void', 'uint32', 'sint32', 'sint32*', 'opaque');
    $glUseProgram = get_gl_func('glUseProgram', 'void', 'uint32');
    
    # Attribute functions
    $glGetAttribLocation = get_gl_func('glGetAttribLocation', 'sint32', 'uint32', 'string');
    $glEnableVertexAttribArray = get_gl_func('glEnableVertexAttribArray', 'void', 'uint32');
    $glVertexAttribPointer = get_gl_func('glVertexAttribPointer', 'void', 'uint32', 'sint32', 'uint32', 'uint8', 'sint32', 'opaque');
    
    # Draw function
    $glDrawArrays = get_gl_func('glDrawArrays', 'void', 'uint32', 'sint32', 'sint32');
    
    print "OpenGL 2.0 functions loaded\n";
}

sub init_shader_and_buffers {
    print "Initializing shaders and buffers...\n";
    
    # Generate VBOs
    my $vbo_buffer = pack('L2', 0, 0);
    my $vbo_ptr = unpack('Q', pack('P', $vbo_buffer));
    $glGenBuffers->(2, $vbo_ptr);
    @vbo = unpack('L2', $vbo_buffer);
    print "VBOs created: $vbo[0], $vbo[1]\n";
    
    # Vertex data
    my $vertices = pack('f9',
         0.0,  0.5, 0.0,
         0.5, -0.5, 0.0,
        -0.5, -0.5, 0.0
    );
    
    # Color data
    my $colors = pack('f9',
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    );
    
    # Upload vertex data
    $glBindBuffer->(GL_ARRAY_BUFFER, $vbo[0]);
    my $vertices_ptr = unpack('Q', pack('P', $vertices));
    $glBufferData->(GL_ARRAY_BUFFER, length($vertices), $vertices_ptr, GL_STATIC_DRAW);
    
    # Upload color data
    $glBindBuffer->(GL_ARRAY_BUFFER, $vbo[1]);
    my $colors_ptr = unpack('Q', pack('P', $colors));
    $glBufferData->(GL_ARRAY_BUFFER, length($colors), $colors_ptr, GL_STATIC_DRAW);
    
    print "Vertex and color data uploaded to VBOs\n";
    
    # Create and compile vertex shader
    my $vertexShader = $glCreateShader->(GL_VERTEX_SHADER);
    $glShaderSource->($vertexShader, 1, [$vertexSource], undef);
    $glCompileShader->($vertexShader);
    
    # Check compile status
    my $status = 0;
    $glGetShaderiv->($vertexShader, GL_COMPILE_STATUS, \$status);
    if ($status == 0) {
        print "Vertex shader compilation failed!\n";
        my $log_len = 0;
        $glGetShaderiv->($vertexShader, GL_INFO_LOG_LENGTH, \$log_len);
        if ($log_len > 1) {
            my $log = "\0" x $log_len;
            my $log_ptr = unpack('Q', pack('P', $log));
            $glGetShaderInfoLog->($vertexShader, $log_len, 0, $log_ptr);
            print "Error log: $log\n";
        }
        print "Press Enter to exit...\n";
        <STDIN>;
        exit(1);
    }
    print "Vertex shader compiled\n";
    
    # Create and compile fragment shader
    my $fragmentShader = $glCreateShader->(GL_FRAGMENT_SHADER);
    $glShaderSource->($fragmentShader, 1, [$fragmentSource], undef);
    $glCompileShader->($fragmentShader);
    
    # Check compile status
    $status = 0;
    $glGetShaderiv->($fragmentShader, GL_COMPILE_STATUS, \$status);
    if ($status == 0) {
        print "Fragment shader compilation failed!\n";
        my $log_len = 0;
        $glGetShaderiv->($fragmentShader, GL_INFO_LOG_LENGTH, \$log_len);
        if ($log_len > 1) {
            my $log = "\0" x $log_len;
            my $log_ptr = unpack('Q', pack('P', $log));
            $glGetShaderInfoLog->($fragmentShader, $log_len, 0, $log_ptr);
            print "Error log: $log\n";
        }
        print "Press Enter to exit...\n";
        <STDIN>;
        exit(1);
    }
    print "Fragment shader compiled\n";
    
    # Create program and link shaders
    $shaderProgram = $glCreateProgram->();
    $glAttachShader->($shaderProgram, $vertexShader);
    $glAttachShader->($shaderProgram, $fragmentShader);
    $glLinkProgram->($shaderProgram);
    
    # Check link status
    my $link_status = 0;
    $glGetProgramiv->($shaderProgram, GL_LINK_STATUS, \$link_status);
    if ($link_status == 0) {
        print "Program linking failed!\n";
        my $log_len = 0;
        $glGetProgramiv->($shaderProgram, GL_INFO_LOG_LENGTH, \$log_len);
        if ($log_len > 1) {
            my $log = "\0" x $log_len;
            my $log_ptr = unpack('Q', pack('P', $log));
            $glGetProgramInfoLog->($shaderProgram, $log_len, 0, $log_ptr);
            print "Error log: $log\n";
        }
        print "Press Enter to exit...\n";
        <STDIN>;
        exit(1);
    }
    
    $glUseProgram->($shaderProgram);
    print "Shader program linked and activated\n";
    
    # Get attribute locations
    $posAttrib = $glGetAttribLocation->($shaderProgram, "position");
    $colAttrib = $glGetAttribLocation->($shaderProgram, "color");
    print "Attribute locations: position=$posAttrib, color=$colAttrib\n";
    
    # Enable vertex attributes
    $glEnableVertexAttribArray->($posAttrib);
    $glEnableVertexAttribArray->($colAttrib);
    
    print "Shaders and buffers initialized\n";
}

sub draw_triangle {
    # Bind position buffer and set attribute pointer
    $glBindBuffer->(GL_ARRAY_BUFFER, $vbo[0]);
    $glVertexAttribPointer->($posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    
    # Bind color buffer and set attribute pointer
    $glBindBuffer->(GL_ARRAY_BUFFER, $vbo[1]);
    $glVertexAttribPointer->($colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    
    # Draw triangle
    $glDrawArrays->(GL_TRIANGLES, 0, 3);
}

# ============================================================
# Main
# ============================================================
eval {
    print "Creating window...\n";
    
    my $hInstance = $GetModuleHandleW->Call(0);
    my $className = encode_utf16("PerlOpenGL20Class");
    
    my $hIcon = $LoadIconW->Call(0, IDI_APPLICATION);
    my $hCursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    # Get DefWindowProcW address
    my $user32_dll = Win32::API->new('kernel32', 'LoadLibraryW', 'P', 'N');
    my $GetProcAddress = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');
    
    my $user32_handle = $user32_dll->Call(encode_utf16('user32.dll'));
    my $defproc_addr = $GetProcAddress->Call($user32_handle, "DefWindowProcW\0");
    
    unless ($defproc_addr) {
        die "Failed to get DefWindowProcW address\n";
    }
    
    use Win32::API::Type;
    my $className_ptr = unpack('Q', pack('P', $className));
    
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
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
    
    my $windowTitle = encode_utf16("OpenGL 2.0 Triangle (Perl)");
    
    my $hwnd = $CreateWindowExW->Call(
        0,                      # dwExStyle
        $className,             # lpClassName
        $windowTitle,           # lpWindowName
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
    
    # Load OpenGL 2.0 functions
    init_gl2_functions();
    print "\n";
    
    # Initialize shaders and buffers
    init_shader_and_buffers();
    print "\n";
    
    print "Running render loop...\n";
    my $msg = "\0" x 48;
    my $running = 1;
    
    while ($running) {
        unless ($IsWindow->Call($hwnd)) {
            print "Window closed by user\n";
            $running = 0;
            last;
        }
        
        if ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            my $msg_id = unpack('L', substr($msg, 8, 4));
            if ($msg_id == WM_QUIT) {
                $running = 0;
            } elsif ($msg_id == WM_CLOSE || $msg_id == WM_DESTROY) {
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
