Attribute VB_Name = "NES_Emulator_Excel"
Option Explicit

' ============================================================
'  64-bit Excel VBA - NES Emulator (Worksheet Cell Rendering)
'
'  Port of a C NES emulator to VBA.
'  Renders NES framebuffer (256x240) to Excel cells as pixels.
'
'  Features:
'    - MOS 6502 CPU (all official instructions)
'    - PPU with background + sprite rendering
'    - Mapper 0 (NROM) and Mapper 66 (GxROM)
'    - Excel worksheet cell rendering (1 cell = 1 pixel)
'
'  Usage:
'    Place triangle.nes in the same folder as this Excel file.
'    Run SetupSheet to prepare the worksheet.
'    Run Main to load the ROM and render.
'    Run AdvanceFrame to step forward one frame.
'
'  Debug log: C:\TEMP\debug.log
' ============================================================

' -------------------------------------------------------
' Win32 API (minimal - for file I/O and logging)
' -------------------------------------------------------
#If VBA7 Then
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
    Private Declare PtrSafe Function QueryPerformanceFrequency Lib "kernel32" (ByRef lpFrequency As LongLong) As Long
    Private Declare PtrSafe Function QueryPerformanceCounter Lib "kernel32" (ByRef lpPerformanceCount As LongLong) As Long
#End If

Private Const GENERIC_WRITE As Long = &H40000000
Private Const FILE_SHARE_READ As Long = &H1
Private Const FILE_SHARE_WRITE As Long = &H2
Private Const CREATE_ALWAYS As Long = 2
Private Const FILE_ATTRIBUTE_NORMAL As Long = &H80

' -------------------------------------------------------
' NES constants
' -------------------------------------------------------
Private Const NES_WIDTH As Long = 256
Private Const NES_HEIGHT As Long = 240

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
' NES CPU state
' -------------------------------------------------------
Private cpu_a As Byte
Private cpu_x As Byte
Private cpu_y As Byte
Private cpu_sp As Byte
Private cpu_pc As Long
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
Private ppu_v As Long
Private ppu_t As Long
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
Private ppu_framebuffer() As Long

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
' Opcode table
' -------------------------------------------------------
Private op_ins(0 To 255) As Byte
Private op_mode(0 To 255) As Byte
Private op_cyc(0 To 255) As Byte
Private op_page(0 To 255) As Byte
Private g_opTableInit As Boolean

' -------------------------------------------------------
' NES Palette (ARGB format: &HAARRGGBB)
' -------------------------------------------------------
Private nes_pal(0 To 63) As Long

' -------------------------------------------------------
' Logger & state
' -------------------------------------------------------
Private g_log As LongPtr
Private g_nesReady As Boolean
Private g_totalFrames As Long

' ============================================================
' Logger
' ============================================================
Private Sub LogOpen()
    On Error Resume Next
    CreateDirectoryW StrPtr("C:\TEMP"), 0
    g_log = CreateFileW(StrPtr("C:\TEMP\debug.log"), GENERIC_WRITE, FILE_SHARE_READ Or FILE_SHARE_WRITE, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0)
    If g_log = 0 Or g_log = -1 Then g_log = 0
    LogMsg "==== NES EMULATOR (EXCEL CELL) LOG START ===="
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
    Dim line As String: line = Format$(now, "yyyy-mm-dd hh:nn:ss") & " | " & s & vbCrLf
    Dim b() As Byte: b = StrConv(line, vbFromUnicode)
    Dim written As Long
    WriteFile g_log, b(0), UBound(b) + 1, written, 0
    FlushFileBuffers g_log
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
    Dim i As Long
    For i = 0 To 31: nes_pal(i) = nes_pal(i) Or &HFF000000: Next i
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
    For i = 0 To 255: SetOp i, INS_XXX, AM_IMP, 2, 0: Next i
    
    SetOp &H0, INS_BRK, AM_IMP, 7, 0: SetOp &H1, INS_ORA, AM_IZX, 6, 0
    SetOp &H5, INS_ORA, AM_ZPG, 3, 0: SetOp &H6, INS_ASL, AM_ZPG, 5, 0
    SetOp &H8, INS_PHP, AM_IMP, 3, 0: SetOp &H9, INS_ORA, AM_IMM, 2, 0: SetOp &HA, INS_ASL, AM_ACC, 2, 0
    SetOp &HD, INS_ORA, AM_ABS, 4, 0: SetOp &HE, INS_ASL, AM_ABS, 6, 0
    SetOp &H10, INS_BPL, AM_REL, 2, 0: SetOp &H11, INS_ORA, AM_IZY, 5, 1
    SetOp &H15, INS_ORA, AM_ZPX, 4, 0: SetOp &H16, INS_ASL, AM_ZPX, 6, 0
    SetOp &H18, INS_CLC, AM_IMP, 2, 0: SetOp &H19, INS_ORA, AM_ABY, 4, 1
    SetOp &H1D, INS_ORA, AM_ABX, 4, 1: SetOp &H1E, INS_ASL, AM_ABX, 7, 0
    SetOp &H20, INS_JSR, AM_ABS, 6, 0: SetOp &H21, INS_AND, AM_IZX, 6, 0
    SetOp &H24, INS_BIT, AM_ZPG, 3, 0: SetOp &H25, INS_AND, AM_ZPG, 3, 0: SetOp &H26, INS_ROL, AM_ZPG, 5, 0
    SetOp &H28, INS_PLP, AM_IMP, 4, 0: SetOp &H29, INS_AND, AM_IMM, 2, 0: SetOp &H2A, INS_ROL, AM_ACC, 2, 0
    SetOp &H2C, INS_BIT, AM_ABS, 4, 0: SetOp &H2D, INS_AND, AM_ABS, 4, 0: SetOp &H2E, INS_ROL, AM_ABS, 6, 0
    SetOp &H30, INS_BMI, AM_REL, 2, 0: SetOp &H31, INS_AND, AM_IZY, 5, 1
    SetOp &H35, INS_AND, AM_ZPX, 4, 0: SetOp &H36, INS_ROL, AM_ZPX, 6, 0
    SetOp &H38, INS_SEC, AM_IMP, 2, 0: SetOp &H39, INS_AND, AM_ABY, 4, 1
    SetOp &H3D, INS_AND, AM_ABX, 4, 1: SetOp &H3E, INS_ROL, AM_ABX, 7, 0
    SetOp &H40, INS_RTI, AM_IMP, 6, 0: SetOp &H41, INS_EOR, AM_IZX, 6, 0
    SetOp &H45, INS_EOR, AM_ZPG, 3, 0: SetOp &H46, INS_LSR, AM_ZPG, 5, 0
    SetOp &H48, INS_PHA, AM_IMP, 3, 0: SetOp &H49, INS_EOR, AM_IMM, 2, 0: SetOp &H4A, INS_LSR, AM_ACC, 2, 0
    SetOp &H4C, INS_JMP, AM_ABS, 3, 0: SetOp &H4D, INS_EOR, AM_ABS, 4, 0: SetOp &H4E, INS_LSR, AM_ABS, 6, 0
    SetOp &H50, INS_BVC, AM_REL, 2, 0: SetOp &H51, INS_EOR, AM_IZY, 5, 1
    SetOp &H55, INS_EOR, AM_ZPX, 4, 0: SetOp &H56, INS_LSR, AM_ZPX, 6, 0
    SetOp &H58, INS_CLI, AM_IMP, 2, 0: SetOp &H59, INS_EOR, AM_ABY, 4, 1
    SetOp &H5D, INS_EOR, AM_ABX, 4, 1: SetOp &H5E, INS_LSR, AM_ABX, 7, 0
    SetOp &H60, INS_RTS, AM_IMP, 6, 0: SetOp &H61, INS_ADC, AM_IZX, 6, 0
    SetOp &H65, INS_ADC, AM_ZPG, 3, 0: SetOp &H66, INS_ROR, AM_ZPG, 5, 0
    SetOp &H68, INS_PLA, AM_IMP, 4, 0: SetOp &H69, INS_ADC, AM_IMM, 2, 0: SetOp &H6A, INS_ROR, AM_ACC, 2, 0
    SetOp &H6C, INS_JMP, AM_IND, 5, 0: SetOp &H6D, INS_ADC, AM_ABS, 4, 0: SetOp &H6E, INS_ROR, AM_ABS, 6, 0
    SetOp &H70, INS_BVS, AM_REL, 2, 0: SetOp &H71, INS_ADC, AM_IZY, 5, 1
    SetOp &H75, INS_ADC, AM_ZPX, 4, 0: SetOp &H76, INS_ROR, AM_ZPX, 6, 0
    SetOp &H78, INS_SEI, AM_IMP, 2, 0: SetOp &H79, INS_ADC, AM_ABY, 4, 1
    SetOp &H7D, INS_ADC, AM_ABX, 4, 1: SetOp &H7E, INS_ROR, AM_ABX, 7, 0
    SetOp &H81, INS_STA, AM_IZX, 6, 0
    SetOp &H84, INS_STY, AM_ZPG, 3, 0: SetOp &H85, INS_STA, AM_ZPG, 3, 0: SetOp &H86, INS_STX, AM_ZPG, 3, 0
    SetOp &H88, INS_DEY, AM_IMP, 2, 0: SetOp &H8A, INS_TXA, AM_IMP, 2, 0
    SetOp &H8C, INS_STY, AM_ABS, 4, 0: SetOp &H8D, INS_STA, AM_ABS, 4, 0: SetOp &H8E, INS_STX, AM_ABS, 4, 0
    SetOp &H90, INS_BCC, AM_REL, 2, 0: SetOp &H91, INS_STA, AM_IZY, 6, 0
    SetOp &H94, INS_STY, AM_ZPX, 4, 0: SetOp &H95, INS_STA, AM_ZPX, 4, 0: SetOp &H96, INS_STX, AM_ZPY, 4, 0
    SetOp &H98, INS_TYA, AM_IMP, 2, 0: SetOp &H99, INS_STA, AM_ABY, 5, 0: SetOp &H9A, INS_TXS, AM_IMP, 2, 0
    SetOp &H9D, INS_STA, AM_ABX, 5, 0
    SetOp &HA0, INS_LDY, AM_IMM, 2, 0: SetOp &HA1, INS_LDA, AM_IZX, 6, 0: SetOp &HA2, INS_LDX, AM_IMM, 2, 0
    SetOp &HA4, INS_LDY, AM_ZPG, 3, 0: SetOp &HA5, INS_LDA, AM_ZPG, 3, 0: SetOp &HA6, INS_LDX, AM_ZPG, 3, 0
    SetOp &HA8, INS_TAY, AM_IMP, 2, 0: SetOp &HA9, INS_LDA, AM_IMM, 2, 0: SetOp &HAA, INS_TAX, AM_IMP, 2, 0
    SetOp &HAC, INS_LDY, AM_ABS, 4, 0: SetOp &HAD, INS_LDA, AM_ABS, 4, 0: SetOp &HAE, INS_LDX, AM_ABS, 4, 0
    SetOp &HB0, INS_BCS, AM_REL, 2, 0: SetOp &HB1, INS_LDA, AM_IZY, 5, 1
    SetOp &HB4, INS_LDY, AM_ZPX, 4, 0: SetOp &HB5, INS_LDA, AM_ZPX, 4, 0: SetOp &HB6, INS_LDX, AM_ZPY, 4, 0
    SetOp &HB8, INS_CLV, AM_IMP, 2, 0: SetOp &HB9, INS_LDA, AM_ABY, 4, 1: SetOp &HBA, INS_TSX, AM_IMP, 2, 0
    SetOp &HBC, INS_LDY, AM_ABX, 4, 1: SetOp &HBD, INS_LDA, AM_ABX, 4, 1: SetOp &HBE, INS_LDX, AM_ABY, 4, 1
    SetOp &HC0, INS_CPY, AM_IMM, 2, 0: SetOp &HC1, INS_CMP, AM_IZX, 6, 0
    SetOp &HC4, INS_CPY, AM_ZPG, 3, 0: SetOp &HC5, INS_CMP, AM_ZPG, 3, 0: SetOp &HC6, INS_DEC, AM_ZPG, 5, 0
    SetOp &HC8, INS_INY, AM_IMP, 2, 0: SetOp &HC9, INS_CMP, AM_IMM, 2, 0: SetOp &HCA, INS_DEX, AM_IMP, 2, 0
    SetOp &HCC, INS_CPY, AM_ABS, 4, 0: SetOp &HCD, INS_CMP, AM_ABS, 4, 0: SetOp &HCE, INS_DEC, AM_ABS, 6, 0
    SetOp &HD0, INS_BNE, AM_REL, 2, 0: SetOp &HD1, INS_CMP, AM_IZY, 5, 1
    SetOp &HD5, INS_CMP, AM_ZPX, 4, 0: SetOp &HD6, INS_DEC, AM_ZPX, 6, 0
    SetOp &HD8, INS_CLD, AM_IMP, 2, 0: SetOp &HD9, INS_CMP, AM_ABY, 4, 1
    SetOp &HDD, INS_CMP, AM_ABX, 4, 1: SetOp &HDE, INS_DEC, AM_ABX, 7, 0
    SetOp &HE0, INS_CPX, AM_IMM, 2, 0: SetOp &HE1, INS_SBC, AM_IZX, 6, 0
    SetOp &HE4, INS_CPX, AM_ZPG, 3, 0: SetOp &HE5, INS_SBC, AM_ZPG, 3, 0: SetOp &HE6, INS_INC, AM_ZPG, 5, 0
    SetOp &HE8, INS_INX, AM_IMP, 2, 0: SetOp &HE9, INS_SBC, AM_IMM, 2, 0: SetOp &HEA, INS_NOP, AM_IMP, 2, 0
    SetOp &HEC, INS_CPX, AM_ABS, 4, 0: SetOp &HED, INS_SBC, AM_ABS, 4, 0: SetOp &HEE, INS_INC, AM_ABS, 6, 0
    SetOp &HF0, INS_BEQ, AM_REL, 2, 0: SetOp &HF1, INS_SBC, AM_IZY, 5, 1
    SetOp &HF5, INS_SBC, AM_ZPX, 4, 0: SetOp &HF6, INS_INC, AM_ZPX, 6, 0
    SetOp &HF8, INS_SED, AM_IMP, 2, 0: SetOp &HF9, INS_SBC, AM_ABY, 4, 1
    SetOp &HFD, INS_SBC, AM_ABX, 4, 1: SetOp &HFE, INS_INC, AM_ABX, 7, 0
    g_opTableInit = True
End Sub

' ============================================================
' Cartridge
' ============================================================
Private Function CartridgeLoad(ByVal filename As String) As Boolean
    CartridgeLoad = False
    Dim fn As Integer: fn = FreeFile
    On Error GoTo LoadErr
    Open filename For Binary Access Read As #fn
    Dim hdr(0 To 15) As Byte
    Get #fn, , hdr
    If hdr(0) <> &H4E Or hdr(1) <> &H45 Or hdr(2) <> &H53 Or hdr(3) <> &H1A Then
        LogMsg "Error: Invalid iNES file": Close #fn: Exit Function
    End If
    cart_mapper = (hdr(7) And &HF0) Or (hdr(6) \ 16)
    If cart_mapper <> MAPPER_NROM And cart_mapper <> MAPPER_GXROM Then
        LogMsg "Error: Only Mapper 0 and 66 supported (got " & cart_mapper & ")": Close #fn: Exit Function
    End If
    If (hdr(6) And &H8) <> 0 Then
        cart_mirror = MIRROR_FOUR_SCREEN
    ElseIf (hdr(6) And &H1) <> 0 Then
        cart_mirror = MIRROR_VERTICAL
    Else
        cart_mirror = MIRROR_HORIZONTAL
    End If
    If (hdr(6) And &H4) <> 0 Then
        Dim dummy(0 To 511) As Byte: Get #fn, , dummy
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
        cart_has_chr_ram = 1
    End If
    Close #fn
    cart_prg_bank_select = 0: cart_chr_bank_select = 0
    LogMsg "ROM: PRG=" & (cart_prg_size \ 1024) & "KB CHR=" & (cart_chr_size \ 1024) & "KB Mapper=" & cart_mapper & " Mirror=" & cart_mirror
    CartridgeLoad = True
    Exit Function
LoadErr:
    LogMsg "Error loading ROM: " & Err.Description
    On Error Resume Next: Close #fn: CartridgeLoad = False
End Function

Private Function CartridgePrgAddr(ByVal addr As Long) As Long
    If cart_mapper = MAPPER_GXROM Then
        Dim bc As Long: bc = cart_prg_size \ &H8000
        Dim bk As Long: If bc > 0 Then bk = (cart_prg_bank_select Mod bc) Else bk = 0
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
        Dim bk As Long: If bc > 0 Then bk = (cart_chr_bank_select Mod bc) Else bk = 0
        CartridgeChrAddr = bk * &H2000 + addr
    Else
        CartridgeChrAddr = addr
    End If
End Function

Private Function CartridgeCpuRead(ByVal addr As Long) As Byte
    If addr >= &H8000& Then
        Dim m As Long: m = CartridgePrgAddr(addr)
        If m >= 0 And m <= UBound(cart_prg_rom) Then CartridgeCpuRead = cart_prg_rom(m) Else CartridgeCpuRead = 0
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
            If ca <= UBound(cart_chr_rom) Then CartridgePpuRead = cart_chr_rom(ca) Else CartridgePpuRead = 0
        End If
    Else
        CartridgePpuRead = 0
    End If
End Function

Private Sub CartridgePpuWrite(ByVal addr As Long, ByVal v As Byte)
    If addr < &H2000& And cart_has_chr_ram = 1 Then
        cart_chr_ram(CartridgeChrAddr(addr) And &H1FFF&) = v
    End If
End Sub

' ============================================================
' PPU
' ============================================================
Private Function MirrorNametable(ByVal addr As Long) As Long
    addr = (addr - &H2000&) And &HFFF&
    Select Case cart_mirror
        Case MIRROR_HORIZONTAL
            If addr < &H800& Then MirrorNametable = addr And &H3FF& Else MirrorNametable = &H400& + (addr And &H3FF&)
        Case MIRROR_VERTICAL: MirrorNametable = addr And &H7FF&
        Case MIRROR_SINGLE_LO: MirrorNametable = addr And &H3FF&
        Case MIRROR_SINGLE_HI: MirrorNametable = &H400& + (addr And &H3FF&)
        Case Else: MirrorNametable = addr And &H7FF&
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
            ppu_nmi_occurred = 0: ppu_w = 0
        Case 4: result = ppu_oam(ppu_oam_addr)
        Case 7
            result = ppu_data_buf: ppu_data_buf = PpuRead(ppu_v)
            If (ppu_v And &H3FFF&) >= &H3F00& Then result = ppu_data_buf: ppu_data_buf = PpuRead(ppu_v - &H1000&)
            If (ppu_ctrl And PPUCTRL_VRAM_INC) <> 0 Then ppu_v = (ppu_v + 32) And &H7FFF& Else ppu_v = (ppu_v + 1) And &H7FFF&
    End Select
    PpuRegRead = result
End Function

Private Sub PpuRegWrite(ByVal reg As Long, ByVal v As Byte)
    Select Case (reg And 7)
        Case 0
            ppu_ctrl = v
            If (v And PPUCTRL_NMI_ENABLE) <> 0 Then ppu_nmi_output = 1 Else ppu_nmi_output = 0
            ppu_t = (ppu_t And &HF3FF&) Or (CLng(v And &H3) * &H400&)
        Case 1: ppu_mask = v
        Case 3: ppu_oam_addr = v
        Case 4: ppu_oam(ppu_oam_addr) = v: ppu_oam_addr = (ppu_oam_addr + 1) And &HFF
        Case 5
            If ppu_w = 0 Then
                ppu_t = (ppu_t And &HFFE0&) Or (CLng(v) \ 8): ppu_fine_x = v And &H7: ppu_w = 1
            Else
                ppu_t = (ppu_t And &H8C1F&) Or (CLng(v And &H7) * &H1000&) Or ((CLng(v) \ 8) * 32): ppu_w = 0
            End If
        Case 6
            If ppu_w = 0 Then
                ppu_t = (ppu_t And &HFF&) Or (CLng(v And &H3F) * &H100&): ppu_w = 1
            Else
                ppu_t = (ppu_t And &HFF00&) Or CLng(v): ppu_v = ppu_t: ppu_w = 0
            End If
        Case 7
            PpuWrite ppu_v, v
            If (ppu_ctrl And PPUCTRL_VRAM_INC) <> 0 Then ppu_v = (ppu_v + 32) And &H7FFF& Else ppu_v = (ppu_v + 1) And &H7FFF&
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
    If (ppu_v And &H1F&) = 31 Then ppu_v = ppu_v And (Not &H1F&): ppu_v = ppu_v Xor &H400& Else ppu_v = ppu_v + 1
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
            Dim pb As Long: If (ppu_ctrl And PPUCTRL_BG_ADDR) <> 0 Then pb = &H1000& Else pb = 0
            Dim patAddr As Long: patAddr = pb + CLng(tile) * 16 + ((v \ &H1000&) And 7)
            Dim lo As Byte: lo = PpuRead(patAddr)
            Dim hi As Byte: hi = PpuRead(patAddr + 8)
            Dim bitPos As Long: bitPos = 7 - fx
            pixel = ((lo \ (2 ^ bitPos)) And 1) Or (((hi \ (2 ^ bitPos)) And 1) * 2)
        End If
        bg_px(x) = pixel: bg_pal(x) = pal
        If fx = 7 Then fx = 0: IncrementX: v = ppu_v Else fx = fx + 1
    Next x
End Sub

Private Sub RenderSprites(ByVal scanline As Long, ByRef bg_px() As Byte, ByRef bg_pal() As Byte, ByVal lineOffset As Long)
    Dim show_spr As Boolean: show_spr = ((ppu_mask And PPUMASK_SPR_ENABLE) <> 0)
    Dim show_left As Boolean: show_left = ((ppu_mask And PPUMASK_SPR_LEFT) <> 0)
    Dim spr_h As Long: If (ppu_ctrl And PPUCTRL_SPR_SIZE) <> 0 Then spr_h = 16 Else spr_h = 8
    Dim count As Long: count = 0
    Dim sp_px(0 To 255) As Byte, sp_pal(0 To 255) As Byte, sp_pri(0 To 255) As Byte, sp_z(0 To 255) As Byte
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
            Dim patAddr As Long, r As Long
            If spr_h = 8 Then
                If fv Then r = 7 - row Else r = row
                Dim sprBase As Long: If (ppu_ctrl And PPUCTRL_SPR_ADDR) <> 0 Then sprBase = &H1000& Else sprBase = 0
                patAddr = sprBase + tileNum * 16 + r
            Else
                Dim base16 As Long: If (tileNum And 1) <> 0 Then base16 = &H1000& Else base16 = 0
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
                Dim bitPos As Long: If fh Then bitPos = px Else bitPos = 7 - px
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
            If sp_pri(x) = 0 Then ci = PpuRead(&H3F00& + CLng(sp_pal(x)) * 4 + sp) Else ci = PpuRead(&H3F00& + CLng(bg_pal(x)) * 4 + bp)
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
            Dim bg_px(0 To 255) As Byte, bg_pal(0 To 255) As Byte
            CopyHorizontal
            RenderBgScanline bg_px, bg_pal
            RenderSprites ppu_scanline, bg_px, bg_pal, ppu_scanline * 256
            IncrementY
        Else
            Dim bgCol As Byte: bgCol = ppu_palette(0) And &H3F
            Dim ln As Long: ln = ppu_scanline * 256
            Dim xp As Long
            For xp = 0 To 255: ppu_framebuffer(ln + xp) = nes_pal(bgCol): Next xp
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
        ppu_cycle = 0: ppu_scanline = ppu_scanline + 1
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
        Dim d As Byte: If (bus_controller_latch(0) And &H80) <> 0 Then d = 1 Else d = 0
        bus_controller_latch(0) = (bus_controller_latch(0) * 2) And &HFF
        BusCpuRead = d Or &H40
    ElseIf addr = &H4017& Then
        Dim d2 As Byte: If (bus_controller_latch(1) And &H80) <> 0 Then d2 = 1 Else d2 = 0
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
        bus_dma_page = v: bus_dma_addr = 0: bus_dma_transfer = 1: bus_dma_dummy = 1
    ElseIf addr = &H4016& Then
        bus_controller_strobe = v And 1
        If bus_controller_strobe <> 0 Then
            bus_controller_latch(0) = bus_controller(0): bus_controller_latch(1) = bus_controller(1)
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
    CpuSetFlag FLAG_Z, (v = 0): CpuSetFlag FLAG_N, ((v And &H80) <> 0)
End Sub
Private Sub CpuPush8(ByVal v As Byte)
    BusCpuWrite &H100& + CLng(cpu_sp), v: cpu_sp = (cpu_sp - 1) And &HFF
End Sub
Private Sub CpuPush16(ByVal v As Long)
    CpuPush8 CByte((v \ 256) And &HFF): CpuPush8 CByte(v And &HFF)
End Sub
Private Function CpuPull8() As Byte
    cpu_sp = (cpu_sp + 1) And &HFF: CpuPull8 = BusCpuRead(&H100& + CLng(cpu_sp))
End Function
Private Function CpuPull16() As Long
    Dim lo As Long: lo = CpuPull8(): Dim hi As Long: hi = CpuPull8()
    CpuPull16 = (hi * 256 + lo) And &HFFFF&
End Function

Private Sub CpuReset()
    Dim lo As Long: lo = BusCpuRead(&HFFFC&): Dim hi As Long: hi = BusCpuRead(&HFFFD&)
    cpu_pc = (hi * 256 + lo) And &HFFFF&
    cpu_sp = &HFD: cpu_p = FLAG_U Or FLAG_I
    cpu_a = 0: cpu_x = 0: cpu_y = 0
    cpu_cycles = 0: cpu_stall = 0: cpu_nmi_pending = 0: cpu_irq_pending = 0
End Sub

Private Sub CpuNmi()
    CpuPush16 cpu_pc: CpuPush8 (cpu_p Or FLAG_U) And (Not FLAG_B): cpu_p = cpu_p Or FLAG_I
    Dim lo As Long: lo = BusCpuRead(&HFFFA&): Dim hi As Long: hi = BusCpuRead(&HFFFB&)
    cpu_pc = (hi * 256 + lo) And &HFFFF&: cpu_cycles = cpu_cycles + 7
End Sub

Private Function CpuStep() As Long
    Dim extra As Long: extra = 0
    If cpu_stall > 0 Then cpu_stall = cpu_stall - 1: CpuStep = 1: Exit Function
    If cpu_nmi_pending <> 0 Then CpuNmi: cpu_nmi_pending = 0: CpuStep = 7: Exit Function
    If cpu_irq_pending <> 0 And (cpu_p And FLAG_I) = 0 Then
        CpuPush16 cpu_pc: CpuPush8 (cpu_p Or FLAG_U) And (Not FLAG_B): cpu_p = cpu_p Or FLAG_I
        Dim ilo As Long: ilo = BusCpuRead(&HFFFE&): Dim ihi As Long: ihi = BusCpuRead(&HFFFF&)
        cpu_pc = (ihi * 256 + ilo) And &HFFFF&: cpu_irq_pending = 0: cpu_cycles = cpu_cycles + 7
        CpuStep = 7: Exit Function
    End If
    Dim opcode As Byte: opcode = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
    Dim ins As Byte: ins = op_ins(opcode)
    Dim md As Byte: md = op_mode(opcode)
    Dim cyc As Long: cyc = op_cyc(opcode)
    Dim pxc As Long: pxc = 0
    Dim addr As Long: addr = 0
    Dim lo As Long, hi As Long, tmp As Long
    Select Case md
        Case AM_IMP, AM_ACC
        Case AM_IMM: addr = cpu_pc: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPG: addr = BusCpuRead(cpu_pc) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPX: addr = (CLng(BusCpuRead(cpu_pc)) + cpu_x) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ZPY: addr = (CLng(BusCpuRead(cpu_pc)) + cpu_y) And &HFF&: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_REL: addr = cpu_pc: cpu_pc = (cpu_pc + 1) And &HFFFF&
        Case AM_ABS
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            addr = (hi * 256 + lo) And &HFFFF&
        Case AM_ABX
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            tmp = hi * 256 + lo: addr = (tmp + cpu_x) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
        Case AM_ABY
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            tmp = hi * 256 + lo: addr = (tmp + cpu_y) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
        Case AM_IND
            lo = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            hi = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            Dim ptr As Long: ptr = hi * 256 + lo
            Dim ph As Long: If (lo = &HFF) Then ph = ptr And &HFF00& Else ph = ptr + 1
            addr = (CLng(BusCpuRead(ph)) * 256 + BusCpuRead(ptr)) And &HFFFF&
        Case AM_IZX
            Dim bx As Long: bx = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            Dim zx As Long: zx = (bx + cpu_x) And &HFF&
            lo = BusCpuRead(zx): hi = BusCpuRead((zx + 1) And &HFF&)
            addr = (hi * 256 + lo) And &HFFFF&
        Case AM_IZY
            Dim zy As Long: zy = BusCpuRead(cpu_pc): cpu_pc = (cpu_pc + 1) And &HFFFF&
            lo = BusCpuRead(zy): hi = BusCpuRead((zy + 1) And &HFF&)
            tmp = hi * 256 + lo: addr = (tmp + cpu_y) And &HFFFF&
            If (addr And &HFF00&) <> (tmp And &HFF00&) Then pxc = 1
    End Select
    If pxc <> 0 And op_page(opcode) <> 0 Then cyc = cyc + 1
    Dim v As Long, s As Long, c As Long
    Select Case ins
        Case INS_ADC
            v = BusCpuRead(addr): s = CLng(cpu_a) + v + IIf((cpu_p And FLAG_C) <> 0, 1, 0)
            CpuSetFlag FLAG_C, (s > 255): CpuSetFlag FLAG_V, (((Not (CLng(cpu_a) Xor v)) And (CLng(cpu_a) Xor s)) And &H80) <> 0
            cpu_a = CByte(s And &HFF): CpuUpdateNZ cpu_a
        Case INS_SBC
            v = BusCpuRead(addr): s = CLng(cpu_a) - v - IIf((cpu_p And FLAG_C) <> 0, 0, 1)
            CpuSetFlag FLAG_C, (s >= 0): CpuSetFlag FLAG_V, (((CLng(cpu_a) Xor v) And (CLng(cpu_a) Xor s)) And &H80) <> 0
            cpu_a = CByte(s And &HFF): CpuUpdateNZ cpu_a
        Case INS_AND: cpu_a = cpu_a And BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_ORA: cpu_a = cpu_a Or BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_EOR: cpu_a = cpu_a Xor BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_ASL
            If md = AM_ACC Then
                CpuSetFlag FLAG_C, (cpu_a And &H80) <> 0: cpu_a = (CLng(cpu_a) * 2) And &HFF: CpuUpdateNZ cpu_a
            Else
                Dim va As Byte: va = BusCpuRead(addr): CpuSetFlag FLAG_C, (va And &H80) <> 0
                va = (CLng(va) * 2) And &HFF: BusCpuWrite addr, va: CpuUpdateNZ va
            End If
        Case INS_LSR
            If md = AM_ACC Then
                CpuSetFlag FLAG_C, (cpu_a And 1) <> 0: cpu_a = cpu_a \ 2: CpuUpdateNZ cpu_a
            Else
                Dim vl As Byte: vl = BusCpuRead(addr): CpuSetFlag FLAG_C, (vl And 1) <> 0
                vl = vl \ 2: BusCpuWrite addr, vl: CpuUpdateNZ vl
            End If
        Case INS_ROL
            If md = AM_ACC Then
                c = IIf((cpu_p And FLAG_C) <> 0, 1, 0): CpuSetFlag FLAG_C, (cpu_a And &H80) <> 0
                cpu_a = ((CLng(cpu_a) * 2) Or c) And &HFF: CpuUpdateNZ cpu_a
            Else
                Dim vr As Byte: vr = BusCpuRead(addr): c = IIf((cpu_p And FLAG_C) <> 0, 1, 0)
                CpuSetFlag FLAG_C, (vr And &H80) <> 0: vr = ((CLng(vr) * 2) Or c) And &HFF
                BusCpuWrite addr, vr: CpuUpdateNZ vr
            End If
        Case INS_ROR
            If md = AM_ACC Then
                c = IIf((cpu_p And FLAG_C) <> 0, &H80, 0): CpuSetFlag FLAG_C, (cpu_a And 1) <> 0
                cpu_a = (cpu_a \ 2) Or c: CpuUpdateNZ cpu_a
            Else
                Dim vro As Byte: vro = BusCpuRead(addr): c = IIf((cpu_p And FLAG_C) <> 0, &H80, 0)
                CpuSetFlag FLAG_C, (vro And 1) <> 0: vro = (vro \ 2) Or c
                BusCpuWrite addr, vro: CpuUpdateNZ vro
            End If
        Case INS_CMP: v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_a >= v): CpuUpdateNZ CByte((CLng(cpu_a) - v) And &HFF)
        Case INS_CPX: v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_x >= v): CpuUpdateNZ CByte((CLng(cpu_x) - v) And &HFF)
        Case INS_CPY: v = BusCpuRead(addr): CpuSetFlag FLAG_C, (cpu_y >= v): CpuUpdateNZ CByte((CLng(cpu_y) - v) And &HFF)
        Case INS_INC: Dim vi As Byte: vi = (CLng(BusCpuRead(addr)) + 1) And &HFF: BusCpuWrite addr, vi: CpuUpdateNZ vi
        Case INS_DEC: Dim vd As Byte: vd = (CLng(BusCpuRead(addr)) - 1) And &HFF: BusCpuWrite addr, vd: CpuUpdateNZ vd
        Case INS_INX: cpu_x = (cpu_x + 1) And &HFF: CpuUpdateNZ cpu_x
        Case INS_INY: cpu_y = (cpu_y + 1) And &HFF: CpuUpdateNZ cpu_y
        Case INS_DEX: cpu_x = (cpu_x - 1) And &HFF: CpuUpdateNZ cpu_x
        Case INS_DEY: cpu_y = (cpu_y - 1) And &HFF: CpuUpdateNZ cpu_y
        Case INS_LDA: cpu_a = BusCpuRead(addr): CpuUpdateNZ cpu_a
        Case INS_LDX: cpu_x = BusCpuRead(addr): CpuUpdateNZ cpu_x
        Case INS_LDY: cpu_y = BusCpuRead(addr): CpuUpdateNZ cpu_y
        Case INS_STA: BusCpuWrite addr, cpu_a
        Case INS_STX: BusCpuWrite addr, cpu_x
        Case INS_STY: BusCpuWrite addr, cpu_y
        Case INS_TAX: cpu_x = cpu_a: CpuUpdateNZ cpu_x
        Case INS_TAY: cpu_y = cpu_a: CpuUpdateNZ cpu_y
        Case INS_TXA: cpu_a = cpu_x: CpuUpdateNZ cpu_a
        Case INS_TYA: cpu_a = cpu_y: CpuUpdateNZ cpu_a
        Case INS_TSX: cpu_x = cpu_sp: CpuUpdateNZ cpu_x
        Case INS_TXS: cpu_sp = cpu_x
        Case INS_PHA: CpuPush8 cpu_a
        Case INS_PHP: CpuPush8 cpu_p Or FLAG_B Or FLAG_U
        Case INS_PLA: cpu_a = CpuPull8(): CpuUpdateNZ cpu_a
        Case INS_PLP: cpu_p = (CpuPull8() And (Not FLAG_B)) Or FLAG_U
        Case INS_BCC: extra = DoBranch(addr, (cpu_p And FLAG_C) = 0)
        Case INS_BCS: extra = DoBranch(addr, (cpu_p And FLAG_C) <> 0)
        Case INS_BEQ: extra = DoBranch(addr, (cpu_p And FLAG_Z) <> 0)
        Case INS_BNE: extra = DoBranch(addr, (cpu_p And FLAG_Z) = 0)
        Case INS_BMI: extra = DoBranch(addr, (cpu_p And FLAG_N) <> 0)
        Case INS_BPL: extra = DoBranch(addr, (cpu_p And FLAG_N) = 0)
        Case INS_BVS: extra = DoBranch(addr, (cpu_p And FLAG_V) <> 0)
        Case INS_BVC: extra = DoBranch(addr, (cpu_p And FLAG_V) = 0)
        Case INS_JMP: cpu_pc = addr
        Case INS_JSR: CpuPush16 (cpu_pc - 1) And &HFFFF&: cpu_pc = addr
        Case INS_RTS: cpu_pc = (CpuPull16() + 1) And &HFFFF&
        Case INS_RTI: cpu_p = (CpuPull8() And (Not FLAG_B)) Or FLAG_U: cpu_pc = CpuPull16()
        Case INS_CLC: cpu_p = cpu_p And (Not FLAG_C)
        Case INS_SEC: cpu_p = cpu_p Or FLAG_C
        Case INS_CLD: cpu_p = cpu_p And (Not FLAG_D)
        Case INS_SED: cpu_p = cpu_p Or FLAG_D
        Case INS_CLI: cpu_p = cpu_p And (Not FLAG_I)
        Case INS_SEI: cpu_p = cpu_p Or FLAG_I
        Case INS_CLV: cpu_p = cpu_p And (Not FLAG_V)
        Case INS_BIT
            v = BusCpuRead(addr): CpuSetFlag FLAG_Z, (cpu_a And v) = 0
            CpuSetFlag FLAG_V, (v And &H40) <> 0: CpuSetFlag FLAG_N, (v And &H80) <> 0
        Case INS_BRK
            cpu_pc = (cpu_pc + 1) And &HFFFF&: CpuPush16 cpu_pc
            CpuPush8 cpu_p Or FLAG_B Or FLAG_U: cpu_p = cpu_p Or FLAG_I
            lo = BusCpuRead(&HFFFE&): hi = BusCpuRead(&HFFFF&)
            cpu_pc = (hi * 256 + lo) And &HFFFF&
        Case INS_NOP, INS_XXX
    End Select
    cyc = cyc + extra: cpu_cycles = cpu_cycles + cyc: CpuStep = cyc
End Function

Private Function DoBranch(ByVal addr As Long, ByVal cond As Boolean) As Long
    If Not cond Then DoBranch = 0: Exit Function
    Dim off As Long: off = BusCpuRead(addr)
    If off >= 128 Then off = off - 256
    Dim np As Long: np = (cpu_pc + off) And &HFFFF&
    Dim ex As Long: ex = 1: If (np And &HFF00&) <> (cpu_pc And &HFF00&) Then ex = 2
    cpu_pc = np: DoBranch = ex
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
' Color conversion: NES framebuffer (ARGB) -> Excel (BGR)
' ============================================================
Private Function FBToExcelColor(ByVal c As Long) As Long
    ' Framebuffer Long = &HAARRGGBB (ARGB, little-endian for GL_BGRA)
    ' Excel Interior.Color = &H00BBGGRR
    Dim r As Long: r = (c \ &H10000) And &HFF&
    Dim g As Long: g = (c \ &H100&) And &HFF&
    Dim b As Long: b = c And &HFF&
    FBToExcelColor = b * &H10000 + g * &H100& + r
End Function

' ============================================================
' Worksheet rendering
' ============================================================
Private Sub RenderToSheet(ByVal ws As Worksheet)
    Dim t1 As Double, t2 As Double
    t1 = Timer
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    Application.EnableEvents = False
    
    Dim y As Long, x As Long
    Dim idx As Long
    Dim prevColor As Long: prevColor = -1
    
    For y = 0 To NES_HEIGHT - 1
        idx = y * NES_WIDTH
        For x = 0 To NES_WIDTH - 1
            Dim ec As Long: ec = FBToExcelColor(ppu_framebuffer(idx + x))
            ws.Cells(y + 1, x + 1).Interior.Color = ec
        Next x
        ' Progress update every 20 rows
        If (y Mod 20) = 0 Then
            Application.StatusBar = "Rendering: row " & y & " / " & NES_HEIGHT
            DoEvents
        End If
    Next y
    
    Application.StatusBar = False
    Application.EnableEvents = True
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    
    t2 = Timer
    LogMsg "RenderToSheet: " & Format$(t2 - t1, "0.00") & " sec"
End Sub

' Optimized version: batch by color using Union
Private Sub RenderToSheetFast(ByVal ws As Worksheet)
    Dim t1 As Double: t1 = Timer
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    Application.EnableEvents = False
    
    ' Build color dictionary: color -> collection of cell addresses
    ' For performance, process row by row and batch same-color runs
    Dim y As Long, x As Long, idx As Long
    
    For y = 0 To NES_HEIGHT - 1
        idx = y * NES_WIDTH
        Dim runStart As Long: runStart = 0
        Dim runColor As Long: runColor = FBToExcelColor(ppu_framebuffer(idx))
        
        For x = 1 To NES_WIDTH   ' go to NES_WIDTH (one past) to flush final run
            Dim curColor As Long
            If x < NES_WIDTH Then
                curColor = FBToExcelColor(ppu_framebuffer(idx + x))
            Else
                curColor = -1  ' force flush
            End If
            
            If curColor <> runColor Then
                ' Flush run from runStart to x-1
                ws.Range(ws.Cells(y + 1, runStart + 1), ws.Cells(y + 1, x)).Interior.Color = runColor
                runStart = x
                runColor = curColor
            End If
        Next x
        
        If (y Mod 20) = 0 Then
            Application.StatusBar = "Rendering: row " & y & " / " & NES_HEIGHT
            DoEvents
        End If
    Next y
    
    Application.StatusBar = False
    Application.EnableEvents = True
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    
    Dim t2 As Double: t2 = Timer
    LogMsg "RenderToSheetFast: " & Format$(t2 - t1, "0.00") & " sec"
End Sub

' ============================================================
' SetupSheet - prepare worksheet with pixel-sized cells
' ============================================================
Public Sub SetupSheet()
    Dim ws As Worksheet
    
    ' Create or get "NES" sheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("NES")
    On Error GoTo 0
    
    If ws Is Nothing Then
        Set ws = ThisWorkbook.Worksheets.Add
        ws.name = "NES"
    End If
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    ' Clear all
    ws.Cells.Clear
    ws.Cells.Interior.Color = RGB(0, 0, 0)
    
    ' Set cell sizes: small square cells
    ' ColumnWidth is in characters (~7.5 pixels per unit at default)
    ' RowHeight is in points (1 pt = 1.333 pixels at 96 DPI)
    
    ' Target: ~3x3 pixel cells
    Dim col As Long
    For col = 1 To NES_WIDTH
        ws.Columns(col).ColumnWidth = 0.42   ' ~3 pixels
    Next col
    ws.Rows("1:" & NES_HEIGHT).RowHeight = 2.25  ' ~3 pixels
    
    ' Hide gridlines
    ActiveWindow.DisplayGridlines = False
    
    ' Zoom to fit
    ActiveWindow.Zoom = 100
    
    ' Scroll to top-left
    Application.GoTo ws.Range("A1"), True
    
    Application.Calculation = xlCalculationAutomatic
    Application.ScreenUpdating = True
    
    MsgBox "NES sheet ready! " & NES_WIDTH & "x" & NES_HEIGHT & " cells configured." & vbCrLf & _
           "Run 'Main' to load ROM and render.", vbInformation
End Sub

' ============================================================
' Main - Load ROM, run frames, render to sheet
' ============================================================
Public Sub Main()
    LogOpen
    On Error GoTo EH
    LogMsg "Main: start (Excel cell rendering)"
    
    ' Init tables
    InitPalette
    InitOpcodeTable
    
    ' Load ROM
    Dim romPath As String
    romPath = ThisWorkbook.Path & "\triangle.nes"
    LogMsg "Loading ROM: " & romPath
    
    If Not CartridgeLoad(romPath) Then
        MsgBox "Failed to load ROM: " & romPath & vbCrLf & _
               "Place triangle.nes in: " & ThisWorkbook.Path, vbCritical
        GoTo FIN
    End If
    
    ' Get or create NES sheet
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("NES")
    On Error GoTo EH
    If ws Is Nothing Then
        MsgBox "Run 'SetupSheet' first to prepare the worksheet.", vbExclamation
        GoTo FIN
    End If
    ws.Activate
    
    ' Init NES
    Dim j As Long
    For j = 0 To &H7FF: bus_ram(j) = 0: Next j
    bus_controller(0) = 0: bus_controller(1) = 0
    bus_controller_latch(0) = 0: bus_controller_latch(1) = 0
    bus_controller_strobe = 0: bus_dma_transfer = 0: bus_dma_dummy = 0
    bus_system_cycles = 0
    PpuReset
    CpuReset
    LogMsg "NES initialized. PC=" & Hex$(cpu_pc)
    
    g_nesReady = True
    g_totalFrames = 0
    
    ' Run several frames to stabilize the picture
    Dim numFrames As Long: numFrames = 10
    LogMsg "Running " & numFrames & " frames..."
    Application.StatusBar = "Running NES emulation..."
    
    Dim f As Long
    For f = 1 To numFrames
        BusRunFrame
        g_totalFrames = g_totalFrames + 1
        Application.StatusBar = "NES frame " & f & " / " & numFrames
        DoEvents
    Next f
    
    LogMsg "Emulation done. Rendering to worksheet..."
    Application.StatusBar = "Rendering to Excel cells..."
    
    ' Render framebuffer to worksheet
    RenderToSheetFast ws
    
    Application.StatusBar = False
    LogMsg "Main: complete"
    
    MsgBox "NES frame rendered to worksheet!" & vbCrLf & _
           "Frames emulated: " & g_totalFrames & vbCrLf & _
           "Run 'AdvanceFrame' or 'AdvanceFrames' for more.", vbInformation
    GoTo FIN

EH:
    LogMsg "ERROR: " & Err.Number & " / " & Err.Description
    MsgBox "Error: " & Err.Number & " - " & Err.Description, vbCritical
    Application.StatusBar = False
    
FIN:
    LogClose
End Sub

' ============================================================
' AdvanceFrame - run 1 more frame and re-render
' ============================================================
Public Sub AdvanceFrame()
    If Not g_nesReady Then
        MsgBox "Run 'Main' first to initialize the emulator.", vbExclamation
        Exit Sub
    End If
    
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("NES")
    On Error GoTo 0
    If ws Is Nothing Then Exit Sub
    
    BusRunFrame
    g_totalFrames = g_totalFrames + 1
    RenderToSheetFast ws
End Sub

' ============================================================
' AdvanceFrames - run N frames and re-render
' ============================================================
Public Sub AdvanceFrames()
    If Not g_nesReady Then
        MsgBox "Run 'Main' first to initialize the emulator.", vbExclamation
        Exit Sub
    End If
    
    Dim n As Variant
    n = InputBox("How many frames to advance?", "Advance Frames", "60")
    If IsEmpty(n) Or n = "" Then Exit Sub
    
    Dim numF As Long: numF = CLng(n)
    If numF <= 0 Then Exit Sub
    
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets("NES")
    On Error GoTo 0
    If ws Is Nothing Then Exit Sub
    
    Application.StatusBar = "Running " & numF & " frames..."
    Dim f As Long
    For f = 1 To numF
        BusRunFrame
        g_totalFrames = g_totalFrames + 1
        If (f Mod 10) = 0 Then
            Application.StatusBar = "Frame " & f & " / " & numF
            DoEvents
        End If
    Next f
    
    Application.StatusBar = "Rendering..."
    RenderToSheetFast ws
    Application.StatusBar = False
End Sub


