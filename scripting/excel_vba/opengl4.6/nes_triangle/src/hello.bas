Attribute VB_Name = "NES_Emulator"
Option Explicit

' ============================================================
'  64-bit Excel VBA + OpenGL 4.6 Core Profile - NES Emulator
'
'  Port of a C NES emulator to VBA.
'  Features:
'    - MOS 6502 CPU (all official instructions)
'    - PPU with background + sprite rendering
'    - Mapper 0 (NROM) and Mapper 66 (GxROM)
'    - OpenGL 4.6 rendering (texture + fullscreen quad)
'    - Player 1 keyboard input
'
'  Usage:
'    Place triangle.nes in the same folder as this Excel file.
'    Run the Main macro.
'
'  Debug log: C:\TEMP\debug.log
' ============================================================

' -------------------------------------------------------
' Win32 constants
' -------------------------------------------------------
Private Const PM_REMOVE As Long = &H1&
Private Const WM_QUIT As Long = &H12&
Private Const WM_DESTROY As Long = &H2&
Private Const WM_CLOSE As Long = &H10&
Private Const WM_SIZE As Long = &H5&
Private Const WM_KEYDOWN As Long = &H100&

Private Const CS_VREDRAW As Long = &H1&
Private Const CS_HREDRAW As Long = &H2&
Private Const CS_OWNDC As Long = &H20&

Private Const IDI_APPLICATION As Long = 32512&
Private Const IDC_ARROW As Long = 32512&
Private Const COLOR_WINDOW As Long = 5&
Private Const CW_USEDEFAULT As Long = &H80000000

Private Const WS_OVERLAPPED As Long = &H0&
Private Const WS_MAXIMIZEBOX As Long = &H10000
Private Const WS_MINIMIZEBOX As Long = &H20000
Private Const WS_THICKFRAME As Long = &H40000
Private Const WS_SYSMENU As Long = &H80000
Private Const WS_CAPTION As Long = &HC00000
Private Const WS_OVERLAPPEDWINDOW As Long = (WS_OVERLAPPED Or WS_CAPTION Or WS_SYSMENU Or WS_THICKFRAME Or WS_MINIMIZEBOX Or WS_MAXIMIZEBOX)

Private Const SW_SHOWDEFAULT As Long = 10
Private Const VK_ESCAPE As Long = &H1B

Private Const PFD_DOUBLEBUFFER As Long = 1
Private Const PFD_DRAW_TO_WINDOW As Long = 4
Private Const PFD_SUPPORT_OPENGL As Long = 32

' -------------------------------------------------------
' OpenGL constants
' -------------------------------------------------------
Private Const GL_COLOR_BUFFER_BIT As Long = &H4000&
Private Const GL_TRIANGLES As Long = &H4&
Private Const GL_TRIANGLE_STRIP As Long = &H5&
Private Const GL_FLOAT As Long = &H1406&
Private Const GL_FALSE_GL As Long = 0
Private Const GL_UNSIGNED_BYTE As Long = &H1401&
Private Const GL_NEAREST As Long = &H2600&
Private Const GL_TEXTURE_2D As Long = &HDE1&
Private Const GL_TEXTURE_MIN_FILTER As Long = &H2801&
Private Const GL_TEXTURE_MAG_FILTER As Long = &H2800&
Private Const GL_TEXTURE_WRAP_S As Long = &H2802&
Private Const GL_TEXTURE_WRAP_T As Long = &H2803&
Private Const GL_CLAMP_TO_EDGE As Long = &H812F&
Private Const GL_TEXTURE_BASE_LEVEL As Long = &H813C&
Private Const GL_TEXTURE_MAX_LEVEL As Long = &H813D&
Private Const GL_RGBA8 As Long = &H8058&
Private Const GL_BGRA As Long = &H80E1&
Private Const GL_TEXTURE0 As Long = &H84C0&

Private Const GL_VENDOR As Long = &H1F00&
Private Const GL_RENDERER_STR As Long = &H1F01&
Private Const GL_VERSION As Long = &H1F02&
Private Const GL_SHADING_LANGUAGE_VERSION As Long = &H8B8C&

Private Const GL_VERTEX_SHADER As Long = &H8B31&
Private Const GL_FRAGMENT_SHADER As Long = &H8B30&
Private Const GL_COMPILE_STATUS As Long = &H8B81&
Private Const GL_LINK_STATUS As Long = &H8B82&
Private Const GL_INFO_LOG_LENGTH As Long = &H8B84&

Private Const GL_ARRAY_BUFFER As Long = &H8892&
Private Const GL_STATIC_DRAW As Long = &H88E4&

' WGL
Private Const WGL_CONTEXT_MAJOR_VERSION_ARB As Long = &H2091&
Private Const WGL_CONTEXT_MINOR_VERSION_ARB As Long = &H2092&
Private Const WGL_CONTEXT_FLAGS_ARB As Long = &H2094&
Private Const WGL_CONTEXT_PROFILE_MASK_ARB As Long = &H9126&
Private Const WGL_CONTEXT_CORE_PROFILE_BIT_ARB As Long = &H1&

' -------------------------------------------------------
' NES constants
' -------------------------------------------------------
Private Const NES_WIDTH As Long = 256
Private Const NES_HEIGHT As Long = 240
Private Const SCREEN_SCALE As Long = 2
Private Const WINDOW_WIDTH As Long = NES_WIDTH * SCREEN_SCALE
Private Const WINDOW_HEIGHT As Long = NES_HEIGHT * SCREEN_SCALE

' 6502 status flags
Private Const FLAG_C As Byte = &H1
Private Const FLAG_Z As Byte = &H2
Private Const FLAG_I As Byte = &H4
Private Const FLAG_D As Byte = &H8
Private Const FLAG_B As Byte = &H10
Private Const FLAG_U As Byte = &H20
Private Const FLAG_V As Byte = &H40
Private Const FLAG_N As Byte = &H80

' PPU control ($2000)
Private Const PPUCTRL_NAMETABLE As Byte = &H3
Private Const PPUCTRL_VRAM_INC As Byte = &H4
Private Const PPUCTRL_SPR_ADDR As Byte = &H8
Private Const PPUCTRL_BG_ADDR As Byte = &H10
Private Const PPUCTRL_SPR_SIZE As Byte = &H20
Private Const PPUCTRL_NMI_ENABLE As Byte = &H80

' PPU mask ($2001)
Private Const PPUMASK_BG_LEFT As Byte = &H2
Private Const PPUMASK_SPR_LEFT As Byte = &H4
Private Const PPUMASK_BG_ENABLE As Byte = &H8
Private Const PPUMASK_SPR_ENABLE As Byte = &H10

' PPU status ($2002)
Private Const PPUSTAT_OVERFLOW As Byte = &H20
Private Const PPUSTAT_SPR0_HIT As Byte = &H40
Private Const PPUSTAT_VBLANK As Byte = &H80

' Mirroring
Private Const MIRROR_HORIZONTAL As Byte = 0
Private Const MIRROR_VERTICAL As Byte = 1
Private Const MIRROR_SINGLE_LO As Byte = 2
Private Const MIRROR_SINGLE_HI As Byte = 3
Private Const MIRROR_FOUR_SCREEN As Byte = 4

' Mappers
Private Const MAPPER_NROM As Byte = 0
Private Const MAPPER_GXROM As Byte = 66

' Controller buttons
Private Const BTN_A As Byte = &H80
Private Const BTN_B As Byte = &H40
Private Const BTN_SELECT As Byte = &H20
Private Const BTN_START As Byte = &H10
Private Const BTN_UP As Byte = &H8
Private Const BTN_DOWN As Byte = &H4
Private Const BTN_LEFT As Byte = &H2
Private Const BTN_RIGHT As Byte = &H1

' Instruction types
Private Const INS_ADC As Byte = 0
Private Const INS_AND As Byte = 1
Private Const INS_ASL As Byte = 2
Private Const INS_BCC As Byte = 3
Private Const INS_BCS As Byte = 4
Private Const INS_BEQ As Byte = 5
Private Const INS_BIT As Byte = 6
Private Const INS_BMI As Byte = 7
Private Const INS_BNE As Byte = 8
Private Const INS_BPL As Byte = 9
Private Const INS_BRK As Byte = 10
Private Const INS_BVC As Byte = 11
Private Const INS_BVS As Byte = 12
Private Const INS_CLC As Byte = 13
Private Const INS_CLD As Byte = 14
Private Const INS_CLI As Byte = 15
Private Const INS_CLV As Byte = 16
Private Const INS_CMP As Byte = 17
Private Const INS_CPX As Byte = 18
Private Const INS_CPY As Byte = 19
Private Const INS_DEC As Byte = 20
Private Const INS_DEX As Byte = 21
Private Const INS_DEY As Byte = 22
Private Const INS_EOR As Byte = 23
Private Const INS_INC As Byte = 24
Private Const INS_INX As Byte = 25
Private Const INS_INY As Byte = 26
Private Const INS_JMP As Byte = 27
Private Const INS_JSR As Byte = 28
Private Const INS_LDA As Byte = 29
Private Const INS_LDX As Byte = 30
Private Const INS_LDY As Byte = 31
Private Const INS_LSR As Byte = 32
Private Const INS_NOP As Byte = 33
Private Const INS_ORA As Byte = 34
Private Const INS_PHA As Byte = 35
Private Const INS_PHP As Byte = 36
Private Const INS_PLA As Byte = 37
Private Const INS_PLP As Byte = 38
Private Const INS_ROL As Byte = 39
Private Const INS_ROR As Byte = 40
Private Const INS_RTI As Byte = 41
Private Const INS_RTS As Byte = 42
Private Const INS_SBC As Byte = 43
Private Const INS_SEC As Byte = 44
Private Const INS_SED As Byte = 45
Private Const INS_SEI As Byte = 46
Private Const INS_STA As Byte = 47
Private Const INS_STX As Byte = 48
Private Const INS_STY As Byte = 49
Private Const INS_TAX As Byte = 50
Private Const INS_TAY As Byte = 51
Private Const INS_TSX As Byte = 52
Private Const INS_TXA As Byte = 53
Private Const INS_TXS As Byte = 54
Private Const INS_TYA As Byte = 55
Private Const INS_XXX As Byte = 56

' Addressing modes
Private Const AM_IMP As Byte = 0
Private Const AM_ACC As Byte = 1
Private Const AM_IMM As Byte = 2
Private Const AM_ZPG As Byte = 3
Private Const AM_ZPX As Byte = 4
Private Const AM_ZPY As Byte = 5
Private Const AM_REL As Byte = 6
Private Const AM_ABS As Byte = 7
Private Const AM_ABX As Byte = 8
Private Const AM_ABY As Byte = 9
Private Const AM_IND As Byte = 10
Private Const AM_IZX As Byte = 11
Private Const AM_IZY As Byte = 12

' -------------------------------------------------------
' Types
' -------------------------------------------------------
Private Type POINTAPI
    x As Long
    y As Long
End Type

Private Type MSGW
    hWnd As LongPtr
    message As Long
    wParam As LongPtr
    lParam As LongPtr
    time As Long
    pt As POINTAPI
End Type

Private Type WNDCLASSEXW
    cbSize As Long
    style As Long
    lpfnWndProc As LongPtr
    cbClsExtra As Long
    cbWndExtra As Long
    hInstance As LongPtr
    hIcon As LongPtr
    hCursor As LongPtr
    hbrBackground As LongPtr
    lpszMenuName As LongPtr
    lpszClassName As LongPtr
    hIconSm As LongPtr
End Type

Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Type PIXELFORMATDESCRIPTOR
    nSize As Integer
    nVersion As Integer
    dwFlags As Long
    iPixelType As Byte
    cColorBits As Byte
    cRedBits As Byte
    cRedShift As Byte
    cGreenBits As Byte
    cGreenShift As Byte
    cBlueBits As Byte
    cBlueShift As Byte
    cAlphaBits As Byte
    cAlphaShift As Byte
    cAccumBits As Byte
    cAccumRedBits As Byte
    cAccumGreenBits As Byte
    cAccumBlueBits As Byte
    cAccumAlphaBits As Byte
    cDepthBits As Byte
    cStencilBits As Byte
    cAuxBuffers As Byte
    iLayerType As Byte
    bReserved As Byte
    dwLayerMask As Long
    dwVisibleMask As Long
    dwDamageMask As Long
End Type

Private Type LARGE_INTEGER
    QuadPart As LongLong
End Type

' Thunk args for glVertexAttribPointer (6 args)
Private Type VAPArgs
    a1_index As LongPtr
    a2_size As LongPtr
    a3_type As LongPtr
    a4_norm As LongPtr
    a5_stride As LongPtr
    a6_ptr As LongPtr
End Type

' -------------------------------------------------------
' Win32 API Declares
' -------------------------------------------------------
#If VBA7 Then
    Private Declare PtrSafe Function GetModuleHandleW Lib "kernel32" (ByVal lpModuleName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadIconW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpIconName As LongPtr) As LongPtr
    Private Declare PtrSafe Function LoadCursorW Lib "user32" (ByVal hInstance As LongPtr, ByVal lpCursorName As LongPtr) As LongPtr
    Private Declare PtrSafe Function RegisterClassExW Lib "user32" (ByRef lpwcx As WNDCLASSEXW) As Integer
    Private Declare PtrSafe Function CreateWindowExW Lib "user32" ( _
        ByVal dwExStyle As Long, ByVal lpClassName As LongPtr, ByVal lpWindowName As LongPtr, _
        ByVal dwStyle As Long, ByVal x As Long, ByVal y As Long, _
        ByVal nWidth As Long, ByVal nHeight As Long, _
        ByVal hWndParent As LongPtr, ByVal hMenu As LongPtr, _
        ByVal hInstance As LongPtr, ByVal lpParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function ShowWindow Lib "user32" (ByVal hWnd As LongPtr, ByVal nCmdShow As Long) As Long
    Private Declare PtrSafe Function UpdateWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function DestroyWindow Lib "user32" (ByVal hWnd As LongPtr) As Long
    Private Declare PtrSafe Function PeekMessageW Lib "user32" ( _
        ByRef lpMsg As MSGW, ByVal hWnd As LongPtr, _
        ByVal wMsgFilterMin As Long, ByVal wMsgFilterMax As Long, _
        ByVal wRemoveMsg As Long) As Long
    Private Declare PtrSafe Function TranslateMessage Lib "user32" (ByRef lpMsg As MSGW) As Long
    Private Declare PtrSafe Function DispatchMessageW Lib "user32" (ByRef lpMsg As MSGW) As LongPtr
    Private Declare PtrSafe Sub PostQuitMessage Lib "user32" (ByVal nExitCode As Long)
    Private Declare PtrSafe Function DefWindowProcW Lib "user32" (ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Private Declare PtrSafe Function GetDC Lib "user32" (ByVal hWnd As LongPtr) As LongPtr
    Private Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As Long
    Private Declare PtrSafe Function GetClientRect Lib "user32" (ByVal hWnd As LongPtr, ByRef lpRect As RECT) As Long
    Private Declare PtrSafe Function AdjustWindowRect Lib "user32" (ByRef lpRect As RECT, ByVal dwStyle As Long, ByVal bMenu As Long) As Long
    Private Declare PtrSafe Function GetAsyncKeyState Lib "user32" (ByVal vKey As Long) As Integer
    Private Declare PtrSafe Function ChoosePixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SetPixelFormat Lib "gdi32" (ByVal hDC As LongPtr, ByVal iPixelFormat As Long, ByRef pfd As PIXELFORMATDESCRIPTOR) As Long
    Private Declare PtrSafe Function SwapBuffers Lib "gdi32" (ByVal hDC As LongPtr) As Long
    Private Declare PtrSafe Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Long)
    Private Declare PtrSafe Function GetLastError Lib "kernel32" () As Long
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As LARGE_INTEGER) As Long
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As LARGE_INTEGER) As Long
    Private Declare PtrSafe Function CallWindowProcW Lib "user32" ( _
        ByVal lpPrevWndFunc As LongPtr, ByVal hWnd As LongPtr, _
        ByVal msg As LongPtr, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr

    ' WGL
    Private Declare PtrSafe Function wglCreateContext Lib "opengl32.dll" (ByVal hDC As LongPtr) As LongPtr
    Private Declare PtrSafe Function wglMakeCurrent Lib "opengl32.dll" (ByVal hDC As LongPtr, ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglDeleteContext Lib "opengl32.dll" (ByVal hGLRC As LongPtr) As Long
    Private Declare PtrSafe Function wglGetProcAddress Lib "opengl32.dll" (ByVal lpszProc As LongPtr) As LongPtr

    ' OpenGL 1.1 (directly from opengl32.dll)
    Private Declare PtrSafe Sub glViewport Lib "opengl32.dll" (ByVal x As Long, ByVal y As Long, ByVal w As Long, ByVal h As Long)
    Private Declare PtrSafe Sub glClear Lib "opengl32.dll" (ByVal Mask As Long)
    Private Declare PtrSafe Sub glClearColor Lib "opengl32.dll" (ByVal r As Single, ByVal g As Single, ByVal b As Single, ByVal a As Single)
    Private Declare PtrSafe Function glGetString Lib "opengl32.dll" (ByVal name As Long) As LongPtr
    Private Declare PtrSafe Sub glDrawArrays Lib "opengl32.dll" (ByVal mode As Long, ByVal first As Long, ByVal count As Long)
    Private Declare PtrSafe Sub glGenTextures Lib "opengl32.dll" (ByVal n As Long, ByRef textures As Long)
    Private Declare PtrSafe Sub glBindTexture Lib "opengl32.dll" (ByVal target As Long, ByVal texture As Long)
    Private Declare PtrSafe Sub glDeleteTextures Lib "opengl32.dll" (ByVal n As Long, ByRef textures As Long)
    Private Declare PtrSafe Sub glTexParameteri Lib "opengl32.dll" (ByVal target As Long, ByVal pname As Long, ByVal param As Long)
    Private Declare PtrSafe Sub glTexImage2D Lib "opengl32.dll" (ByVal target As Long, ByVal level As Long, ByVal internalformat As Long, ByVal Width As Long, ByVal Height As Long, ByVal border As Long, ByVal fmt As Long, ByVal tp As Long, ByVal pixels As LongPtr)
    Private Declare PtrSafe Sub glTexSubImage2D Lib "opengl32.dll" (ByVal target As Long, ByVal level As Long, ByVal xoffset As Long, ByVal yoffset As Long, ByVal Width As Long, ByVal Height As Long, ByVal fmt As Long, ByVal tp As Long, ByVal pixels As LongPtr)

    ' Memory / file
    Private Declare PtrSafe Function CreateDirectoryW Lib "kernel32" (ByVal lpPathName As LongPtr, ByVal lpSecurityAttributes As LongPtr) As Long
    Private Declare PtrSafe Function CreateFileW Lib "kernel32" ( _
        ByVal lpFileName As LongPtr, ByVal dwDesiredAccess As Long, _
        ByVal dwShareMode As Long, ByVal lpSecurityAttributes As LongPtr, _
        ByVal dwCreationDisposition As Long, ByVal dwFlagsAndAttributes As Long, _
        ByVal hTemplateFile As LongPtr) As LongPtr
    Private Declare PtrSafe Function WriteFile Lib "kernel32" ( _
        ByVal hFile As LongPtr, ByRef lpBuffer As Any, _
        ByVal nNumberOfBytesToWrite As Long, ByRef lpNumberOfBytesWritten As Long, _
        ByVal lpOverlapped As LongPtr) As Long
    Private Declare PtrSafe Function FlushFileBuffers Lib "kernel32" (ByVal hFile As LongPtr) As Long
    Private Declare PtrSafe Function CloseHandle Lib "kernel32" (ByVal hObject As LongPtr) As Long
    Private Declare PtrSafe Function lstrlenA Lib "kernel32" (ByVal lpString As LongPtr) As Long
    Private Declare PtrSafe Sub RtlMoveMemory Lib "kernel32" (ByRef Destination As Any, ByVal Source As LongPtr, ByVal Length As Long)
    Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByVal Destination As LongPtr, ByVal Source As LongPtr, ByVal Length As LongPtr)
    Private Declare PtrSafe Function VirtualAlloc Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal flAllocationType As Long, ByVal flProtect As Long) As LongPtr
    Private Declare PtrSafe Function VirtualFree Lib "kernel32" (ByVal lpAddress As LongPtr, ByVal dwSize As LongPtr, ByVal dwFreeType As Long) As Long
#End If

' -------------------------------------------------------
' Memory constants
' -------------------------------------------------------
Private Const GENERIC_WRITE As Long = &H40000000
Private Const FILE_SHARE_READ As Long = &H1
Private Const FILE_SHARE_WRITE As Long = &H2
Private Const CREATE_ALWAYS As Long = 2
Private Const FILE_ATTRIBUTE_NORMAL As Long = &H80
Private Const MEM_COMMIT As Long = &H1000&
Private Const MEM_RESERVE As Long = &H2000&
Private Const MEM_RELEASE As Long = &H8000&
Private Const PAGE_EXECUTE_READWRITE As Long = &H40&

' -------------------------------------------------------
' Window / GL globals
' -------------------------------------------------------
Private g_hWnd As LongPtr
Private g_hDC As LongPtr
Private g_hRC As LongPtr
Private g_running As Boolean
Private g_log As LongPtr
Private g_className As String
Private g_firstFrame As Boolean

' GL objects
Private g_program As Long
Private g_vao As Long
Private g_vbo As Long
Private g_texture As Long

' GL function pointers
Private p_wglCreateContextAttribsARB As LongPtr
Private p_glGenBuffers As LongPtr
Private p_glBindBuffer As LongPtr
Private p_glBufferData As LongPtr
Private p_glCreateShader As LongPtr
Private p_glShaderSource As LongPtr
Private p_glCompileShader As LongPtr
Private p_glGetShaderiv As LongPtr
Private p_glGetShaderInfoLog As LongPtr
Private p_glCreateProgram As LongPtr
Private p_glAttachShader As LongPtr
Private p_glLinkProgram As LongPtr
Private p_glUseProgram As LongPtr
Private p_glGetProgramiv As LongPtr
Private p_glGetProgramInfoLog As LongPtr
Private p_glDeleteShader As LongPtr
Private p_glDeleteProgram As LongPtr
Private p_glDeleteBuffers As LongPtr
Private p_glGenVertexArrays As LongPtr
Private p_glBindVertexArray As LongPtr
Private p_glDeleteVertexArrays As LongPtr
Private p_glEnableVertexAttribArray As LongPtr
Private p_glVertexAttribPointer As LongPtr
Private p_glActiveTexture As LongPtr
Private p_glGetUniformLocation As LongPtr
Private p_glUniform1i As LongPtr

' Thunk pointers
Private p_thunkGen2 As LongPtr
Private p_thunkVAP As LongPtr
Private p_thunkCallN As LongPtr

' -------------------------------------------------------
' NES CPU state
' -------------------------------------------------------
Private cpu_a As Byte
Private cpu_x As Byte
Private cpu_y As Byte
Private cpu_sp As Byte
Private cpu_pc As Long       ' uint16 (0-65535)
Private cpu_p As Byte
Private cpu_cycles As Double
Private cpu_stall As Long
Private cpu_nmi_pending As Byte
Private cpu_irq_pending As Byte

' -------------------------------------------------------
' NES PPU state
' -------------------------------------------------------
Private ppu_ctrl As Byte
Private ppu_mask As Byte
Private ppu_status As Byte
Private ppu_oam_addr As Byte
Private ppu_v As Long        ' uint16
Private ppu_t As Long        ' uint16
Private ppu_fine_x As Byte
Private ppu_w As Byte
Private ppu_data_buf As Byte
Private ppu_oam(0 To 255) As Byte
Private ppu_vram(0 To &H7FF) As Byte
Private ppu_palette(0 To 31) As Byte
Private ppu_scanline As Long
Private ppu_cycle As Long
Private ppu_frame_count As Long
Private ppu_frame_ready As Byte
Private ppu_nmi_occurred As Byte
Private ppu_nmi_output As Byte
Private ppu_framebuffer() As Long   ' NES_WIDTH * NES_HEIGHT

' -------------------------------------------------------
' NES Cartridge
' -------------------------------------------------------
Private cart_prg_rom() As Byte
Private cart_chr_rom() As Byte
Private cart_chr_ram(0 To &H1FFF) As Byte
Private cart_prg_size As Long
Private cart_chr_size As Long
Private cart_prg_banks As Byte
Private cart_chr_banks As Byte
Private cart_mapper As Byte
Private cart_mirror As Byte
Private cart_prg_bank_select As Byte
Private cart_chr_bank_select As Byte
Private cart_has_chr_ram As Byte

' -------------------------------------------------------
' NES Bus
' -------------------------------------------------------
Private bus_ram(0 To &H7FF) As Byte
Private bus_controller(0 To 1) As Byte
Private bus_controller_latch(0 To 1) As Byte
Private bus_controller_strobe As Byte
Private bus_dma_page As Byte
Private bus_dma_addr As Byte
Private bus_dma_data As Byte
Private bus_dma_transfer As Byte
Private bus_dma_dummy As Byte
Private bus_system_cycles As Double

' -------------------------------------------------------
' Opcode table (256 entries)
' -------------------------------------------------------
Private op_ins(0 To 255) As Byte
Private op_mode(0 To 255) As Byte
Private op_cyc(0 To 255) As Byte
Private op_page(0 To 255) As Byte
Private g_opTableInit As Boolean

' -------------------------------------------------------
' NES Palette
' -------------------------------------------------------
Private nes_pal(0 To 63) As Long

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== NES EMULATOR LOG START ===="
End Sub

Private Sub LogClose()
    On Error Resume Next
    If g_log <> 0 Then
        LogMsg "==== LOG END ===="
        CloseHandle g_log
        g_log = 0
    End If
End Sub

Private Sub LogMsg(ByVal s As String)
    On Error Resume Next
    If g_log = 0 Then Exit Sub
    Dim line As String
    line = Format$(Now, "yyyy-mm-dd hh:nn:ss") & " | " & s & vbCrLf
    Dim b() As Byte: b = StrConv(line, vbFromUnicode)
    Dim written As Long
    WriteFile g_log, b(0), UBound(b) + 1, written, 0
    FlushFileBuffers g_log
End Sub

Private Function PtrToAnsiString(ByVal p As LongPtr) As String
    If p = 0 Then PtrToAnsiString = "": Exit Function
    Dim n As Long: n = lstrlenA(p)
    If n <= 0 Then PtrToAnsiString = "": Exit Function
    Dim b() As Byte: ReDim b(0 To n - 1)
    RtlMoveMemory b(0), p, n
    PtrToAnsiString = StrConv(b, vbUnicode)
End Function

' ============================================================
' Helpers
' ============================================================
Private Function AnsiZBytes(ByVal s As String) As Byte()
    AnsiZBytes = StrConv(s & vbNullChar, vbFromUnicode)
End Function

Private Function GetGLProc(ByVal name As String) As LongPtr
    Dim b() As Byte: b = AnsiZBytes(name)
    GetGLProc = wglGetProcAddress(VarPtr(b(0)))
End Function

Private Function GL_Call0(ByVal proc As LongPtr) As LongPtr
    GL_Call0 = CallWindowProcW(proc, 0, 0, 0, 0)
End Function
Private Function GL_Call1(ByVal proc As LongPtr, ByVal a1 As LongPtr) As LongPtr
    GL_Call1 = CallWindowProcW(proc, a1, 0, 0, 0)
End Function

' GL_Call2..4 use the generic thunk to avoid CallWindowProcW
' truncating arg2 (the Msg/UINT parameter) to 32 bits.
' The thunk reads all args from a LongPtr array via wParam (r8, 64-bit safe).
Private Function GL_Call2(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr) As LongPtr
    Dim args(0 To 3) As LongPtr
    args(0) = a1: args(1) = a2: args(2) = 0: args(3) = 0
    GL_Call2 = CallWindowProcW(p_thunkCallN, proc, 0, CLngPtr(VarPtr(args(0))), 0)
End Function
Private Function GL_Call3(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr) As LongPtr
    Dim args(0 To 3) As LongPtr
    args(0) = a1: args(1) = a2: args(2) = a3: args(3) = 0
    GL_Call3 = CallWindowProcW(p_thunkCallN, proc, 0, CLngPtr(VarPtr(args(0))), 0)
End Function
Private Function GL_Call4(ByVal proc As LongPtr, ByVal a1 As LongPtr, ByVal a2 As LongPtr, ByVal a3 As LongPtr, ByVal a4 As LongPtr) As LongPtr
    Dim args(0 To 3) As LongPtr
    args(0) = a1: args(1) = a2: args(2) = a3: args(3) = a4
    GL_Call4 = CallWindowProcW(p_thunkCallN, proc, 0, CLngPtr(VarPtr(args(0))), 0)
End Function

' ============================================================
' Thunks (x64 machine code)
' ============================================================

' Generic thunk for calling any GL function with up to 4 args (all 64-bit safe).
' Called as: CallWindowProcW(thunk, funcPtr, 0, VarPtr(argsArray), 0)
'   rcx = hWnd = funcPtr (64-bit OK)
'   rdx = msg  = ignored
'   r8  = wParam = pointer to LongPtr[4] args array (64-bit OK)
'   r9  = lParam = ignored
Private Function BuildThunk_CallN() As LongPtr
    Dim code(0 To 40) As Byte
    Dim i As Long: i = 0
    ' sub rsp, 28h         ; shadow space
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    ' mov rax, rcx         ; rax = funcPtr
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC8: i = i + 1
    ' mov r10, r8          ; r10 = args array pointer
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    ' mov rcx, [r10+0]     ; arg1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    ' mov rdx, [r10+8]     ; arg2 (full 64-bit!)
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    ' mov r8, [r10+16]     ; arg3
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    ' mov r9, [r10+24]     ; arg4
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    ' call rax
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    ' add rsp, 28h
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    ' ret                  ; return value already in rax
    code(i) = &HC3
    
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9002, , "VirtualAlloc failed for CallN thunk"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk_CallN = mem
End Function
Private Function BuildThunk_Gen2(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 28) As Byte
    Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HD1: i = i + 1
    code(i) = &H4C: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H33: i = i + 1: code(i) = &HC0: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 64, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9000, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), 29
    BuildThunk_Gen2 = mem
End Function

Private Function BuildThunk_VAP(ByVal target As LongPtr) As LongPtr
    Dim code(0 To 74) As Byte
    Dim i As Long: i = 0
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HEC: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &HC2: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &HA: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H52: i = i + 1: code(i) = &H8: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H10: i = i + 1
    code(i) = &H4D: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H4A: i = i + 1: code(i) = &H18: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H20: i = i + 1
    code(i) = &H49: i = i + 1: code(i) = &H8B: i = i + 1: code(i) = &H42: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H89: i = i + 1: code(i) = &H44: i = i + 1: code(i) = &H24: i = i + 1: code(i) = &H28: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &HB8: i = i + 1
    Dim t As LongLong: t = target
    RtlMoveMemory code(i), VarPtr(t), 8: i = i + 8
    code(i) = &HFF: i = i + 1: code(i) = &HD0: i = i + 1
    code(i) = &H48: i = i + 1: code(i) = &H83: i = i + 1: code(i) = &HC4: i = i + 1: code(i) = &H38: i = i + 1
    code(i) = &H33: i = i + 1: code(i) = &HC0: i = i + 1
    code(i) = &HC3
    Dim mem As LongPtr
    mem = VirtualAlloc(0, 128, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If mem = 0 Then Err.Raise vbObjectError + 9001, , "VirtualAlloc failed"
    CopyMemory mem, VarPtr(code(0)), CLngPtr(i + 1)
    BuildThunk_VAP = mem
End Function

Private Sub FreeThunks()
    On Error Resume Next
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    If p_thunkVAP <> 0 Then VirtualFree p_thunkVAP, 0, MEM_RELEASE: p_thunkVAP = 0
    If p_thunkCallN <> 0 Then VirtualFree p_thunkCallN, 0, MEM_RELEASE: p_thunkCallN = 0
End Sub

' ============================================================
' NES Palette init
' ============================================================
Private Sub InitPalette()
    nes_pal(0) = &H666666: nes_pal(1) = &H2A88: nes_pal(2) = &H1412A7: nes_pal(3) = &H3B00A4
    nes_pal(4) = &H5C007E: nes_pal(5) = &H6E0040: nes_pal(6) = &H6C0600: nes_pal(7) = &H561D00
    nes_pal(8) = &H333500: nes_pal(9) = &HB4800: nes_pal(10) = &H5200: nes_pal(11) = &H4F08
    nes_pal(12) = &H404D: nes_pal(13) = 0: nes_pal(14) = 0: nes_pal(15) = 0
    nes_pal(16) = &HADADAD: nes_pal(17) = &H155FD9: nes_pal(18) = &H4240FF: nes_pal(19) = &H7527FE
    nes_pal(20) = &HA01ACC: nes_pal(21) = &HB71E7B: nes_pal(22) = &HB53120: nes_pal(23) = &H994E00
    nes_pal(24) = &H6B6D00: nes_pal(25) = &H388700: nes_pal(26) = &HC9300: nes_pal(27) = &H8F32
    nes_pal(28) = &H7C8D: nes_pal(29) = 0: nes_pal(30) = 0: nes_pal(31) = 0
    ' Use Long with OR for alpha=FF (sign bit set)
    Dim i As Long
    For i = 0 To 31
        nes_pal(i) = nes_pal(i) Or &HFF000000
    Next i
    nes_pal(32) = &HFFFEFF Or &HFF000000: nes_pal(33) = &H64B0FF Or &HFF000000: nes_pal(34) = &H9290FF Or &HFF000000: nes_pal(35) = &HC676FF Or &HFF000000
    nes_pal(36) = &HF36AFF Or &HFF000000: nes_pal(37) = &HFE6ECC Or &HFF000000: nes_pal(38) = &HFE8170 Or &HFF000000: nes_pal(39) = &HEA9E22 Or &HFF000000
    nes_pal(40) = &HBCBE00 Or &HFF000000: nes_pal(41) = &H88D800 Or &HFF000000: nes_pal(42) = &H5CE430 Or &HFF000000: nes_pal(43) = &H45E082 Or &HFF000000
    nes_pal(44) = &H48CDDE Or &HFF000000: nes_pal(45) = &H4F4F4F Or &HFF000000: nes_pal(46) = &HFF000000: nes_pal(47) = &HFF000000
    nes_pal(48) = &HFFFEFF Or &HFF000000: nes_pal(49) = &HC0DFFF Or &HFF000000: nes_pal(50) = &HD3D2FF Or &HFF000000: nes_pal(51) = &HE8C8FF Or &HFF000000
    nes_pal(52) = &HFBC2FF Or &HFF000000: nes_pal(53) = &HFEC4EA Or &HFF000000: nes_pal(54) = &HFECCC5 Or &HFF000000: nes_pal(55) = &HF7D8A5 Or &HFF000000
    nes_pal(56) = &HE4E594 Or &HFF000000: nes_pal(57) = &HCFEF96 Or &HFF000000: nes_pal(58) = &HBDF4AB Or &HFF000000: nes_pal(59) = &HB3F3CC Or &HFF000000
    nes_pal(60) = &HB5EBF2 Or &HFF000000: nes_pal(61) = &HB8B8B8 Or &HFF000000: nes_pal(62) = &HFF000000: nes_pal(63) = &HFF000000
End Sub

' ============================================================
' Opcode table init
' ============================================================
Private Sub SetOp(ByVal idx As Long, ByVal ins As Byte, ByVal md As Byte, ByVal cy As Byte, ByVal pg As Byte)
    op_ins(idx) = ins: op_mode(idx) = md: op_cyc(idx) = cy: op_page(idx) = pg
End Sub

Private Sub InitOpcodeTable()
    If g_opTableInit Then Exit Sub
    Dim i As Long
    ' Default all to XXX/IMP/2/0
    For i = 0 To 255
        SetOp i, INS_XXX, AM_IMP, 2, 0
    Next i
    
    ' Row 0x
    SetOp &H0, INS_BRK, AM_IMP, 7, 0: SetOp &H1, INS_ORA, AM_IZX, 6, 0
    SetOp &H5, INS_ORA, AM_ZPG, 3, 0: SetOp &H6, INS_ASL, AM_ZPG, 5, 0
    SetOp &H8, INS_PHP, AM_IMP, 3, 0: SetOp &H9, INS_ORA, AM_IMM, 2, 0: SetOp &HA, INS_ASL, AM_ACC, 2, 0
    SetOp &HD, INS_ORA, AM_ABS, 4, 0: SetOp &HE, INS_ASL, AM_ABS, 6, 0
    ' Row 1x
    SetOp &H10, INS_BPL, AM_REL, 2, 0: SetOp &H11, INS_ORA, AM_IZY, 5, 1
    SetOp &H15, INS_ORA, AM_ZPX, 4, 0: SetOp &H16, INS_ASL, AM_ZPX, 6, 0
    SetOp &H18, INS_CLC, AM_IMP, 2, 0: SetOp &H19, INS_ORA, AM_ABY, 4, 1
    SetOp &H1D, INS_ORA, AM_ABX, 4, 1: SetOp &H1E, INS_ASL, AM_ABX, 7, 0
    ' Row 2x
    SetOp &H20, INS_JSR, AM_ABS, 6, 0: SetOp &H21, INS_AND, AM_IZX, 6, 0
    SetOp &H24, INS_BIT, AM_ZPG, 3, 0: SetOp &H25, INS_AND, AM_ZPG, 3, 0: SetOp &H26, INS_ROL, AM_ZPG, 5, 0
    SetOp &H28, INS_PLP, AM_IMP, 4, 0: SetOp &H29, INS_AND, AM_IMM, 2, 0: SetOp &H2A, INS_ROL, AM_ACC, 2, 0
    SetOp &H2C, INS_BIT, AM_ABS, 4, 0: SetOp &H2D, INS_AND, AM_ABS, 4, 0: SetOp &H2E, INS_ROL, AM_ABS, 6, 0
    ' Row 3x
    SetOp &H30, INS_BMI, AM_REL, 2, 0: SetOp &H31, INS_AND, AM_IZY, 5, 1
    SetOp &H35, INS_AND, AM_ZPX, 4, 0: SetOp &H36, INS_ROL, AM_ZPX, 6, 0
    SetOp &H38, INS_SEC, AM_IMP, 2, 0: SetOp &H39, INS_AND, AM_ABY, 4, 1
    SetOp &H3D, INS_AND, AM_ABX, 4, 1: SetOp &H3E, INS_ROL, AM_ABX, 7, 0
    ' Row 4x
    SetOp &H40, INS_RTI, AM_IMP, 6, 0: SetOp &H41, INS_EOR, AM_IZX, 6, 0
    SetOp &H45, INS_EOR, AM_ZPG, 3, 0: SetOp &H46, INS_LSR, AM_ZPG, 5, 0
    SetOp &H48, INS_PHA, AM_IMP, 3, 0: SetOp &H49, INS_EOR, AM_IMM, 2, 0: SetOp &H4A, INS_LSR, AM_ACC, 2, 0
    SetOp &H4C, INS_JMP, AM_ABS, 3, 0: SetOp &H4D, INS_EOR, AM_ABS, 4, 0: SetOp &H4E, INS_LSR, AM_ABS, 6, 0
    ' Row 5x
    SetOp &H50, INS_BVC, AM_REL, 2, 0: SetOp &H51, INS_EOR, AM_IZY, 5, 1
    SetOp &H55, INS_EOR, AM_ZPX, 4, 0: SetOp &H56, INS_LSR, AM_ZPX, 6, 0
    SetOp &H58, INS_CLI, AM_IMP, 2, 0: SetOp &H59, INS_EOR, AM_ABY, 4, 1
    SetOp &H5D, INS_EOR, AM_ABX, 4, 1: SetOp &H5E, INS_LSR, AM_ABX, 7, 0
    ' Row 6x
    SetOp &H60, INS_RTS, AM_IMP, 6, 0: SetOp &H61, INS_ADC, AM_IZX, 6, 0
    SetOp &H65, INS_ADC, AM_ZPG, 3, 0: SetOp &H66, INS_ROR, AM_ZPG, 5, 0
    SetOp &H68, INS_PLA, AM_IMP, 4, 0: SetOp &H69, INS_ADC, AM_IMM, 2, 0: SetOp &H6A, INS_ROR, AM_ACC, 2, 0
    SetOp &H6C, INS_JMP, AM_IND, 5, 0: SetOp &H6D, INS_ADC, AM_ABS, 4, 0: SetOp &H6E, INS_ROR, AM_ABS, 6, 0
    ' Row 7x
    SetOp &H70, INS_BVS, AM_REL, 2, 0: SetOp &H71, INS_ADC, AM_IZY, 5, 1
    SetOp &H75, INS_ADC, AM_ZPX, 4, 0: SetOp &H76, INS_ROR, AM_ZPX, 6, 0
    SetOp &H78, INS_SEI, AM_IMP, 2, 0: SetOp &H79, INS_ADC, AM_ABY, 4, 1
    SetOp &H7D, INS_ADC, AM_ABX, 4, 1: SetOp &H7E, INS_ROR, AM_ABX, 7, 0
    ' Row 8x
    SetOp &H81, INS_STA, AM_IZX, 6, 0
    SetOp &H84, INS_STY, AM_ZPG, 3, 0: SetOp &H85, INS_STA, AM_ZPG, 3, 0: SetOp &H86, INS_STX, AM_ZPG, 3, 0
    SetOp &H88, INS_DEY, AM_IMP, 2, 0: SetOp &H8A, INS_TXA, AM_IMP, 2, 0
    SetOp &H8C, INS_STY, AM_ABS, 4, 0: SetOp &H8D, INS_STA, AM_ABS, 4, 0: SetOp &H8E, INS_STX, AM_ABS, 4, 0
    ' Row 9x
    SetOp &H90, INS_BCC, AM_REL, 2, 0: SetOp &H91, INS_STA, AM_IZY, 6, 0
    SetOp &H94, INS_STY, AM_ZPX, 4, 0: SetOp &H95, INS_STA, AM_ZPX, 4, 0: SetOp &H96, INS_STX, AM_ZPY, 4, 0
    SetOp &H98, INS_TYA, AM_IMP, 2, 0: SetOp &H99, INS_STA, AM_ABY, 5, 0: SetOp &H9A, INS_TXS, AM_IMP, 2, 0
    SetOp &H9D, INS_STA, AM_ABX, 5, 0
    ' Row Ax
    SetOp &HA0, INS_LDY, AM_IMM, 2, 0: SetOp &HA1, INS_LDA, AM_IZX, 6, 0: SetOp &HA2, INS_LDX, AM_IMM, 2, 0
    SetOp &HA4, INS_LDY, AM_ZPG, 3, 0: SetOp &HA5, INS_LDA, AM_ZPG, 3, 0: SetOp &HA6, INS_LDX, AM_ZPG, 3, 0
    SetOp &HA8, INS_TAY, AM_IMP, 2, 0: SetOp &HA9, INS_LDA, AM_IMM, 2, 0: SetOp &HAA, INS_TAX, AM_IMP, 2, 0
    SetOp &HAC, INS_LDY, AM_ABS, 4, 0: SetOp &HAD, INS_LDA, AM_ABS, 4, 0: SetOp &HAE, INS_LDX, AM_ABS, 4, 0
    ' Row Bx
    SetOp &HB0, INS_BCS, AM_REL, 2, 0: SetOp &HB1, INS_LDA, AM_IZY, 5, 1
    SetOp &HB4, INS_LDY, AM_ZPX, 4, 0: SetOp &HB5, INS_LDA, AM_ZPX, 4, 0: SetOp &HB6, INS_LDX, AM_ZPY, 4, 0
    SetOp &HB8, INS_CLV, AM_IMP, 2, 0: SetOp &HB9, INS_LDA, AM_ABY, 4, 1: SetOp &HBA, INS_TSX, AM_IMP, 2, 0
    SetOp &HBC, INS_LDY, AM_ABX, 4, 1: SetOp &HBD, INS_LDA, AM_ABX, 4, 1: SetOp &HBE, INS_LDX, AM_ABY, 4, 1
    ' Row Cx
    SetOp &HC0, INS_CPY, AM_IMM, 2, 0: SetOp &HC1, INS_CMP, AM_IZX, 6, 0
    SetOp &HC4, INS_CPY, AM_ZPG, 3, 0: SetOp &HC5, INS_CMP, AM_ZPG, 3, 0: SetOp &HC6, INS_DEC, AM_ZPG, 5, 0
    SetOp &HC8, INS_INY, AM_IMP, 2, 0: SetOp &HC9, INS_CMP, AM_IMM, 2, 0: SetOp &HCA, INS_DEX, AM_IMP, 2, 0
    SetOp &HCC, INS_CPY, AM_ABS, 4, 0: SetOp &HCD, INS_CMP, AM_ABS, 4, 0: SetOp &HCE, INS_DEC, AM_ABS, 6, 0
    ' Row Dx
    SetOp &HD0, INS_BNE, AM_REL, 2, 0: SetOp &HD1, INS_CMP, AM_IZY, 5, 1
    SetOp &HD5, INS_CMP, AM_ZPX, 4, 0: SetOp &HD6, INS_DEC, AM_ZPX, 6, 0
    SetOp &HD8, INS_CLD, AM_IMP, 2, 0: SetOp &HD9, INS_CMP, AM_ABY, 4, 1
    SetOp &HDD, INS_CMP, AM_ABX, 4, 1: SetOp &HDE, INS_DEC, AM_ABX, 7, 0
    ' Row Ex
    SetOp &HE0, INS_CPX, AM_IMM, 2, 0: SetOp &HE1, INS_SBC, AM_IZX, 6, 0
    SetOp &HE4, INS_CPX, AM_ZPG, 3, 0: SetOp &HE5, INS_SBC, AM_ZPG, 3, 0: SetOp &HE6, INS_INC, AM_ZPG, 5, 0
    SetOp &HE8, INS_INX, AM_IMP, 2, 0: SetOp &HE9, INS_SBC, AM_IMM, 2, 0: SetOp &HEA, INS_NOP, AM_IMP, 2, 0
    SetOp &HEC, INS_CPX, AM_ABS, 4, 0: SetOp &HED, INS_SBC, AM_ABS, 4, 0: SetOp &HEE, INS_INC, AM_ABS, 6, 0
    ' Row Fx
    SetOp &HF0, INS_BEQ, AM_REL, 2, 0: SetOp &HF1, INS_SBC, AM_IZY, 5, 1
    SetOp &HF5, INS_SBC, AM_ZPX, 4, 0: SetOp &HF6, INS_INC, AM_ZPX, 6, 0
    SetOp &HF8, INS_SED, AM_IMP, 2, 0: SetOp &HF9, INS_SBC, AM_ABY, 4, 1
    SetOp &HFD, INS_SBC, AM_ABX, 4, 1: SetOp &HFE, INS_INC, AM_ABX, 7, 0

    g_opTableInit = True
End Sub

' ============================================================
' Cartridge - iNES ROM loader
' ============================================================
Private Function CartridgeLoad(ByVal filename As String) As Boolean
    CartridgeLoad = False
    Dim fn As Integer: fn = FreeFile
    On Error GoTo LoadErr
    Open filename For Binary Access Read As #fn
    
    ' Read 16-byte header
    Dim hdr(0 To 15) As Byte
    Get #fn, , hdr
    
    ' Check magic "NES\x1A"
    If hdr(0) <> &H4E Or hdr(1) <> &H45 Or hdr(2) <> &H53 Or hdr(3) <> &H1A Then
        LogMsg "Error: Invalid iNES file"
        Close #fn
        Exit Function
    End If
    
    cart_mapper = (hdr(7) And &HF0) Or (hdr(6) \ 16)
    If cart_mapper <> MAPPER_NROM And cart_mapper <> MAPPER_GXROM Then
        LogMsg "Error: Only Mapper 0 and 66 supported (got " & cart_mapper & ")"
        Close #fn
        Exit Function
    End If
    
    If (hdr(6) And &H8) <> 0 Then
        cart_mirror = MIRROR_FOUR_SCREEN
    ElseIf (hdr(6) And &H1) <> 0 Then
        cart_mirror = MIRROR_VERTICAL
    Else
        cart_mirror = MIRROR_HORIZONTAL
    End If
    
    ' Skip trainer if present
    If (hdr(6) And &H4) <> 0 Then
        Dim dummy(0 To 511) As Byte
        Get #fn, , dummy
    End If
    
    cart_prg_banks = hdr(4)
    cart_prg_size = CLng(hdr(4)) * 16384
    ReDim cart_prg_rom(0 To cart_prg_size - 1)
    Get #fn, , cart_prg_rom
    
    cart_chr_banks = hdr(5)
    If hdr(5) > 0 Then
        cart_chr_size = CLng(hdr(5)) * 8192
        ReDim cart_chr_rom(0 To cart_chr_size - 1)
        Get #fn, , cart_chr_rom
        cart_has_chr_ram = 0
    Else
        cart_chr_size = &H2000
        ' chr_rom points to chr_ram - we'll handle in read/write
        cart_has_chr_ram = 1
    End If
    
    Close #fn
    
    cart_prg_bank_select = 0
    cart_chr_bank_select = 0
    
    LogMsg "ROM: PRG=" & (cart_prg_size \ 1024) & "KB CHR=" & (cart_chr_size \ 1024) & "KB Mapper=" & cart_mapper & " Mirror=" & cart_mirror
    CartridgeLoad = True
    Exit Function

LoadErr:
    LogMsg "Error loading ROM: " & Err.Description
    On Error Resume Next
    Close #fn
    CartridgeLoad = False
End Function

Private Function CartridgePrgAddr(ByVal addr As Long) As Long
    If cart_mapper = MAPPER_GXROM Then
        Dim bc As Long: bc = cart_prg_size \ &H8000
        Dim bk As Long
        If bc > 0 Then bk = (cart_prg_bank_select Mod bc) Else bk = 0
        CartridgePrgAddr = bk * &H8000 + (addr - &H8000&)
    Else
        Dim mapped As Long: mapped = addr - &H8000&
        If cart_prg_banks = 1 Then mapped = mapped And &H3FFF&
        CartridgePrgAddr = mapped
    End If
End Function

Private Function CartridgeChrAddr(ByVal addr As Long) As Long
    If cart_mapper = MAPPER_GXROM Then
        Dim bc As Long: bc = cart_chr_size \ &H2000
        Dim bk As Long
        If bc > 0 Then bk = (cart_chr_bank_select Mod bc) Else bk = 0
        CartridgeChrAddr = bk * &H2000 + addr
    Else
        CartridgeChrAddr = addr
    End If
End Function

Private Function CartridgeCpuRead(ByVal addr As Long) As Byte
    If addr >= &H8000& Then
        Dim m As Long: m = CartridgePrgAddr(addr)
        If m >= 0 And m <= UBound(cart_prg_rom) Then
            CartridgeCpuRead = cart_prg_rom(m)
        Else
            CartridgeCpuRead = 0
        End If
    Else
        CartridgeCpuRead = 0
    End If
End Function

Private Sub CartridgeCpuWrite(ByVal addr As Long, ByVal v As Byte)
    If cart_mapper = MAPPER_GXROM And addr >= &H8000& Then
        Dim latch As Byte: latch = v And CartridgeCpuRead(addr)
        cart_chr_bank_select = latch And &H3
        cart_prg_bank_select = (latch \ 16) And &H3
    End If
End Sub

Private Function CartridgePpuRead(ByVal addr As Long) As Byte
    If addr < &H2000& Then
        Dim ca As Long: ca = CartridgeChrAddr(addr)
        If cart_has_chr_ram = 1 Then
            CartridgePpuRead = cart_chr_ram(ca And &H1FFF&)
        Else
            If ca <= UBound(cart_chr_rom) Then
                CartridgePpuRead = cart_chr_rom(ca)
            Else
                CartridgePpuRead = 0
            End If
        End If
    Else
        CartridgePpuRead = 0
    End If
End Function

Private Sub CartridgePpuWrite(ByVal addr As Long, ByVal v As Byte)
    If addr < &H2000& And cart_has_chr_ram = 1 Then
        Dim ca As Long: ca = CartridgeChrAddr(addr) And &H1FFF&
        cart_chr_ram(ca) = v
    End If
End Sub

' ============================================================
' PPU
' ============================================================
Private Function MirrorNametable(ByVal addr As Long) As Long
    addr = (addr - &H2000&) And &HFFF&
    Select Case cart_mirror
        Case MIRROR_HORIZONTAL
            If addr < &H800& Then
                MirrorNametable = addr And &H3FF&
            Else
                MirrorNametable = &H400& + (addr And &H3FF&)
            End If
        Case MIRROR_VERTICAL
            MirrorNametable = addr And &H7FF&
        Case MIRROR_SINGLE_LO
            MirrorNametable = addr And &H3FF&
        Case MIRROR_SINGLE_HI
            MirrorNametable = &H400& + (addr And &H3FF&)
        Case Else
            MirrorNametable = addr And &H7FF&
    End Select
End Function

Private Function PpuRead(ByVal addr As Long) As Byte
    addr = addr And &H3FFF&
    If addr < &H2000& Then
        PpuRead = CartridgePpuRead(addr)
    ElseIf addr < &H3F00& Then
        PpuRead = ppu_vram(MirrorNametable(addr))
    Else
        Dim pa As Long: pa = addr And &H1F&
        If pa >= 16 And (pa And 3) = 0 Then pa = pa - 16
        PpuRead = ppu_palette(pa)
    End If
End Function

Private Sub PpuWrite(ByVal addr As Long, ByVal v As Byte)
    addr = addr And &H3FFF&
    If addr < &H2000& Then
        CartridgePpuWrite addr, v
    ElseIf addr < &H3F00& Then
        ppu_vram(MirrorNametable(addr)) = v
    Else
        Dim pa As Long: pa = addr And &H1F&
        If pa >= 16 And (pa And 3) = 0 Then pa = pa - 16
        ppu_palette(pa) = v
    End If
End Sub

Private Function PpuRegRead(ByVal reg As Long) As Byte
    Dim result As Byte: result = 0
    Select Case (reg And 7)
        Case 2
            result = (ppu_status And &HE0) Or (ppu_data_buf And &H1F)
            ppu_status = ppu_status And (Not PPUSTAT_VBLANK)
            ppu_nmi_occurred = 0
            ppu_w = 0
        Case 4
            result = ppu_oam(ppu_oam_addr)
        Case 7
            result = ppu_data_buf
            ppu_data_buf = PpuRead(ppu_v)
            If (ppu_v And &H3FFF&) >= &H3F00& Then
                result = ppu_data_buf
                ppu_data_buf = PpuRead(ppu_v - &H1000&)
            End If
            If (ppu_ctrl And PPUCTRL_VRAM_INC) <> 0 Then
                ppu_v = (ppu_v + 32) And &H7FFF&
            Else
                ppu_v = (ppu_v + 1) And &H7FFF&
            End If
    End Select
    PpuRegRead = result
End Function

Private Sub PpuRegWrite(ByVal reg As Long, ByVal v As Byte)
    Select Case (reg And 7)
        Case 0
            ppu_ctrl = v
            If (v And PPUCTRL_NMI_ENABLE) <> 0 Then ppu_nmi_output = 1 Else ppu_nmi_output = 0
            ppu_t = (ppu_t And &HF3FF&) Or (CLng(v And &H3) * &H400&)
        Case 1
            ppu_mask = v
        Case 3
            ppu_oam_addr = v
        Case 4
            ppu_oam(ppu_oam_addr) = v
            ppu_oam_addr = (ppu_oam_addr + 1) And &HFF
        Case 5
            If ppu_w = 0 Then
                ppu_t = (ppu_t And &HFFE0&) Or (CLng(v) \ 8)
                ppu_fine_x = v And &H7
                ppu_w = 1
            Else
                ppu_t = (ppu_t And &H8C1F&) Or (CLng(v And &H7) * &H1000&) Or ((CLng(v) \ 8) * 32)
                ppu_w = 0
            End If
        Case 6
            If ppu_w = 0 Then
                ppu_t = (ppu_t And &HFF&) Or (CLng(v And &H3F) * &H100&)
                ppu_w = 1
            Else
                ppu_t = (ppu_t And &HFF00&) Or CLng(v)
                ppu_v = ppu_t
                ppu_w = 0
            End If
        Case 7
            PpuWrite ppu_v, v
            If (ppu_ctrl And PPUCTRL_VRAM_INC) <> 0 Then
                ppu_v = (ppu_v + 32) And &H7FFF&
            Else
                ppu_v = (ppu_v + 1) And &H7FFF&
            End If
    End Select
End Sub

Private Sub PpuReset()
    ppu_ctrl = 0: ppu_mask = 0: ppu_status = 0: ppu_oam_addr = 0
    ppu_v = 0: ppu_t = 0: ppu_fine_x = 0: ppu_w = 0: ppu_data_buf = 0
    ppu_scanline = -1: ppu_cycle = 0: ppu_frame_count = 0
    ppu_frame_ready = 0: ppu_nmi_occurred = 0: ppu_nmi_output = 0
    Dim i As Long
    For i = 0 To 255: ppu_oam(i) = 0: Next i
    For i = 0 To &H7FF: ppu_vram(i) = 0: Next i
    For i = 0 To 31: ppu_palette(i) = 0: Next i
    ReDim ppu_framebuffer(0 To NES_WIDTH * NES_HEIGHT - 1)
    For i = 0 To NES_WIDTH * NES_HEIGHT - 1: ppu_framebuffer(i) = 0: Next i
End Sub

Private Function RenderingEnabled() As Boolean
    RenderingEnabled = ((ppu_mask And (PPUMASK_BG_ENABLE Or PPUMASK_SPR_ENABLE)) <> 0)
End Function

Private Sub IncrementX()
    If (ppu_v And &H1F&) = 31 Then
        ppu_v = ppu_v And (Not &H1F&)
        ppu_v = ppu_v Xor &H400&
    Else
        ppu_v = ppu_v + 1
    End If
    ppu_v = ppu_v And &H7FFF&
End Sub

Private Sub IncrementY()
    If (ppu_v And &H7000&) <> &H7000& Then
        ppu_v = ppu_v + &H1000&
    Else
        ppu_v = ppu_v And (Not &H7000&)
        Dim cy As Long: cy = (ppu_v And &H3E0&) \ 32
        If cy = 29 Then
            cy = 0: ppu_v = ppu_v Xor &H800&
        ElseIf cy = 31 Then
            cy = 0
        Else
            cy = cy + 1
        End If
        ppu_v = (ppu_v And (Not &H3E0&)) Or (cy * 32)
    End If
    ppu_v = ppu_v And &H7FFF&
End Sub

Private Sub CopyHorizontal()
    ppu_v = (ppu_v And (Not &H41F&)) Or (ppu_t And &H41F&)
End Sub

Private Sub CopyVertical()
    ppu_v = (ppu_v And (Not &H7BE0&)) Or (ppu_t And &H7BE0&)
End Sub

Private Sub RenderBgScanline(ByRef bg_px() As Byte, ByRef bg_pal() As Byte)
    Dim v As Long: v = ppu_v
    Dim fx As Byte: fx = ppu_fine_x
    Dim show_bg As Boolean: show_bg = ((ppu_mask And PPUMASK_BG_ENABLE) <> 0)
    Dim show_left As Boolean: show_left = ((ppu_mask And PPUMASK_BG_LEFT) <> 0)
    Dim x As Long
    
    For x = 0 To 255
        Dim pixel As Byte: pixel = 0
        Dim pal As Byte: pal = 0
        
        If show_bg And (x >= 8 Or show_left) Then
            Dim nt As Long: nt = &H2000& Or (v And &HFFF&)
            Dim tile As Byte: tile = PpuRead(nt)
            Dim at As Long: at = &H23C0& Or (v And &HC00&) Or ((v \ 16) And &H38&) Or ((v \ 4) And &H7&)
            Dim ab As Byte: ab = PpuRead(at)
            pal = (ab \ (2 ^ (((v \ 16) And 4) Or (v And 2)))) And 3
            Dim pb As Long
            If (ppu_ctrl And PPUCTRL_BG_ADDR) <> 0 Then pb = &H1000& Else pb = 0
            Dim patAddr As Long: patAddr = pb + CLng(tile) * 16 + ((v \ &H1000&) And 7)
            Dim lo As Byte: lo = PpuRead(patAddr)
            Dim hi As Byte: hi = PpuRead(patAddr + 8)
            Dim bitPos As Long: bitPos = 7 - fx
            pixel = ((lo \ (2 ^ bitPos)) And 1) Or (((hi \ (2 ^ bitPos)) And 1) * 2)
        End If
        
        bg_px(x) = pixel
        bg_pal(x) = pal
        
        If fx = 7 Then
            fx = 0
            IncrementX
            v = ppu_v
        Else
            fx = fx + 1
        End If
    Next x
End Sub

Private Sub RenderSprites(ByVal scanline As Long, ByRef bg_px() As Byte, ByRef bg_pal() As Byte, ByVal lineOffset As Long)
    Dim show_spr As Boolean: show_spr = ((ppu_mask And PPUMASK_SPR_ENABLE) <> 0)
    Dim show_left As Boolean: show_left = ((ppu_mask And PPUMASK_SPR_LEFT) <> 0)
    Dim spr_h As Long
    If (ppu_ctrl And PPUCTRL_SPR_SIZE) <> 0 Then spr_h = 16 Else spr_h = 8
    Dim count As Long: count = 0
    
    Dim sp_px(0 To 255) As Byte
    Dim sp_pal(0 To 255) As Byte
    Dim sp_pri(0 To 255) As Byte
    Dim sp_z(0 To 255) As Byte
    Dim x As Long
    For x = 0 To 255: sp_px(x) = 0: sp_z(x) = 0: Next x
    
    If show_spr Then
        Dim i As Long
        For i = 63 To 0 Step -1
            Dim sy As Long: sy = CLng(ppu_oam(i * 4)) + 1
            Dim tileNum As Long: tileNum = ppu_oam(i * 4 + 1)
            Dim attr As Long: attr = ppu_oam(i * 4 + 2)
            Dim sx As Long: sx = ppu_oam(i * 4 + 3)
            Dim row As Long: row = scanline - sy
            If row < 0 Or row >= spr_h Then GoTo NextSprite
            count = count + 1
            
            Dim fv As Boolean: fv = ((attr And &H80) <> 0)
            Dim fh As Boolean: fh = ((attr And &H40) <> 0)
            Dim sPal As Byte: sPal = (attr And &H3) + 4
            Dim sPri As Byte: If (attr And &H20) <> 0 Then sPri = 1 Else sPri = 0
            
            Dim patAddr As Long
            Dim r As Long
            If spr_h = 8 Then
                If fv Then r = 7 - row Else r = row
                Dim sprBase As Long
                If (ppu_ctrl And PPUCTRL_SPR_ADDR) <> 0 Then sprBase = &H1000& Else sprBase = 0
                patAddr = sprBase + tileNum * 16 + r
            Else
                Dim base16 As Long
                If (tileNum And 1) <> 0 Then base16 = &H1000& Else base16 = 0
                Dim t16 As Long: t16 = tileNum And &HFE
                If fv Then r = 15 - row Else r = row
                If r >= 8 Then t16 = t16 + 1: r = r - 8
                patAddr = base16 + t16 * 16 + r
            End If
            
            Dim lo As Byte: lo = PpuRead(patAddr)
            Dim hi As Byte: hi = PpuRead(patAddr + 8)
            Dim px As Long
            For px = 0 To 7
                Dim dx As Long: dx = sx + px
                If dx >= 256 Then GoTo NextPx
                If dx < 8 And (Not show_left) Then GoTo NextPx
                Dim bitPos As Long
                If fh Then bitPos = px Else bitPos = 7 - px
                Dim p As Byte: p = ((lo \ (2 ^ bitPos)) And 1) Or (((hi \ (2 ^ bitPos)) And 1) * 2)
                If p = 0 Then GoTo NextPx
                sp_px(dx) = p: sp_pal(dx) = sPal: sp_pri(dx) = sPri
                If i = 0 Then sp_z(dx) = 1
NextPx:
            Next px
NextSprite:
        Next i
        If count > 8 Then ppu_status = ppu_status Or PPUSTAT_OVERFLOW
    End If
    
    ' Compose
    Dim show_bg As Boolean: show_bg = ((ppu_mask And PPUMASK_BG_ENABLE) <> 0)
    For x = 0 To 255
        Dim bp As Byte: bp = bg_px(x)
        Dim sp As Byte: sp = sp_px(x)
        Dim ci As Byte
        
        ' Sprite 0 hit
        If sp_z(x) <> 0 And bp <> 0 And sp <> 0 And show_spr And show_bg Then
            If x >= 8 Or ((ppu_mask And PPUMASK_BG_LEFT) <> 0 And (ppu_mask And PPUMASK_SPR_LEFT) <> 0) Then
                ppu_status = ppu_status Or PPUSTAT_SPR0_HIT
            End If
        End If
        
        If bp = 0 And sp = 0 Then
            ci = PpuRead(&H3F00&)
        ElseIf bp = 0 And sp <> 0 Then
            ci = PpuRead(&H3F00& + CLng(sp_pal(x)) * 4 + sp)
        ElseIf bp <> 0 And sp = 0 Then
            ci = PpuRead(&H3F00& + CLng(bg_pal(x)) * 4 + bp)
        Else
            If sp_pri(x) = 0 Then
                ci = PpuRead(&H3F00& + CLng(sp_pal(x)) * 4 + sp)
            Else
                ci = PpuRead(&H3F00& + CLng(bg_pal(x)) * 4 + bp)
            End If
        End If
        ppu_framebuffer(lineOffset + x) = nes_pal(ci And &H3F)
    Next x
End Sub

Private Sub PpuStep()
    Dim pre As Boolean: pre = (ppu_scanline = -1)
    Dim vis As Boolean: vis = (ppu_scanline >= 0 And ppu_scanline < 240)
    Dim ren As Boolean: ren = RenderingEnabled()
    
    If vis And ppu_cycle = 256 Then
        If ren Then
            Dim bg_px(0 To 255) As Byte
            Dim bg_pal(0 To 255) As Byte
            CopyHorizontal
            RenderBgScanline bg_px, bg_pal
            RenderSprites ppu_scanline, bg_px, bg_pal, ppu_scanline * 256
            IncrementY
        Else
            Dim bgCol As Byte: bgCol = ppu_palette(0) And &H3F
            Dim ln As Long: ln = ppu_scanline * 256
            Dim xp As Long
            For xp = 0 To 255
                ppu_framebuffer(ln + xp) = nes_pal(bgCol)
            Next xp
        End If
    End If
    
    If pre Then
        If ppu_cycle = 1 Then
            ppu_status = ppu_status And (Not (PPUSTAT_VBLANK Or PPUSTAT_SPR0_HIT Or PPUSTAT_OVERFLOW))
            ppu_nmi_occurred = 0
        End If
        If ren And ppu_cycle >= 280 And ppu_cycle <= 304 Then CopyVertical
    End If
    
    If ppu_scanline = 241 And ppu_cycle = 1 Then
        ppu_status = ppu_status Or PPUSTAT_VBLANK
        ppu_nmi_occurred = 1
        If ppu_nmi_output <> 0 Then cpu_nmi_pending = 1
        ppu_frame_ready = 1
    End If
    
    ppu_cycle = ppu_cycle + 1
    If ppu_cycle > 340 Then
        ppu_cycle = 0
        ppu_scanline = ppu_scanline + 1
        If ppu_scanline > 260 Then ppu_scanline = -1: ppu_frame_count = ppu_frame_count + 1
    End If
End Sub

' ============================================================
' CPU - MOS 6502
' ============================================================
Private Function BusCpuRead(ByVal addr As Long) As Byte
    addr = addr And &HFFFF&
    If addr < &H2000& Then
        BusCpuRead = bus_ram(addr And &H7FF&)
    ElseIf addr < &H4000& Then
        BusCpuRead = PpuRegRead(addr)
    ElseIf addr = &H4016& Then
        Dim d As Byte
        If (bus_controller_latch(0) And &H80) <> 0 Then d = 1 Else d = 0
        bus_controller_latch(0) = (bus_controller_latch(0) * 2) And &HFF
        BusCpuRead = d Or &H40
    ElseIf addr = &H4017& Then
        Dim d2 As Byte
        If (bus_controller_latch(1) And &H80) <> 0 Then d2 = 1 Else d2 = 0
        bus_controller_latch(1) = (bus_controller_latch(1) * 2) And &HFF
        BusCpuRead = d2 Or &H40
    ElseIf addr < &H4020& Then
        BusCpuRead = 0
    Else
        BusCpuRead = CartridgeCpuRead(addr)
    End If
End Function

Private Sub BusCpuWrite(ByVal addr As Long, ByVal v As Byte)
    addr = addr And &HFFFF&
    If addr < &H2000& Then
        bus_ram(addr And &H7FF&) = v
    ElseIf addr < &H4000& Then
        PpuRegWrite addr, v
    ElseIf addr = &H4014& Then
        bus_dma_page = v: bus_dma_addr = 0
        bus_dma_transfer = 1: bus_dma_dummy = 1
    ElseIf addr = &H4016& Then
        bus_controller_strobe = v And 1
        If bus_controller_strobe <> 0 Then
            bus_controller_latch(0) = bus_controller(0)
            bus_controller_latch(1) = bus_controller(1)
        End If
    ElseIf addr < &H4020& Then
        ' APU/IO - ignore
    Else
        CartridgeCpuWrite addr, v
    End If
End Sub

Private Sub CpuSetFlag(ByVal f As Byte, ByVal v As Boolean)
    If v Then cpu_p = cpu_p Or f Else cpu_p = cpu_p And (Not f)
End Sub

Private Sub CpuUpdateNZ(ByVal v As Byte)
    CpuSetFlag FLAG_Z, (v = 0)
    CpuSetFlag FLAG_N, ((v And &H80) <> 0)
End Sub

Private Sub CpuPush8(ByVal v As Byte)
    BusCpuWrite &H100& + CLng(cpu_sp), v
    cpu_sp = (cpu_sp - 1) And &HFF
End Sub

Private Sub CpuPush16(ByVal v As Long)
    CpuPush8 CByte((v \ 256) And &HFF)
    CpuPush8 CByte(v And &HFF)
End Sub

Private Function CpuPull8() As Byte
    cpu_sp = (cpu_sp + 1) And &HFF
    CpuPull8 = BusCpuRead(&H100& + CLng(cpu_sp))
End Function

Private Function CpuPull16() As Long
    Dim lo As Long: lo = CpuPull8()
    Dim hi As Long: hi = CpuPull8()
    CpuPull16 = (hi * 256 + lo) And &HFFFF&
End Function

Private Sub CpuReset()
    Dim lo As Long: lo = BusCpuRead(&HFFFC&)
    Dim hi As Long: hi = BusCpuRead(&HFFFD&)
    cpu_pc = (hi * 256 + lo) And &HFFFF&
    cpu_sp = &HFD: cpu_p = FLAG_U Or FLAG_I
    cpu_a = 0: cpu_x = 0: cpu_y = 0
    cpu_cycles = 0: cpu_stall = 0
    cpu_nmi_pending = 0: cpu_irq_pending = 0
End Sub

Private Sub CpuNmi()
    CpuPush16 cpu_pc
    CpuPush8 (cpu_p Or FLAG_U) And (Not FLAG_B)
    cpu_p = cpu_p Or FLAG_I
    Dim lo As Long: lo = BusCpuRead(&HFFFA&)
    Dim hi As Long: hi = BusCpuRead(&HFFFB&)
    cpu_pc = (hi * 256 + lo) And &HFFFF&
    cpu_cycles = cpu_cycles + 7
End Sub

Private Function CpuStep() As Long
    Dim extra As Long: extra = 0
    
    If cpu_stall > 0 Then cpu_stall = cpu_stall - 1: CpuStep = 1: Exit Function
    If cpu_nmi_pending <> 0 Then CpuNmi: cpu_nmi_pending = 0: CpuStep = 7: Exit Function
    If cpu_irq_pending <> 0 And (cpu_p And FLAG_I) = 0 Then
        CpuPush16 cpu_pc
        CpuPush8 (cpu_p Or FLAG_U) And (Not FLAG_B)
        cpu_p = cpu_p Or FLAG_I
        Dim ilo As Long: ilo = BusCpuRead(&HFFFE&)
        Dim ihi As Long: ihi = BusCpuRead(&HFFFF&)
        cpu_pc = (ihi * 256 + ilo) And &HFFFF&
        cpu_irq_pending = 0
        cpu_cycles = cpu_cycles + 7
        CpuStep = 7
        Exit Function
    End If
    
    Dim opcode As Byte: opcode = BusCpuRead(cpu_pc)
    cpu_pc = (cpu_pc + 1) And &HFFFF&
    
    Dim ins As Byte: ins = op_ins(opcode)
    Dim md As Byte: md = op_mode(opcode)
    Dim cyc As Long: cyc = op_cyc(opcode)
    Dim pxc As Long: pxc = 0
    
    ' Resolve address
    Dim addr As Long: addr = 0
    Dim lo As Long, hi As Long, tmp As Long
    
    Select Case md
        Case AM_IMP, AM_ACC
            ' no operand
        Case AM_IMM
            addr = cpu_pc: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPG
            addr = BusCpuRead(cpu_pc) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPX
            addr = (CLng(BusCpuRead(cpu_pc)) + cpu_x) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPY
            addr = (CLng(BusCpuRead(cpu_pc)) + cpu_y) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_REL
            addr = cpu_pc: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ABS
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            addr = (hi * 256 + lo) And &HFFFF&
        Case AM_ABX
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            tmp = hi * 256 + lo
            addr = (tmp + cpu_x) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
        Case AM_ABY
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            tmp = hi * 256 + lo
            addr = (tmp + cpu_y) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
        Case AM_IND
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            Dim ptr As Long: ptr = hi * 256 + lo
            Dim ph As Long
            If (lo = &HFF) Then ph = ptr And &HFF00& Else ph = ptr + 1
            addr = (CLng(BusCpuRead(ph)) * 256 + BusCpuRead(ptr)) And &HFFFF&
        Case AM_IZX
            Dim bx As Long: bx = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            Dim zx As Long: zx = (bx + cpu_x) And &HFF&
            lo = BusCpuRead(zx): hi = BusCpuRead((zx + 1) And &HFF&)
            addr = (hi * 256 + lo) And &HFFFF&
        Case AM_IZY
            Dim zy As Long: zy = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            lo = BusCpuRead(zy): hi = BusCpuRead((zy + 1) And &HFF&)
            tmp = hi * 256 + lo
            addr = (tmp + cpu_y) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
    End Select
    
    If pxc <> 0 And op_page(opcode) <> 0 Then cyc = cyc + 1
    
    ' Execute instruction
    Dim v As Long, s As Long, c As Long, oldA As Long
    
    Select Case ins
        Case INS_ADC
            v = BusCpuRead(addr)
            s = CLng(cpu_a) + v + IIf((cpu_p And FLAG_C) <> 0, 1, 0)
            CpuSetFlag FLAG_C, (s > 255)
            CpuSetFlag FLAG_V, (((Not (CLng(cpu_a) Xor v)) And (CLng(cpu_a) Xor s)) And &H80) <> 0
            cpu_a = CByte(s And &HFF): CpuUpdateNZ cpu_a
        Case INS_SBC
            v = BusCpuRead(addr)
            s = CLng(cpu_a) - v - IIf((cpu_p And FLAG_C) <> 0, 0, 1)
            CpuSetFlag FLAG_C, (s >= 0)
            CpuSetFlag FLAG_V, (((CLng(cpu_a) Xor v) And (CLng(cpu_a) Xor s)) And &H80) <> 0
            cpu_a = CByte(s And &HFF): CpuUpdateNZ cpu_a
        Case INS_AND
            cpu_a = cpu_a And BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_ORA
            cpu_a = cpu_a Or BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_EOR
            cpu_a = cpu_a Xor BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_ASL
            If md = AM_ACC Then
                CpuSetFlag FLAG_C, (cpu_a And &H80) <> 0
                cpu_a = (CLng(cpu_a) * 2) And &HFF: CpuUpdateNZ cpu_a
            Else
                Dim va As Byte: va = BusCpuRead(addr)
                CpuSetFlag FLAG_C, (va And &H80) <> 0
                va = (CLng(va) * 2) And &HFF: BusCpuWrite addr, va: CpuUpdateNZ va
            End If
        Case INS_LSR
            If md = AM_ACC Then
                CpuSetFlag FLAG_C, (cpu_a And 1) <> 0
                cpu_a = cpu_a \ 2: CpuUpdateNZ cpu_a
            Else
                Dim vl As Byte: vl = BusCpuRead(addr)
                CpuSetFlag FLAG_C, (vl And 1) <> 0
                vl = vl \ 2: BusCpuWrite addr, vl: CpuUpdateNZ vl
            End If
        Case INS_ROL
            If md = AM_ACC Then
                c = IIf((cpu_p And FLAG_C) <> 0, 1, 0)
                CpuSetFlag FLAG_C, (cpu_a And &H80) <> 0
                cpu_a = ((CLng(cpu_a) * 2) Or c) And &HFF: CpuUpdateNZ cpu_a
            Else
                Dim vr As Byte: vr = BusCpuRead(addr)
                c = IIf((cpu_p And FLAG_C) <> 0, 1, 0)
                CpuSetFlag FLAG_C, (vr And &H80) <> 0
                vr = ((CLng(vr) * 2) Or c) And &HFF: BusCpuWrite addr, vr: CpuUpdateNZ vr
            End If
        Case INS_ROR
            If md = AM_ACC Then
                c = IIf((cpu_p And FLAG_C) <> 0, &H80, 0)
                CpuSetFlag FLAG_C, (cpu_a And 1) <> 0
                cpu_a = (cpu_a \ 2) Or c: CpuUpdateNZ cpu_a
            Else
                Dim vro As Byte: vro = BusCpuRead(addr)
                c = IIf((cpu_p And FLAG_C) <> 0, &H80, 0)
                CpuSetFlag FLAG_C, (vro And 1) <> 0
                vro = (vro \ 2) Or c: BusCpuWrite addr, vro: CpuUpdateNZ vro
            End If
        Case INS_CMP
            v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_a >= v): CpuUpdateNZ CByte((CLng(cpu_a) - v) And &HFF)
        Case INS_CPX
            v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_x >= v): CpuUpdateNZ CByte((CLng(cpu_x) - v) And &HFF)
        Case INS_CPY
            v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_y >= v): CpuUpdateNZ CByte((CLng(cpu_y) - v) And &HFF)
        Case INS_INC
            Dim vi As Byte: vi = (CLng(BusCpuRead(addr)) + 1) And &HFF: BusCpuWrite addr, vi: CpuUpdateNZ vi
        Case INS_DEC
            Dim vd As Byte: vd = (CLng(BusCpuRead(addr)) - 1) And &HFF: BusCpuWrite addr, vd: CpuUpdateNZ vd
        Case INS_INX
            cpu_x = (cpu_x + 1) And &HFF: CpuUpdateNZ cpu_x
        Case INS_INY
            cpu_y = (cpu_y + 1) And &HFF: CpuUpdateNZ cpu_y
        Case INS_DEX
            cpu_x = (cpu_x - 1) And &HFF: CpuUpdateNZ cpu_x
        Case INS_DEY
            cpu_y = (cpu_y - 1) And &HFF: CpuUpdateNZ cpu_y
        Case INS_LDA
            cpu_a = BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_LDX
            cpu_x = BusCpuRead(addr): CpuUpdateNZ cpu_x
        Case INS_LDY
            cpu_y = BusCpuRead(addr): CpuUpdateNZ cpu_y
        Case INS_STA
            BusCpuWrite addr, cpu_a
        Case INS_STX
            BusCpuWrite addr, cpu_x
        Case INS_STY
            BusCpuWrite addr, cpu_y
        Case INS_TAX
            cpu_x = cpu_a: CpuUpdateNZ cpu_x
        Case INS_TAY
            cpu_y = cpu_a: CpuUpdateNZ cpu_y
        Case INS_TXA
            cpu_a = cpu_x: CpuUpdateNZ cpu_a
        Case INS_TYA
            cpu_a = cpu_y: CpuUpdateNZ cpu_a
        Case INS_TSX
            cpu_x = cpu_sp: CpuUpdateNZ cpu_x
        Case INS_TXS
            cpu_sp = cpu_x
        Case INS_PHA
            CpuPush8 cpu_a
        Case INS_PHP
            CpuPush8 cpu_p Or FLAG_B Or FLAG_U
        Case INS_PLA
            cpu_a = CpuPull8(): CpuUpdateNZ cpu_a
        Case INS_PLP
            cpu_p = (CpuPull8() And (Not FLAG_B)) Or FLAG_U
        Case INS_BCC
            extra = DoBranch(addr, (cpu_p And FLAG_C) = 0)
        Case INS_BCS
            extra = DoBranch(addr, (cpu_p And FLAG_C) <> 0)
        Case INS_BEQ
            extra = DoBranch(addr, (cpu_p And FLAG_Z) <> 0)
        Case INS_BNE
            extra = DoBranch(addr, (cpu_p And FLAG_Z) = 0)
        Case INS_BMI
            extra = DoBranch(addr, (cpu_p And FLAG_N) <> 0)
        Case INS_BPL
            extra = DoBranch(addr, (cpu_p And FLAG_N) = 0)
        Case INS_BVS
            extra = DoBranch(addr, (cpu_p And FLAG_V) <> 0)
        Case INS_BVC
            extra = DoBranch(addr, (cpu_p And FLAG_V) = 0)
        Case INS_JMP
            cpu_pc = addr
        Case INS_JSR
            CpuPush16 (cpu_pc - 1) And &HFFFF&
            cpu_pc = addr
        Case INS_RTS
            cpu_pc = (CpuPull16() + 1) And &HFFFF&
        Case INS_RTI
            cpu_p = (CpuPull8() And (Not FLAG_B)) Or FLAG_U
            cpu_pc = CpuPull16()
        Case INS_CLC: cpu_p = cpu_p And (Not FLAG_C)
        Case INS_SEC: cpu_p = cpu_p Or FLAG_C
        Case INS_CLD: cpu_p = cpu_p And (Not FLAG_D)
        Case INS_SED: cpu_p = cpu_p Or FLAG_D
        Case INS_CLI: cpu_p = cpu_p And (Not FLAG_I)
        Case INS_SEI: cpu_p = cpu_p Or FLAG_I
        Case INS_CLV: cpu_p = cpu_p And (Not FLAG_V)
        Case INS_BIT
            v = BusCpuRead(addr)
            CpuSetFlag FLAG_Z, (cpu_a And v) = 0
            CpuSetFlag FLAG_V, (v And &H40) <> 0
            CpuSetFlag FLAG_N, (v And &H80) <> 0
        Case INS_BRK
            cpu_pc = (cpu_pc + 1) And &HFFFF&
            CpuPush16 cpu_pc
            CpuPush8 cpu_p Or FLAG_B Or FLAG_U
            cpu_p = cpu_p Or FLAG_I
            lo = BusCpuRead(&HFFFE&): hi = BusCpuRead(&HFFFF&)
            cpu_pc = (hi * 256 + lo) And &HFFFF&
        Case INS_NOP
            ' nothing
        Case INS_XXX
            ' illegal - nop
    End Select
    
    cyc = cyc + extra
    cpu_cycles = cpu_cycles + cyc
    CpuStep = cyc
End Function

Private Function DoBranch(ByVal addr As Long, ByVal cond As Boolean) As Long
    If Not cond Then DoBranch = 0: Exit Function
    Dim off As Long: off = BusCpuRead(addr)
    If off >= 128 Then off = off - 256   ' sign extend
    Dim np As Long: np = (cpu_pc + off) And &HFFFF&
    Dim ex As Long: ex = 1
    If (np And &HFF00&) <> (cpu_pc And &HFF00&) Then ex = 2
    cpu_pc = np
    DoBranch = ex
End Function

' ============================================================
' Bus - run one frame
' ============================================================
Private Sub BusRunFrame()
    ppu_frame_ready = 0
    Dim c As Long, i As Long
    Do While ppu_frame_ready = 0
        If bus_dma_transfer <> 0 Then
            If bus_dma_dummy <> 0 Then
                If (CLng(bus_system_cycles) And 1) <> 0 Then bus_dma_dummy = 0
            Else
                If (CLng(bus_system_cycles) And 1) = 0 Then
                    bus_dma_data = BusCpuRead(CLng(bus_dma_page) * 256& + CLng(bus_dma_addr))
                Else
                    ppu_oam(ppu_oam_addr) = bus_dma_data
                    ppu_oam_addr = (ppu_oam_addr + 1) And &HFF
                    bus_dma_addr = (bus_dma_addr + 1) And &HFF
                    If bus_dma_addr = 0 Then bus_dma_transfer = 0
                End If
            End If
            Call PpuStep: Call PpuStep: Call PpuStep
            bus_system_cycles = bus_system_cycles + 1
        Else
            c = CpuStep()
            For i = 1 To c
                Call PpuStep: Call PpuStep: Call PpuStep
                bus_system_cycles = bus_system_cycles + 1
            Next i
        End If
    Loop
End Sub

' ============================================================
' OpenGL context + renderer
' ============================================================
Private Function CreateGL46CoreContext(ByVal hWnd As LongPtr, ByVal hDC As LongPtr) As LongPtr
    LogMsg "CreateGL46CoreContext: start"
    Dim pfd As PIXELFORMATDESCRIPTOR
    pfd.nSize = LenB(pfd): pfd.nVersion = 1
    pfd.dwFlags = PFD_DRAW_TO_WINDOW Or PFD_SUPPORT_OPENGL Or PFD_DOUBLEBUFFER
    pfd.iPixelType = 0: pfd.cColorBits = 32: pfd.cDepthBits = 24: pfd.iLayerType = 0
    
    Dim iFormat As Long: iFormat = ChoosePixelFormat(hDC, pfd)
    If iFormat = 0 Then Err.Raise vbObjectError + 8000, , "ChoosePixelFormat failed"
    SetPixelFormat hDC, iFormat, pfd
    
    Dim hRC_old As LongPtr: hRC_old = wglCreateContext(hDC)
    If hRC_old = 0 Then Err.Raise vbObjectError + 8002, , "wglCreateContext failed"
    wglMakeCurrent hDC, hRC_old
    
    p_wglCreateContextAttribsARB = GetGLProc("wglCreateContextAttribsARB")
    If p_wglCreateContextAttribsARB = 0 Then Err.Raise vbObjectError + 8004, , "wglCreateContextAttribsARB not available"
    
    Dim attribs(0 To 8) As Long
    attribs(0) = WGL_CONTEXT_MAJOR_VERSION_ARB: attribs(1) = 4
    attribs(2) = WGL_CONTEXT_MINOR_VERSION_ARB: attribs(3) = 6
    attribs(4) = WGL_CONTEXT_PROFILE_MASK_ARB: attribs(5) = WGL_CONTEXT_CORE_PROFILE_BIT_ARB
    attribs(6) = WGL_CONTEXT_FLAGS_ARB: attribs(7) = 0
    attribs(8) = 0
    
    Dim hRC_new As LongPtr
    hRC_new = CallWindowProcW(p_wglCreateContextAttribsARB, hDC, 0, CLngPtr(VarPtr(attribs(0))), 0)
    If hRC_new = 0 Then Err.Raise vbObjectError + 8005, , "GL 4.6 core context creation failed"
    
    wglMakeCurrent hDC, hRC_new
    wglDeleteContext hRC_old
    
    Dim rc As RECT
    If GetClientRect(hWnd, rc) <> 0 Then glViewport 0, 0, rc.Right - rc.Left, rc.Bottom - rc.Top
    
    LogMsg "CreateGL46CoreContext: done"
    CreateGL46CoreContext = hRC_new
End Function

Private Sub LoadGLFunctions()
    LogMsg "LoadGLFunctions: start"
    
    ' Build the generic call thunk first (needed by GL_Call2/3/4)
    If p_thunkCallN = 0 Then
        p_thunkCallN = BuildThunk_CallN()
        LogMsg "ThunkCallN=" & Hex$(p_thunkCallN)
    End If
    
    LogMsg "GL_VENDOR=" & PtrToAnsiString(glGetString(GL_VENDOR))
    LogMsg "GL_VERSION=" & PtrToAnsiString(glGetString(GL_VERSION))
    
    p_glGenBuffers = GetGLProc("glGenBuffers")
    p_glBindBuffer = GetGLProc("glBindBuffer")
    p_glBufferData = GetGLProc("glBufferData")
    p_glGenVertexArrays = GetGLProc("glGenVertexArrays")
    p_glBindVertexArray = GetGLProc("glBindVertexArray")
    p_glDeleteVertexArrays = GetGLProc("glDeleteVertexArrays")
    p_glEnableVertexAttribArray = GetGLProc("glEnableVertexAttribArray")
    p_glVertexAttribPointer = GetGLProc("glVertexAttribPointer")
    p_glCreateShader = GetGLProc("glCreateShader")
    p_glShaderSource = GetGLProc("glShaderSource")
    p_glCompileShader = GetGLProc("glCompileShader")
    p_glGetShaderiv = GetGLProc("glGetShaderiv")
    p_glGetShaderInfoLog = GetGLProc("glGetShaderInfoLog")
    p_glCreateProgram = GetGLProc("glCreateProgram")
    p_glAttachShader = GetGLProc("glAttachShader")
    p_glLinkProgram = GetGLProc("glLinkProgram")
    p_glUseProgram = GetGLProc("glUseProgram")
    p_glGetProgramiv = GetGLProc("glGetProgramiv")
    p_glGetProgramInfoLog = GetGLProc("glGetProgramInfoLog")
    p_glDeleteShader = GetGLProc("glDeleteShader")
    p_glDeleteProgram = GetGLProc("glDeleteProgram")
    p_glDeleteBuffers = GetGLProc("glDeleteBuffers")
    p_glActiveTexture = GetGLProc("glActiveTexture")
    p_glGetUniformLocation = GetGLProc("glGetUniformLocation")
    p_glUniform1i = GetGLProc("glUniform1i")
    
    LogMsg "Proc glGenBuffers=" & Hex$(p_glGenBuffers)
    LogMsg "Proc glGenVertexArrays=" & Hex$(p_glGenVertexArrays)
    LogMsg "Proc glVertexAttribPointer=" & Hex$(p_glVertexAttribPointer)
    LogMsg "Proc glActiveTexture=" & Hex$(p_glActiveTexture)
    LogMsg "Proc glGetUniformLocation=" & Hex$(p_glGetUniformLocation)
    LogMsg "Proc glUniform1i=" & Hex$(p_glUniform1i)
    LogMsg "Proc glDeleteShader=" & Hex$(p_glDeleteShader)
    
    If p_glGenBuffers = 0 Or p_glBindBuffer = 0 Or p_glBufferData = 0 Then Err.Raise vbObjectError + 8100, , "VBO entry points missing"
    If p_glGenVertexArrays = 0 Or p_glBindVertexArray = 0 Then Err.Raise vbObjectError + 8101, , "VAO entry points missing"
    If p_glEnableVertexAttribArray = 0 Or p_glVertexAttribPointer = 0 Then Err.Raise vbObjectError + 8102, , "Vertex attrib entry points missing"
    If p_glCreateShader = 0 Or p_glCreateProgram = 0 Then Err.Raise vbObjectError + 8103, , "Shader entry points missing"
    If p_glActiveTexture = 0 Then Err.Raise vbObjectError + 8104, , "glActiveTexture missing"
    If p_glGetUniformLocation = 0 Or p_glUniform1i = 0 Then Err.Raise vbObjectError + 8105, , "Uniform entry points missing"
    
    ' Build thunk for glVertexAttribPointer (6 args)
    If p_thunkVAP = 0 Then
        p_thunkVAP = BuildThunk_VAP(p_glVertexAttribPointer)
        LogMsg "ThunkVAP=" & Hex$(p_thunkVAP)
    End If
    
    LogMsg "LoadGLFunctions: done"
End Sub

Private Function VertSrc() As String
    VertSrc = _
        "#version 460 core" & vbLf & _
        "layout(location = 0) in vec3 position;" & vbLf & _
        "layout(location = 1) in vec2 texcoord;" & vbLf & _
        "out vec2 v_texcoord;" & vbLf & _
        "void main() {" & vbLf & _
        "  v_texcoord = texcoord;" & vbLf & _
        "  gl_Position = vec4(position, 1.0);" & vbLf & _
        "}"
End Function

Private Function FragSrc() As String
    FragSrc = _
        "#version 460 core" & vbLf & _
        "in vec2 v_texcoord;" & vbLf & _
        "uniform sampler2D u_texture;" & vbLf & _
        "out vec4 out_color;" & vbLf & _
        "void main() {" & vbLf & _
        "  out_color = texture(u_texture, v_texcoord);" & vbLf & _
        "}"
End Function

Private Function GetShaderInfoLogStr(ByVal shader As Long) As String
    Dim logLen As Long
    Call GL_Call3(p_glGetShaderiv, shader, GL_INFO_LOG_LENGTH, VarPtr(logLen))
    If logLen <= 1 Then GetShaderInfoLogStr = "": Exit Function
    Dim b() As Byte: ReDim b(0 To logLen - 1)
    Dim outLen As Long
    Call GL_Call4(p_glGetShaderInfoLog, shader, logLen, VarPtr(outLen), VarPtr(b(0)))
    If outLen > 0 Then ReDim Preserve b(0 To outLen - 1)
    GetShaderInfoLogStr = StrConv(b, vbUnicode)
End Function

Private Function CompileShaderGL(ByVal shaderType As Long, ByVal src As String, ByVal tag As String) As Long
    Dim sh As Long: sh = CLng(GL_Call1(p_glCreateShader, shaderType))
    If sh = 0 Then Err.Raise vbObjectError + 7000, , "glCreateShader failed (" & tag & ")"
    
    Dim srcBytes() As Byte: srcBytes = AnsiZBytes(src)
    Dim pStr As LongPtr: pStr = VarPtr(srcBytes(0))
    Dim ppStr As LongPtr: ppStr = VarPtr(pStr)
    Call GL_Call4(p_glShaderSource, sh, 1, ppStr, 0)
    Call GL_Call1(p_glCompileShader, sh)
    
    Dim ok As Long
    Call GL_Call3(p_glGetShaderiv, sh, GL_COMPILE_STATUS, VarPtr(ok))
    LogMsg "CompileShader(" & tag & "): status=" & ok
    If ok = 0 Then
        LogMsg "ShaderInfoLog: " & GetShaderInfoLogStr(sh)
        Err.Raise vbObjectError + 7001, , "Shader compile failed (" & tag & ")"
    End If
    CompileShaderGL = sh
End Function

Private Sub InitRenderer()
    LogMsg "InitRenderer: start"
    
    ' Compile shaders and link program
    Dim vs As Long: vs = CompileShaderGL(GL_VERTEX_SHADER, VertSrc(), "VS")
    LogMsg "InitRenderer: vs=" & vs
    Dim fs As Long: fs = CompileShaderGL(GL_FRAGMENT_SHADER, FragSrc(), "FS")
    LogMsg "InitRenderer: fs=" & fs
    
    g_program = CLng(GL_Call0(p_glCreateProgram))
    LogMsg "InitRenderer: program=" & g_program
    Call GL_Call2(p_glAttachShader, g_program, vs)
    LogMsg "InitRenderer: attached vs"
    Call GL_Call2(p_glAttachShader, g_program, fs)
    LogMsg "InitRenderer: attached fs"
    Call GL_Call1(p_glLinkProgram, g_program)
    LogMsg "InitRenderer: linked"
    
    Dim ok As Long
    Call GL_Call3(p_glGetProgramiv, g_program, GL_LINK_STATUS, VarPtr(ok))
    LogMsg "InitRenderer: link status=" & ok
    If ok = 0 Then Err.Raise vbObjectError + 8201, , "Program link failed"
    
    LogMsg "InitRenderer: deleting shaders..."
    If p_glDeleteShader <> 0 Then
        Call GL_Call1(p_glDeleteShader, vs)
        LogMsg "InitRenderer: deleted vs"
        Call GL_Call1(p_glDeleteShader, fs)
        LogMsg "InitRenderer: deleted fs"
    End If
    
    ' ---- Create VAO ----
    LogMsg "InitRenderer: creating VAO..."
    Dim vaoOut As Long: vaoOut = 0
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenVertexArrays)
    LogMsg "InitRenderer: thunkGen2(VAO)=" & Hex$(p_thunkGen2)
    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(vaoOut)), 0
    LogMsg "InitRenderer: vao=" & vaoOut
    If vaoOut = 0 Then Err.Raise vbObjectError + 8300, , "glGenVertexArrays failed"
    g_vao = vaoOut
    Call GL_Call1(p_glBindVertexArray, g_vao)
    LogMsg "InitRenderer: VAO bound"
    
    ' ---- Create VBO ----
    LogMsg "InitRenderer: creating VBO..."
    ' Fullscreen quad: 4 vertices, 5 floats each (x,y,z,u,v) = 80 bytes
    Dim vertices(0 To 19) As Single
    vertices(0) = -1!: vertices(1) = 1!: vertices(2) = 0!: vertices(3) = 0!: vertices(4) = 0!
    vertices(5) = 1!: vertices(6) = 1!: vertices(7) = 0!: vertices(8) = 1!: vertices(9) = 0!
    vertices(10) = -1!: vertices(11) = -1!: vertices(12) = 0!: vertices(13) = 0!: vertices(14) = 1!
    vertices(15) = 1!: vertices(16) = -1!: vertices(17) = 0!: vertices(18) = 1!: vertices(19) = 1!
    
    Dim bufOut As Long: bufOut = 0
    If p_thunkGen2 <> 0 Then VirtualFree p_thunkGen2, 0, MEM_RELEASE: p_thunkGen2 = 0
    p_thunkGen2 = BuildThunk_Gen2(p_glGenBuffers)
    LogMsg "InitRenderer: thunkGen2(VBO)=" & Hex$(p_thunkGen2)
    CallWindowProcW p_thunkGen2, g_hWnd, 1, CLngPtr(VarPtr(bufOut)), 0
    LogMsg "InitRenderer: vbo=" & bufOut
    If bufOut = 0 Then Err.Raise vbObjectError + 8301, , "glGenBuffers failed"
    g_vbo = bufOut
    
    Call GL_Call2(p_glBindBuffer, GL_ARRAY_BUFFER, g_vbo)
    LogMsg "InitRenderer: VBO bound"
    Call GL_Call4(p_glBufferData, GL_ARRAY_BUFFER, CLngPtr(80), CLngPtr(VarPtr(vertices(0))), GL_STATIC_DRAW)
    LogMsg "InitRenderer: VBO data uploaded"
    
    ' ---- Vertex attributes via thunk ----
    LogMsg "InitRenderer: setting attrib 0..."
    Call GL_Call1(p_glEnableVertexAttribArray, 0)
    Dim a As VAPArgs
    a.a1_index = 0: a.a2_size = 3: a.a3_type = GL_FLOAT: a.a4_norm = GL_FALSE_GL
    a.a5_stride = 20: a.a6_ptr = 0
    CallWindowProcW p_thunkVAP, g_hWnd, 0, CLngPtr(VarPtr(a)), 0
    LogMsg "InitRenderer: attrib 0 set"
    
    LogMsg "InitRenderer: setting attrib 1..."
    Call GL_Call1(p_glEnableVertexAttribArray, 1)
    a.a1_index = 1: a.a2_size = 2: a.a3_type = GL_FLOAT: a.a4_norm = GL_FALSE_GL
    a.a5_stride = 20: a.a6_ptr = 12
    CallWindowProcW p_thunkVAP, g_hWnd, 0, CLngPtr(VarPtr(a)), 0
    LogMsg "InitRenderer: attrib 1 set"
    
    ' ---- Create texture ----
    LogMsg "InitRenderer: creating texture..."
    glGenTextures 1, g_texture
    LogMsg "InitRenderer: texture=" & g_texture
    glBindTexture GL_TEXTURE_2D, g_texture
    LogMsg "InitRenderer: texture bound"
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0
    glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0
    LogMsg "InitRenderer: tex params set"
    
    ' Allocate texture storage (NULL data)
    LogMsg "InitRenderer: calling glTexImage2D..."
    glTexImage2D GL_TEXTURE_2D, 0, GL_RGBA8, NES_WIDTH, NES_HEIGHT, 0, GL_BGRA, GL_UNSIGNED_BYTE, 0
    LogMsg "InitRenderer: glTexImage2D done"
    
    ' ---- Set uniform ----
    LogMsg "InitRenderer: setting uniform..."
    Call GL_Call1(p_glUseProgram, g_program)
    LogMsg "InitRenderer: program active"
    Dim uNameBytes() As Byte: uNameBytes = AnsiZBytes("u_texture")
    Dim uLoc As Long: uLoc = CLng(GL_Call2(p_glGetUniformLocation, g_program, VarPtr(uNameBytes(0))))
    LogMsg "InitRenderer: uniform loc=" & uLoc
    Call GL_Call2(p_glUniform1i, uLoc, 0)
    LogMsg "InitRenderer: uniform set"
    
    ' Unbind
    Call GL_Call1(p_glBindVertexArray, 0)
    Call GL_Call2(p_glBindBuffer, GL_ARRAY_BUFFER, 0)
    
    LogMsg "InitRenderer: done"
End Sub

Private Sub RenderFrame()
    glClearColor 0!, 0!, 0!, 1!
    glClear GL_COLOR_BUFFER_BIT
    
    Call GL_Call1(p_glUseProgram, g_program)
    Call GL_Call1(p_glActiveTexture, GL_TEXTURE0)
    glBindTexture GL_TEXTURE_2D, g_texture
    
    ' Upload framebuffer to texture
    glTexSubImage2D GL_TEXTURE_2D, 0, 0, 0, NES_WIDTH, NES_HEIGHT, GL_BGRA, GL_UNSIGNED_BYTE, VarPtr(ppu_framebuffer(0))
    
    Call GL_Call1(p_glBindVertexArray, g_vao)
    glDrawArrays GL_TRIANGLE_STRIP, 0, 4
    Call GL_Call1(p_glBindVertexArray, 0)
    
    SwapBuffers g_hDC
    
    If Not g_firstFrame Then
        LogMsg "RenderFrame: first frame rendered OK"
        g_firstFrame = True
    End If
End Sub

' ============================================================
' Input
' ============================================================
Private Sub UpdateInput()
    Dim s As Byte: s = 0
    Const VK_RSHIFT As Long = &HA1&
    If (GetAsyncKeyState(vbKeyZ) And &H8000) <> 0 Then s = s Or BTN_A
    If (GetAsyncKeyState(vbKeyX) And &H8000) <> 0 Then s = s Or BTN_B
    If (GetAsyncKeyState(VK_RSHIFT) And &H8000) <> 0 Then s = s Or BTN_SELECT
    If (GetAsyncKeyState(vbKeyReturn) And &H8000) <> 0 Then s = s Or BTN_START
    If (GetAsyncKeyState(vbKeyUp) And &H8000) <> 0 Then s = s Or BTN_UP
    If (GetAsyncKeyState(vbKeyDown) And &H8000) <> 0 Then s = s Or BTN_DOWN
    If (GetAsyncKeyState(vbKeyLeft) And &H8000) <> 0 Then s = s Or BTN_LEFT
    If (GetAsyncKeyState(vbKeyRight) And &H8000) <> 0 Then s = s Or BTN_RIGHT
    bus_controller(0) = s
End Sub

' ============================================================
' Window Proc
' ============================================================
Public Function WindowProc(ByVal hWnd As LongPtr, ByVal uMsg As Long, ByVal wParam As LongPtr, ByVal lParam As LongPtr) As LongPtr
    Select Case uMsg
        Case WM_CLOSE
            DestroyWindow hWnd
            WindowProc = 0: Exit Function
        Case WM_DESTROY
            PostQuitMessage 0
            g_running = False
            WindowProc = 0: Exit Function
        Case WM_KEYDOWN
            If CLng(wParam) = VK_ESCAPE Then
                g_running = False
                PostQuitMessage 0
                WindowProc = 0: Exit Function
            End If
        Case WM_SIZE
            If g_hRC <> 0 And g_hDC <> 0 Then
                Dim rc As RECT
                If GetClientRect(hWnd, rc) <> 0 Then
                    Dim w As Long: w = rc.Right - rc.Left
                    Dim h As Long: h = rc.Bottom - rc.Top
                    If w > 0 And h > 0 Then
                        wglMakeCurrent g_hDC, g_hRC
                        glViewport 0, 0, w, h
                    End If
                End If
            End If
            WindowProc = 0: Exit Function
    End Select
    WindowProc = DefWindowProcW(hWnd, uMsg, wParam, lParam)
End Function

Private Sub DisableOpenGL()
    If g_hRC <> 0 Then wglMakeCurrent 0, 0: wglDeleteContext g_hRC
    If g_hDC <> 0 Then ReleaseDC g_hWnd, g_hDC
End Sub

' ============================================================
' Main
' ============================================================
Public Sub Main()
    LogOpen
    On Error GoTo EH
    LogMsg "Main: start"
    
    ' Init tables
    InitPalette
    InitOpcodeTable
    
    ' Load ROM
    Dim romPath As String
    romPath = ThisWorkbook.Path & "\triangle.nes"
    LogMsg "Loading ROM: " & romPath
    
    If Not CartridgeLoad(romPath) Then
        MsgBox "Failed to load ROM: " & romPath, vbCritical
        GoTo FIN
    End If
    
    ' Create window
    g_className = "NES_VBA_" & Format$(Timer * 1000, "0")
    Dim hInstance As LongPtr: hInstance = GetModuleHandleW(0)
    
    Dim wcex As WNDCLASSEXW
    wcex.cbSize = LenB(wcex)
    wcex.style = CS_HREDRAW Or CS_VREDRAW Or CS_OWNDC
    wcex.lpfnWndProc = VBA.CLngPtr(AddressOf WindowProc)
    wcex.hInstance = hInstance
    wcex.hIcon = LoadIconW(0, IDI_APPLICATION)
    wcex.hCursor = LoadCursorW(0, IDC_ARROW)
    wcex.hbrBackground = 0
    wcex.lpszClassName = StrPtr(g_className)
    wcex.hIconSm = LoadIconW(0, IDI_APPLICATION)
    
    If RegisterClassExW(wcex) = 0 Then
        MsgBox "RegisterClassExW failed.", vbCritical
        GoTo FIN
    End If
    
    Dim rc As RECT
    rc.Left = 0: rc.Top = 0: rc.Right = WINDOW_WIDTH: rc.Bottom = WINDOW_HEIGHT
    Dim wStyle As Long: wStyle = WS_OVERLAPPEDWINDOW And (Not (WS_THICKFRAME Or WS_MAXIMIZEBOX))
    AdjustWindowRect rc, wStyle, 0
    
    g_hWnd = CreateWindowExW(0, StrPtr(g_className), StrPtr("NES Emulator (VBA + OpenGL 4.6)"), _
        wStyle, CW_USEDEFAULT, CW_USEDEFAULT, _
        rc.Right - rc.Left, rc.Bottom - rc.Top, 0, 0, hInstance, 0)
    
    If g_hWnd = 0 Then
        MsgBox "CreateWindowExW failed.", vbCritical
        GoTo FIN
    End If
    
    ShowWindow g_hWnd, SW_SHOWDEFAULT
    UpdateWindow g_hWnd
    
    g_hDC = GetDC(g_hWnd)
    If g_hDC = 0 Then
        MsgBox "GetDC failed.", vbCritical
        GoTo FIN
    End If
    
    g_hRC = CreateGL46CoreContext(g_hWnd, g_hDC)
    LoadGLFunctions
    InitRenderer
    LogMsg "Main: renderer initialized"
    
    ' Init NES
    Dim j As Long
    For j = 0 To &H7FF: bus_ram(j) = 0: Next j
    bus_controller(0) = 0: bus_controller(1) = 0
    bus_controller_latch(0) = 0: bus_controller_latch(1) = 0
    bus_controller_strobe = 0
    bus_dma_transfer = 0: bus_dma_dummy = 0
    bus_system_cycles = 0
    
    PpuReset
    CpuReset
    
    LogMsg "NES initialized. PC=" & Hex$(cpu_pc)
    g_firstFrame = False
    
    ' Main loop
    g_running = True
    Dim msg As MSGW
    Dim freq As LARGE_INTEGER, last As LARGE_INTEGER, now As LARGE_INTEGER
    Dim accum As Double
    Dim frame_us As Double: frame_us = 1000000# / 60.0988
    
    QueryPerformanceFrequency freq
    QueryPerformanceCounter last
    accum = 0
    
    Dim frameNum As Long: frameNum = 0
    
    LogMsg "Main: entering loop"
    Do While g_running
        ' Process messages
        Do While PeekMessageW(msg, 0, 0, 0, PM_REMOVE) <> 0
            If msg.message = WM_QUIT Then g_running = False: Exit Do
            TranslateMessage msg
            DispatchMessageW msg
        Loop
        If Not g_running Then Exit Do
        
        QueryPerformanceCounter now
        Dim elapsed As Double
        elapsed = CDbl(now.QuadPart - last.QuadPart) * 1000000# / CDbl(freq.QuadPart)
        last = now
        accum = accum + elapsed
        
        If accum >= frame_us Then
            If accum > frame_us * 3 Then accum = frame_us
            accum = accum - frame_us
            
            UpdateInput
            
            If frameNum = 0 Then LogMsg "Main: running first NES frame..."
            BusRunFrame
            If frameNum = 0 Then LogMsg "Main: first NES frame done, rendering..."
            
            wglMakeCurrent g_hDC, g_hRC
            RenderFrame
            
            frameNum = frameNum + 1
            If (frameNum Mod 60) = 0 Then
                LogMsg "Frame " & frameNum
                DoEvents
            End If
        Else
            Sleep 1
        End If
    Loop

FIN:
    LogMsg "Cleanup: start"
    On Error Resume Next
    
    ' Cleanup GL
    If g_texture <> 0 Then glDeleteTextures 1, g_texture: g_texture = 0
    FreeThunks
    DisableOpenGL
    If g_hWnd <> 0 Then DestroyWindow g_hWnd: g_hWnd = 0
    
    g_program = 0: g_vao = 0: g_vbo = 0
    g_hRC = 0: g_hDC = 0
    
    LogMsg "Cleanup: done"
    LogMsg "Main: end"
    LogClose
    Exit Sub

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    MsgBox "Error: " & Err.Number & " - " & Err.Description, vbCritical
    Resume FIN
End Sub
