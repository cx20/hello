// Hello.cs
// OpenGL 4.6 + D3D11 + Vulkan 1.4 Triangles via Windows.UI.Composition (Win32 Desktop Interop)
// ALL COM/WinRT calls via vtable index. No external libraries. No WinRT projections.
// Logging: OutputDebugStringW (use DebugView to monitor)
//
// Build (Visual Studio Developer Command Prompt):
//   csc /target:winexe /unsafe Hello.cs

using System;
using System.Runtime.InteropServices;
using System.IO;
using System.Text;

static class SC
{
    const string L = "shaderc_shared.dll";
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compiler_initialize();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compiler_release(IntPtr c);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_options_initialize();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compile_options_release(IntPtr o);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compile_options_set_optimization_level(IntPtr o, int l);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_into_spv(IntPtr c, [MarshalAs(UnmanagedType.LPStr)] string s, UIntPtr sz, int k, [MarshalAs(UnmanagedType.LPStr)] string fn, [MarshalAs(UnmanagedType.LPStr)] string ep, IntPtr o);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern int shaderc_result_get_compilation_status(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern UIntPtr shaderc_result_get_length(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_bytes(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_error_message(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_result_release(IntPtr r);

    public static byte[] Compile(string src, int kind, string file)
    {
        IntPtr comp = shaderc_compiler_initialize();
        IntPtr opt = shaderc_compile_options_initialize();
        shaderc_compile_options_set_optimization_level(opt, 2);
        try
        {
            IntPtr res = shaderc_compile_into_spv(comp, src, (UIntPtr)Encoding.UTF8.GetByteCount(src), kind, file, "main", opt);
            try
            {
                if (shaderc_result_get_compilation_status(res) != 0)
                {
                    string e = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(res));
                    throw new Exception("Shader: " + e);
                }
                int len = (int)(ulong)shaderc_result_get_length(res);
                byte[] data = new byte[len];
                Marshal.Copy(shaderc_result_get_bytes(res), data, 0, len);
                return data;
            }
            finally { shaderc_result_release(res); }
        }
        finally
        {
            shaderc_compile_options_release(opt);
            shaderc_compiler_release(comp);
        }
    }
}

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
    struct Float2 { public float X, Y; }
    [StructLayout(LayoutKind.Sequential)]
    struct Float3 { public float X, Y, Z; }

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
    const uint D3D11_USAGE_STAGING      = 3;
    const uint D3D11_CPU_ACCESS_WRITE   = 0x10000;
    const uint D3D11_MAP_WRITE          = 2;
    const uint D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

    const int PANEL_COUNT = 3;
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
    const uint GL_LOWER_LEFT = 0x8CA1;
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

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_TEXTURE2D_DESC
    {
        public uint Width, Height, MipLevels, ArraySize, Format;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint Usage, BindFlags, CPUAccessFlags, MiscFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_MAPPED_SUBRESOURCE
    {
        public IntPtr pData;
        public uint RowPitch, DepthPitch;
    }

    // Vulkan structs
    [StructLayout(LayoutKind.Sequential)] struct VkAppInfo { public uint sType; public IntPtr pNext, pAppName; public uint appVer; public IntPtr pEngName; public uint engVer, apiVer; }
    [StructLayout(LayoutKind.Sequential)] struct VkInstCI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pAppInfo; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; }
    [StructLayout(LayoutKind.Sequential)] struct VkDevQCI { public uint sType; public IntPtr pNext; public uint flags, qfi, qCnt; public IntPtr pPrio; }
    [StructLayout(LayoutKind.Sequential)] struct VkDevCI { public uint sType; public IntPtr pNext; public uint flags, qciCnt; public IntPtr pQCI; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; public IntPtr pFeat; }
    [StructLayout(LayoutKind.Sequential)] struct VkQFP { public uint qFlags, qCnt, tsVB, gW, gH, gD; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemReq { public ulong size, align; public uint memBits; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemAI { public uint sType; public IntPtr pNext; public ulong size; public uint memIdx; }
    [StructLayout(LayoutKind.Sequential)] struct VkMemType { public uint propFlags, heapIdx; }
    [StructLayout(LayoutKind.Sequential, Pack = 4)] unsafe struct VkPhysMemProps { public uint typeCnt; public fixed byte types[256]; public uint heapCnt; public fixed byte heaps[256]; }
    [StructLayout(LayoutKind.Sequential)] struct VkImgCI { public uint sType; public IntPtr pNext; public uint flags, imgType, fmt, eW, eH, eD, mip, arr, samples, tiling, usage, sharing, qfCnt; public IntPtr pQF; public uint initLayout; }
    [StructLayout(LayoutKind.Sequential)] struct VkImgViewCI { public uint sType; public IntPtr pNext; public uint flags; public ulong img; public uint viewType, fmt, cR, cG, cB, cA, aspect, baseMip, lvlCnt, baseLayer, layerCnt; }
    [StructLayout(LayoutKind.Sequential)] struct VkBufCI { public uint sType; public IntPtr pNext; public uint flags; public ulong size; public uint usage, sharing, qfCnt; public IntPtr pQF; }
    [StructLayout(LayoutKind.Sequential)] struct VkAttDesc { public uint flags, fmt, samples, loadOp, storeOp, stLoadOp, stStoreOp, initLayout, finalLayout; }
    [StructLayout(LayoutKind.Sequential)] struct VkAttRef { public uint att, layout; }
    [StructLayout(LayoutKind.Sequential)] struct VkSubDesc { public uint flags, bp, iaCnt; public IntPtr pIA; public uint caCnt; public IntPtr pCA, pRA, pDA; public uint paCnt; public IntPtr pPA; }
    [StructLayout(LayoutKind.Sequential)] struct VkRPCI { public uint sType; public IntPtr pNext; public uint flags, attCnt; public IntPtr pAtts; public uint subCnt; public IntPtr pSubs; public uint depCnt; public IntPtr pDeps; }
    [StructLayout(LayoutKind.Sequential)] struct VkFBCI { public uint sType; public IntPtr pNext; public uint flags; public ulong rp; public uint attCnt; public IntPtr pAtts; public uint w, h, layers; }
    [StructLayout(LayoutKind.Sequential)] struct VkSMCI { public uint sType; public IntPtr pNext; public uint flags; public UIntPtr codeSz; public IntPtr pCode; }
    [StructLayout(LayoutKind.Sequential)] struct VkPSSCI { public uint sType; public IntPtr pNext; public uint flags, stage; public ulong module; public IntPtr pName, pSpec; }
    [StructLayout(LayoutKind.Sequential)] struct VkPVICI { public uint sType; public IntPtr pNext; public uint flags, vbdCnt; public IntPtr pVBD; public uint vadCnt; public IntPtr pVAD; }
    [StructLayout(LayoutKind.Sequential)] struct VkPIACI { public uint sType; public IntPtr pNext; public uint flags, topo, primRestart; }
    [StructLayout(LayoutKind.Sequential)] struct VkViewport { public float x, y, w, h, minD, maxD; }
    [StructLayout(LayoutKind.Sequential)] struct VkOff2D { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct VkExt2D { public uint w, h; }
    [StructLayout(LayoutKind.Sequential)] struct VkRect2D { public VkOff2D off; public VkExt2D ext; }
    [StructLayout(LayoutKind.Sequential)] struct VkPVPCI { public uint sType; public IntPtr pNext; public uint flags, vpCnt; public IntPtr pVP; public uint scCnt; public IntPtr pSC; }
    [StructLayout(LayoutKind.Sequential)] struct VkPRCI { public uint sType; public IntPtr pNext; public uint flags, depthClamp, rastDiscard, polyMode, cullMode, frontFace, depthBias; public float dbConst, dbClamp, dbSlope, lineW; }
    [StructLayout(LayoutKind.Sequential)] struct VkPMSCI { public uint sType; public IntPtr pNext; public uint flags, rSamples, sShading; public float minSS; public IntPtr pSM; public uint a2c, a2o; }
    [StructLayout(LayoutKind.Sequential)] struct VkPCBAS { public uint blendEn, sCBF, dCBF, cbOp, sABF, dABF, abOp, wMask; }
    [StructLayout(LayoutKind.Sequential)] unsafe struct VkPCBCI { public uint sType; public IntPtr pNext; public uint flags, logicOpEn, logicOp, attCnt; public IntPtr pAtts; public fixed float bc[4]; }
    [StructLayout(LayoutKind.Sequential)] struct VkPLCI { public uint sType; public IntPtr pNext; public uint flags, slCnt; public IntPtr pSL; public uint pcCnt; public IntPtr pPC; }
    [StructLayout(LayoutKind.Sequential)] struct VkGPCI { public uint sType; public IntPtr pNext; public uint flags, stageCnt; public IntPtr pStages, pVIS, pIAS, pTess, pVPS, pRast, pMS, pDS, pCBS, pDyn; public ulong layout, rp; public uint subpass; public ulong basePipe; public int basePipeIdx; }
    [StructLayout(LayoutKind.Sequential)] struct VkCPCI { public uint sType; public IntPtr pNext; public uint flags, qfi; }
    [StructLayout(LayoutKind.Sequential)] struct VkCBAI { public uint sType; public IntPtr pNext; public IntPtr pool; public uint level, cnt; }
    [StructLayout(LayoutKind.Sequential)] struct VkCBBI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pInh; }
    [StructLayout(LayoutKind.Sequential)] struct VkClearCol { public float r, g, b, a; }
    [StructLayout(LayoutKind.Explicit)] struct VkClearVal { [FieldOffset(0)] public VkClearCol color; }
    [StructLayout(LayoutKind.Sequential)] struct VkRPBI { public uint sType; public IntPtr pNext; public ulong rp, fb; public VkRect2D area; public uint cvCnt; public IntPtr pCV; }
    [StructLayout(LayoutKind.Sequential)] struct VkFenceCI { public uint sType; public IntPtr pNext; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct VkSubmitInfo { public uint sType; public IntPtr pNext; public uint wsCnt; public IntPtr pWS, pWSM; public uint cbCnt; public IntPtr pCB; public uint ssCnt; public IntPtr pSS; }
    [StructLayout(LayoutKind.Sequential)] struct VkBufImgCopy { public ulong bufOff; public uint bRL, bIH, aspect, mip, baseL, lCnt; public int oX, oY, oZ; public uint eW, eH, eD; }

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

    [DllImport("vulkan-1.dll")] static extern int vkCreateInstance(ref VkInstCI ci, IntPtr a, out IntPtr i);
    [DllImport("vulkan-1.dll")] static extern int vkEnumeratePhysicalDevices(IntPtr i, ref uint c, IntPtr[] d);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr p, ref uint c, [Out] VkQFP[] q);
    [DllImport("vulkan-1.dll")] static extern int vkCreateDevice(IntPtr p, ref VkDevCI ci, IntPtr a, out IntPtr d);
    [DllImport("vulkan-1.dll")] static extern void vkGetDeviceQueue(IntPtr d, uint qf, uint qi, out IntPtr q);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr p, out VkPhysMemProps m);
    [DllImport("vulkan-1.dll")] static extern int vkCreateImage(IntPtr d, ref VkImgCI ci, IntPtr a, out ulong img);
    [DllImport("vulkan-1.dll")] static extern void vkGetImageMemoryRequirements(IntPtr d, ulong img, out VkMemReq r);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateMemory(IntPtr d, ref VkMemAI ai, IntPtr a, out ulong m);
    [DllImport("vulkan-1.dll")] static extern int vkBindImageMemory(IntPtr d, ulong img, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] static extern int vkCreateImageView(IntPtr d, ref VkImgViewCI ci, IntPtr a, out ulong v);
    [DllImport("vulkan-1.dll")] static extern int vkCreateBuffer(IntPtr d, ref VkBufCI ci, IntPtr a, out ulong b);
    [DllImport("vulkan-1.dll")] static extern void vkGetBufferMemoryRequirements(IntPtr d, ulong b, out VkMemReq r);
    [DllImport("vulkan-1.dll")] static extern int vkBindBufferMemory(IntPtr d, ulong b, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] static extern int vkCreateRenderPass(IntPtr d, ref VkRPCI ci, IntPtr a, out ulong rp);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFramebuffer(IntPtr d, ref VkFBCI ci, IntPtr a, out ulong fb);
    [DllImport("vulkan-1.dll")] static extern int vkCreateShaderModule(IntPtr d, ref VkSMCI ci, IntPtr a, out ulong sm);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyShaderModule(IntPtr d, ulong sm, IntPtr a);
    [DllImport("vulkan-1.dll")] static extern int vkCreatePipelineLayout(IntPtr d, ref VkPLCI ci, IntPtr a, out ulong pl);
    [DllImport("vulkan-1.dll")] static extern int vkCreateGraphicsPipelines(IntPtr d, ulong cache, uint n, ref VkGPCI ci, IntPtr a, out ulong p);
    [DllImport("vulkan-1.dll")] static extern int vkCreateCommandPool(IntPtr d, ref VkCPCI ci, IntPtr a, out IntPtr p);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateCommandBuffers(IntPtr d, ref VkCBAI ai, out IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFence(IntPtr d, ref VkFenceCI ci, IntPtr a, out ulong f);
    [DllImport("vulkan-1.dll")] static extern int vkWaitForFences(IntPtr d, uint n, ulong[] f, uint all, ulong t);
    [DllImport("vulkan-1.dll")] static extern int vkResetFences(IntPtr d, uint n, ulong[] f);
    [DllImport("vulkan-1.dll")] static extern int vkResetCommandBuffer(IntPtr cb, uint f);
    [DllImport("vulkan-1.dll")] static extern int vkBeginCommandBuffer(IntPtr cb, ref VkCBBI bi);
    [DllImport("vulkan-1.dll")] static extern int vkEndCommandBuffer(IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBeginRenderPass(IntPtr cb, ref VkRPBI rp, uint c);
    [DllImport("vulkan-1.dll")] static extern void vkCmdEndRenderPass(IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindPipeline(IntPtr cb, uint bp, ulong p);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDraw(IntPtr cb, uint vc, uint ic, uint fv, uint fi);
    [DllImport("vulkan-1.dll")] static extern unsafe void vkCmdCopyImageToBuffer(IntPtr cb, ulong img, uint layout, ulong buf, uint n, VkBufImgCopy* r);
    [DllImport("vulkan-1.dll")] static extern int vkQueueSubmit(IntPtr q, uint n, ref VkSubmitInfo si, ulong f);
    [DllImport("vulkan-1.dll")] static extern int vkMapMemory(IntPtr d, ulong m, ulong o, ulong sz, uint f, out IntPtr p);
    [DllImport("vulkan-1.dll")] static extern void vkUnmapMemory(IntPtr d, ulong m);
    [DllImport("vulkan-1.dll")] static extern int vkDeviceWaitIdle(IntPtr d);

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
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateTexture2DDelegate(IntPtr device, ref D3D11_TEXTURE2D_DESC pDesc, IntPtr pInitData, out IntPtr ppTexture2D);

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
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int MapDelegate(IntPtr ctx, IntPtr res, uint subresource, uint mapType, uint mapFlags, out D3D11_MAPPED_SUBRESOURCE mapped);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void UnmapDelegate(IntPtr ctx, IntPtr res, uint subresource);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void CopyResourceDelegate(IntPtr ctx, IntPtr dst, IntPtr src);

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
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PutOffsetDelegate(IntPtr visual, Float3 offset);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hdc, IntPtr shareContext, int[] attribList);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr wglDXOpenDeviceNVDelegate(IntPtr dxDevice);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate bool wglDXCloseDeviceNVDelegate(IntPtr hDevice);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr wglDXRegisterObjectNVDelegate(IntPtr hDevice, IntPtr dxObject, uint name, uint type, uint access);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate bool wglDXUnregisterObjectNVDelegate(IntPtr hDevice, IntPtr hObject);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate bool wglDXLockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate bool wglDXUnlockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glGenBuffersDelegate(int n, uint[] buffers);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glBindBufferDelegate(uint target, uint buffer);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glBufferDataFloatDelegate(uint target, int size, float[] data, uint usage);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint glCreateShaderDelegate(uint shaderType);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glShaderSourceDelegate(uint shader, int count, string[] source, int[] length);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glCompileShaderDelegate(uint shader);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint glCreateProgramDelegate();
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glAttachShaderDelegate(uint program, uint shader);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glLinkProgramDelegate(uint program);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glUseProgramDelegate(uint program);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int glGetAttribLocationDelegate(uint program, string name);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glEnableVertexAttribArrayDelegate(uint index);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glGenVertexArraysDelegate(int n, uint[] arrays);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glBindVertexArrayDelegate(uint array);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glGenFramebuffersDelegate(int n, uint[] framebuffers);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glBindFramebufferDelegate(uint target, uint framebuffer);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glFramebufferRenderbufferDelegate(uint target, uint attachment, uint renderbuffertarget, uint renderbuffer);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glGenRenderbuffersDelegate(int n, uint[] renderbuffers);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void glClipControlDelegate(uint origin, uint depth);

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
    static uint WIDTH = 320;
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

    const string VS_GLSL = @"
#version 460 core
in vec3 position;
in vec3 color;
out vec4 vColor;
void main() {
    gl_Position = vec4(position.x, -position.y, position.z, 1.0);
    vColor = vec4(color, 1.0);
}";

    const string FS_GLSL = @"
#version 460 core
in vec4 vColor;
out vec4 outColor;
void main() {
    outColor = vColor;
}";

    // Composition COM pointers
    static IntPtr g_dqController;
    static IntPtr g_compositor;
    static IntPtr g_compositorUnk;
    static IntPtr g_desktopTarget;
    static IntPtr g_compTarget;
    static IntPtr g_rootContainer;
    static IntPtr g_rootVisual;
    static IntPtr g_children;
    static IntPtr[] g_spriteRaw = new IntPtr[PANEL_COUNT];
    static IntPtr[] g_spriteVisual = new IntPtr[PANEL_COUNT];
    static IntPtr[] g_brush = new IntPtr[PANEL_COUNT];

    static IntPtr g_hDC;
    static IntPtr g_hGLRC;
    static IntPtr g_dxInteropDevice;
    static IntPtr g_dxInteropObject;
    static uint g_fbo;
    static uint g_rbo;
    static uint[] g_vbo = new uint[2];
    static uint g_program;
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

    // Vulkan resources
    static IntPtr g_vkPhysicalDevice;
    static IntPtr g_vkDevice;
    static IntPtr g_vkQueue;
    static IntPtr g_vkCommandPool;
    static IntPtr g_vkCommandBuffer;
    static IntPtr g_stagingTexture;
    static IntPtr g_swapChainBackBuffer;
    static ulong g_vkImage;
    static ulong g_vkImageView;
    static ulong g_vkImageMemory;
    static ulong g_vkReadbackBuffer;
    static ulong g_vkReadbackMemory;
    static ulong g_vkRenderPass;
    static ulong g_vkFramebuffer;
    static ulong g_vkPipelineLayout;
    static ulong g_vkPipeline;
    static ulong g_vkFence;
    static int g_vkQueueFamily = -1;

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

    static T LoadGL<T>(string name) where T : class
    {
        IntPtr p = wglGetProcAddress(name);
        if (p == IntPtr.Zero) throw new Exception("GL symbol not found: " + name);
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
                BeginPaint(hWnd, out PAINTSTRUCT ps);
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

        RECT rc = new RECT { Right = (int)(WIDTH * PANEL_COUNT), Bottom = (int)HEIGHT };
        AdjustWindowRect(ref rc, WS_OVERLAPPEDWINDOW, false);

        dbg(FN, "calling CreateWindowEx");
        IntPtr hwnd = CreateWindowEx(0,
            "Win32CompTriangle",
            "OpenGL + D3D11 + Vulkan via Windows.UI.Composition (C#)",
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

        // 6) GetBuffer(0) (vtable #9 on SwapChain)
        dbg(FN, "step 6: IDXGISwapChain::GetBuffer(0) (vt#9)");
        IntPtr backBuf;
        hr = ((GetSCBufferDelegate)VT(swapChain, 9, typeof(GetSCBufferDelegate)))(swapChain, 0, ref IID_ID3D11Texture2D, out backBuf);
        if (hr < 0) { dbgHR(FN, "GetBuffer", hr); return hr; }
        dbgPtr(FN, "BackBuffer", backBuf);

        // 7) CreateRenderTargetView (vtable #9 on Device)
        dbg(FN, "step 7: ID3D11Device::CreateRenderTargetView (vt#9)");
        hr = ((CreateRTVDelegate)VT(device, 9, typeof(CreateRTVDelegate)))(device, backBuf, IntPtr.Zero, out rtv);
        Marshal.Release(backBuf);
        if (hr < 0) { dbgHR(FN, "CreateRTV", hr); return hr; }
        dbgPtr(FN, "RTV", rtv);

        // 8) Compile shaders
        dbg(FN, "step 8a: D3DCompile VS");
        IntPtr vsBlob, psBlob, errBlob;
        hr = D3DCompile(VS_HLSL, (IntPtr)VS_HLSL.Length, null, IntPtr.Zero, IntPtr.Zero,
                        "main", "vs_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, out vsBlob, out errBlob);
        if (errBlob != IntPtr.Zero) Marshal.Release(errBlob);
        if (hr < 0) { dbgHR(FN, "D3DCompile(VS)", hr); return hr; }
        dbgPtr(FN, "vsBlob", vsBlob);
        dbg(FN, "  vsBlob size=" + BlobSize(vsBlob));

        dbg(FN, "step 8b: D3DCompile PS");
        hr = D3DCompile(PS_HLSL, (IntPtr)PS_HLSL.Length, null, IntPtr.Zero, IntPtr.Zero,
                        "main", "ps_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, out psBlob, out errBlob);
        if (errBlob != IntPtr.Zero) Marshal.Release(errBlob);
        if (hr < 0) { dbgHR(FN, "D3DCompile(PS)", hr); return hr; }
        dbgPtr(FN, "psBlob", psBlob);

        // 9) CreateVertexShader (vtable #12)
        dbg(FN, "step 9: ID3D11Device::CreateVertexShader (vt#12)");
        hr = ((CreateVSDelegate)VT(device, 12, typeof(CreateVSDelegate)))(device, BlobPtr(vsBlob), (IntPtr)BlobSize(vsBlob), IntPtr.Zero, out vs);
        if (hr < 0) { dbgHR(FN, "CreateVertexShader", hr); return hr; }
        dbgPtr(FN, "VS", vs);

        // 10) CreatePixelShader (vtable #15)
        dbg(FN, "step 10: ID3D11Device::CreatePixelShader (vt#15)");
        hr = ((CreatePSDelegate)VT(device, 15, typeof(CreatePSDelegate)))(device, BlobPtr(psBlob), (IntPtr)BlobSize(psBlob), IntPtr.Zero, out ps);
        if (hr < 0) { dbgHR(FN, "CreatePixelShader", hr); return hr; }
        dbgPtr(FN, "PS", ps);

        // 11) CreateInputLayout (vtable #11)
        dbg(FN, "step 11: ID3D11Device::CreateInputLayout (vt#11)");
        var elems = new D3D11_INPUT_ELEMENT_DESC[]
        {
            new D3D11_INPUT_ELEMENT_DESC { SemanticName="POSITION", Format=DXGI_FORMAT_R32G32B32_FLOAT,    AlignedByteOffset=0  },
            new D3D11_INPUT_ELEMENT_DESC { SemanticName="COLOR",    Format=DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset=12 },
        };
        hr = ((CreateInputLayoutDelegate)VT(device, 11, typeof(CreateInputLayoutDelegate)))(device, elems, (uint)elems.Length,
            BlobPtr(vsBlob), (IntPtr)BlobSize(vsBlob), out inputLayout);
        Marshal.Release(vsBlob);
        Marshal.Release(psBlob);
        if (hr < 0) { dbgHR(FN, "CreateInputLayout", hr); return hr; }
        dbgPtr(FN, "InputLayout", inputLayout);

        // 12) CreateBuffer (vtable #3)
        dbg(FN, "step 12: ID3D11Device::CreateBuffer (vt#3)");
        var verts = new Vertex[]
        {
            new Vertex { X= 0.0f, Y= 0.5f, Z=0.5f, R=1,G=0,B=0,A=1 },
            new Vertex { X= 0.5f, Y=-0.5f, Z=0.5f, R=0,G=1,B=0,A=1 },
            new Vertex { X=-0.5f, Y=-0.5f, Z=0.5f, R=0,G=0,B=1,A=1 },
        };
        var bd = new D3D11_BUFFER_DESC
        {
            ByteWidth = (uint)(Marshal.SizeOf(typeof(Vertex)) * verts.Length),
            Usage = D3D11_USAGE_DEFAULT,
            BindFlags = D3D11_BIND_VERTEX_BUFFER,
        };
        dbg(FN, "  ByteWidth=" + bd.ByteWidth);
        GCHandle pin = GCHandle.Alloc(verts, GCHandleType.Pinned);
        try
        {
            var sd = new D3D11_SUBRESOURCE_DATA { pSysMem = pin.AddrOfPinnedObject() };
            hr = ((CreateBufferDelegate)VT(device, 3, typeof(CreateBufferDelegate)))(device, ref bd, ref sd, out vertexBuffer);
        }
        finally { pin.Free(); }
        if (hr < 0) { dbgHR(FN, "CreateBuffer", hr); return hr; }
        dbgPtr(FN, "VertexBuffer", vertexBuffer);

        dbg(FN, "ok (all 12 steps completed)");
        return 0;
    }

    static int CreateSwapChainForComposition(IntPtr device, out IntPtr swapChain)
    {
        swapChain = IntPtr.Zero;
        IntPtr dxgiDev;
        int hr = QI(device, ref IID_IDXGIDevice, out dxgiDev);
        if (hr < 0) return hr;

        IntPtr adapter;
        hr = ((GetAdapterDelegate)VT(dxgiDev, 7, typeof(GetAdapterDelegate)))(dxgiDev, out adapter);
        if (hr < 0) { Marshal.Release(dxgiDev); return hr; }

        IntPtr factory;
        hr = ((GetParentDelegate)VT(adapter, 6, typeof(GetParentDelegate)))(adapter, ref IID_IDXGIFactory2, out factory);
        Marshal.Release(adapter);
        if (hr < 0) { Marshal.Release(dxgiDev); return hr; }

        var scDesc = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = WIDTH,
            Height = HEIGHT,
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
        return hr;
    }

    // ============================================================
    // InitComposition
    // ============================================================
    static int AddCompositionPanel(IntPtr swapChain, float offsetX, int index)
    {
        const string FN = "AddCompositionPanel";
        int hr;

        IntPtr compInterop;
        hr = QI(g_compositorUnk, ref IID_ICompositorInterop, out compInterop);
        if (hr < 0) { dbgHR(FN, "QI(ICompositorInterop)", hr); return hr; }

        IntPtr surface;
        hr = ((CreateCompSurfaceForSCDelegate)VT(compInterop, 4, typeof(CreateCompSurfaceForSCDelegate)))(compInterop, swapChain, out surface);
        Marshal.Release(compInterop);
        if (hr < 0) { dbgHR(FN, "CreateCompositionSurfaceForSwapChain", hr); return hr; }

        IntPtr surfBrush;
        hr = ((CreateSurfaceBrushWithSurfaceDelegate)VT(g_compositor, 24, typeof(CreateSurfaceBrushWithSurfaceDelegate)))(g_compositor, surface, out surfBrush);
        Marshal.Release(surface);
        if (hr < 0) return hr;
        hr = QI(surfBrush, ref IID_ICompositionBrush, out g_brush[index]);
        Marshal.Release(surfBrush);
        if (hr < 0) return hr;

        hr = ((CreateSpriteVisualDelegate)VT(g_compositor, 22, typeof(CreateSpriteVisualDelegate)))(g_compositor, out g_spriteRaw[index]);
        if (hr < 0) return hr;
        hr = ((PutBrushDelegate)VT(g_spriteRaw[index], 7, typeof(PutBrushDelegate)))(g_spriteRaw[index], g_brush[index]);
        if (hr < 0) return hr;
        hr = QI(g_spriteRaw[index], ref IID_IVisual, out g_spriteVisual[index]);
        if (hr < 0) return hr;
        hr = ((PutSizeDelegate)VT(g_spriteVisual[index], 36, typeof(PutSizeDelegate)))(g_spriteVisual[index], new Float2 { X = WIDTH, Y = HEIGHT });
        if (hr < 0) return hr;
        hr = ((PutOffsetDelegate)VT(g_spriteVisual[index], 21, typeof(PutOffsetDelegate)))(g_spriteVisual[index], new Float3 { X = offsetX, Y = 0.0f, Z = 0.0f });
        if (hr < 0) return hr;
        hr = ((InsertAtTopDelegate)VT(g_children, 9, typeof(InsertAtTopDelegate)))(g_children, g_spriteVisual[index]);
        return 0;
    }

    static int InitComposition(IntPtr hwnd, IntPtr glSwapChain, IntPtr d3dSwapChain, IntPtr vkSwapChain)
    {
        const string FN = "InitComposition";
        dbg(FN, "begin");
        int hr;

        hr = RoInitialize(0);
        if (hr < 0 && hr != 1) return hr;

        var dqOpt = new DispatcherQueueOptions
        {
            dwSize = Marshal.SizeOf(typeof(DispatcherQueueOptions)),
            threadType = 2,
            apartmentType = 0,
        };
        hr = CreateDispatcherQueueController(ref dqOpt, out g_dqController);
        if (hr < 0) return hr;

        string className = "Windows.UI.Composition.Compositor";
        hr = WindowsCreateString(className, (uint)className.Length, out IntPtr hstr);
        if (hr < 0) return hr;
        hr = RoActivateInstance(hstr, out g_compositorUnk);
        WindowsDeleteString(hstr);
        if (hr < 0) return hr;

        hr = QI(g_compositorUnk, ref IID_ICompositor, out g_compositor);
        if (hr < 0) return hr;

        IntPtr deskInterop;
        hr = QI(g_compositorUnk, ref IID_ICompositorDesktopInterop, out deskInterop);
        if (hr < 0) return hr;
        hr = ((CreateDesktopWindowTargetDelegate)VT(deskInterop, 3, typeof(CreateDesktopWindowTargetDelegate)))(deskInterop, hwnd, 0, out g_desktopTarget);
        Marshal.Release(deskInterop);
        if (hr < 0) return hr;

        hr = QI(g_desktopTarget, ref IID_ICompositionTarget, out g_compTarget);
        if (hr < 0) return hr;
        hr = ((CreateContainerVisualDelegate)VT(g_compositor, 9, typeof(CreateContainerVisualDelegate)))(g_compositor, out g_rootContainer);
        if (hr < 0) return hr;
        hr = QI(g_rootContainer, ref IID_IVisual, out g_rootVisual);
        if (hr < 0) return hr;
        hr = ((PutRootDelegate)VT(g_compTarget, 7, typeof(PutRootDelegate)))(g_compTarget, g_rootVisual);
        if (hr < 0) return hr;
        hr = ((GetChildrenDelegate)VT(g_rootContainer, 6, typeof(GetChildrenDelegate)))(g_rootContainer, out g_children);
        if (hr < 0) return hr;

        hr = AddCompositionPanel(glSwapChain, 0.0f, 0);
        if (hr < 0) return hr;
        hr = AddCompositionPanel(d3dSwapChain, (float)WIDTH, 1);
        if (hr < 0) return hr;
        hr = AddCompositionPanel(vkSwapChain, (float)WIDTH * 2.0f, 2);
        if (hr < 0) return hr;

        dbg(FN, "ok");
        return 0;
    }

    static IntPtr CreateStagingTexture(IntPtr device)
    {
        var desc = new D3D11_TEXTURE2D_DESC
        {
            Width = WIDTH,
            Height = HEIGHT,
            MipLevels = 1,
            ArraySize = 1,
            Format = DXGI_FORMAT_B8G8R8A8_UNORM,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            Usage = D3D11_USAGE_STAGING,
            BindFlags = 0,
            CPUAccessFlags = D3D11_CPU_ACCESS_WRITE,
            MiscFlags = 0,
        };
        int hr = ((CreateTexture2DDelegate)VT(device, 5, typeof(CreateTexture2DDelegate)))(device, ref desc, IntPtr.Zero, out IntPtr tex);
        if (hr < 0) throw new Exception("CreateTexture2D failed hr=0x" + hr.ToString("X8"));
        return tex;
    }

    static D3D11_MAPPED_SUBRESOURCE MapWrite(IntPtr ctx, IntPtr resource)
    {
        int hr = ((MapDelegate)VT(ctx, 14, typeof(MapDelegate)))(ctx, resource, 0, D3D11_MAP_WRITE, 0, out D3D11_MAPPED_SUBRESOURCE map);
        if (hr < 0) throw new Exception("Map failed hr=0x" + hr.ToString("X8"));
        return map;
    }

    static void UnmapWrite(IntPtr ctx, IntPtr resource)
    {
        ((UnmapDelegate)VT(ctx, 15, typeof(UnmapDelegate)))(ctx, resource, 0);
    }

    static void CopyResource(IntPtr ctx, IntPtr dst, IntPtr src)
    {
        ((CopyResourceDelegate)VT(ctx, 47, typeof(CopyResourceDelegate)))(ctx, dst, src);
    }

    static unsafe uint FindMemoryType(ref VkPhysMemProps p, uint bits, uint req)
    {
        for (uint i = 0; i < p.typeCnt; i++)
        {
            if ((bits & (1u << (int)i)) == 0) continue;
            uint f;
            fixed (byte* b = p.types) { f = ((VkMemType*)b)[i].propFlags; }
            if ((f & req) == req) return i;
        }
        throw new Exception("No VK memory type");
    }

    static unsafe void InitVulkan(IntPtr device, IntPtr swapChain)
    {
        IntPtr appName = Marshal.StringToHGlobalAnsi("vk14");
        var ai = new VkAppInfo { sType = 0, pAppName = appName, apiVer = (1u << 22) | (4u << 12) };
        GCHandle hAI = GCHandle.Alloc(ai, GCHandleType.Pinned);
        var ici = new VkInstCI { sType = 1, pAppInfo = hAI.AddrOfPinnedObject() };
        IntPtr vkInstance;
        if (vkCreateInstance(ref ici, IntPtr.Zero, out vkInstance) != 0) throw new Exception("vkCreateInstance failed");
        hAI.Free();
        Marshal.FreeHGlobal(appName);

        uint count = 0;
        vkEnumeratePhysicalDevices(vkInstance, ref count, null);
        var devs = new IntPtr[count];
        vkEnumeratePhysicalDevices(vkInstance, ref count, devs);
        g_vkPhysicalDevice = devs[0];

        uint qc = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(g_vkPhysicalDevice, ref qc, null);
        var qps = new VkQFP[qc];
        vkGetPhysicalDeviceQueueFamilyProperties(g_vkPhysicalDevice, ref qc, qps);
        for (int i = 0; i < qc; i++) { if ((qps[i].qFlags & 1) != 0) { g_vkQueueFamily = i; break; } }
        if (g_vkQueueFamily < 0) throw new Exception("No graphics queue");

        GCHandle hP = GCHandle.Alloc(new float[] { 1.0f }, GCHandleType.Pinned);
        var qci = new VkDevQCI { sType = 2, qfi = (uint)g_vkQueueFamily, qCnt = 1, pPrio = hP.AddrOfPinnedObject() };
        GCHandle hQ = GCHandle.Alloc(qci, GCHandleType.Pinned);
        var dci = new VkDevCI { sType = 3, qciCnt = 1, pQCI = hQ.AddrOfPinnedObject() };
        if (vkCreateDevice(g_vkPhysicalDevice, ref dci, IntPtr.Zero, out g_vkDevice) != 0) throw new Exception("vkCreateDevice failed");
        hQ.Free();
        hP.Free();
        vkGetDeviceQueue(g_vkDevice, (uint)g_vkQueueFamily, 0, out g_vkQueue);

        vkGetPhysicalDeviceMemoryProperties(g_vkPhysicalDevice, out var memProps);

        var ic = new VkImgCI { sType = 14, imgType = 1, fmt = 44, eW = WIDTH, eH = HEIGHT, eD = 1, mip = 1, arr = 1, samples = 1, usage = 0x11 };
        if (vkCreateImage(g_vkDevice, ref ic, IntPtr.Zero, out g_vkImage) != 0) throw new Exception("vkCreateImage failed");
        vkGetImageMemoryRequirements(g_vkDevice, g_vkImage, out var ir);
        var ia = new VkMemAI { sType = 5, size = ir.size, memIdx = FindMemoryType(ref memProps, ir.memBits, 1) };
        if (vkAllocateMemory(g_vkDevice, ref ia, IntPtr.Zero, out g_vkImageMemory) != 0) throw new Exception("vkAllocateMemory(image) failed");
        vkBindImageMemory(g_vkDevice, g_vkImage, g_vkImageMemory, 0);

        var ivc = new VkImgViewCI { sType = 15, img = g_vkImage, viewType = 1, fmt = 44, aspect = 1, lvlCnt = 1, layerCnt = 1 };
        if (vkCreateImageView(g_vkDevice, ref ivc, IntPtr.Zero, out g_vkImageView) != 0) throw new Exception("vkCreateImageView failed");

        ulong readSize = (ulong)(WIDTH * HEIGHT * 4);
        var bc = new VkBufCI { sType = 12, size = readSize, usage = 2 };
        if (vkCreateBuffer(g_vkDevice, ref bc, IntPtr.Zero, out g_vkReadbackBuffer) != 0) throw new Exception("vkCreateBuffer failed");
        vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuffer, out var br);
        var ba = new VkMemAI { sType = 5, size = br.size, memIdx = FindMemoryType(ref memProps, br.memBits, 6) };
        if (vkAllocateMemory(g_vkDevice, ref ba, IntPtr.Zero, out g_vkReadbackMemory) != 0) throw new Exception("vkAllocateMemory(buffer) failed");
        vkBindBufferMemory(g_vkDevice, g_vkReadbackBuffer, g_vkReadbackMemory, 0);

        var att = new VkAttDesc { fmt = 44, samples = 1, loadOp = 1, storeOp = 0, stLoadOp = 2, stStoreOp = 1, finalLayout = 6 };
        var ar = new VkAttRef { att = 0, layout = 2 };
        GCHandle hA = GCHandle.Alloc(att, GCHandleType.Pinned);
        GCHandle hR = GCHandle.Alloc(ar, GCHandleType.Pinned);
        var sub = new VkSubDesc { caCnt = 1, pCA = hR.AddrOfPinnedObject() };
        GCHandle hS = GCHandle.Alloc(sub, GCHandleType.Pinned);
        var rpc = new VkRPCI { sType = 38, attCnt = 1, pAtts = hA.AddrOfPinnedObject(), subCnt = 1, pSubs = hS.AddrOfPinnedObject() };
        if (vkCreateRenderPass(g_vkDevice, ref rpc, IntPtr.Zero, out g_vkRenderPass) != 0) throw new Exception("vkCreateRenderPass failed");
        hA.Free(); hR.Free(); hS.Free();

        GCHandle hV = GCHandle.Alloc(new ulong[] { g_vkImageView }, GCHandleType.Pinned);
        var fbc = new VkFBCI { sType = 37, rp = g_vkRenderPass, attCnt = 1, pAtts = hV.AddrOfPinnedObject(), w = WIDTH, h = HEIGHT, layers = 1 };
        if (vkCreateFramebuffer(g_vkDevice, ref fbc, IntPtr.Zero, out g_vkFramebuffer) != 0) throw new Exception("vkCreateFramebuffer failed");
        hV.Free();

        byte[] vsSpv = SC.Compile(File.ReadAllText("hello.vert"), 0, "hello.vert");
        byte[] fsSpv = SC.Compile(File.ReadAllText("hello.frag"), 1, "hello.frag");
        ulong vsm, fsm;

        GCHandle hVS = GCHandle.Alloc(vsSpv, GCHandleType.Pinned);
        var smv = new VkSMCI { sType = 16, codeSz = (UIntPtr)vsSpv.Length, pCode = hVS.AddrOfPinnedObject() };
        if (vkCreateShaderModule(g_vkDevice, ref smv, IntPtr.Zero, out vsm) != 0) throw new Exception("vkCreateShaderModule(vs) failed");
        hVS.Free();

        GCHandle hFS = GCHandle.Alloc(fsSpv, GCHandleType.Pinned);
        var smf = new VkSMCI { sType = 16, codeSz = (UIntPtr)fsSpv.Length, pCode = hFS.AddrOfPinnedObject() };
        if (vkCreateShaderModule(g_vkDevice, ref smf, IntPtr.Zero, out fsm) != 0) throw new Exception("vkCreateShaderModule(fs) failed");
        hFS.Free();

        IntPtr mainName = Marshal.StringToHGlobalAnsi("main");
        var stg = new VkPSSCI[] {
            new VkPSSCI { sType = 18, stage = 1, module = vsm, pName = mainName },
            new VkPSSCI { sType = 18, stage = 0x10, module = fsm, pName = mainName },
        };
        GCHandle hStg = GCHandle.Alloc(stg, GCHandleType.Pinned);
        var vi = new VkPVICI { sType = 19 };
        var ia2 = new VkPIACI { sType = 20, topo = 3 };
        var vp = new VkViewport { w = WIDTH, h = HEIGHT, maxD = 1 };
        var sc = new VkRect2D { ext = new VkExt2D { w = WIDTH, h = HEIGHT } };
        GCHandle hVP = GCHandle.Alloc(vp, GCHandleType.Pinned);
        GCHandle hSC = GCHandle.Alloc(sc, GCHandleType.Pinned);
        var vps = new VkPVPCI { sType = 22, vpCnt = 1, pVP = hVP.AddrOfPinnedObject(), scCnt = 1, pSC = hSC.AddrOfPinnedObject() };
        var rs = new VkPRCI { sType = 23, lineW = 1f };
        var ms = new VkPMSCI { sType = 24, rSamples = 1 };
        var cba = new VkPCBAS { wMask = 0xF };
        GCHandle hCBA = GCHandle.Alloc(cba, GCHandleType.Pinned);
        var cbs = new VkPCBCI { sType = 26, attCnt = 1, pAtts = hCBA.AddrOfPinnedObject() };
        GCHandle hVI = GCHandle.Alloc(vi, GCHandleType.Pinned);
        GCHandle hIA = GCHandle.Alloc(ia2, GCHandleType.Pinned);
        GCHandle hVPS = GCHandle.Alloc(vps, GCHandleType.Pinned);
        GCHandle hRS = GCHandle.Alloc(rs, GCHandleType.Pinned);
        GCHandle hMS = GCHandle.Alloc(ms, GCHandleType.Pinned);
        GCHandle hCB = GCHandle.Alloc(cbs, GCHandleType.Pinned);

        var plc = new VkPLCI { sType = 30 };
        vkCreatePipelineLayout(g_vkDevice, ref plc, IntPtr.Zero, out g_vkPipelineLayout);
        var gpc = new VkGPCI
        {
            sType = 28,
            stageCnt = 2,
            pStages = hStg.AddrOfPinnedObject(),
            pVIS = hVI.AddrOfPinnedObject(),
            pIAS = hIA.AddrOfPinnedObject(),
            pVPS = hVPS.AddrOfPinnedObject(),
            pRast = hRS.AddrOfPinnedObject(),
            pMS = hMS.AddrOfPinnedObject(),
            pCBS = hCB.AddrOfPinnedObject(),
            layout = g_vkPipelineLayout,
            rp = g_vkRenderPass,
        };
        if (vkCreateGraphicsPipelines(g_vkDevice, 0, 1, ref gpc, IntPtr.Zero, out g_vkPipeline) != 0)
            throw new Exception("vkCreateGraphicsPipelines failed");

        hStg.Free(); hVI.Free(); hIA.Free(); hVPS.Free(); hRS.Free(); hMS.Free(); hCB.Free(); hCBA.Free(); hVP.Free(); hSC.Free();
        Marshal.FreeHGlobal(mainName);
        vkDestroyShaderModule(g_vkDevice, vsm, IntPtr.Zero);
        vkDestroyShaderModule(g_vkDevice, fsm, IntPtr.Zero);

        var cpc = new VkCPCI { sType = 39, flags = 2, qfi = (uint)g_vkQueueFamily };
        if (vkCreateCommandPool(g_vkDevice, ref cpc, IntPtr.Zero, out g_vkCommandPool) != 0) throw new Exception("vkCreateCommandPool failed");
        var cbi = new VkCBAI { sType = 40, pool = g_vkCommandPool, cnt = 1 };
        if (vkAllocateCommandBuffers(g_vkDevice, ref cbi, out g_vkCommandBuffer) != 0) throw new Exception("vkAllocateCommandBuffers failed");
        var fc = new VkFenceCI { sType = 8, flags = 1 };
        if (vkCreateFence(g_vkDevice, ref fc, IntPtr.Zero, out g_vkFence) != 0) throw new Exception("vkCreateFence failed");

        g_stagingTexture = CreateStagingTexture(device);
        int hr = ((GetSCBufferDelegate)VT(swapChain, 9, typeof(GetSCBufferDelegate)))(swapChain, 0, ref IID_ID3D11Texture2D, out g_swapChainBackBuffer);
        if (hr < 0) throw new Exception("GetBuffer failed hr=0x" + hr.ToString("X8"));
    }

    static unsafe void RenderVulkan(IntPtr context, IntPtr swapChain)
    {
        ulong[] f = { g_vkFence };
        vkWaitForFences(g_vkDevice, 1, f, 1, ulong.MaxValue);
        vkResetFences(g_vkDevice, 1, f);
        vkResetCommandBuffer(g_vkCommandBuffer, 0);

        var bi = new VkCBBI { sType = 42 };
        vkBeginCommandBuffer(g_vkCommandBuffer, ref bi);
        var cv = new VkClearVal { color = new VkClearCol { r = 0.15f, g = 0.05f, b = 0.05f, a = 1f } };
        GCHandle hCV = GCHandle.Alloc(cv, GCHandleType.Pinned);
        var rpbi = new VkRPBI
        {
            sType = 43,
            rp = g_vkRenderPass,
            fb = g_vkFramebuffer,
            area = new VkRect2D { ext = new VkExt2D { w = WIDTH, h = HEIGHT } },
            cvCnt = 1,
            pCV = hCV.AddrOfPinnedObject(),
        };
        vkCmdBeginRenderPass(g_vkCommandBuffer, ref rpbi, 0);
        vkCmdBindPipeline(g_vkCommandBuffer, 0, g_vkPipeline);
        vkCmdDraw(g_vkCommandBuffer, 3, 1, 0, 0);
        vkCmdEndRenderPass(g_vkCommandBuffer);
        hCV.Free();

        var rg = new VkBufImgCopy { bRL = WIDTH, bIH = HEIGHT, aspect = 1, lCnt = 1, eW = WIDTH, eH = HEIGHT, eD = 1 };
        vkCmdCopyImageToBuffer(g_vkCommandBuffer, g_vkImage, 6, g_vkReadbackBuffer, 1, &rg);
        vkEndCommandBuffer(g_vkCommandBuffer);

        GCHandle hC = GCHandle.Alloc(new IntPtr[] { g_vkCommandBuffer }, GCHandleType.Pinned);
        var si = new VkSubmitInfo { sType = 4, cbCnt = 1, pCB = hC.AddrOfPinnedObject() };
        vkQueueSubmit(g_vkQueue, 1, ref si, g_vkFence);
        hC.Free();

        vkWaitForFences(g_vkDevice, 1, f, 1, ulong.MaxValue);
        vkMapMemory(g_vkDevice, g_vkReadbackMemory, 0, (ulong)(WIDTH * HEIGHT * 4), 0, out IntPtr src);
        var map = MapWrite(context, g_stagingTexture);
        int pitch = (int)WIDTH * 4;
        for (int y = 0; y < HEIGHT; y++)
        {
            Buffer.MemoryCopy((void*)(src + y * pitch), (void*)(map.pData + y * (int)map.RowPitch), pitch, pitch);
        }
        UnmapWrite(context, g_stagingTexture);
        vkUnmapMemory(g_vkDevice, g_vkReadbackMemory);

        CopyResource(context, g_swapChainBackBuffer, g_stagingTexture);
        ((PresentDelegate)VT(swapChain, 8, typeof(PresentDelegate)))(swapChain, 1, 0);
    }

    static int InitOpenGLInterop(IntPtr hwnd, IntPtr device, IntPtr swapChain)
    {
        g_hDC = GetDC(hwnd);
        if (g_hDC == IntPtr.Zero) return Marshal.GetHRForLastWin32Error();

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

        glClipControl(GL_LOWER_LEFT, GL_NEGATIVE_ONE_TO_ONE);

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
        return 0;
    }

    static void RenderOpenGL(IntPtr swapChain)
    {
        wglMakeCurrent(g_hDC, g_hGLRC);
        IntPtr[] objs = { g_dxInteropObject };
        if (!wglDXLockObjectsNV(g_dxInteropDevice, 1, objs)) return;
        try
        {
            glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
            glViewport(0, 0, (int)WIDTH, (int)HEIGHT);
            glClearColor(0.05f, 0.05f, 0.15f, 1f);
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
        ((PresentDelegate)VT(swapChain, 8, typeof(PresentDelegate)))(swapChain, 1, 0);
    }

    // ============================================================
    // Render
    // ============================================================
    static bool g_firstRender = true;

    static void Render(IntPtr ctx, IntPtr rtv, IntPtr vs, IntPtr ps,
                       IntPtr layout, IntPtr vb, IntPtr sc)
    {
        if (g_firstRender)
        {
            dbg("Render", "first frame begin");
        }

        try
        {
            var vp = new D3D11_VIEWPORT { Width = WIDTH, Height = HEIGHT, MaxDepth = 1 };
            ((RSSetViewportsDelegate)VT(ctx, 44, typeof(RSSetViewportsDelegate)))(ctx, 1, ref vp);
            ((OMSetRenderTargetsDelegate)VT(ctx, 33, typeof(OMSetRenderTargetsDelegate)))(ctx, 1, new IntPtr[] { rtv }, IntPtr.Zero);
            ((ClearRTVDelegate)VT(ctx, 50, typeof(ClearRTVDelegate)))(ctx, rtv, new float[] { 0.05f, 0.15f, 0.05f, 1f });
            ((IASetInputLayoutDelegate)VT(ctx, 17, typeof(IASetInputLayoutDelegate)))(ctx, layout);

            uint stride = (uint)Marshal.SizeOf(typeof(Vertex));
            ((IASetVertexBuffersDelegate)VT(ctx, 18, typeof(IASetVertexBuffersDelegate)))(ctx, 0, 1, new IntPtr[] { vb }, new uint[] { stride }, new uint[] { 0 });
            ((IASetPrimitiveTopologyDelegate)VT(ctx, 24, typeof(IASetPrimitiveTopologyDelegate)))(ctx, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            ((VSSetShaderDelegate)VT(ctx, 11, typeof(VSSetShaderDelegate)))(ctx, vs, null, 0);
            ((PSSetShaderDelegate)VT(ctx, 9, typeof(PSSetShaderDelegate)))(ctx, ps, null, 0);
            ((DrawDelegate)VT(ctx, 13, typeof(DrawDelegate)))(ctx, 3, 0);

            int hr = ((PresentDelegate)VT(sc, 8, typeof(PresentDelegate)))(sc, 1, 0);

            if (g_firstRender)
            {
                dbg("Render", "first frame Present hr=0x" + hr.ToString("X8"));
                g_firstRender = false;
            }
        }
        catch (Exception ex)
        {
            dbg("Render", "EXCEPTION: " + ex.Message);
            dbg("Render", "StackTrace: " + ex.StackTrace);
        }
    }

    // ============================================================
    // Cleanup
    // ============================================================
    static void Cleanup(IntPtr device, IntPtr context, IntPtr d3dSwapChain, IntPtr glSwapChain, IntPtr vkSwapChain,
                        IntPtr rtv, IntPtr vs, IntPtr ps,
                        IntPtr inputLayout, IntPtr vertexBuffer)
    {
        const string FN = "Cleanup";
        dbg(FN, "begin");

        if (g_dxInteropObject != IntPtr.Zero && g_dxInteropDevice != IntPtr.Zero)
        {
            wglDXUnregisterObjectNV(g_dxInteropDevice, g_dxInteropObject);
            g_dxInteropObject = IntPtr.Zero;
        }
        if (g_dxInteropDevice != IntPtr.Zero)
        {
            wglDXCloseDeviceNV(g_dxInteropDevice);
            g_dxInteropDevice = IntPtr.Zero;
        }
        wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
        if (g_hGLRC != IntPtr.Zero) { wglDeleteContext(g_hGLRC); g_hGLRC = IntPtr.Zero; }
        if (g_hDC != IntPtr.Zero) { ReleaseDC(g_hwnd, g_hDC); g_hDC = IntPtr.Zero; }

        if (g_children      != IntPtr.Zero) { Marshal.Release(g_children);      dbg(FN, "released children"); }
        for (int i = 0; i < PANEL_COUNT; i++)
        {
            if (g_spriteVisual[i]  != IntPtr.Zero) { Marshal.Release(g_spriteVisual[i]);  dbg(FN, "released spriteVisual[" + i + "]"); }
            if (g_spriteRaw[i]     != IntPtr.Zero) { Marshal.Release(g_spriteRaw[i]);     dbg(FN, "released spriteRaw[" + i + "]"); }
            if (g_brush[i]         != IntPtr.Zero) { Marshal.Release(g_brush[i]);         dbg(FN, "released brush[" + i + "]"); }
        }
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
        if (d3dSwapChain != IntPtr.Zero) { Marshal.Release(d3dSwapChain); dbg(FN, "released d3dSwapChain"); }
        if (glSwapChain  != IntPtr.Zero) { Marshal.Release(glSwapChain);  dbg(FN, "released glSwapChain"); }
        if (vkSwapChain  != IntPtr.Zero) { Marshal.Release(vkSwapChain);  dbg(FN, "released vkSwapChain"); }
        if (context      != IntPtr.Zero) { Marshal.Release(context);      dbg(FN, "released context"); }
        if (g_swapChainBackBuffer != IntPtr.Zero) { Marshal.Release(g_swapChainBackBuffer); dbg(FN, "released vk backbuffer"); }
        if (g_stagingTexture != IntPtr.Zero) { Marshal.Release(g_stagingTexture); dbg(FN, "released vk staging texture"); }
        if (g_vkDevice != IntPtr.Zero) { vkDeviceWaitIdle(g_vkDevice); dbg(FN, "vkDeviceWaitIdle"); }
        if (device       != IntPtr.Zero) { Marshal.Release(device);       dbg(FN, "released device"); }

        dbg(FN, "ok");
    }

    // ============================================================
    // Entry Point
    // ============================================================
    [STAThread]
    static unsafe int Main(string[] args)
    {
        const string FN = "Main";
        dbg(FN, "========================================");
        dbg(FN, "OpenGL 4.6 + D3D11 + Vulkan 1.4 via Composition (C# vtable)");
        dbg(FN, "========================================");

        dbg(FN, "calling CreateAppWindow");
        g_hwnd = CreateAppWindow();
        if (g_hwnd == IntPtr.Zero) { dbg(FN, "FATAL: CreateAppWindow failed"); return 1; }

        dbg(FN, "calling InitD3D11");
        IntPtr device, context, d3dSwapChain, rtv, vs, ps, inputLayout, vertexBuffer;
        int hr = InitD3D11(out device, out context, out d3dSwapChain,
                           out rtv, out vs, out ps,
                           out inputLayout, out vertexBuffer);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitD3D11 failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, d3dSwapChain, IntPtr.Zero, IntPtr.Zero, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        IntPtr glSwapChain = IntPtr.Zero;
        IntPtr vkSwapChain = IntPtr.Zero;
        hr = CreateSwapChainForComposition(device, out glSwapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: CreateSwapChainForComposition(gl) failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }
        hr = CreateSwapChainForComposition(device, out vkSwapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: CreateSwapChainForComposition(vk) failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        dbg(FN, "calling InitOpenGLInterop");
        hr = InitOpenGLInterop(g_hwnd, device, glSwapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitOpenGLInterop failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return hr;
        }

        dbg(FN, "calling InitVulkan");
        try
        {
            InitVulkan(device, vkSwapChain);
        }
        catch (Exception ex)
        {
            dbg(FN, "FATAL: InitVulkan failed: " + ex.Message);
            Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
            return -1;
        }

        dbg(FN, "calling InitComposition");
        hr = InitComposition(g_hwnd, glSwapChain, d3dSwapChain, vkSwapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitComposition failed hr=0x" + hr.ToString("X8"));
            Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
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
                RenderOpenGL(glSwapChain);
                Render(context, rtv, vs, ps, inputLayout, vertexBuffer, d3dSwapChain);
                RenderVulkan(context, vkSwapChain);
            }
        }

        dbg(FN, "message loop ended");
        Cleanup(device, context, d3dSwapChain, glSwapChain, vkSwapChain, rtv, vs, ps, inputLayout, vertexBuffer);
        dbg(FN, "exit");
        return 0;
    }
}




