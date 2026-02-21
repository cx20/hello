// Hello.cs
// OpenGL 4.6 Triangle via Windows.UI.Composition (Win32 Desktop Interop)
// ALL COM/WinRT calls via vtable index. No external libraries. No WinRT projections.
// Logging: OutputDebugStringW (use DebugView to monitor)
//
// Build (Visual Studio Developer Command Prompt):
//   csc /target:winexe /platform:x64 Hello.cs

using System;
using System.Runtime.InteropServices;

class Hello
{
    // ============================================================
    // Debug Logging - OutputDebugStringW (DebugView)
    // ============================================================
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern void OutputDebugStringW(string lpOutputString);

    static void dbg(string fn, string msg)
    {
        string text = "[" + fn + "] " + msg + "\n";
        OutputDebugStringW(text);
    }

    static void dbgHR(string fn, string api, int hr)
    {
        string text = "[" + fn + "] " + api + " failed hr=0x" + hr.ToString("X8") + "\n";
        OutputDebugStringW(text);
    }

    static void dbgPtr(string fn, string name, IntPtr ptr)
    {
        string text = "[" + fn + "] " + name + "=0x" + ptr.ToString("X") + "\n";
        OutputDebugStringW(text);
    }

    // ============================================================
    // Win32 Structures
    // ============================================================
    [StructLayout(LayoutKind.Sequential)]
    struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)]
    struct MSG
    {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    struct WNDCLASSEX
    {
        public uint cbSize;
        public uint style;
        public WndProcDelegate lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    struct PAINTSTRUCT
    {
        public IntPtr hdc;
        public int fErase;
        public RECT rcPaint;
        public int fRestore;
        public int fIncUpdate;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] rgbReserved;
    }

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

    [StructLayout(LayoutKind.Sequential)]
    struct Float2 { public float X, Y; }

    // ============================================================
    // Win32 Constants
    // ============================================================
    const uint WS_OVERLAPPEDWINDOW = 0x00CF0000;
    const uint WS_VISIBLE = 0x10000000;
    const uint WM_DESTROY = 0x0002;
    const uint WM_PAINT = 0x000F;
    const uint WM_QUIT = 0x0012;
    const uint PM_REMOVE = 0x0001;
    const uint CS_OWNDC = 0x0020;
    const int  IDC_ARROW = 32512;
    const int  COLOR_WINDOW = 5;

    // ============================================================
    // Win32 P/Invoke
    // ============================================================
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool UpdateWindow(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);

    [DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)]
    static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr CreateWindowEx(
        uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle,
        int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool TranslateMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DispatchMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll")]
    static extern void PostQuitMessage(int nExitCode);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);

    [DllImport("user32.dll")]
    static extern bool AdjustWindowRect(ref RECT lpRect, uint dwStyle, bool bMenu);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
    static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

    [DllImport("user32.dll")]
    static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll")]
    static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDc);

    [DllImport("gdi32.dll")]
    static extern int ChoosePixelFormat(IntPtr hdc, [In] ref PIXELFORMATDESCRIPTOR pfd);

    [DllImport("gdi32.dll")]
    static extern bool SetPixelFormat(IntPtr hdc, int format, [In] ref PIXELFORMATDESCRIPTOR pfd);

    [DllImport("opengl32.dll")]
    static extern IntPtr wglCreateContext(IntPtr hdc);

    [DllImport("opengl32.dll")]
    static extern int wglMakeCurrent(IntPtr hdc, IntPtr hglrc);

    [DllImport("opengl32.dll")]
    static extern int wglDeleteContext(IntPtr hglrc);

    [DllImport("opengl32.dll")]
    static extern IntPtr wglGetProcAddress(string procName);

    [DllImport("opengl32.dll")]
    static extern void glClearColor(float red, float green, float blue, float alpha);

    [DllImport("opengl32.dll")]
    static extern void glClear(uint mask);

    [DllImport("opengl32.dll")]
    static extern void glViewport(int x, int y, int width, int height);

    [DllImport("opengl32.dll")]
    static extern void glDrawArrays(uint mode, int first, int count);

    [DllImport("opengl32.dll")]
    static extern void glFlush();

    // ============================================================
    // DXGI / D3D11 Constants
    // ============================================================
    const uint DXGI_FORMAT_R32G32B32_FLOAT    = 6;
    const uint DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    const uint DXGI_FORMAT_B8G8R8A8_UNORM     = 87;
    const uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    const uint DXGI_SCALING_STRETCH     = 0;
    const uint DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;
    const uint DXGI_ALPHA_MODE_IGNORE   = 0;

    const int  D3D_DRIVER_TYPE_HARDWARE = 1;
    const uint D3D_FEATURE_LEVEL_11_0   = 0xb000;
    const uint D3D11_SDK_VERSION        = 7;

    const uint D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20;
    const uint D3D11_BIND_VERTEX_BUFFER = 0x1;
    const uint D3D11_USAGE_DEFAULT      = 0;
    const uint D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);
    const int PFD_TYPE_RGBA = 0;
    const int PFD_DOUBLEBUFFER = 1;
    const int PFD_DRAW_TO_WINDOW = 4;
    const int PFD_SUPPORT_OPENGL = 32;

    const uint GL_TRIANGLES = 0x0004;
    const uint GL_FLOAT = 0x1406;
    const uint GL_COLOR_BUFFER_BIT = 0x00004000;
    const uint GL_ARRAY_BUFFER = 0x8892;
    const uint GL_STATIC_DRAW = 0x88E4;
    const uint GL_FRAGMENT_SHADER = 0x8B30;
    const uint GL_VERTEX_SHADER = 0x8B31;
    const uint GL_FRAMEBUFFER = 0x8D40;
    const uint GL_RENDERBUFFER = 0x8D41;
    const uint GL_COLOR_ATTACHMENT0 = 0x8CE0;
    const uint GL_UPPER_LEFT = 0x8CA2;
    const uint GL_NEGATIVE_ONE_TO_ONE = 0x935E;

    const int WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    const int WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    const int WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
    const int WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
    const uint WGL_ACCESS_READ_WRITE_NV = 0x0001;

    // ============================================================
    // DXGI / D3D11 Structures
    // ============================================================
    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SAMPLE_DESC { public uint Count, Quality; }

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SWAP_CHAIN_DESC1
    {
        public uint Width, Height, Format;
        public int  Stereo;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage, BufferCount, Scaling, SwapEffect, AlphaMode, Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct Vertex { public float X, Y, Z, R, G, B, A; }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct D3D11_BUFFER_DESC
    {
        public uint ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_SUBRESOURCE_DATA
    {
        public IntPtr pSysMem;
        public uint SysMemPitch, SysMemSlicePitch;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_INPUT_ELEMENT_DESC
    {
        [MarshalAs(UnmanagedType.LPStr)] public string SemanticName;
        public uint SemanticIndex, Format, InputSlot, AlignedByteOffset, InputSlotClass, InstanceDataStepRate;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_VIEWPORT
    {
        public float TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth;
    }

    // ============================================================
    // D3D11 / DXGI / WinRT P/Invoke
    // ============================================================
    [DllImport("d3d11.dll")]
    static extern int D3D11CreateDevice(
        IntPtr pAdapter, int DriverType, IntPtr Software, uint Flags,
        [In, MarshalAs(UnmanagedType.LPArray)] uint[] pFeatureLevels, uint FeatureLevels,
        uint SDKVersion,
        out IntPtr ppDevice, out IntPtr pFeatureLevel, out IntPtr ppImmediateContext);

    [DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int D3DCompile(
        [MarshalAs(UnmanagedType.LPStr)] string srcData, IntPtr srcDataSize,
        [MarshalAs(UnmanagedType.LPStr)] string sourceName,
        IntPtr defines, IntPtr include,
        [MarshalAs(UnmanagedType.LPStr)] string entryPoint,
        [MarshalAs(UnmanagedType.LPStr)] string target,
        uint flags1, uint flags2,
        out IntPtr code, out IntPtr errorMsgs);

    [StructLayout(LayoutKind.Sequential)]
    struct DispatcherQueueOptions { public int dwSize, threadType, apartmentType; }

    [DllImport("CoreMessaging.dll")]
    static extern int CreateDispatcherQueueController(ref DispatcherQueueOptions options, out IntPtr controller);

    [DllImport("combase.dll", PreserveSig = true)]
    static extern int RoInitialize(int initType);

    [DllImport("combase.dll", PreserveSig = true)]
    static extern int RoActivateInstance(IntPtr activatableClassId, out IntPtr instance);

    [DllImport("combase.dll", PreserveSig = true)]
    static extern int WindowsCreateString(
        [MarshalAs(UnmanagedType.LPWStr)] string sourceString, uint length, out IntPtr hstring);

    [DllImport("combase.dll", PreserveSig = true)]
    static extern int WindowsDeleteString(IntPtr hstring);

    // ============================================================
    // COM vtable delegate types
    // ============================================================
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int QIDelegate(IntPtr thisPtr, ref Guid riid, out IntPtr ppv);

    // D3D11 Device
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateBufferDelegate(IntPtr device, ref D3D11_BUFFER_DESC pDesc, ref D3D11_SUBRESOURCE_DATA pInit, out IntPtr ppBuffer);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateRTVDelegate(IntPtr device, IntPtr pResource, IntPtr pDesc, out IntPtr ppRTView);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateInputLayoutDelegate(IntPtr device, [In] D3D11_INPUT_ELEMENT_DESC[] pDescs, uint num, IntPtr pBytecode, IntPtr len, out IntPtr ppLayout);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateVSDelegate(IntPtr device, IntPtr pBytecode, IntPtr len, IntPtr pLinkage, out IntPtr ppVS);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreatePSDelegate(IntPtr device, IntPtr pBytecode, IntPtr len, IntPtr pLinkage, out IntPtr ppPS);

    // D3D11 DeviceContext
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void PSSetShaderDelegate(IntPtr ctx, IntPtr ps, IntPtr[] ci, uint num);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void VSSetShaderDelegate(IntPtr ctx, IntPtr vs, IntPtr[] ci, uint num);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DrawDelegate(IntPtr ctx, uint vertexCount, uint startVertex);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetInputLayoutDelegate(IntPtr ctx, IntPtr layout);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetVertexBuffersDelegate(IntPtr ctx, uint slot, uint num, [In] IntPtr[] vbs, [In] uint[] strides, [In] uint[] offsets);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetPrimitiveTopologyDelegate(IntPtr ctx, uint topology);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void OMSetRenderTargetsDelegate(IntPtr ctx, uint num, [In] IntPtr[] rtvs, IntPtr dsv);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void RSSetViewportsDelegate(IntPtr ctx, uint num, ref D3D11_VIEWPORT vp);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearRTVDelegate(IntPtr ctx, IntPtr rtv, [MarshalAs(UnmanagedType.LPArray, SizeConst = 4)] float[] color);

    // DXGI
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetAdapterDelegate(IntPtr dxgiDevice, out IntPtr ppAdapter);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetParentDelegate(IntPtr obj, ref Guid riid, out IntPtr ppParent);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSCForCompDelegate(IntPtr factory, IntPtr pDevice, ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pRestrict, out IntPtr ppSC);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetSCBufferDelegate(IntPtr sc, uint buf, ref Guid riid, out IntPtr ppSurface);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PresentDelegate(IntPtr sc, uint sync, uint flags);

    // ID3DBlob
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr BlobGetPtrDelegate(IntPtr blob);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr BlobGetSizeDelegate(IntPtr blob);

    // Composition Interop (IUnknown-based)
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateDesktopWindowTargetDelegate(IntPtr interop, IntPtr hwnd, int isTopmost, out IntPtr ppTarget);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateCompSurfaceForSCDelegate(IntPtr interop, IntPtr swapChain, out IntPtr ppSurface);

    // WinRT Composition (IInspectable-based, vtable offset +6)
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateContainerVisualDelegate(IntPtr compositor, out IntPtr ppVisual);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSpriteVisualDelegate(IntPtr compositor, out IntPtr ppVisual);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSurfaceBrushWithSurfaceDelegate(IntPtr compositor, IntPtr surface, out IntPtr ppBrush);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PutRootDelegate(IntPtr target, IntPtr visual);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetChildrenDelegate(IntPtr container, out IntPtr ppChildren);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int InsertAtTopDelegate(IntPtr collection, IntPtr visual);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PutBrushDelegate(IntPtr sprite, IntPtr brush);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PutSizeDelegate(IntPtr visual, Float2 size);

    // OpenGL / WGL extension delegates
    delegate void glGenBuffersDelegate(int n, uint[] buffers);
    delegate void glBindBufferDelegate(uint target, uint buffer);
    delegate void glBufferDataFloatDelegate(uint target, int size, float[] data, uint usage);
    delegate uint glCreateShaderDelegate(uint type);
    delegate void glShaderSourceDelegate(uint shader, int count, string[] src, int[] length);
    delegate void glCompileShaderDelegate(uint shader);
    delegate uint glCreateProgramDelegate();
    delegate void glAttachShaderDelegate(uint program, uint shader);
    delegate void glLinkProgramDelegate(uint program);
    delegate void glUseProgramDelegate(uint program);
    delegate int glGetAttribLocationDelegate(uint program, string name);
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    delegate void glGenVertexArraysDelegate(int n, uint[] arrays);
    delegate void glBindVertexArrayDelegate(uint array);
    delegate void glGenFramebuffersDelegate(int n, uint[] framebuffers);
    delegate void glBindFramebufferDelegate(uint target, uint framebuffer);
    delegate void glFramebufferRenderbufferDelegate(uint target, uint attachment, uint renderbuffertarget, uint renderbuffer);
    delegate void glGenRenderbuffersDelegate(int n, uint[] renderbuffers);
    delegate void glClipControlDelegate(uint origin, uint depth);

    delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hDC, IntPtr hShareContext, int[] attribList);
    delegate IntPtr wglDXOpenDeviceNVDelegate(IntPtr dxDevice);
    delegate bool wglDXCloseDeviceNVDelegate(IntPtr hDevice);
    delegate IntPtr wglDXRegisterObjectNVDelegate(IntPtr hDevice, IntPtr dxObject, uint name, uint type, uint access);
    delegate bool wglDXUnregisterObjectNVDelegate(IntPtr hDevice, IntPtr hObject);
    delegate bool wglDXLockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);
    delegate bool wglDXUnlockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);

    // ============================================================
    // Known GUIDs
    // ============================================================
    static Guid IID_IDXGIDevice     = new Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c");
    static Guid IID_IDXGIFactory2   = new Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0");
    static Guid IID_ID3D11Texture2D = new Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c");

    static Guid IID_ICompositorDesktopInterop = new Guid("29E691FA-4567-4DCA-B319-D0F207EB6807");
    static Guid IID_ICompositorInterop        = new Guid("25297D5C-3AD4-4C9C-B5CF-E36A38512330");

    static Guid IID_ICompositor         = new Guid("B403CA50-7F8C-4E83-985F-CC45060036D8");
    static Guid IID_ICompositionTarget  = new Guid("A1BEA8BA-D726-4663-8129-6B5E7927FFA6");
    static Guid IID_IContainerVisual    = new Guid("02F6BC74-ED20-4773-AFE6-D49B4A93DB32");
    static Guid IID_IVisualCollection   = new Guid("8B745505-FD3E-4A98-84A8-E949468C6BCB");
    static Guid IID_ISpriteVisual       = new Guid("08E05581-1AD1-4F97-9757-402D76E4233B");
    static Guid IID_IVisual             = new Guid("117E202D-A859-4C89-873B-C2AA566788E3");
    static Guid IID_ICompositionBrush   = new Guid("AB0D7608-30C0-40E9-B568-B60A6BD1FB46");

    // ============================================================
    // Globals
    // ============================================================
    static uint WIDTH = 640;
    static uint HEIGHT = 480;
    static WndProcDelegate wndProcDelegate;
    static IntPtr g_hwnd;

    const string VS_HLSL = @"
struct VSInput  { float3 pos : POSITION; float4 col : COLOR; };
struct VSOutput { float4 pos : SV_POSITION; float4 col : COLOR; };
VSOutput main(VSInput i) {
    VSOutput o;
    o.pos = float4(i.pos, 1);
    o.col = i.col;
    return o;
}";

    const string PS_HLSL = @"
struct PSInput { float4 pos : SV_POSITION; float4 col : COLOR; };
float4 main(PSInput i) : SV_TARGET { return i.col; }
";

    const string VS_GLSL =
        "#version 460 core\n" +
        "layout(location = 0) in vec3 position;\n" +
        "layout(location = 1) in vec3 color;\n" +
        "out vec4 vColor;\n" +
        "void main() {\n" +
        "    vColor = vec4(color, 1.0);\n" +
        "    gl_Position = vec4(position, 1.0);\n" +
        "}\n";

    const string FS_GLSL =
        "#version 460 core\n" +
        "in vec4 vColor;\n" +
        "out vec4 outColor;\n" +
        "void main() {\n" +
        "    outColor = vColor;\n" +
        "}\n";

    // Composition COM pointers
    static IntPtr g_dqController;
    static IntPtr g_compositor;
    static IntPtr g_compositorUnk;
    static IntPtr g_desktopTarget;
    static IntPtr g_compTarget;
    static IntPtr g_rootContainer;
    static IntPtr g_rootVisual;
    static IntPtr g_spriteRaw;
    static IntPtr g_spriteVisual;
    static IntPtr g_children;
    static IntPtr g_brush;

    static IntPtr g_hDC;
    static IntPtr g_hGLRC;
    static IntPtr g_dxInteropDevice;
    static IntPtr g_dxInteropObject;
    static uint g_fbo;
    static uint g_rbo;
    static uint g_program;
    static readonly uint[] g_vbo = new uint[2];
    static int g_posAttrib;
    static int g_colAttrib;

    static glGenBuffersDelegate glGenBuffers;
    static glBindBufferDelegate glBindBuffer;
    static glBufferDataFloatDelegate glBufferData;
    static glCreateShaderDelegate glCreateShader;
    static glShaderSourceDelegate glShaderSource;
    static glCompileShaderDelegate glCompileShader;
    static glCreateProgramDelegate glCreateProgram;
    static glAttachShaderDelegate glAttachShader;
    static glLinkProgramDelegate glLinkProgram;
    static glUseProgramDelegate glUseProgram;
    static glGetAttribLocationDelegate glGetAttribLocation;
    static glEnableVertexAttribArrayDelegate glEnableVertexAttribArray;
    static glVertexAttribPointerDelegate glVertexAttribPointer;
    static glGenVertexArraysDelegate glGenVertexArrays;
    static glBindVertexArrayDelegate glBindVertexArray;
    static glGenFramebuffersDelegate glGenFramebuffers;
    static glBindFramebufferDelegate glBindFramebuffer;
    static glFramebufferRenderbufferDelegate glFramebufferRenderbuffer;
    static glGenRenderbuffersDelegate glGenRenderbuffers;
    static glClipControlDelegate glClipControl;

    static wglDXOpenDeviceNVDelegate wglDXOpenDeviceNV;
    static wglDXCloseDeviceNVDelegate wglDXCloseDeviceNV;
    static wglDXRegisterObjectNVDelegate wglDXRegisterObjectNV;
    static wglDXUnregisterObjectNVDelegate wglDXUnregisterObjectNV;
    static wglDXLockObjectsNVDelegate wglDXLockObjectsNV;
    static wglDXUnlockObjectsNVDelegate wglDXUnlockObjectsNV;

    // ============================================================
    // Helpers
    // ============================================================
    static int QI(IntPtr pUnk, ref Guid iid, out IntPtr ppv)
    {
        IntPtr vt = Marshal.ReadIntPtr(pUnk);
        IntPtr mp = Marshal.ReadIntPtr(vt, 0 * IntPtr.Size);
        var fn    = Marshal.GetDelegateForFunctionPointer(mp, typeof(QIDelegate)) as QIDelegate;
        return fn(pUnk, ref iid, out ppv);
    }

    static IntPtr BlobPtr(IntPtr blob)
    {
        IntPtr vt = Marshal.ReadIntPtr(blob);
        IntPtr mp = Marshal.ReadIntPtr(vt, 3 * IntPtr.Size);
        var fn    = Marshal.GetDelegateForFunctionPointer(mp, typeof(BlobGetPtrDelegate)) as BlobGetPtrDelegate;
        return fn(blob);
    }

    static int BlobSize(IntPtr blob)
    {
        IntPtr vt = Marshal.ReadIntPtr(blob);
        IntPtr mp = Marshal.ReadIntPtr(vt, 4 * IntPtr.Size);
        var fn    = Marshal.GetDelegateForFunctionPointer(mp, typeof(BlobGetSizeDelegate)) as BlobGetSizeDelegate;
        return (int)fn(blob);
    }

    static Delegate VT(IntPtr pCom, int index, Type delegateType)
    {
        IntPtr vt = Marshal.ReadIntPtr(pCom);
        IntPtr mp = Marshal.ReadIntPtr(vt, index * IntPtr.Size);
        return Marshal.GetDelegateForFunctionPointer(mp, delegateType);
    }

    static bool IsInvalidProcAddress(IntPtr p)
    {
        return p == IntPtr.Zero || p == (IntPtr)1 || p == (IntPtr)2 || p == (IntPtr)3 || p == (IntPtr)(-1);
    }

    static T LoadGL<T>(string name) where T : class
    {
        IntPtr p = wglGetProcAddress(name);
        if (IsInvalidProcAddress(p))
        {
            IntPtr module = GetModuleHandle("opengl32.dll");
            p = GetProcAddress(module, name);
        }

        if (p == IntPtr.Zero)
        {
            throw new Exception("Failed to load GL proc: " + name);
        }

        return Marshal.GetDelegateForFunctionPointer(p, typeof(T)) as T;
    }

    // ============================================================
    // WndProc
    // ============================================================
    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        switch (uMsg)
        {
            case WM_PAINT:
                PAINTSTRUCT ps;
                BeginPaint(hWnd, out ps);
                EndPaint(hWnd, ref ps);
                return IntPtr.Zero;
            case WM_DESTROY:
                dbg("WndProc", "WM_DESTROY received");
                PostQuitMessage(0);
                return IntPtr.Zero;
            default:
                return DefWindowProc(hWnd, uMsg, wParam, lParam);
        }
    }

    // ============================================================
    // CreateAppWindow
    // ============================================================
    static IntPtr CreateAppWindow()
    {
        const string FN = "CreateAppWindow";
        dbg(FN, "begin");

        IntPtr hInstance = GetModuleHandle(null);
        dbgPtr(FN, "hInstance", hInstance);

        wndProcDelegate = new WndProcDelegate(WndProc);

        var wc = new WNDCLASSEX
        {
            cbSize        = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style         = CS_OWNDC,
            lpfnWndProc   = wndProcDelegate,
            hInstance     = hInstance,
            hCursor       = LoadCursor(IntPtr.Zero, IDC_ARROW),
            hbrBackground = (IntPtr)(COLOR_WINDOW + 1),
            lpszClassName = "Win32CompTriangle",
        };

        dbg(FN, "calling RegisterClassEx");
        ushort atom = RegisterClassEx(ref wc);
        if (atom == 0)
        {
            dbg(FN, "RegisterClassEx FAILED GLE=" + Marshal.GetLastWin32Error());
            return IntPtr.Zero;
        }
        dbg(FN, "RegisterClassEx ok atom=" + atom);

        RECT rc = new RECT { Right = (int)WIDTH, Bottom = (int)HEIGHT };
        AdjustWindowRect(ref rc, WS_OVERLAPPEDWINDOW, false);

        dbg(FN, "calling CreateWindowEx");
        IntPtr hwnd = CreateWindowEx(0,
            "Win32CompTriangle",
            "D3D11 Triangle via Windows.UI.Composition (C#)",
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100, 100, rc.Right - rc.Left, rc.Bottom - rc.Top,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);

        if (hwnd == IntPtr.Zero)
        {
            dbg(FN, "CreateWindowEx FAILED GLE=" + Marshal.GetLastWin32Error());
            return IntPtr.Zero;
        }
        dbgPtr(FN, "hwnd", hwnd);

        ShowWindow(hwnd, 1);
        UpdateWindow(hwnd);
        dbg(FN, "ok");
        return hwnd;
    }

    // ============================================================
    // InitD3D11
    // ============================================================
    static int InitD3D11(
        out IntPtr device, out IntPtr context, out IntPtr swapChain,
        out IntPtr rtv, out IntPtr vs, out IntPtr ps,
        out IntPtr inputLayout, out IntPtr vertexBuffer)
    {
        const string FN = "InitD3D11";
        device = context = swapChain = rtv = vs = ps = inputLayout = vertexBuffer = IntPtr.Zero;
        dbg(FN, "begin");

        // 1) D3D11CreateDevice
        dbg(FN, "step 1: D3D11CreateDevice (BGRA_SUPPORT)");
        uint flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
        uint[] fls = { D3D_FEATURE_LEVEL_11_0 };
        IntPtr flOut;
        int hr = D3D11CreateDevice(IntPtr.Zero, D3D_DRIVER_TYPE_HARDWARE, IntPtr.Zero,
            flags, fls, (uint)fls.Length, D3D11_SDK_VERSION,
            out device, out flOut, out context);
        if (hr < 0) { dbgHR(FN, "D3D11CreateDevice", hr); return hr; }
        dbgPtr(FN, "Device", device);
        dbgPtr(FN, "Context", context);

        // 2) QI -> IDXGIDevice
        dbg(FN, "step 2: QI IDXGIDevice");
        IntPtr dxgiDev;
        hr = QI(device, ref IID_IDXGIDevice, out dxgiDev);
        if (hr < 0) { dbgHR(FN, "QI(IDXGIDevice)", hr); return hr; }
        dbgPtr(FN, "IDXGIDevice", dxgiDev);

        // 3) GetAdapter (vtable #7)
        dbg(FN, "step 3: IDXGIDevice::GetAdapter (vt#7)");
        IntPtr adapter;
        hr = ((GetAdapterDelegate)VT(dxgiDev, 7, typeof(GetAdapterDelegate)))(dxgiDev, out adapter);
        if (hr < 0) { dbgHR(FN, "GetAdapter", hr); return hr; }
        dbgPtr(FN, "Adapter", adapter);

        // 4) GetParent -> IDXGIFactory2 (vtable #6)
        dbg(FN, "step 4: IDXGIAdapter::GetParent(IDXGIFactory2) (vt#6)");
        IntPtr factory;
        hr = ((GetParentDelegate)VT(adapter, 6, typeof(GetParentDelegate)))(adapter, ref IID_IDXGIFactory2, out factory);
        Marshal.Release(adapter);
        if (hr < 0) { dbgHR(FN, "GetParent(IDXGIFactory2)", hr); return hr; }
        dbgPtr(FN, "IDXGIFactory2", factory);

        // 5) CreateSwapChainForComposition (vtable #24)
        dbg(FN, "step 5: IDXGIFactory2::CreateSwapChainForComposition (vt#24)");
        var scDesc = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = WIDTH, Height = HEIGHT,
            Format = DXGI_FORMAT_B8G8R8A8_UNORM,
            Stereo = 0,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            BufferCount = 2,
            Scaling = DXGI_SCALING_STRETCH,
            SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD,
            AlphaMode = DXGI_ALPHA_MODE_IGNORE,
            Flags = 0,
        };
        hr = ((CreateSCForCompDelegate)VT(factory, 24, typeof(CreateSCForCompDelegate)))(factory, device, ref scDesc, IntPtr.Zero, out swapChain);
        Marshal.Release(factory);
        Marshal.Release(dxgiDev);
        if (hr < 0) { dbgHR(FN, "CreateSwapChainForComposition", hr); return hr; }
        dbgPtr(FN, "SwapChain", swapChain);

        dbg(FN, "ok (device/context/swapchain ready)");
        return 0;
    }

    // ============================================================
    // InitComposition
    // ============================================================
    static int InitComposition(IntPtr hwnd, IntPtr swapChain)
    {
        const string FN = "InitComposition";
        dbg(FN, "begin");
        int hr;

        // 1) RoInitialize
        dbg(FN, "step 1: RoInitialize");
        hr = RoInitialize(0);
        if (hr < 0 && hr != 1)
        {
            dbgHR(FN, "RoInitialize", hr);
            return hr;
        }
        dbg(FN, "  RoInitialize ok (hr=" + hr + ")");

        // 2) DispatcherQueue
        dbg(FN, "step 2: CreateDispatcherQueueController");
        var dqOpt = new DispatcherQueueOptions
        {
            dwSize = Marshal.SizeOf(typeof(DispatcherQueueOptions)),
            threadType = 2,
            apartmentType = 0,
        };
        hr = CreateDispatcherQueueController(ref dqOpt, out g_dqController);
        if (hr < 0) { dbgHR(FN, "CreateDispatcherQueueController", hr); return hr; }
        dbgPtr(FN, "DQController", g_dqController);

        // 3) RoActivateInstance(Compositor)
        dbg(FN, "step 3: RoActivateInstance(Windows.UI.Composition.Compositor)");
        string className = "Windows.UI.Composition.Compositor";
        IntPtr hstr;
        hr = WindowsCreateString(className, (uint)className.Length, out hstr);
        if (hr < 0) { dbgHR(FN, "WindowsCreateString", hr); return hr; }
        dbg(FN, "  HSTRING created");

        hr = RoActivateInstance(hstr, out g_compositorUnk);
        WindowsDeleteString(hstr);
        if (hr < 0) { dbgHR(FN, "RoActivateInstance", hr); return hr; }
        dbgPtr(FN, "CompositorUnk", g_compositorUnk);

        // QI -> ICompositor
        dbg(FN, "step 3b: QI ICompositor");
        hr = QI(g_compositorUnk, ref IID_ICompositor, out g_compositor);
        if (hr < 0) { dbgHR(FN, "QI(ICompositor)", hr); return hr; }
        dbgPtr(FN, "ICompositor", g_compositor);

        // 4) ICompositorDesktopInterop::CreateDesktopWindowTarget (vt#3)
        dbg(FN, "step 4: QI ICompositorDesktopInterop");
        IntPtr deskInterop;
        hr = QI(g_compositorUnk, ref IID_ICompositorDesktopInterop, out deskInterop);
        if (hr < 0) { dbgHR(FN, "QI(ICompositorDesktopInterop)", hr); return hr; }
        dbgPtr(FN, "ICompositorDesktopInterop", deskInterop);

        dbg(FN, "step 4b: CreateDesktopWindowTarget (vt#3)");
        hr = ((CreateDesktopWindowTargetDelegate)VT(deskInterop, 3, typeof(CreateDesktopWindowTargetDelegate)))(deskInterop, hwnd, 0, out g_desktopTarget);
        Marshal.Release(deskInterop);
        if (hr < 0) { dbgHR(FN, "CreateDesktopWindowTarget", hr); return hr; }
        dbgPtr(FN, "DesktopWindowTarget", g_desktopTarget);

        // 5) QI -> ICompositionTarget
        dbg(FN, "step 5: QI ICompositionTarget");
        hr = QI(g_desktopTarget, ref IID_ICompositionTarget, out g_compTarget);
        if (hr < 0) { dbgHR(FN, "QI(ICompositionTarget)", hr); return hr; }
        dbgPtr(FN, "ICompositionTarget", g_compTarget);

        // 6) CreateContainerVisual (vt#9 on ICompositor)
        dbg(FN, "step 6: ICompositor::CreateContainerVisual (vt#9)");
        hr = ((CreateContainerVisualDelegate)VT(g_compositor, 9, typeof(CreateContainerVisualDelegate)))(g_compositor, out g_rootContainer);
        if (hr < 0) { dbgHR(FN, "CreateContainerVisual", hr); return hr; }
        dbgPtr(FN, "ContainerVisual", g_rootContainer);

        // QI -> IVisual
        dbg(FN, "step 6b: QI IVisual (root)");
        hr = QI(g_rootContainer, ref IID_IVisual, out g_rootVisual);
        if (hr < 0) { dbgHR(FN, "QI(IVisual) root", hr); return hr; }
        dbgPtr(FN, "IVisual(root)", g_rootVisual);

        // put_Root (vt#7 on ICompositionTarget)
        dbg(FN, "step 6c: ICompositionTarget::put_Root (vt#7)");
        hr = ((PutRootDelegate)VT(g_compTarget, 7, typeof(PutRootDelegate)))(g_compTarget, g_rootVisual);
        if (hr < 0) { dbgHR(FN, "put_Root", hr); return hr; }
        dbg(FN, "  Root visual set");

        // 7) ICompositorInterop::CreateCompositionSurfaceForSwapChain (vt#4)
        dbg(FN, "step 7: QI ICompositorInterop");
        IntPtr compInterop;
        hr = QI(g_compositorUnk, ref IID_ICompositorInterop, out compInterop);
        if (hr < 0) { dbgHR(FN, "QI(ICompositorInterop)", hr); return hr; }
        dbgPtr(FN, "ICompositorInterop", compInterop);

        dbg(FN, "step 7b: CreateCompositionSurfaceForSwapChain (vt#4)");
        IntPtr surface;
        hr = ((CreateCompSurfaceForSCDelegate)VT(compInterop, 4, typeof(CreateCompSurfaceForSCDelegate)))(compInterop, swapChain, out surface);
        Marshal.Release(compInterop);
        if (hr < 0) { dbgHR(FN, "CreateCompSurfaceForSwapChain", hr); return hr; }
        dbgPtr(FN, "CompositionSurface", surface);

        // 8) CreateSurfaceBrushWithSurface (vt#24 on ICompositor)
        dbg(FN, "step 8: ICompositor::CreateSurfaceBrushWithSurface (vt#24)");
        IntPtr surfBrush;
        hr = ((CreateSurfaceBrushWithSurfaceDelegate)VT(g_compositor, 24, typeof(CreateSurfaceBrushWithSurfaceDelegate)))(g_compositor, surface, out surfBrush);
        Marshal.Release(surface);
        if (hr < 0) { dbgHR(FN, "CreateSurfaceBrushWithSurface", hr); return hr; }
        dbgPtr(FN, "SurfaceBrush", surfBrush);

        // QI -> ICompositionBrush
        dbg(FN, "step 8b: QI ICompositionBrush");
        hr = QI(surfBrush, ref IID_ICompositionBrush, out g_brush);
        Marshal.Release(surfBrush);
        if (hr < 0) { dbgHR(FN, "QI(ICompositionBrush)", hr); return hr; }
        dbgPtr(FN, "ICompositionBrush", g_brush);

        // 9) CreateSpriteVisual (vt#22 on ICompositor)
        dbg(FN, "step 9: ICompositor::CreateSpriteVisual (vt#22)");
        hr = ((CreateSpriteVisualDelegate)VT(g_compositor, 22, typeof(CreateSpriteVisualDelegate)))(g_compositor, out g_spriteRaw);
        if (hr < 0) { dbgHR(FN, "CreateSpriteVisual", hr); return hr; }
        dbgPtr(FN, "SpriteVisual", g_spriteRaw);

        // put_Brush (vt#7 on ISpriteVisual)
        dbg(FN, "step 9b: ISpriteVisual::put_Brush (vt#7)");
        hr = ((PutBrushDelegate)VT(g_spriteRaw, 7, typeof(PutBrushDelegate)))(g_spriteRaw, g_brush);
        if (hr < 0) { dbgHR(FN, "put_Brush", hr); return hr; }
        dbg(FN, "  Brush set");

        // QI sprite -> IVisual
        dbg(FN, "step 9c: QI IVisual (sprite)");
        hr = QI(g_spriteRaw, ref IID_IVisual, out g_spriteVisual);
        if (hr < 0) { dbgHR(FN, "QI(IVisual) sprite", hr); return hr; }
        dbgPtr(FN, "IVisual(sprite)", g_spriteVisual);

        // put_Size (vt#36 on IVisual)
        dbg(FN, "step 9d: IVisual::put_Size (vt#36) size=" + WIDTH + "x" + HEIGHT);
        hr = ((PutSizeDelegate)VT(g_spriteVisual, 36, typeof(PutSizeDelegate)))(g_spriteVisual, new Float2 { X = WIDTH, Y = HEIGHT });
        if (hr < 0) { dbgHR(FN, "put_Size", hr); return hr; }
        dbg(FN, "  Size set");

        // 10) get_Children (vt#6 on IContainerVisual) + InsertAtTop (vt#9)
        dbg(FN, "step 10: IContainerVisual::get_Children (vt#6)");
        hr = ((GetChildrenDelegate)VT(g_rootContainer, 6, typeof(GetChildrenDelegate)))(g_rootContainer, out g_children);
        if (hr < 0) { dbgHR(FN, "get_Children", hr); return hr; }
        dbgPtr(FN, "IVisualCollection", g_children);

        dbg(FN, "step 10b: IVisualCollection::InsertAtTop (vt#9)");
        hr = ((InsertAtTopDelegate)VT(g_children, 9, typeof(InsertAtTopDelegate)))(g_children, g_spriteVisual);
        if (hr < 0) { dbgHR(FN, "InsertAtTop", hr); return hr; }
        dbg(FN, "  SpriteVisual inserted");

        dbg(FN, "ok (all 10 steps completed)");
        return 0;
    }

    static int InitOpenGLInterop(IntPtr hwnd, IntPtr device, IntPtr swapChain)
    {
        const string FN = "InitOpenGLInterop";
        dbg(FN, "begin");

        g_hDC = GetDC(hwnd);
        if (g_hDC == IntPtr.Zero)
        {
            return Marshal.GetHRForLastWin32Error();
        }

        var pfd = new PIXELFORMATDESCRIPTOR
        {
            nSize = (ushort)Marshal.SizeOf(typeof(PIXELFORMATDESCRIPTOR)),
            nVersion = 1,
            dwFlags = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER,
            iPixelType = (byte)PFD_TYPE_RGBA,
            cColorBits = 32,
            cAlphaBits = 8,
            cDepthBits = 24,
        };

        int format = ChoosePixelFormat(g_hDC, ref pfd);
        if (format == 0) return Marshal.GetHRForLastWin32Error();
        if (!SetPixelFormat(g_hDC, format, ref pfd)) return Marshal.GetHRForLastWin32Error();

        IntPtr tmp = wglCreateContext(g_hDC);
        if (tmp == IntPtr.Zero) return Marshal.GetHRForLastWin32Error();
        wglMakeCurrent(g_hDC, tmp);

        var createCtx = LoadGL<wglCreateContextAttribsARBDelegate>("wglCreateContextAttribsARB");
        int[] attrs =
        {
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, 6,
            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0,
        };
        g_hGLRC = createCtx(g_hDC, IntPtr.Zero, attrs);
        if (g_hGLRC == IntPtr.Zero) return -1;

        wglMakeCurrent(g_hDC, g_hGLRC);
        wglDeleteContext(tmp);

        glGenBuffers = LoadGL<glGenBuffersDelegate>("glGenBuffers");
        glBindBuffer = LoadGL<glBindBufferDelegate>("glBindBuffer");
        glBufferData = LoadGL<glBufferDataFloatDelegate>("glBufferData");
        glCreateShader = LoadGL<glCreateShaderDelegate>("glCreateShader");
        glShaderSource = LoadGL<glShaderSourceDelegate>("glShaderSource");
        glCompileShader = LoadGL<glCompileShaderDelegate>("glCompileShader");
        glCreateProgram = LoadGL<glCreateProgramDelegate>("glCreateProgram");
        glAttachShader = LoadGL<glAttachShaderDelegate>("glAttachShader");
        glLinkProgram = LoadGL<glLinkProgramDelegate>("glLinkProgram");
        glUseProgram = LoadGL<glUseProgramDelegate>("glUseProgram");
        glGetAttribLocation = LoadGL<glGetAttribLocationDelegate>("glGetAttribLocation");
        glEnableVertexAttribArray = LoadGL<glEnableVertexAttribArrayDelegate>("glEnableVertexAttribArray");
        glVertexAttribPointer = LoadGL<glVertexAttribPointerDelegate>("glVertexAttribPointer");
        glGenVertexArrays = LoadGL<glGenVertexArraysDelegate>("glGenVertexArrays");
        glBindVertexArray = LoadGL<glBindVertexArrayDelegate>("glBindVertexArray");
        glGenFramebuffers = LoadGL<glGenFramebuffersDelegate>("glGenFramebuffers");
        glBindFramebuffer = LoadGL<glBindFramebufferDelegate>("glBindFramebuffer");
        glFramebufferRenderbuffer = LoadGL<glFramebufferRenderbufferDelegate>("glFramebufferRenderbuffer");
        glGenRenderbuffers = LoadGL<glGenRenderbuffersDelegate>("glGenRenderbuffers");
        glClipControl = LoadGL<glClipControlDelegate>("glClipControl");

        wglDXOpenDeviceNV = LoadGL<wglDXOpenDeviceNVDelegate>("wglDXOpenDeviceNV");
        wglDXCloseDeviceNV = LoadGL<wglDXCloseDeviceNVDelegate>("wglDXCloseDeviceNV");
        wglDXRegisterObjectNV = LoadGL<wglDXRegisterObjectNVDelegate>("wglDXRegisterObjectNV");
        wglDXUnregisterObjectNV = LoadGL<wglDXUnregisterObjectNVDelegate>("wglDXUnregisterObjectNV");
        wglDXLockObjectsNV = LoadGL<wglDXLockObjectsNVDelegate>("wglDXLockObjectsNV");
        wglDXUnlockObjectsNV = LoadGL<wglDXUnlockObjectsNVDelegate>("wglDXUnlockObjectsNV");

        // Flip output vertically without modifying vertices or shaders.
        glClipControl(GL_UPPER_LEFT, GL_NEGATIVE_ONE_TO_ONE);

        g_dxInteropDevice = wglDXOpenDeviceNV(device);
        if (g_dxInteropDevice == IntPtr.Zero) return -1;

        IntPtr backBuffer;
        int hr = ((GetSCBufferDelegate)VT(swapChain, 9, typeof(GetSCBufferDelegate)))(swapChain, 0, ref IID_ID3D11Texture2D, out backBuffer);
        if (hr < 0) return hr;

        uint[] rbo = new uint[1];
        glGenRenderbuffers(1, rbo);
        g_rbo = rbo[0];

        g_dxInteropObject = wglDXRegisterObjectNV(g_dxInteropDevice, backBuffer, g_rbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
        Marshal.Release(backBuffer);
        if (g_dxInteropObject == IntPtr.Zero) return -1;

        uint[] fbo = new uint[1];
        glGenFramebuffers(1, fbo);
        g_fbo = fbo[0];
        glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_rbo);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        uint[] vao = new uint[1];
        glGenVertexArrays(1, vao);
        glBindVertexArray(vao[0]);

        glGenBuffers(2, g_vbo);
        float[] vertices = {
            -0.5f, -0.5f, 0.0f,
             0.5f, -0.5f, 0.0f,
             0.0f,  0.5f, 0.0f
        };
        float[] colors = {
            0.0f, 0.0f, 1.0f,
            0.0f, 1.0f, 0.0f,
            1.0f, 0.0f, 0.0f
        };
        glBindBuffer(GL_ARRAY_BUFFER, g_vbo[0]);
        glBufferData(GL_ARRAY_BUFFER, vertices.Length * sizeof(float), vertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, g_vbo[1]);
        glBufferData(GL_ARRAY_BUFFER, colors.Length * sizeof(float), colors, GL_STATIC_DRAW);

        uint vs = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vs, 1, new[] { VS_GLSL }, null);
        glCompileShader(vs);
        uint fs = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fs, 1, new[] { FS_GLSL }, null);
        glCompileShader(fs);

        g_program = glCreateProgram();
        glAttachShader(g_program, vs);
        glAttachShader(g_program, fs);
        glLinkProgram(g_program);
        glUseProgram(g_program);

        g_posAttrib = glGetAttribLocation(g_program, "position");
        g_colAttrib = glGetAttribLocation(g_program, "color");
        glEnableVertexAttribArray((uint)g_posAttrib);
        glEnableVertexAttribArray((uint)g_colAttrib);

        dbg(FN, "ok");
        return 0;
    }

    static bool g_firstRender = true;

    static void Render(IntPtr swapChain)
    {
        if (g_firstRender) dbg("Render", "first frame begin");

        wglMakeCurrent(g_hDC, g_hGLRC);
        IntPtr[] objs = { g_dxInteropObject };
        if (!wglDXLockObjectsNV(g_dxInteropDevice, 1, objs))
        {
            dbg("Render", "wglDXLockObjectsNV failed");
            return;
        }

        try
        {
            glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
            glViewport(0, 0, (int)WIDTH, (int)HEIGHT);
            glClearColor(0f, 0f, 0f, 1f);
            glClear(GL_COLOR_BUFFER_BIT);

            glUseProgram(g_program);
            glBindBuffer(GL_ARRAY_BUFFER, g_vbo[0]);
            glVertexAttribPointer((uint)g_posAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
            glBindBuffer(GL_ARRAY_BUFFER, g_vbo[1]);
            glVertexAttribPointer((uint)g_colAttrib, 3, GL_FLOAT, false, 0, IntPtr.Zero);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            glFlush();
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
        }
        finally
        {
            wglDXUnlockObjectsNV(g_dxInteropDevice, 1, objs);
        }

        int hr = ((PresentDelegate)VT(swapChain, 8, typeof(PresentDelegate)))(swapChain, 1, 0);
        if (g_firstRender)
        {
            dbg("Render", "first frame Present hr=0x" + hr.ToString("X8"));
            g_firstRender = false;
        }
    }

    // ============================================================
    // Cleanup
    // ============================================================
    static void Cleanup(IntPtr device, IntPtr context, IntPtr swapChain,
                        IntPtr rtv, IntPtr vs, IntPtr ps,
                        IntPtr inputLayout, IntPtr vertexBuffer)
    {
        const string FN = "Cleanup";
        dbg(FN, "begin");

        if (g_dxInteropObject != IntPtr.Zero && g_dxInteropDevice != IntPtr.Zero)
        {
            wglDXUnregisterObjectNV(g_dxInteropDevice, g_dxInteropObject);
            g_dxInteropObject = IntPtr.Zero;
            dbg(FN, "unregistered DX interop object");
        }
        if (g_dxInteropDevice != IntPtr.Zero)
        {
            wglDXCloseDeviceNV(g_dxInteropDevice);
            g_dxInteropDevice = IntPtr.Zero;
            dbg(FN, "closed DX interop device");
        }

        wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
        if (g_hGLRC != IntPtr.Zero)
        {
            wglDeleteContext(g_hGLRC);
            g_hGLRC = IntPtr.Zero;
            dbg(FN, "released GL context");
        }
        if (g_hDC != IntPtr.Zero)
        {
            ReleaseDC(g_hwnd, g_hDC);
            g_hDC = IntPtr.Zero;
            dbg(FN, "released DC");
        }

        if (g_children      != IntPtr.Zero) { Marshal.Release(g_children);      dbg(FN, "released children"); }
        if (g_spriteVisual  != IntPtr.Zero) { Marshal.Release(g_spriteVisual);  dbg(FN, "released spriteVisual"); }
        if (g_spriteRaw     != IntPtr.Zero) { Marshal.Release(g_spriteRaw);     dbg(FN, "released spriteRaw"); }
        if (g_brush         != IntPtr.Zero) { Marshal.Release(g_brush);         dbg(FN, "released brush"); }
        if (g_rootVisual    != IntPtr.Zero) { Marshal.Release(g_rootVisual);    dbg(FN, "released rootVisual"); }
        if (g_rootContainer != IntPtr.Zero) { Marshal.Release(g_rootContainer); dbg(FN, "released rootContainer"); }
        if (g_compTarget    != IntPtr.Zero) { Marshal.Release(g_compTarget);    dbg(FN, "released compTarget"); }
        if (g_desktopTarget != IntPtr.Zero) { Marshal.Release(g_desktopTarget); dbg(FN, "released desktopTarget"); }
        if (g_compositor    != IntPtr.Zero) { Marshal.Release(g_compositor);    dbg(FN, "released compositor"); }
        if (g_compositorUnk != IntPtr.Zero) { Marshal.Release(g_compositorUnk); dbg(FN, "released compositorUnk"); }
        if (g_dqController  != IntPtr.Zero) { Marshal.Release(g_dqController);  dbg(FN, "released dqController"); }

        if (vertexBuffer != IntPtr.Zero) { Marshal.Release(vertexBuffer); dbg(FN, "released vertexBuffer"); }
        if (inputLayout  != IntPtr.Zero) { Marshal.Release(inputLayout);  dbg(FN, "released inputLayout"); }
        if (ps           != IntPtr.Zero) { Marshal.Release(ps);           dbg(FN, "released PS"); }
        if (vs           != IntPtr.Zero) { Marshal.Release(vs);           dbg(FN, "released VS"); }
        if (rtv          != IntPtr.Zero) { Marshal.Release(rtv);          dbg(FN, "released RTV"); }
        if (swapChain    != IntPtr.Zero) { Marshal.Release(swapChain);    dbg(FN, "released swapChain"); }
        if (context      != IntPtr.Zero) { Marshal.Release(context);      dbg(FN, "released context"); }
        if (device       != IntPtr.Zero) { Marshal.Release(device);       dbg(FN, "released device"); }

        dbg(FN, "ok");
    }

    // ============================================================
    // Entry Point
    // ============================================================
    [STAThread]
    static int Main(string[] args)
    {
        const string FN = "Main";
        dbg(FN, "========================================");
        dbg(FN, "OpenGL 4.6 Triangle via Composition (C# vtable)");
        dbg(FN, "========================================");

        dbg(FN, "calling CreateAppWindow");
        g_hwnd = CreateAppWindow();
        if (g_hwnd == IntPtr.Zero) { dbg(FN, "FATAL: CreateAppWindow failed"); return 1; }

        dbg(FN, "calling InitD3D11");
        IntPtr device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer;
        int hr = InitD3D11(out device, out context, out swapChain,
                           out rtv, out vs, out ps,
                           out inputLayout, out vertexBuffer);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitD3D11 failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        dbg(FN, "calling InitComposition");
        hr = InitComposition(g_hwnd, swapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitComposition failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        dbg(FN, "calling InitOpenGLInterop");
        hr = InitOpenGLInterop(g_hwnd, device, swapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitOpenGLInterop failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        dbg(FN, "entering message loop");
        MSG msg = new MSG();
        while (msg.message != WM_QUIT)
        {
            if (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE))
            {
                TranslateMessage(ref msg);
                DispatchMessage(ref msg);
            }
            else
            {
                Render(swapChain);
            }
        }

        dbg(FN, "message loop ended");
        Cleanup(device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer);
        dbg(FN, "exit");
        return 0;
    }
}




