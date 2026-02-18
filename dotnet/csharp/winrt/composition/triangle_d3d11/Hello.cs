// Hello.cs
// D3D11 Triangle via Windows.UI.Composition (Win32 Desktop Interop)
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
        hr = WindowsCreateString(className, (uint)className.Length, out IntPtr hstr);
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
            ((ClearRTVDelegate)VT(ctx, 50, typeof(ClearRTVDelegate)))(ctx, rtv, new float[] { 1f, 1f, 1f, 1f });
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
    static void Cleanup(IntPtr device, IntPtr context, IntPtr swapChain,
                        IntPtr rtv, IntPtr vs, IntPtr ps,
                        IntPtr inputLayout, IntPtr vertexBuffer)
    {
        const string FN = "Cleanup";
        dbg(FN, "begin");

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
        dbg(FN, "D3D11 Triangle via Composition (C# vtable)");
        dbg(FN, "========================================");

        dbg(FN, "calling CreateAppWindow");
        IntPtr hwnd = CreateAppWindow();
        if (hwnd == IntPtr.Zero) { dbg(FN, "FATAL: CreateAppWindow failed"); return 1; }

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
        hr = InitComposition(hwnd, swapChain);
        if (hr < 0)
        {
            dbg(FN, "FATAL: InitComposition failed hr=0x" + hr.ToString("X8"));
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
                Render(context, rtv, vs, ps, inputLayout, vertexBuffer, swapChain);
            }
        }

        dbg(FN, "message loop ended");
        Cleanup(device, context, swapChain, rtv, vs, ps, inputLayout, vertexBuffer);
        dbg(FN, "exit");
        return 0;
    }
}




