using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

using GLuint = System.UInt32;

internal enum AddrMode
{
    AM_IMP, AM_ACC, AM_IMM, AM_ZPG, AM_ZPX, AM_ZPY,
    AM_REL, AM_ABS, AM_ABX, AM_ABY, AM_IND, AM_IZX, AM_IZY
}

internal enum InsType
{
    INS_ADC, INS_AND, INS_ASL, INS_BCC, INS_BCS, INS_BEQ, INS_BIT, INS_BMI,
    INS_BNE, INS_BPL, INS_BRK, INS_BVC, INS_BVS, INS_CLC, INS_CLD, INS_CLI,
    INS_CLV, INS_CMP, INS_CPX, INS_CPY, INS_DEC, INS_DEX, INS_DEY, INS_EOR,
    INS_INC, INS_INX, INS_INY, INS_JMP, INS_JSR, INS_LDA, INS_LDX, INS_LDY,
    INS_LSR, INS_NOP, INS_ORA, INS_PHA, INS_PHP, INS_PLA, INS_PLP, INS_ROL,
    INS_ROR, INS_RTI, INS_RTS, INS_SBC, INS_SEC, INS_SED, INS_SEI, INS_STA,
    INS_STX, INS_STY, INS_TAX, INS_TAY, INS_TSX, INS_TXA, INS_TXS, INS_TYA,
    INS_XXX
}

[StructLayout(LayoutKind.Sequential)]
internal struct OpcodeEntry
{
    public byte Ins;
    public byte Mode;
    public byte Cycles;
    public byte PagePenalty;

    public OpcodeEntry(InsType ins, AddrMode mode, byte cycles, byte pagePenalty)
    {
        Ins = (byte)ins;
        Mode = (byte)mode;
        Cycles = cycles;
        PagePenalty = pagePenalty;
    }
}

internal sealed class CpuState
{
    public byte A;
    public byte X;
    public byte Y;
    public byte SP;
    public ushort PC;
    public byte P;
    public ulong Cycles;
    public int Stall;
    public byte NmiPending;
    public byte IrqPending;
}

internal sealed class PpuState
{
    public byte Ctrl;
    public byte Mask;
    public byte Status;
    public byte OamAddr;
    public ushort V;
    public ushort T;
    public byte FineX;
    public byte W;
    public byte DataBuf;
    public readonly byte[] Oam = new byte[256];
    public readonly byte[] Vram = new byte[0x800];
    public readonly byte[] Palette = new byte[32];
    public int Scanline;
    public int Cycle;
    public int FrameCount;
    public byte FrameReady;
    public byte NmiOccurred;
    public byte NmiOutput;
    public readonly uint[] Framebuffer = new uint[HelloForm.NES_WIDTH * HelloForm.NES_HEIGHT];
    public readonly byte[] BgPx = new byte[256];
    public readonly byte[] BgPal = new byte[256];
    public readonly byte[] SpPx = new byte[256];
    public readonly byte[] SpPal = new byte[256];
    public readonly byte[] SpPri = new byte[256];
    public readonly byte[] SpZ = new byte[256];
}

internal sealed class Cartridge
{
    public byte[] PrgRom = Array.Empty<byte>();
    public byte[] ChrRom = Array.Empty<byte>();
    public uint PrgSize;
    public uint ChrSize;
    public byte PrgBanks;
    public byte ChrBanks;
    public byte Mapper;
    public byte Mirror;
    public byte PrgBankSelect;
    public byte ChrBankSelect;
    public readonly byte[] ChrRam = new byte[0x2000];
    public bool HasChrRam;
}

internal sealed class BusState
{
    public readonly CpuState Cpu = new CpuState();
    public readonly PpuState Ppu = new PpuState();
    public Cartridge Cart = null;
    public readonly byte[] Ram = new byte[0x800];
    public readonly byte[] Controller = new byte[2];
    public readonly byte[] ControllerLatch = new byte[2];
    public byte ControllerStrobe;
    public byte DmaPage;
    public byte DmaAddr;
    public byte DmaData;
    public byte DmaTransfer;
    public byte DmaDummy;
    public ulong SystemCycles;
}

internal sealed class HelloForm : Form
{
    internal const int NES_WIDTH = 256;
    internal const int NES_HEIGHT = 240;
    const int SCREEN_SCALE = 2;

    const byte FLAG_C = 0x01;
    const byte FLAG_Z = 0x02;
    const byte FLAG_I = 0x04;
    const byte FLAG_D = 0x08;
    const byte FLAG_B = 0x10;
    const byte FLAG_U = 0x20;
    const byte FLAG_V = 0x40;
    const byte FLAG_N = 0x80;

    const byte PPUCTRL_VRAM_INC = 0x04;
    const byte PPUCTRL_SPR_ADDR = 0x08;
    const byte PPUCTRL_BG_ADDR = 0x10;
    const byte PPUCTRL_SPR_SIZE = 0x20;
    const byte PPUCTRL_NMI_ENABLE = 0x80;

    const byte PPUMASK_BG_LEFT = 0x02;
    const byte PPUMASK_SPR_LEFT = 0x04;
    const byte PPUMASK_BG_ENABLE = 0x08;
    const byte PPUMASK_SPR_ENABLE = 0x10;

    const byte PPUSTAT_OVERFLOW = 0x20;
    const byte PPUSTAT_SPR0_HIT = 0x40;
    const byte PPUSTAT_VBLANK = 0x80;

    const byte MIRROR_HORIZONTAL = 0;
    const byte MIRROR_VERTICAL = 1;
    const byte MIRROR_SINGLE_LO = 2;
    const byte MIRROR_SINGLE_HI = 3;
    const byte MIRROR_FOUR_SCREEN = 4;

    const byte MAPPER_NROM = 0;
    const byte MAPPER_GXROM = 66;

    const byte BTN_A = 0x80;
    const byte BTN_B = 0x40;
    const byte BTN_SELECT = 0x20;
    const byte BTN_START = 0x10;
    const byte BTN_UP = 0x08;
    const byte BTN_DOWN = 0x04;
    const byte BTN_LEFT = 0x02;
    const byte BTN_RIGHT = 0x01;

    const uint GL_ARRAY_BUFFER = 0x8892;
    const uint GL_STATIC_DRAW = 0x88E4;
    const uint GL_VERTEX_SHADER = 0x8B31;
    const uint GL_FRAGMENT_SHADER = 0x8B30;
    const uint GL_COMPILE_STATUS = 0x8B81;
    const uint GL_LINK_STATUS = 0x8B82;
    const uint GL_TEXTURE0 = 0x84C0;
    const uint GL_CLAMP_TO_EDGE = 0x812F;
    const uint GL_BGRA = 0x80E1;
    const uint GL_RGBA8 = 0x8058;
    const uint GL_TEXTURE_MIN_FILTER = 0x2801;
    const uint GL_TEXTURE_MAG_FILTER = 0x2800;
    const uint GL_TEXTURE_WRAP_S = 0x2802;
    const uint GL_TEXTURE_WRAP_T = 0x2803;
    const uint GL_TEXTURE_2D = 0x0DE1;
    const uint GL_TEXTURE_BASE_LEVEL = 0x813C;
    const uint GL_TEXTURE_MAX_LEVEL = 0x813D;
    const uint GL_TRIANGLE_STRIP = 0x0005;
    const uint GL_UNSIGNED_BYTE = 0x1401;
    const uint GL_FLOAT = 0x1406;
    const uint GL_COLOR_BUFFER_BIT = 0x00004000;
    const int GL_NEAREST = 0x2600;

    const int WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    const int WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    const int WGL_CONTEXT_FLAGS_ARB = 0x2094;
    const int WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
    const int WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;

    const int PFD_TYPE_RGBA = 0;
    const int PFD_MAIN_PLANE = 0;
    const int PFD_DOUBLEBUFFER = 1;
    const int PFD_DRAW_TO_WINDOW = 4;
    const int PFD_SUPPORT_OPENGL = 32;

    static readonly uint[] NesPalette = {
        0xFF666666,0xFF002A88,0xFF1412A7,0xFF3B00A4,0xFF5C007E,0xFF6E0040,0xFF6C0600,0xFF561D00,
        0xFF333500,0xFF0B4800,0xFF005200,0xFF004F08,0xFF00404D,0xFF000000,0xFF000000,0xFF000000,
        0xFFADADAD,0xFF155FD9,0xFF4240FF,0xFF7527FE,0xFFA01ACC,0xFFB71E7B,0xFFB53120,0xFF994E00,
        0xFF6B6D00,0xFF388700,0xFF0C9300,0xFF008F32,0xFF007C8D,0xFF000000,0xFF000000,0xFF000000,
        0xFFFFFEFF,0xFF64B0FF,0xFF9290FF,0xFFC676FF,0xFFF36AFF,0xFFFE6ECC,0xFFFE8170,0xFFEA9E22,
        0xFFBCBE00,0xFF88D800,0xFF5CE430,0xFF45E082,0xFF48CDDE,0xFF4F4F4F,0xFF000000,0xFF000000,
        0xFFFFFEFF,0xFFC0DFFF,0xFFD3D2FF,0xFFE8C8FF,0xFFFBC2FF,0xFFFEC4EA,0xFFFECCC5,0xFFF7D8A5,
        0xFFE4E594,0xFFCFEF96,0xFFBDF4AB,0xFFB3F3CC,0xFFB5EBF2,0xFFB8B8B8,0xFF000000,0xFF000000,
    };

    static readonly OpcodeEntry[] OpcodeTable = BuildOpcodeTable();

    const string VertexSource =
        "#version 460 core\n" +
        "layout(location = 0) in vec3 position;\n" +
        "layout(location = 1) in vec2 texcoord;\n" +
        "out vec2 v_texcoord;\n" +
        "void main() {\n" +
        "  v_texcoord = texcoord;\n" +
        "  gl_Position = vec4(position, 1.0);\n" +
        "}\n";

    const string FragmentSource =
        "#version 460 core\n" +
        "in vec2 v_texcoord;\n" +
        "uniform sampler2D u_texture;\n" +
        "out vec4 out_color;\n" +
        "void main() {\n" +
        "  out_color = texture(u_texture, v_texcoord);\n" +
        "}\n";

    [StructLayout(LayoutKind.Sequential)]
    struct PIXELFORMATDESCRIPTOR
    {
        public ushort nSize;
        public ushort nVersion;
        public uint dwFlags;
        public byte iPixelType;
        public byte cColorBits;
        public byte cRedBits;
        public byte cRedShift;
        public byte cGreenBits;
        public byte cGreenShift;
        public byte cBlueBits;
        public byte cBlueShift;
        public byte cAlphaBits;
        public byte cAlphaShift;
        public byte cAccumBits;
        public byte cAccumRedBits;
        public byte cAccumGreenBits;
        public byte cAccumBlueBits;
        public byte cAccumAlphaBits;
        public byte cDepthBits;
        public byte cStencilBits;
        public byte cAuxBuffers;
        public byte iLayerType;
        public byte bReserved;
        public uint dwLayerMask;
        public uint dwVisibleMask;
        public uint dwDamageMask;
    }

    [DllImport("user32.dll")]
    static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll")]
    static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern int ReleaseDC(IntPtr hWnd, IntPtr hDc);

    [DllImport("gdi32.dll")]
    static extern int ChoosePixelFormat(IntPtr hdc, ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")]
    static extern bool SetPixelFormat(IntPtr hdc, int format, ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")]
    static extern bool SwapBuffers(IntPtr hdc);

    [DllImport("opengl32.dll")]
    static extern IntPtr wglCreateContext(IntPtr hdc);
    [DllImport("opengl32.dll")]
    static extern int wglMakeCurrent(IntPtr hdc, IntPtr hglrc);
    [DllImport("opengl32.dll")]
    static extern int wglDeleteContext(IntPtr hglrc);
    [DllImport("opengl32.dll")]
    static extern IntPtr wglGetProcAddress(string name);
    [DllImport("opengl32.dll")]
    static extern void glClearColor(float r, float g, float b, float a);
    [DllImport("opengl32.dll")]
    static extern void glClear(uint mask);
    [DllImport("opengl32.dll")]
    static extern void glViewport(int x, int y, int width, int height);
    [DllImport("opengl32.dll")]
    static extern void glGenTextures(int n, uint[] textures);
    [DllImport("opengl32.dll")]
    static extern void glDeleteTextures(int n, uint[] textures);
    [DllImport("opengl32.dll")]
    static extern void glBindTexture(uint target, uint texture);
    [DllImport("opengl32.dll")]
    static extern void glTexParameteri(uint target, uint pname, int param);
    [DllImport("opengl32.dll")]
    static extern void glTexImage2D(uint target, int level, int internalFormat, int width, int height, int border, uint format, uint type, IntPtr data);
    [DllImport("opengl32.dll")]
    static extern void glTexSubImage2D(uint target, int level, int xoffset, int yoffset, int width, int height, uint format, uint type, uint[] pixels);
    [DllImport("opengl32.dll")]
    static extern void glDrawArrays(uint mode, int first, int count);

    delegate void GlGenVertexArraysDelegate(int n, uint[] arrays);
    delegate void GlBindVertexArrayDelegate(uint array);
    delegate void GlGenBuffersDelegate(int n, uint[] buffers);
    delegate void GlBindBufferDelegate(uint target, uint buffer);
    delegate void GlBufferDataDelegate(uint target, IntPtr size, float[] data, uint usage);
    delegate uint GlCreateShaderDelegate(uint type);
    delegate void GlShaderSourceDelegate(uint shader, int count, string[] source, int[] lengths);
    delegate void GlCompileShaderDelegate(uint shader);
    delegate void GlGetShaderivDelegate(uint shader, uint pname, out int value);
    delegate void GlGetShaderInfoLogDelegate(uint shader, int maxLength, out int length, StringBuilder log);
    delegate uint GlCreateProgramDelegate();
    delegate void GlAttachShaderDelegate(uint program, uint shader);
    delegate void GlLinkProgramDelegate(uint program);
    delegate void GlGetProgramivDelegate(uint program, uint pname, out int value);
    delegate void GlGetProgramInfoLogDelegate(uint program, int maxLength, out int length, StringBuilder log);
    delegate void GlUseProgramDelegate(uint program);
    delegate int GlGetUniformLocationDelegate(uint program, string name);
    delegate void GlUniform1iDelegate(int location, int value);
    delegate void GlEnableVertexAttribArrayDelegate(uint index);
    delegate void GlVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate void GlActiveTextureDelegate(uint texture);
    delegate void GlDeleteBuffersDelegate(int n, uint[] buffers);
    delegate void GlDeleteVertexArraysDelegate(int n, uint[] arrays);
    delegate void GlDeleteShaderDelegate(uint shader);
    delegate void GlDeleteProgramDelegate(uint program);
    delegate IntPtr WglCreateContextAttribsArbDelegate(IntPtr hdc, IntPtr share, int[] attribs);

    GlGenVertexArraysDelegate glGenVertexArrays = null;
    GlBindVertexArrayDelegate glBindVertexArray = null;
    GlGenBuffersDelegate glGenBuffers = null;
    GlBindBufferDelegate glBindBuffer = null;
    GlBufferDataDelegate glBufferData = null;
    GlCreateShaderDelegate glCreateShader = null;
    GlShaderSourceDelegate glShaderSource = null;
    GlCompileShaderDelegate glCompileShader = null;
    GlGetShaderivDelegate glGetShaderiv = null;
    GlGetShaderInfoLogDelegate glGetShaderInfoLog = null;
    GlCreateProgramDelegate glCreateProgram = null;
    GlAttachShaderDelegate glAttachShader = null;
    GlLinkProgramDelegate glLinkProgram = null;
    GlGetProgramivDelegate glGetProgramiv = null;
    GlGetProgramInfoLogDelegate glGetProgramInfoLog = null;
    GlUseProgramDelegate glUseProgram = null;
    GlGetUniformLocationDelegate glGetUniformLocation = null;
    GlUniform1iDelegate glUniform1i = null;
    GlEnableVertexAttribArrayDelegate glEnableVertexAttribArray = null;
    GlVertexAttribPointerDelegate glVertexAttribPointer = null;
    GlActiveTextureDelegate glActiveTexture = null;
    GlDeleteBuffersDelegate glDeleteBuffers = null;
    GlDeleteVertexArraysDelegate glDeleteVertexArrays = null;
    GlDeleteShaderDelegate glDeleteShader = null;
    GlDeleteProgramDelegate glDeleteProgram = null;
    WglCreateContextAttribsArbDelegate wglCreateContextAttribsARB = null;

    readonly BusState bus = new BusState();
    readonly Cartridge cart = new Cartridge();
    readonly Timer frameTimer = new Timer();
    readonly Stopwatch stopwatch = new Stopwatch();

    IntPtr hdc;
    IntPtr hglrc;
    uint program;
    uint vao;
    uint vbo;
    readonly uint[] texture = new uint[1];
    int textureUniform;
    double accumulatedUs;
    long lastTimestamp;
    string romPath = string.Empty;
    bool emulatorReady;
    public HelloForm(string[] args)
    {
        ClientSize = new Size(NES_WIDTH * SCREEN_SCALE, NES_HEIGHT * SCREEN_SCALE);
        Text = "NES Emulator";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        SetStyle(ControlStyles.Opaque, true);
        romPath = ResolveRomPath(args);
        frameTimer.Interval = 1;
        frameTimer.Tick += OnFrame;
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        EnableOpenGL();
        InitOpenGLFunctions();
        InitRenderer();
        LoadCartridge(cart, romPath);
        bus.Cart = cart;
        PpuReset(bus.Ppu);
        CpuReset(bus.Cpu, bus);
        emulatorReady = true;
        stopwatch.Start();
        lastTimestamp = stopwatch.ElapsedTicks;
        frameTimer.Start();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        if (emulatorReady)
        {
            RenderFrame();
        }
    }

    protected override void OnResize(EventArgs e)
    {
        base.OnResize(e);
        if (hglrc != IntPtr.Zero)
        {
            glViewport(0, 0, ClientSize.Width, ClientSize.Height);
        }
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        frameTimer.Stop();
        DestroyRenderer();
        DisableOpenGL();
        base.OnFormClosed(e);
    }

    void OnFrame(object sender, EventArgs e)
    {
        if (!emulatorReady)
        {
            return;
        }

        long now = stopwatch.ElapsedTicks;
        accumulatedUs += (now - lastTimestamp) * 1000000.0 / Stopwatch.Frequency;
        lastTimestamp = now;

        const double frameUs = 1000000.0 / 60.0988;
        if (accumulatedUs < frameUs)
        {
            return;
        }

        if (accumulatedUs > frameUs * 3)
        {
            accumulatedUs = frameUs;
        }
        accumulatedUs -= frameUs;

        UpdateInput();
        BusRunFrame(bus);
        RenderFrame();
    }

    void EnableOpenGL()
    {
        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR
        {
            nSize = (ushort)Marshal.SizeOf(typeof(PIXELFORMATDESCRIPTOR)),
            nVersion = 1,
            dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
            iPixelType = PFD_TYPE_RGBA,
            cColorBits = 32,
            cDepthBits = 24,
            iLayerType = PFD_MAIN_PLANE
        };

        hdc = GetDC(Handle);
        int format = ChoosePixelFormat(hdc, ref pfd);
        SetPixelFormat(hdc, format, ref pfd);

        IntPtr oldRc = wglCreateContext(hdc);
        wglMakeCurrent(hdc, oldRc);
        wglCreateContextAttribsARB = LoadGl<WglCreateContextAttribsArbDelegate>("wglCreateContextAttribsARB", false);
        if (wglCreateContextAttribsARB != null)
        {
            int[] gl46 = {
                WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
                WGL_CONTEXT_MINOR_VERSION_ARB, 6,
                WGL_CONTEXT_FLAGS_ARB, 0,
                WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
                0
            };
            hglrc = wglCreateContextAttribsARB(hdc, IntPtr.Zero, gl46);
        }
        if (hglrc == IntPtr.Zero)
        {
            hglrc = wglCreateContext(hdc);
        }
        wglMakeCurrent(hdc, hglrc);
        wglDeleteContext(oldRc);
    }

    void DisableOpenGL()
    {
        wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
        if (hglrc != IntPtr.Zero)
        {
            wglDeleteContext(hglrc);
            hglrc = IntPtr.Zero;
        }
        if (hdc != IntPtr.Zero)
        {
            ReleaseDC(Handle, hdc);
            hdc = IntPtr.Zero;
        }
    }

    T LoadGl<T>(string name, bool required) where T : class
    {
        IntPtr proc = wglGetProcAddress(name);
        if (proc == IntPtr.Zero)
        {
            if (required)
            {
                throw new InvalidOperationException("OpenGL function not available: " + name);
            }
            return null;
        }
        return (T)(object)Marshal.GetDelegateForFunctionPointer(proc, typeof(T));
    }

    T LoadGl<T>(string name) where T : class
    {
        return LoadGl<T>(name, true);
    }

    void InitOpenGLFunctions()
    {
        glGenVertexArrays = LoadGl<GlGenVertexArraysDelegate>("glGenVertexArrays");
        glBindVertexArray = LoadGl<GlBindVertexArrayDelegate>("glBindVertexArray");
        glGenBuffers = LoadGl<GlGenBuffersDelegate>("glGenBuffers");
        glBindBuffer = LoadGl<GlBindBufferDelegate>("glBindBuffer");
        glBufferData = LoadGl<GlBufferDataDelegate>("glBufferData");
        glCreateShader = LoadGl<GlCreateShaderDelegate>("glCreateShader");
        glShaderSource = LoadGl<GlShaderSourceDelegate>("glShaderSource");
        glCompileShader = LoadGl<GlCompileShaderDelegate>("glCompileShader");
        glGetShaderiv = LoadGl<GlGetShaderivDelegate>("glGetShaderiv");
        glGetShaderInfoLog = LoadGl<GlGetShaderInfoLogDelegate>("glGetShaderInfoLog");
        glCreateProgram = LoadGl<GlCreateProgramDelegate>("glCreateProgram");
        glAttachShader = LoadGl<GlAttachShaderDelegate>("glAttachShader");
        glLinkProgram = LoadGl<GlLinkProgramDelegate>("glLinkProgram");
        glGetProgramiv = LoadGl<GlGetProgramivDelegate>("glGetProgramiv");
        glGetProgramInfoLog = LoadGl<GlGetProgramInfoLogDelegate>("glGetProgramInfoLog");
        glUseProgram = LoadGl<GlUseProgramDelegate>("glUseProgram");
        glGetUniformLocation = LoadGl<GlGetUniformLocationDelegate>("glGetUniformLocation");
        glUniform1i = LoadGl<GlUniform1iDelegate>("glUniform1i");
        glEnableVertexAttribArray = LoadGl<GlEnableVertexAttribArrayDelegate>("glEnableVertexAttribArray");
        glVertexAttribPointer = LoadGl<GlVertexAttribPointerDelegate>("glVertexAttribPointer");
        glActiveTexture = LoadGl<GlActiveTextureDelegate>("glActiveTexture");
        glDeleteBuffers = LoadGl<GlDeleteBuffersDelegate>("glDeleteBuffers", false);
        glDeleteVertexArrays = LoadGl<GlDeleteVertexArraysDelegate>("glDeleteVertexArrays", false);
        glDeleteShader = LoadGl<GlDeleteShaderDelegate>("glDeleteShader", false);
        glDeleteProgram = LoadGl<GlDeleteProgramDelegate>("glDeleteProgram", false);
    }

    void InitRenderer()
    {
        float[] vertices = {
            -1.0f,  1.0f, 0.0f, 0.0f, 0.0f,
             1.0f,  1.0f, 0.0f, 1.0f, 0.0f,
            -1.0f, -1.0f, 0.0f, 0.0f, 1.0f,
             1.0f, -1.0f, 0.0f, 1.0f, 1.0f,
        };

        program = CreateProgram();
        uint[] vaos = new uint[1];
        uint[] vbos = new uint[1];
        glGenVertexArrays(1, vaos);
        vao = vaos[0];
        glBindVertexArray(vao);
        glGenBuffers(1, vbos);
        vbo = vbos[0];
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, (IntPtr)(vertices.Length * sizeof(float)), vertices, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 5 * sizeof(float), IntPtr.Zero);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, false, 5 * sizeof(float), (IntPtr)(3 * sizeof(float)));

        glGenTextures(1, texture);
        glBindTexture(GL_TEXTURE_2D, texture[0]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (int)GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (int)GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
        glTexImage2D(GL_TEXTURE_2D, 0, (int)GL_RGBA8, NES_WIDTH, NES_HEIGHT, 0, GL_BGRA, GL_UNSIGNED_BYTE, IntPtr.Zero);

        glUseProgram(program);
        textureUniform = glGetUniformLocation(program, "u_texture");
        glUniform1i(textureUniform, 0);
        glViewport(0, 0, ClientSize.Width, ClientSize.Height);
    }

    void DestroyRenderer()
    {
        if (texture[0] != 0)
        {
            glDeleteTextures(1, texture);
            texture[0] = 0;
        }
        if (vbo != 0 && glDeleteBuffers != null)
        {
            glDeleteBuffers(1, new uint[] { vbo });
            vbo = 0;
        }
        if (vao != 0 && glDeleteVertexArrays != null)
        {
            glDeleteVertexArrays(1, new uint[] { vao });
            vao = 0;
        }
        if (program != 0 && glDeleteProgram != null)
        {
            glDeleteProgram(program);
            program = 0;
        }
    }

    uint CompileShader(uint type, string source)
    {
        uint shader = glCreateShader(type);
        glShaderSource(shader, 1, new string[] { source }, null);
        glCompileShader(shader);
        int ok;
        glGetShaderiv(shader, GL_COMPILE_STATUS, out ok);
        if (ok == 0)
        {
            StringBuilder log = new StringBuilder(1024);
            int length;
            glGetShaderInfoLog(shader, log.Capacity, out length, log);
            throw new InvalidOperationException("Shader compile failed: " + log.ToString());
        }
        return shader;
    }

    uint CreateProgram()
    {
        uint vs = CompileShader(GL_VERTEX_SHADER, VertexSource);
        uint fs = CompileShader(GL_FRAGMENT_SHADER, FragmentSource);
        uint p = glCreateProgram();
        glAttachShader(p, vs);
        glAttachShader(p, fs);
        glLinkProgram(p);
        int ok;
        glGetProgramiv(p, GL_LINK_STATUS, out ok);
        if (glDeleteShader != null)
        {
            glDeleteShader(vs);
            glDeleteShader(fs);
        }
        if (ok == 0)
        {
            StringBuilder log = new StringBuilder(1024);
            int length;
            glGetProgramInfoLog(p, log.Capacity, out length, log);
            throw new InvalidOperationException("Program link failed: " + log.ToString());
        }
        return p;
    }

    void RenderFrame()
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(program);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, texture[0]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, NES_WIDTH, NES_HEIGHT, GL_BGRA, GL_UNSIGNED_BYTE, bus.Ppu.Framebuffer);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        SwapBuffers(hdc);
    }

    void UpdateInput()
    {
        byte state = 0;
        if ((GetAsyncKeyState('Z') & 0x8000) != 0) state |= BTN_A;
        if ((GetAsyncKeyState('X') & 0x8000) != 0) state |= BTN_B;
        if ((GetAsyncKeyState((int)Keys.RShiftKey) & 0x8000) != 0) state |= BTN_SELECT;
        if ((GetAsyncKeyState((int)Keys.Enter) & 0x8000) != 0) state |= BTN_START;
        if ((GetAsyncKeyState((int)Keys.Up) & 0x8000) != 0) state |= BTN_UP;
        if ((GetAsyncKeyState((int)Keys.Down) & 0x8000) != 0) state |= BTN_DOWN;
        if ((GetAsyncKeyState((int)Keys.Left) & 0x8000) != 0) state |= BTN_LEFT;
        if ((GetAsyncKeyState((int)Keys.Right) & 0x8000) != 0) state |= BTN_RIGHT;
        bus.Controller[0] = state;
    }

    static string ResolveRomPath(string[] args)
    {
        if (args.Length >= 2 && File.Exists(args[1]))
        {
            return Path.GetFullPath(args[1]);
        }

        string local = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "triangle.nes");
        if (File.Exists(local))
        {
            return local;
        }

        string repoRom = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
            "..", "..", "..", "..", "..", "native_win", "c", "opengl4.6", "nes_triangle", "triangle.nes"));
        if (File.Exists(repoRom))
        {
            return repoRom;
        }

        throw new FileNotFoundException("ROM file not found. Pass a .nes file path as the first argument.");
    }

    static void LoadCartridge(Cartridge cart, string filename)
    {
        byte[] data = File.ReadAllBytes(filename);
        if (data.Length < 16 || data[0] != 'N' || data[1] != 'E' || data[2] != 'S' || data[3] != 0x1A)
        {
            throw new InvalidDataException("Invalid iNES file.");
        }

        byte prgCount = data[4];
        byte chrCount = data[5];
        byte flags6 = data[6];
        byte flags7 = data[7];

        cart.Mapper = (byte)((flags7 & 0xF0) | (flags6 >> 4));
        if (cart.Mapper != MAPPER_NROM && cart.Mapper != MAPPER_GXROM)
        {
            throw new InvalidDataException("Only Mapper 0 and 66 are supported (got " + cart.Mapper + ").");
        }

        cart.Mirror = (flags6 & 0x08) != 0 ? MIRROR_FOUR_SCREEN : ((flags6 & 0x01) != 0 ? MIRROR_VERTICAL : MIRROR_HORIZONTAL);
        int offset = 16;
        if ((flags6 & 0x04) != 0)
        {
            offset += 512;
        }

        cart.PrgBanks = prgCount;
        cart.PrgSize = (uint)prgCount * 16384u;
        cart.PrgRom = new byte[cart.PrgSize];
        Buffer.BlockCopy(data, offset, cart.PrgRom, 0, (int)cart.PrgSize);
        offset += (int)cart.PrgSize;

        cart.ChrBanks = chrCount;
        if (chrCount > 0)
        {
            cart.ChrSize = (uint)chrCount * 8192u;
            cart.ChrRom = new byte[cart.ChrSize];
            Buffer.BlockCopy(data, offset, cart.ChrRom, 0, (int)cart.ChrSize);
            cart.HasChrRam = false;
        }
        else
        {
            cart.ChrRom = cart.ChrRam;
            cart.ChrSize = 0x2000;
            cart.HasChrRam = true;
        }
    }

    static uint CartridgePrgAddr(Cartridge cart, ushort addr)
    {
        if (cart.Mapper == MAPPER_GXROM)
        {
            uint bankCount = cart.PrgSize / 0x8000;
            uint bank = bankCount != 0 ? (uint)(cart.PrgBankSelect % bankCount) : 0;
            return bank * 0x8000 + (uint)(addr - 0x8000);
        }

        uint mapped = (uint)(addr - 0x8000);
        if (cart.PrgBanks == 1)
        {
            mapped &= 0x3FFF;
        }
        return mapped;
    }

    static uint CartridgeChrAddr(Cartridge cart, ushort addr)
    {
        if (cart.Mapper == MAPPER_GXROM)
        {
            uint bankCount = cart.ChrSize / 0x2000;
            uint bank = bankCount != 0 ? (uint)(cart.ChrBankSelect % bankCount) : 0;
            return bank * 0x2000 + addr;
        }
        return addr;
    }

    static byte CartridgeCpuRead(Cartridge cart, ushort addr)
    {
        return addr >= 0x8000 ? cart.PrgRom[CartridgePrgAddr(cart, addr)] : (byte)0;
    }

    static void CartridgeCpuWrite(Cartridge cart, ushort addr, byte value)
    {
        if (cart.Mapper == MAPPER_GXROM && addr >= 0x8000)
        {
            byte latch = (byte)(value & CartridgeCpuRead(cart, addr));
            cart.ChrBankSelect = (byte)(latch & 0x03);
            cart.PrgBankSelect = (byte)((latch >> 4) & 0x03);
        }
    }

    static byte CartridgePpuRead(Cartridge cart, ushort addr)
    {
        return addr < 0x2000 ? cart.ChrRom[CartridgeChrAddr(cart, addr)] : (byte)0;
    }

    static void CartridgePpuWrite(Cartridge cart, ushort addr, byte value)
    {
        if (addr < 0x2000 && cart.HasChrRam)
        {
            cart.ChrRam[CartridgeChrAddr(cart, addr)] = value;
        }
    }

    static ushort MirrorNametable(Cartridge cart, ushort addr)
    {
        addr = (ushort)((addr - 0x2000) & 0x0FFF);
        switch (cart.Mirror)
        {
            case MIRROR_HORIZONTAL:
                return (ushort)(addr < 0x800 ? (addr & 0x3FF) : (0x400 + (addr & 0x3FF)));
            case MIRROR_VERTICAL:
                return (ushort)(addr & 0x7FF);
            case MIRROR_SINGLE_LO:
                return (ushort)(addr & 0x3FF);
            case MIRROR_SINGLE_HI:
                return (ushort)(0x400 + (addr & 0x3FF));
            default:
                return (ushort)(addr & 0x7FF);
        }
    }

    static byte PpuRead(PpuState ppu, Cartridge cart, ushort addr)
    {
        addr &= 0x3FFF;
        if (addr < 0x2000) return CartridgePpuRead(cart, addr);
        if (addr < 0x3F00) return ppu.Vram[MirrorNametable(cart, addr)];
        ushort paletteAddr = (ushort)(addr & 0x1F);
        if (paletteAddr >= 16 && (paletteAddr & 3) == 0) paletteAddr -= 16;
        return ppu.Palette[paletteAddr];
    }

    static void PpuWrite(PpuState ppu, Cartridge cart, ushort addr, byte value)
    {
        addr &= 0x3FFF;
        if (addr < 0x2000)
        {
            CartridgePpuWrite(cart, addr, value);
            return;
        }
        if (addr < 0x3F00)
        {
            ppu.Vram[MirrorNametable(cart, addr)] = value;
            return;
        }
        ushort paletteAddr = (ushort)(addr & 0x1F);
        if (paletteAddr >= 16 && (paletteAddr & 3) == 0) paletteAddr -= 16;
        ppu.Palette[paletteAddr] = value;
    }

    static byte PpuRegRead(PpuState ppu, Cartridge cart, ushort reg)
    {
        byte result = 0;
        switch (reg & 7)
        {
            case 2:
                result = (byte)((ppu.Status & 0xE0) | (ppu.DataBuf & 0x1F));
                ppu.Status &= unchecked((byte)~PPUSTAT_VBLANK);
                ppu.NmiOccurred = 0;
                ppu.W = 0;
                break;
            case 4:
                result = ppu.Oam[ppu.OamAddr];
                break;
            case 7:
                result = ppu.DataBuf;
                ppu.DataBuf = PpuRead(ppu, cart, ppu.V);
                if ((ppu.V & 0x3FFF) >= 0x3F00)
                {
                    result = ppu.DataBuf;
                    ppu.DataBuf = PpuRead(ppu, cart, (ushort)(ppu.V - 0x1000));
                }
                ppu.V += (ushort)((ppu.Ctrl & PPUCTRL_VRAM_INC) != 0 ? 32 : 1);
                break;
        }
        return result;
    }

    static void PpuRegWrite(PpuState ppu, Cartridge cart, ushort reg, byte value)
    {
        switch (reg & 7)
        {
            case 0:
                ppu.Ctrl = value;
                ppu.NmiOutput = (byte)(((value & PPUCTRL_NMI_ENABLE) != 0) ? 1 : 0);
                ppu.T = (ushort)((ppu.T & 0xF3FF) | ((value & 0x03) << 10));
                break;
            case 1:
                ppu.Mask = value;
                break;
            case 3:
                ppu.OamAddr = value;
                break;
            case 4:
                ppu.Oam[ppu.OamAddr++] = value;
                break;
            case 5:
                if (ppu.W == 0)
                {
                    ppu.T = (ushort)((ppu.T & 0xFFE0) | (value >> 3));
                    ppu.FineX = (byte)(value & 0x07);
                    ppu.W = 1;
                }
                else
                {
                    ppu.T = (ushort)((ppu.T & 0x8C1F) | ((value & 0x07) << 12) | ((value >> 3) << 5));
                    ppu.W = 0;
                }
                break;
            case 6:
                if (ppu.W == 0)
                {
                    ppu.T = (ushort)((ppu.T & 0x00FF) | ((value & 0x3F) << 8));
                    ppu.W = 1;
                }
                else
                {
                    ppu.T = (ushort)((ppu.T & 0xFF00) | value);
                    ppu.V = ppu.T;
                    ppu.W = 0;
                }
                break;
            case 7:
                PpuWrite(ppu, cart, ppu.V, value);
                ppu.V += (ushort)((ppu.Ctrl & PPUCTRL_VRAM_INC) != 0 ? 32 : 1);
                break;
        }
    }

    static void PpuReset(PpuState ppu)
    {
        Array.Clear(ppu.Oam, 0, ppu.Oam.Length);
        Array.Clear(ppu.Vram, 0, ppu.Vram.Length);
        Array.Clear(ppu.Palette, 0, ppu.Palette.Length);
        Array.Clear(ppu.Framebuffer, 0, ppu.Framebuffer.Length);
        ppu.Ctrl = 0;
        ppu.Mask = 0;
        ppu.Status = 0;
        ppu.OamAddr = 0;
        ppu.V = 0;
        ppu.T = 0;
        ppu.FineX = 0;
        ppu.W = 0;
        ppu.DataBuf = 0;
        ppu.Scanline = -1;
        ppu.Cycle = 0;
        ppu.FrameCount = 0;
        ppu.FrameReady = 0;
        ppu.NmiOccurred = 0;
        ppu.NmiOutput = 0;
    }

    static bool RenderingEnabled(PpuState ppu)
    {
        return (ppu.Mask & (PPUMASK_BG_ENABLE | PPUMASK_SPR_ENABLE)) != 0;
    }

    static void IncrementX(PpuState ppu)
    {
        if ((ppu.V & 0x001F) == 31)
        {
            ppu.V &= 0xFFE0;
            ppu.V ^= 0x0400;
        }
        else
        {
            ppu.V++;
        }
    }

    static void IncrementY(PpuState ppu)
    {
        if ((ppu.V & 0x7000) != 0x7000)
        {
            ppu.V += 0x1000;
        }
        else
        {
            ppu.V &= 0x8FFF;
            int coarseY = (ppu.V & 0x03E0) >> 5;
            if (coarseY == 29)
            {
                coarseY = 0;
                ppu.V ^= 0x0800;
            }
            else if (coarseY == 31)
            {
                coarseY = 0;
            }
            else
            {
                coarseY++;
            }
            ppu.V = (ushort)((ppu.V & ~0x03E0) | (coarseY << 5));
        }
    }

    static void CopyHorizontal(PpuState ppu)
    {
        ppu.V = (ushort)((ppu.V & ~0x041F) | (ppu.T & 0x041F));
    }

    static void CopyVertical(PpuState ppu)
    {
        ppu.V = (ushort)((ppu.V & ~0x7BE0) | (ppu.T & 0x7BE0));
    }

    static void RenderBgScanline(PpuState ppu, Cartridge cart)
    {
        ushort v = ppu.V;
        byte fineX = ppu.FineX;
        bool showBg = (ppu.Mask & PPUMASK_BG_ENABLE) != 0;
        bool showLeft = (ppu.Mask & PPUMASK_BG_LEFT) != 0;

        for (int x = 0; x < 256; x++)
        {
            byte pixel = 0;
            byte palette = 0;
            if (showBg && (x >= 8 || showLeft))
            {
                ushort nt = (ushort)(0x2000 | (v & 0x0FFF));
                byte tile = PpuRead(ppu, cart, nt);
                ushort at = (ushort)(0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07));
                byte attrByte = PpuRead(ppu, cart, at);
                palette = (byte)((attrByte >> (((v >> 4) & 4) | (v & 2))) & 3);
                ushort patternBase = (ushort)(((ppu.Ctrl & PPUCTRL_BG_ADDR) != 0) ? 0x1000 : 0);
                ushort patternAddr = (ushort)(patternBase + tile * 16 + ((v >> 12) & 7));
                byte lo = PpuRead(ppu, cart, patternAddr);
                byte hi = PpuRead(ppu, cart, (ushort)(patternAddr + 8));
                int bit = 7 - fineX;
                pixel = (byte)(((lo >> bit) & 1) | (((hi >> bit) & 1) << 1));
            }
            ppu.BgPx[x] = pixel;
            ppu.BgPal[x] = palette;
            if (fineX == 7)
            {
                fineX = 0;
                IncrementX(ppu);
                v = ppu.V;
            }
            else
            {
                fineX++;
            }
        }
    }

    static void RenderSprites(PpuState ppu, Cartridge cart, int scanline)
    {
        bool showSpr = (ppu.Mask & PPUMASK_SPR_ENABLE) != 0;
        bool showLeft = (ppu.Mask & PPUMASK_SPR_LEFT) != 0;
        int spriteHeight = (ppu.Ctrl & PPUCTRL_SPR_SIZE) != 0 ? 16 : 8;
        int count = 0;

        Array.Clear(ppu.SpPx, 0, ppu.SpPx.Length);
        Array.Clear(ppu.SpPal, 0, ppu.SpPal.Length);
        Array.Clear(ppu.SpPri, 0, ppu.SpPri.Length);
        Array.Clear(ppu.SpZ, 0, ppu.SpZ.Length);

        if (showSpr)
        {
            for (int i = 63; i >= 0; i--)
            {
                int y = ppu.Oam[i * 4] + 1;
                int tile = ppu.Oam[i * 4 + 1];
                int attr = ppu.Oam[i * 4 + 2];
                int sx = ppu.Oam[i * 4 + 3];
                int row = scanline - y;
                if (row < 0 || row >= spriteHeight) continue;
                count++;

                bool flipV = (attr & 0x80) != 0;
                bool flipH = (attr & 0x40) != 0;
                byte palette = (byte)((attr & 0x03) + 4);
                byte priority = (byte)(((attr & 0x20) != 0) ? 1 : 0);

                ushort patternAddr;
                if (spriteHeight == 8)
                {
                    int r = flipV ? (7 - row) : row;
                    patternAddr = (ushort)((((ppu.Ctrl & PPUCTRL_SPR_ADDR) != 0) ? 0x1000 : 0) + tile * 16 + r);
                }
                else
                {
                    ushort patternBase = (ushort)(((tile & 1) != 0) ? 0x1000 : 0);
                    int t = tile & 0xFE;
                    int r = flipV ? (15 - row) : row;
                    if (r >= 8)
                    {
                        t++;
                        r -= 8;
                    }
                    patternAddr = (ushort)(patternBase + t * 16 + r);
                }

                byte lo = PpuRead(ppu, cart, patternAddr);
                byte hi = PpuRead(ppu, cart, (ushort)(patternAddr + 8));
                for (int px = 0; px < 8; px++)
                {
                    int dx = sx + px;
                    if (dx >= 256) continue;
                    if (dx < 8 && !showLeft) continue;
                    int bit = flipH ? px : (7 - px);
                    byte p = (byte)(((lo >> bit) & 1) | (((hi >> bit) & 1) << 1));
                    if (p == 0) continue;
                    ppu.SpPx[dx] = p;
                    ppu.SpPal[dx] = palette;
                    ppu.SpPri[dx] = priority;
                    if (i == 0) ppu.SpZ[dx] = 1;
                }
            }
        }

        if (count > 8) ppu.Status |= PPUSTAT_OVERFLOW;

        int lineOffset = scanline * 256;
        for (int x = 0; x < 256; x++)
        {
            byte bp = ppu.BgPx[x];
            byte sp = ppu.SpPx[x];
            byte ci;
            if (ppu.SpZ[x] != 0 && bp != 0 && sp != 0 && showSpr && (ppu.Mask & PPUMASK_BG_ENABLE) != 0)
            {
                if (x >= 8 || ((ppu.Mask & PPUMASK_BG_LEFT) != 0 && (ppu.Mask & PPUMASK_SPR_LEFT) != 0))
                {
                    ppu.Status |= PPUSTAT_SPR0_HIT;
                }
            }
            if (bp == 0 && sp == 0) ci = PpuRead(ppu, cart, 0x3F00);
            else if (bp == 0) ci = PpuRead(ppu, cart, (ushort)(0x3F00 + ppu.SpPal[x] * 4 + sp));
            else if (sp == 0) ci = PpuRead(ppu, cart, (ushort)(0x3F00 + ppu.BgPal[x] * 4 + bp));
            else ci = ppu.SpPri[x] == 0
                    ? PpuRead(ppu, cart, (ushort)(0x3F00 + ppu.SpPal[x] * 4 + sp))
                    : PpuRead(ppu, cart, (ushort)(0x3F00 + ppu.BgPal[x] * 4 + bp));
            ppu.Framebuffer[lineOffset + x] = NesPalette[ci & 0x3F];
        }
    }

    static void PpuStep(PpuState ppu, BusState bus)
    {
        Cartridge cart = bus.Cart;
        bool pre = ppu.Scanline == -1;
        bool vis = ppu.Scanline >= 0 && ppu.Scanline < 240;
        bool ren = RenderingEnabled(ppu);

        if (vis && ppu.Cycle == 256)
        {
            if (ren)
            {
                CopyHorizontal(ppu);
                RenderBgScanline(ppu, cart);
                RenderSprites(ppu, cart, ppu.Scanline);
                IncrementY(ppu);
            }
            else
            {
                uint bg = NesPalette[ppu.Palette[0] & 0x3F];
                int offset = ppu.Scanline * 256;
                for (int x = 0; x < 256; x++) ppu.Framebuffer[offset + x] = bg;
            }
        }

        if (pre)
        {
            if (ppu.Cycle == 1)
            {
                ppu.Status &= unchecked((byte)~(PPUSTAT_VBLANK | PPUSTAT_SPR0_HIT | PPUSTAT_OVERFLOW));
                ppu.NmiOccurred = 0;
            }
            if (ren && ppu.Cycle >= 280 && ppu.Cycle <= 304) CopyVertical(ppu);
        }

        if (ppu.Scanline == 241 && ppu.Cycle == 1)
        {
            ppu.Status |= PPUSTAT_VBLANK;
            ppu.NmiOccurred = 1;
            if (ppu.NmiOutput != 0) bus.Cpu.NmiPending = 1;
            ppu.FrameReady = 1;
        }

        ppu.Cycle++;
        if (ppu.Cycle > 340)
        {
            ppu.Cycle = 0;
            ppu.Scanline++;
            if (ppu.Scanline > 260)
            {
                ppu.Scanline = -1;
                ppu.FrameCount++;
            }
        }
    }

    static void SetFlag(CpuState cpu, byte flag, bool value)
    {
        if (value) cpu.P |= flag;
        else cpu.P &= (byte)~flag;
    }

    static void UpdateNz(CpuState cpu, byte value)
    {
        SetFlag(cpu, FLAG_Z, value == 0);
        SetFlag(cpu, FLAG_N, (value & 0x80) != 0);
    }

    static void Push8(CpuState cpu, BusState bus, byte value)
    {
        BusCpuWrite(bus, (ushort)(0x0100 + cpu.SP), value);
        cpu.SP--;
    }

    static void Push16(CpuState cpu, BusState bus, ushort value)
    {
        Push8(cpu, bus, (byte)(value >> 8));
        Push8(cpu, bus, (byte)value);
    }

    static byte Pull8(CpuState cpu, BusState bus)
    {
        cpu.SP++;
        return BusCpuRead(bus, (ushort)(0x0100 + cpu.SP));
    }

    static ushort Pull16(CpuState cpu, BusState bus)
    {
        ushort lo = Pull8(cpu, bus);
        ushort hi = Pull8(cpu, bus);
        return (ushort)((hi << 8) | lo);
    }

    static bool PagesDiffer(ushort a, ushort b)
    {
        return (a & 0xFF00) != (b & 0xFF00);
    }

    static ushort ResolveAddr(CpuState cpu, BusState bus, AddrMode mode, out int pageCrossed)
    {
        ushort addr = 0;
        pageCrossed = 0;
        ushort lo;
        ushort hi;
        switch (mode)
        {
            case AddrMode.AM_IMM: addr = cpu.PC++; break;
            case AddrMode.AM_ZPG: addr = BusCpuRead(bus, cpu.PC++); break;
            case AddrMode.AM_ZPX: addr = (byte)(BusCpuRead(bus, cpu.PC++) + cpu.X); break;
            case AddrMode.AM_ZPY: addr = (byte)(BusCpuRead(bus, cpu.PC++) + cpu.Y); break;
            case AddrMode.AM_REL: addr = cpu.PC++; break;
            case AddrMode.AM_ABS:
                lo = BusCpuRead(bus, cpu.PC++); hi = BusCpuRead(bus, cpu.PC++); addr = (ushort)((hi << 8) | lo); break;
            case AddrMode.AM_ABX:
                lo = BusCpuRead(bus, cpu.PC++); hi = BusCpuRead(bus, cpu.PC++);
                ushort baseX = (ushort)((hi << 8) | lo); addr = (ushort)(baseX + cpu.X); pageCrossed = PagesDiffer(addr, baseX) ? 1 : 0; break;
            case AddrMode.AM_ABY:
                lo = BusCpuRead(bus, cpu.PC++); hi = BusCpuRead(bus, cpu.PC++);
                ushort baseY = (ushort)((hi << 8) | lo); addr = (ushort)(baseY + cpu.Y); pageCrossed = PagesDiffer(addr, baseY) ? 1 : 0; break;
            case AddrMode.AM_IND:
                lo = BusCpuRead(bus, cpu.PC++); hi = BusCpuRead(bus, cpu.PC++);
                ushort p = (ushort)((hi << 8) | lo); ushort ph = (ushort)(lo == 0x00FF ? (p & 0xFF00) : (p + 1));
                addr = (ushort)(BusCpuRead(bus, p) | (BusCpuRead(bus, ph) << 8)); break;
            case AddrMode.AM_IZX:
                byte b = BusCpuRead(bus, cpu.PC++); byte z = (byte)(b + cpu.X);
                lo = BusCpuRead(bus, z); hi = BusCpuRead(bus, (byte)(z + 1)); addr = (ushort)((hi << 8) | lo); break;
            case AddrMode.AM_IZY:
                byte zy = BusCpuRead(bus, cpu.PC++);
                lo = BusCpuRead(bus, zy); hi = BusCpuRead(bus, (byte)(zy + 1)); ushort baseIzy = (ushort)((hi << 8) | lo); addr = (ushort)(baseIzy + cpu.Y); pageCrossed = PagesDiffer(addr, baseIzy) ? 1 : 0; break;
        }
        return addr;
    }

    static int DoBranch(CpuState cpu, BusState bus, ushort addr, bool cond)
    {
        if (!cond) return 0;
        sbyte off = unchecked((sbyte)BusCpuRead(bus, addr));
        ushort np = (ushort)(cpu.PC + off);
        int extra = 1 + (PagesDiffer(cpu.PC, np) ? 1 : 0);
        cpu.PC = np;
        return extra;
    }

    static void CpuNmi(CpuState cpu, BusState bus)
    {
        Push16(cpu, bus, cpu.PC);
        Push8(cpu, bus, (byte)((cpu.P | FLAG_U) & ~FLAG_B));
        cpu.P |= FLAG_I;
        cpu.PC = (ushort)(BusCpuRead(bus, 0xFFFA) | (BusCpuRead(bus, 0xFFFB) << 8));
        cpu.Cycles += 7;
    }

    static void CpuIrq(CpuState cpu, BusState bus)
    {
        if ((cpu.P & FLAG_I) != 0) return;
        Push16(cpu, bus, cpu.PC);
        Push8(cpu, bus, (byte)((cpu.P | FLAG_U) & ~FLAG_B));
        cpu.P |= FLAG_I;
        cpu.PC = (ushort)(BusCpuRead(bus, 0xFFFE) | (BusCpuRead(bus, 0xFFFF) << 8));
        cpu.Cycles += 7;
    }

    static void CpuReset(CpuState cpu, BusState bus)
    {
        cpu.PC = (ushort)(BusCpuRead(bus, 0xFFFC) | (BusCpuRead(bus, 0xFFFD) << 8));
        cpu.SP = 0xFD;
        cpu.P = (byte)(FLAG_U | FLAG_I);
        cpu.A = 0;
        cpu.X = 0;
        cpu.Y = 0;
        cpu.Cycles = 0;
        cpu.Stall = 0;
        cpu.NmiPending = 0;
        cpu.IrqPending = 0;
    }

    static int CpuStep(CpuState cpu, BusState bus)
    {
        if (cpu.Stall > 0) { cpu.Stall--; return 1; }
        if (cpu.NmiPending != 0) { CpuNmi(cpu, bus); cpu.NmiPending = 0; return 7; }
        if (cpu.IrqPending != 0 && (cpu.P & FLAG_I) == 0) { CpuIrq(cpu, bus); cpu.IrqPending = 0; return 7; }

        byte opcode = BusCpuRead(bus, cpu.PC++);
        OpcodeEntry op = OpcodeTable[opcode];
        AddrMode mode = (AddrMode)op.Mode;
        int pxc;
        ushort addr = ResolveAddr(cpu, bus, mode, out pxc);
        int cycles = op.Cycles + ((pxc != 0 && op.PagePenalty != 0) ? 1 : 0);
        int extra = 0;

        switch ((InsType)op.Ins)
        {
            case InsType.INS_ADC: { byte v = BusCpuRead(bus, addr); ushort s = (ushort)(cpu.A + v + ((cpu.P & FLAG_C) != 0 ? 1 : 0)); SetFlag(cpu, FLAG_C, s > 0xFF); SetFlag(cpu, FLAG_V, ((~(cpu.A ^ v) & (cpu.A ^ s)) & 0x80) != 0); cpu.A = (byte)s; UpdateNz(cpu, cpu.A); } break;
            case InsType.INS_SBC: { byte v = BusCpuRead(bus, addr); ushort s = (ushort)(cpu.A - v - ((cpu.P & FLAG_C) != 0 ? 0 : 1)); SetFlag(cpu, FLAG_C, s < 0x100); SetFlag(cpu, FLAG_V, (((cpu.A ^ v) & (cpu.A ^ s)) & 0x80) != 0); cpu.A = (byte)s; UpdateNz(cpu, cpu.A); } break;
            case InsType.INS_AND: cpu.A = (byte)(cpu.A & BusCpuRead(bus, addr)); UpdateNz(cpu, cpu.A); break;
            case InsType.INS_ORA: cpu.A = (byte)(cpu.A | BusCpuRead(bus, addr)); UpdateNz(cpu, cpu.A); break;
            case InsType.INS_EOR: cpu.A = (byte)(cpu.A ^ BusCpuRead(bus, addr)); UpdateNz(cpu, cpu.A); break;
            case InsType.INS_ASL:
                if (mode == AddrMode.AM_ACC) { SetFlag(cpu, FLAG_C, (cpu.A & 0x80) != 0); cpu.A <<= 1; UpdateNz(cpu, cpu.A); }
                else { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_C, (v & 0x80) != 0); v <<= 1; BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); }
                break;
            case InsType.INS_LSR:
                if (mode == AddrMode.AM_ACC) { SetFlag(cpu, FLAG_C, (cpu.A & 1) != 0); cpu.A >>= 1; UpdateNz(cpu, cpu.A); }
                else { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_C, (v & 1) != 0); v >>= 1; BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); }
                break;
            case InsType.INS_ROL:
                if (mode == AddrMode.AM_ACC) { byte c = (byte)((cpu.P & FLAG_C) != 0 ? 1 : 0); SetFlag(cpu, FLAG_C, (cpu.A & 0x80) != 0); cpu.A = (byte)((cpu.A << 1) | c); UpdateNz(cpu, cpu.A); }
                else { byte v = BusCpuRead(bus, addr); byte c = (byte)((cpu.P & FLAG_C) != 0 ? 1 : 0); SetFlag(cpu, FLAG_C, (v & 0x80) != 0); v = (byte)((v << 1) | c); BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); }
                break;
            case InsType.INS_ROR:
                if (mode == AddrMode.AM_ACC) { byte c = (byte)((cpu.P & FLAG_C) != 0 ? 0x80 : 0); SetFlag(cpu, FLAG_C, (cpu.A & 1) != 0); cpu.A = (byte)((cpu.A >> 1) | c); UpdateNz(cpu, cpu.A); }
                else { byte v = BusCpuRead(bus, addr); byte c = (byte)((cpu.P & FLAG_C) != 0 ? 0x80 : 0); SetFlag(cpu, FLAG_C, (v & 1) != 0); v = (byte)((v >> 1) | c); BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); }
                break;
            case InsType.INS_CMP: { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_C, cpu.A >= v); UpdateNz(cpu, (byte)(cpu.A - v)); } break;
            case InsType.INS_CPX: { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_C, cpu.X >= v); UpdateNz(cpu, (byte)(cpu.X - v)); } break;
            case InsType.INS_CPY: { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_C, cpu.Y >= v); UpdateNz(cpu, (byte)(cpu.Y - v)); } break;
            case InsType.INS_INC: { byte v = (byte)(BusCpuRead(bus, addr) + 1); BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); } break;
            case InsType.INS_DEC: { byte v = (byte)(BusCpuRead(bus, addr) - 1); BusCpuWrite(bus, addr, v); UpdateNz(cpu, v); } break;
            case InsType.INS_INX: cpu.X++; UpdateNz(cpu, cpu.X); break;
            case InsType.INS_INY: cpu.Y++; UpdateNz(cpu, cpu.Y); break;
            case InsType.INS_DEX: cpu.X--; UpdateNz(cpu, cpu.X); break;
            case InsType.INS_DEY: cpu.Y--; UpdateNz(cpu, cpu.Y); break;
            case InsType.INS_LDA: cpu.A = BusCpuRead(bus, addr); UpdateNz(cpu, cpu.A); break;
            case InsType.INS_LDX: cpu.X = BusCpuRead(bus, addr); UpdateNz(cpu, cpu.X); break;
            case InsType.INS_LDY: cpu.Y = BusCpuRead(bus, addr); UpdateNz(cpu, cpu.Y); break;
            case InsType.INS_STA: BusCpuWrite(bus, addr, cpu.A); break;
            case InsType.INS_STX: BusCpuWrite(bus, addr, cpu.X); break;
            case InsType.INS_STY: BusCpuWrite(bus, addr, cpu.Y); break;
            case InsType.INS_TAX: cpu.X = cpu.A; UpdateNz(cpu, cpu.X); break;
            case InsType.INS_TAY: cpu.Y = cpu.A; UpdateNz(cpu, cpu.Y); break;
            case InsType.INS_TXA: cpu.A = cpu.X; UpdateNz(cpu, cpu.A); break;
            case InsType.INS_TYA: cpu.A = cpu.Y; UpdateNz(cpu, cpu.A); break;
            case InsType.INS_TSX: cpu.X = cpu.SP; UpdateNz(cpu, cpu.X); break;
            case InsType.INS_TXS: cpu.SP = cpu.X; break;
            case InsType.INS_PHA: Push8(cpu, bus, cpu.A); break;
            case InsType.INS_PHP: Push8(cpu, bus, (byte)(cpu.P | FLAG_B | FLAG_U)); break;
            case InsType.INS_PLA: cpu.A = Pull8(cpu, bus); UpdateNz(cpu, cpu.A); break;
            case InsType.INS_PLP: cpu.P = (byte)((Pull8(cpu, bus) & ~FLAG_B) | FLAG_U); break;
            case InsType.INS_BCC: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_C) == 0); break;
            case InsType.INS_BCS: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_C) != 0); break;
            case InsType.INS_BEQ: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_Z) != 0); break;
            case InsType.INS_BNE: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_Z) == 0); break;
            case InsType.INS_BMI: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_N) != 0); break;
            case InsType.INS_BPL: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_N) == 0); break;
            case InsType.INS_BVS: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_V) != 0); break;
            case InsType.INS_BVC: extra = DoBranch(cpu, bus, addr, (cpu.P & FLAG_V) == 0); break;
            case InsType.INS_JMP: cpu.PC = addr; break;
            case InsType.INS_JSR: Push16(cpu, bus, (ushort)(cpu.PC - 1)); cpu.PC = addr; break;
            case InsType.INS_RTS: cpu.PC = (ushort)(Pull16(cpu, bus) + 1); break;
            case InsType.INS_RTI: cpu.P = (byte)((Pull8(cpu, bus) & ~FLAG_B) | FLAG_U); cpu.PC = Pull16(cpu, bus); break;
            case InsType.INS_CLC: cpu.P &= unchecked((byte)~FLAG_C); break;
            case InsType.INS_SEC: cpu.P |= FLAG_C; break;
            case InsType.INS_CLD: cpu.P &= unchecked((byte)~FLAG_D); break;
            case InsType.INS_SED: cpu.P |= FLAG_D; break;
            case InsType.INS_CLI: cpu.P &= unchecked((byte)~FLAG_I); break;
            case InsType.INS_SEI: cpu.P |= FLAG_I; break;
            case InsType.INS_CLV: cpu.P &= unchecked((byte)~FLAG_V); break;
            case InsType.INS_BIT: { byte v = BusCpuRead(bus, addr); SetFlag(cpu, FLAG_Z, (cpu.A & v) == 0); SetFlag(cpu, FLAG_V, (v & 0x40) != 0); SetFlag(cpu, FLAG_N, (v & 0x80) != 0); } break;
            case InsType.INS_BRK: cpu.PC++; Push16(cpu, bus, cpu.PC); Push8(cpu, bus, (byte)(cpu.P | FLAG_B | FLAG_U)); cpu.P |= FLAG_I; cpu.PC = (ushort)(BusCpuRead(bus, 0xFFFE) | (BusCpuRead(bus, 0xFFFF) << 8)); break;
            case InsType.INS_NOP:
            case InsType.INS_XXX:
                break;
        }

        cycles += extra;
        cpu.Cycles += (ulong)cycles;
        return cycles;
    }

    static byte BusCpuRead(BusState bus, ushort addr)
    {
        if (addr < 0x2000) return bus.Ram[addr & 0x07FF];
        if (addr < 0x4000) return PpuRegRead(bus.Ppu, bus.Cart, addr);
        if (addr == 0x4016) { byte d = (byte)(((bus.ControllerLatch[0] & 0x80) != 0) ? 1 : 0); bus.ControllerLatch[0] <<= 1; return (byte)(d | 0x40); }
        if (addr == 0x4017) { byte d = (byte)(((bus.ControllerLatch[1] & 0x80) != 0) ? 1 : 0); bus.ControllerLatch[1] <<= 1; return (byte)(d | 0x40); }
        if (addr < 0x4020) return 0;
        return CartridgeCpuRead(bus.Cart, addr);
    }

    static void BusCpuWrite(BusState bus, ushort addr, byte value)
    {
        if (addr < 0x2000) { bus.Ram[addr & 0x07FF] = value; return; }
        if (addr < 0x4000) { PpuRegWrite(bus.Ppu, bus.Cart, addr, value); return; }
        if (addr == 0x4014) { bus.DmaPage = value; bus.DmaAddr = 0; bus.DmaTransfer = 1; bus.DmaDummy = 1; return; }
        if (addr == 0x4016)
        {
            bus.ControllerStrobe = (byte)(value & 1);
            if (bus.ControllerStrobe != 0)
            {
                bus.ControllerLatch[0] = bus.Controller[0];
                bus.ControllerLatch[1] = bus.Controller[1];
            }
            return;
        }
        if (addr < 0x4020) return;
        CartridgeCpuWrite(bus.Cart, addr, value);
    }

    static void BusRunFrame(BusState bus)
    {
        bus.Ppu.FrameReady = 0;
        while (bus.Ppu.FrameReady == 0)
        {
            if (bus.DmaTransfer != 0)
            {
                if (bus.DmaDummy != 0)
                {
                    if ((bus.SystemCycles & 1) != 0) bus.DmaDummy = 0;
                }
                else
                {
                    if ((bus.SystemCycles & 1) == 0)
                    {
                        bus.DmaData = BusCpuRead(bus, (ushort)((bus.DmaPage << 8) | bus.DmaAddr));
                    }
                    else
                    {
                        bus.Ppu.Oam[bus.Ppu.OamAddr] = bus.DmaData;
                        bus.Ppu.OamAddr++;
                        bus.DmaAddr++;
                        if (bus.DmaAddr == 0) bus.DmaTransfer = 0;
                    }
                }
                PpuStep(bus.Ppu, bus);
                PpuStep(bus.Ppu, bus);
                PpuStep(bus.Ppu, bus);
                bus.SystemCycles++;
                continue;
            }

            int c = CpuStep(bus.Cpu, bus);
            for (int i = 0; i < c; i++)
            {
                PpuStep(bus.Ppu, bus);
                PpuStep(bus.Ppu, bus);
                PpuStep(bus.Ppu, bus);
                bus.SystemCycles++;
            }
        }
    }

    static OpcodeEntry[] BuildOpcodeTable()
    {
        return new OpcodeEntry[]
        {
            new OpcodeEntry(InsType.INS_BRK, AddrMode.AM_IMP, 7, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_ASL, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_PHP, AddrMode.AM_IMP, 3, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_ASL, AddrMode.AM_ACC, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_ASL, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BPL, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_ASL, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CLC, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ORA, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_ASL, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_JSR, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BIT, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_ROL, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_PLP, AddrMode.AM_IMP, 4, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_ROL, AddrMode.AM_ACC, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BIT, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_ROL, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BMI, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_ROL, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SEC, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_AND, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_ROL, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_RTI, AddrMode.AM_IMP, 6, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_LSR, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_PHA, AddrMode.AM_IMP, 3, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_LSR, AddrMode.AM_ACC, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_JMP, AddrMode.AM_ABS, 3, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_LSR, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BVC, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_LSR, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CLI, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_EOR, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_LSR, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_RTS, AddrMode.AM_IMP, 6, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_ROR, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_PLA, AddrMode.AM_IMP, 4, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_ROR, AddrMode.AM_ACC, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_JMP, AddrMode.AM_IND, 5, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_ROR, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BVS, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_ROR, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SEI, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_ADC, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_ROR, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STY, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_STX, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_DEY, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_TXA, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STY, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_STX, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BCC, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_IZY, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STY, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_STX, AddrMode.AM_ZPY, 4, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_TYA, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_ABY, 5, 0),
            new OpcodeEntry(InsType.INS_TXS, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_STA, AddrMode.AM_ABX, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDY, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_LDX, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDY, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_LDX, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_TAY, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_TAX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDY, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_LDX, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BCS, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDY, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_LDX, AddrMode.AM_ZPY, 4, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CLV, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_TSX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_LDY, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_LDA, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_LDX, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPY, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPY, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_DEC, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_INY, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_DEX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPY, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_DEC, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BNE, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_DEC, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CLD, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CMP, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_DEC, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPX, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_IZX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPX, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_ZPG, 3, 0),
            new OpcodeEntry(InsType.INS_INC, AddrMode.AM_ZPG, 5, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_INX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_IMM, 2, 0),
            new OpcodeEntry(InsType.INS_NOP, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_CPX, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_ABS, 4, 0),
            new OpcodeEntry(InsType.INS_INC, AddrMode.AM_ABS, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_BEQ, AddrMode.AM_REL, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_IZY, 5, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_ZPX, 4, 0),
            new OpcodeEntry(InsType.INS_INC, AddrMode.AM_ZPX, 6, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SED, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_ABY, 4, 1),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),
            new OpcodeEntry(InsType.INS_SBC, AddrMode.AM_ABX, 4, 1),
            new OpcodeEntry(InsType.INS_INC, AddrMode.AM_ABX, 7, 0),
            new OpcodeEntry(InsType.INS_XXX, AddrMode.AM_IMP, 2, 0),

        };
    }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        try
        {
            Application.Run(new HelloForm(Environment.GetCommandLineArgs()));
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "NES Emulator", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}

