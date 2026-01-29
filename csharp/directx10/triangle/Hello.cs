using System;
using System.Text;
using System.Runtime.InteropServices;

class Hello
{
    [StructLayout(LayoutKind.Sequential)]
    struct POINT
    {
        public int X;
        public int Y;
    }

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
        public Int32 cbClsExtra;
        public Int32 cbWndExtra;
        public IntPtr hInstance;
        public IntPtr hIcon;
        public IntPtr hCursor;
        public IntPtr hbrBackground;
        public string lpszMenuName;
        public string lpszClassName;
        public IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
 
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
 
    const uint WS_OVERLAPPEDWINDOW = 0x0CF0000;
    const uint WS_VISIBLE = 0x10000000;

    const uint WM_DESTROY = 0x0002;
    const uint WM_PAINT = 0x000F;

    const uint WM_QUIT = 0x0012;
    const uint PM_REMOVE = 0x0001;

    const uint CS_OWNDC = 0x0020;

    const int IDC_ARROW = 32512;

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr LoadCursor(IntPtr hInstance, int lpCursorName);

    [DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)]
    static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr CreateWindowEx(
        uint dwExStyle,
        string lpClassName,
        string lpWindowName,
        uint dwStyle,
        int x,
        int y,
        int nWidth,
        int nHeight,
        IntPtr hWndParent,
        IntPtr hMenu,
        IntPtr hInstance,
        IntPtr lpParam
    );

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool TranslateMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DispatchMessage([In] ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern void PostQuitMessage(int nExitCode);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);
 
    [DllImport("gdi32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr TextOut( IntPtr hdc, int x, int y, string lpString, int nCount );

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    const uint DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    const uint DXGI_FORMAT_R32G32B32_FLOAT = 6;
    const uint DXGI_FORMAT_R8G8B8A8_UNORM = 28;

    const uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    
    const uint DXGI_SWAP_EFFECT_DISCARD = 0;

    const int  D3D10_DRIVER_TYPE_HARDWARE = 1;
    const uint D3D10_SDK_VERSION = 29;
    const uint D3D10_BIND_VERTEX_BUFFER = 0x1;
    const uint D3D10_USAGE_DEFAULT = 0;
    const uint D3D10_CREATE_DEVICE_DEBUG = 0x2;

    const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

    [DllImport("d3d10.dll", CallingConvention = CallingConvention.StdCall, SetLastError = true)]
    static extern int D3D10CreateDeviceAndSwapChain(
        IntPtr pAdapter,
        int DriverType,
        IntPtr Software,
        uint Flags,
        uint SDKVersion,
        [In] ref DXGI_SWAP_CHAIN_DESC pSwapChainDesc,
        out IntPtr ppSwapChain,
        out IntPtr ppDevice
    );

    // =====================================
    // ID3D10Device VTable Delegates
    // =====================================

    // #5 PSSetShader
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void PSSetShaderDelegate(IntPtr device, IntPtr pPixelShader);

    // #7 VSSetShader
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void VSSetShaderDelegate(IntPtr device, IntPtr pVertexShader);

    // #9 Draw
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DrawDelegate(IntPtr device, uint VertexCount, uint StartVertexLocation);

    // #11 IASetInputLayout
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetInputLayoutDelegate(IntPtr device, IntPtr pInputLayout);

    // #12 IASetVertexBuffers
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetVertexBuffersDelegate(
        IntPtr device,
        uint StartSlot,
        uint NumBuffers,
        [In] IntPtr[] ppVertexBuffers,
        [In] uint[] pStrides,
        [In] uint[] pOffsets
    );

    // #18 IASetPrimitiveTopology
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetPrimitiveTopologyDelegate(IntPtr device, uint Topology);

    // #24 OMSetRenderTargets
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void OMSetRenderTargetsDelegate(
        IntPtr device,
        uint NumViews,
        [In] IntPtr[] ppRenderTargetViews,
        IntPtr pDepthStencilView
    );

    // #30 RSSetViewports
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void RSSetViewportsDelegate(IntPtr device, uint NumViewports, ref D3D10_VIEWPORT pViewports);

    // #35 ClearRenderTargetView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearRenderTargetViewDelegate(
        IntPtr device,
        IntPtr pRenderTargetView,
        [MarshalAs(UnmanagedType.LPArray, SizeConst = 4)] float[] ColorRGBA
    );

    // #69 ClearState
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearStateDelegate(IntPtr device);

    // #71 CreateBuffer
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateBufferDelegate(
        IntPtr device,
        ref D3D10_BUFFER_DESC pDesc,
        ref D3D10_SUBRESOURCE_DATA pInitialData,
        out IntPtr ppBuffer
    );

    // #76 CreateRenderTargetView
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateRenderTargetViewDelegate(
        IntPtr device,
        IntPtr pResource,
        IntPtr pDesc,
        out IntPtr ppRTView
    );

    // #78 CreateInputLayout
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateInputLayoutDelegate(
        IntPtr device,
        [In] D3D10_INPUT_ELEMENT_DESC[] pInputElementDescs,
        uint NumElements,
        IntPtr pShaderBytecodeWithInputSignature,
        IntPtr BytecodeLength,
        out IntPtr ppInputLayout
    );

    // #79 CreateVertexShader
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateVertexShaderDelegate(
        IntPtr device,
        IntPtr pShaderBytecode,
        IntPtr BytecodeLength,
        out IntPtr ppVertexShader
    );

    // #82 CreatePixelShader
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreatePixelShaderDelegate(
        IntPtr device,
        IntPtr pShaderBytecode,
        IntPtr BytecodeLength,
        out IntPtr ppPixelShader
    );

    // =====================================
    // IDXGISwapChain VTable Delegates
    // =====================================

    // #8 Present
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PresentDelegate(IntPtr pSwapChain, uint SyncInterval, uint Flags);

    // #9 GetBuffer
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetBufferDelegate(IntPtr swapChain, uint Buffer, ref Guid riid, out IntPtr ppSurface);

    // =====================================
    // ID3DBlob VTable Delegates
    // =====================================

    // #3 GetBufferPointer
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferPointerDelegate(IntPtr pBlob);

    // #4 GetBufferSize
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferSizeDelegate(IntPtr pBlob);

    // =====================================
    // Structures
    // =====================================

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SWAP_CHAIN_DESC
    {
        public DXGI_MODE_DESC BufferDesc;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage;
        public uint BufferCount;
        public IntPtr OutputWindow;
        public bool Windowed;
        public uint SwapEffect;
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_MODE_DESC
    {
        public uint Width;
        public uint Height;
        public DXGI_RATIONAL RefreshRate;
        public uint Format;
        public uint ScanlineOrdering;
        public uint Scaling;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_RATIONAL
    {
        public uint Numerator;
        public uint Denominator;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct DXGI_SAMPLE_DESC
    {
        public uint Count;
        public uint Quality;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct Vertex
    {
        public float X, Y, Z;    // position
        public float R, G, B, A; // color
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)] 
    struct D3D10_BUFFER_DESC
    {
        public uint ByteWidth;
        public uint Usage;
        public uint BindFlags;
        public uint CPUAccessFlags;
        public uint MiscFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D10_SUBRESOURCE_DATA
    {
        public IntPtr pSysMem;
        public uint SysMemPitch;
        public uint SysMemSlicePitch;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D3D10_INPUT_ELEMENT_DESC
    {
        [MarshalAs(UnmanagedType.LPStr)]
        public string SemanticName;
        public uint SemanticIndex;
        public uint Format;
        public uint InputSlot;
        public uint AlignedByteOffset;
        public uint InputSlotClass;
        public uint InstanceDataStepRate;
    }

    // D3D10_VIEWPORT uses UINT for Width/Height (different from D3D11)
    [StructLayout(LayoutKind.Sequential)]
    struct D3D10_VIEWPORT
    {
        public int TopLeftX;
        public int TopLeftY;
        public uint Width;
        public uint Height;
        public float MinDepth;
        public float MaxDepth;
    }

    [DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.Winapi)]
    static extern int D3DCompileFromFile(
        [MarshalAs(UnmanagedType.LPWStr)] string pFileName,
        IntPtr pDefines,
        IntPtr pInclude,
        [MarshalAs(UnmanagedType.LPStr)] string pEntrypoint,
        [MarshalAs(UnmanagedType.LPStr)] string pTarget,
        uint Flags1,
        uint Flags2,
        out IntPtr ppCode,
        out IntPtr ppErrorMsgs
    );

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        PAINTSTRUCT ps = new PAINTSTRUCT();
        IntPtr hdc;
        string strMessage = "Hello, DirectX10(C#) World!";
 
        switch (uMsg)
        {
            case WM_PAINT:
                hdc = BeginPaint( hWnd, out ps );
                TextOut( hdc, 0, 0, strMessage, strMessage.Length );
                EndPaint( hWnd, ref ps );
                break;
            case WM_DESTROY:
                PostQuitMessage(0);
                break;
            default:
                return DefWindowProc(hWnd, uMsg, wParam, lParam);
        }
 
        return IntPtr.Zero;
    }

    static IntPtr GetBufferPointerFromBlob(IntPtr pBlob)
    {
        if (pBlob == IntPtr.Zero) return IntPtr.Zero;

        IntPtr vTable = Marshal.ReadIntPtr(pBlob);
        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);  // #3 GetBufferPointer
        var getBufferPointer = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(methodPtr);
        return getBufferPointer(pBlob);
    }
    
    static int GetBufferSizeFromBlob(IntPtr pBlob)
    {
        if (pBlob == IntPtr.Zero) return 0;

        IntPtr vTable = Marshal.ReadIntPtr(pBlob);
        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size);  // #4 GetBufferSize
        var getBufferSize = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(methodPtr);
        return (int)getBufferSize(pBlob);
    }

    static IntPtr CompileShaderFromFile(string filename, string entryPoint, string profile)
    {
        Console.WriteLine($"Compiling shader: {filename}, Entry: {entryPoint}, Profile: {profile}");

        IntPtr shaderBlob = IntPtr.Zero;
        IntPtr errorBlob = IntPtr.Zero;

        int result = D3DCompileFromFile(
            filename,
            IntPtr.Zero,
            IntPtr.Zero,
            entryPoint,
            profile,
            D3DCOMPILE_ENABLE_STRICTNESS,
            0,
            out shaderBlob,
            out errorBlob
        );

        if (result < 0)
        {
            if (errorBlob != IntPtr.Zero)
            {
                IntPtr errorPtr = GetBufferPointerFromBlob(errorBlob);
                string errorMsg = Marshal.PtrToStringAnsi(errorPtr);
                Console.WriteLine($"Shader compilation error: {errorMsg}");
                Marshal.Release(errorBlob);
            }
            return IntPtr.Zero;
        }

        if (errorBlob != IntPtr.Zero)
            Marshal.Release(errorBlob);

        Console.WriteLine($"Shader compiled successfully: {shaderBlob:X}");
        return shaderBlob;
    }

    static IntPtr CreateWindow()
    {
        Console.WriteLine("[CreateWindow]");

        const string CLASS_NAME = "MyDX10WindowClass";
        const string WINDOW_NAME = "Hello, World!";

        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);

        var wndClassEx = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style = CS_OWNDC,
            lpfnWndProc = new WndProcDelegate(WndProc),
            cbClsExtra = 0,
            cbWndExtra = 0,
            hInstance = hInstance,
            hIcon = IntPtr.Zero,
            hCursor = LoadCursor(IntPtr.Zero, IDC_ARROW),
            hbrBackground = IntPtr.Zero,
            lpszMenuName = null,
            lpszClassName = CLASS_NAME,
            hIconSm = IntPtr.Zero
        };

        ushort atom = RegisterClassEx(ref wndClassEx);
        if (atom == 0)
        {
            Console.WriteLine($"Failed to register window class. Error: {Marshal.GetLastWin32Error()}");
            return IntPtr.Zero;
        }

        IntPtr hwnd = CreateWindowEx(
            0,
            CLASS_NAME,
            WINDOW_NAME,
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100, 100,
            800, 600,
            IntPtr.Zero,
            IntPtr.Zero,
            hInstance,
            IntPtr.Zero
        );

        if (hwnd == IntPtr.Zero)
        {
            Console.WriteLine($"Failed to create window. Error: {Marshal.GetLastWin32Error()}");
            return IntPtr.Zero;
        }

        Console.WriteLine($"Window created: {hwnd:X}");
        return hwnd;
    }

    static int WinMain(string[] args)
    {
        IntPtr hwnd = CreateWindow();
        if (hwnd == IntPtr.Zero) return -1;

        // Create swap chain description
        var swapChainDesc = new DXGI_SWAP_CHAIN_DESC
        {
            BufferDesc = new DXGI_MODE_DESC
            {
                Width = 800,
                Height = 600,
                RefreshRate = new DXGI_RATIONAL { Numerator = 60, Denominator = 1 },
                Format = DXGI_FORMAT_R8G8B8A8_UNORM,
                ScanlineOrdering = 0,
                Scaling = 0
            },
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            BufferCount = 1,
            OutputWindow = hwnd,
            Windowed = true,
            SwapEffect = DXGI_SWAP_EFFECT_DISCARD,
            Flags = 0
        };

        // Create device and swap chain
        IntPtr device, swapChain;
        int result = D3D10CreateDeviceAndSwapChain(
            IntPtr.Zero,
            D3D10_DRIVER_TYPE_HARDWARE,
            IntPtr.Zero,
            0,  // Flags
            D3D10_SDK_VERSION,
            ref swapChainDesc,
            out swapChain,
            out device
        );

        if (result < 0)
        {
            Console.WriteLine($"Failed to create device and swap chain: {result:X}");
            return -1;
        }
        Console.WriteLine($"Device: {device:X}, SwapChain: {swapChain:X}");

        // Get back buffer
        Guid IID_ID3D10Texture2D = new Guid("9B7E4C04-342C-4106-A19F-4F2704F689F0");
        IntPtr backBuffer;
        {
            IntPtr vTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // #9 GetBuffer
            var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(methodPtr);
            result = getBuffer(swapChain, 0, ref IID_ID3D10Texture2D, out backBuffer);
            if (result < 0)
            {
                Console.WriteLine($"Failed to get back buffer: {result:X}");
                return -1;
            }
        }
        Console.WriteLine($"BackBuffer: {backBuffer:X}");

        // Create render target view
        IntPtr renderTargetView;
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 76 * IntPtr.Size);  // #76 CreateRenderTargetView
            var createRTV = Marshal.GetDelegateForFunctionPointer<CreateRenderTargetViewDelegate>(methodPtr);
            result = createRTV(device, backBuffer, IntPtr.Zero, out renderTargetView);
            if (result < 0)
            {
                Console.WriteLine($"Failed to create render target view: {result:X}");
                return -1;
            }
        }
        Console.WriteLine($"RenderTargetView: {renderTargetView:X}");
        Marshal.Release(backBuffer);

        // Set render targets
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 24 * IntPtr.Size);  // #24 OMSetRenderTargets
            var omSetRenderTargets = Marshal.GetDelegateForFunctionPointer<OMSetRenderTargetsDelegate>(methodPtr);
            IntPtr[] rtViews = new IntPtr[] { renderTargetView };
            omSetRenderTargets(device, 1, rtViews, IntPtr.Zero);
        }

        // Set viewport
        var viewport = new D3D10_VIEWPORT
        {
            TopLeftX = 0,
            TopLeftY = 0,
            Width = 800,
            Height = 600,
            MinDepth = 0.0f,
            MaxDepth = 1.0f
        };
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 30 * IntPtr.Size);  // #30 RSSetViewports
            var rsSetViewports = Marshal.GetDelegateForFunctionPointer<RSSetViewportsDelegate>(methodPtr);
            rsSetViewports(device, 1, ref viewport);
        }

        // Compile vertex shader
        IntPtr vsBlob = CompileShaderFromFile("hello.fx", "VS", "vs_4_0");
        if (vsBlob == IntPtr.Zero)
        {
            Console.WriteLine("Failed to compile vertex shader");
            return -1;
        }

        // Create vertex shader
        IntPtr vertexShader;
        {
            IntPtr codePtr = GetBufferPointerFromBlob(vsBlob);
            int size = GetBufferSizeFromBlob(vsBlob);

            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 79 * IntPtr.Size);  // #79 CreateVertexShader
            var createVS = Marshal.GetDelegateForFunctionPointer<CreateVertexShaderDelegate>(methodPtr);
            result = createVS(device, codePtr, (IntPtr)size, out vertexShader);
            if (result < 0)
            {
                Console.WriteLine($"Failed to create vertex shader: {result:X}");
                return -1;
            }
        }
        Console.WriteLine($"VertexShader: {vertexShader:X}");

        // Create input layout
        IntPtr inputLayout;
        {
            var inputElements = new[]
            {
                new D3D10_INPUT_ELEMENT_DESC
                {
                    SemanticName = "POSITION",
                    SemanticIndex = 0,
                    Format = DXGI_FORMAT_R32G32B32_FLOAT,
                    InputSlot = 0,
                    AlignedByteOffset = 0,
                    InputSlotClass = 0,
                    InstanceDataStepRate = 0
                },
                new D3D10_INPUT_ELEMENT_DESC
                {
                    SemanticName = "COLOR",
                    SemanticIndex = 0,
                    Format = DXGI_FORMAT_R32G32B32A32_FLOAT,
                    InputSlot = 0,
                    AlignedByteOffset = 12,
                    InputSlotClass = 0,
                    InstanceDataStepRate = 0
                }
            };

            IntPtr shaderBytecode = GetBufferPointerFromBlob(vsBlob);
            int bytecodeLength = GetBufferSizeFromBlob(vsBlob);

            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 78 * IntPtr.Size);  // #78 CreateInputLayout
            var createInputLayout = Marshal.GetDelegateForFunctionPointer<CreateInputLayoutDelegate>(methodPtr);
            result = createInputLayout(device, inputElements, (uint)inputElements.Length, 
                                       shaderBytecode, (IntPtr)bytecodeLength, out inputLayout);
            if (result < 0)
            {
                Console.WriteLine($"Failed to create input layout: {result:X}");
                return -1;
            }
        }
        Console.WriteLine($"InputLayout: {inputLayout:X}");
        Marshal.Release(vsBlob);

        // Compile pixel shader
        IntPtr psBlob = CompileShaderFromFile("hello.fx", "PS", "ps_4_0");
        if (psBlob == IntPtr.Zero)
        {
            Console.WriteLine("Failed to compile pixel shader");
            return -1;
        }

        // Create pixel shader
        IntPtr pixelShader;
        {
            IntPtr codePtr = GetBufferPointerFromBlob(psBlob);
            int size = GetBufferSizeFromBlob(psBlob);

            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 82 * IntPtr.Size);  // #82 CreatePixelShader
            var createPS = Marshal.GetDelegateForFunctionPointer<CreatePixelShaderDelegate>(methodPtr);
            result = createPS(device, codePtr, (IntPtr)size, out pixelShader);
            if (result < 0)
            {
                Console.WriteLine($"Failed to create pixel shader: {result:X}");
                return -1;
            }
        }
        Console.WriteLine($"PixelShader: {pixelShader:X}");
        Marshal.Release(psBlob);

        // Create vertex buffer
        Vertex[] vertices = new Vertex[]
        {
            new Vertex { X =  0.0f, Y =  0.5f, Z = 0.5f, R = 1.0f, G = 0.0f, B = 0.0f, A = 1.0f },
            new Vertex { X =  0.5f, Y = -0.5f, Z = 0.5f, R = 0.0f, G = 1.0f, B = 0.0f, A = 1.0f },
            new Vertex { X = -0.5f, Y = -0.5f, Z = 0.5f, R = 0.0f, G = 0.0f, B = 1.0f, A = 1.0f },
        };

        IntPtr vertexBuffer;
        {
            var bufferDesc = new D3D10_BUFFER_DESC
            {
                ByteWidth = (uint)(Marshal.SizeOf<Vertex>() * vertices.Length),
                Usage = D3D10_USAGE_DEFAULT,
                BindFlags = D3D10_BIND_VERTEX_BUFFER,
                CPUAccessFlags = 0,
                MiscFlags = 0
            };

            GCHandle handle = GCHandle.Alloc(vertices, GCHandleType.Pinned);
            try
            {
                var initData = new D3D10_SUBRESOURCE_DATA
                {
                    pSysMem = handle.AddrOfPinnedObject(),
                    SysMemPitch = 0,
                    SysMemSlicePitch = 0
                };

                IntPtr vTable = Marshal.ReadIntPtr(device);
                IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 71 * IntPtr.Size);  // #71 CreateBuffer
                var createBuffer = Marshal.GetDelegateForFunctionPointer<CreateBufferDelegate>(methodPtr);
                result = createBuffer(device, ref bufferDesc, ref initData, out vertexBuffer);
                if (result < 0)
                {
                    Console.WriteLine($"Failed to create vertex buffer: {result:X}");
                    return -1;
                }
            }
            finally
            {
                handle.Free();
            }
        }
        Console.WriteLine($"VertexBuffer: {vertexBuffer:X}");

        // Set input layout
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 11 * IntPtr.Size);  // #11 IASetInputLayout
            var iaSetInputLayout = Marshal.GetDelegateForFunctionPointer<IASetInputLayoutDelegate>(methodPtr);
            iaSetInputLayout(device, inputLayout);
        }

        // Set vertex buffer
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size);  // #12 IASetVertexBuffers
            var iaSetVertexBuffers = Marshal.GetDelegateForFunctionPointer<IASetVertexBuffersDelegate>(methodPtr);
            IntPtr[] buffers = new IntPtr[] { vertexBuffer };
            uint[] strides = new uint[] { (uint)Marshal.SizeOf<Vertex>() };
            uint[] offsets = new uint[] { 0 };
            iaSetVertexBuffers(device, 0, 1, buffers, strides, offsets);
        }

        // Set primitive topology
        {
            const uint D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 18 * IntPtr.Size);  // #18 IASetPrimitiveTopology
            var iaSetPrimitiveTopology = Marshal.GetDelegateForFunctionPointer<IASetPrimitiveTopologyDelegate>(methodPtr);
            iaSetPrimitiveTopology(device, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        }

        Console.WriteLine("Starting render loop...");

        // Message loop
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
                Render(device, renderTargetView, vertexShader, pixelShader, swapChain, (uint)vertices.Length);
            }
        }

        // Cleanup
        Console.WriteLine("Cleaning up...");
        {
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 69 * IntPtr.Size);  // #69 ClearState
            var clearState = Marshal.GetDelegateForFunctionPointer<ClearStateDelegate>(methodPtr);
            clearState(device);
        }

        if (vertexBuffer != IntPtr.Zero) Marshal.Release(vertexBuffer);
        if (inputLayout != IntPtr.Zero) Marshal.Release(inputLayout);
        if (vertexShader != IntPtr.Zero) Marshal.Release(vertexShader);
        if (pixelShader != IntPtr.Zero) Marshal.Release(pixelShader);
        if (renderTargetView != IntPtr.Zero) Marshal.Release(renderTargetView);
        if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
        if (device != IntPtr.Zero) Marshal.Release(device);

        return 0;
    }
    
    static void Render(IntPtr device, IntPtr renderTargetView, IntPtr vertexShader, 
                       IntPtr pixelShader, IntPtr swapChain, uint vertexCount)
    {
        IntPtr vTable = Marshal.ReadIntPtr(device);

        // Clear render target
        float[] clearColor = new float[] { 1.0f, 1.0f, 1.0f, 1.0f };
        {
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 35 * IntPtr.Size);  // #35 ClearRenderTargetView
            var clearRTV = Marshal.GetDelegateForFunctionPointer<ClearRenderTargetViewDelegate>(methodPtr);
            clearRTV(device, renderTargetView, clearColor);
        }

        // Set vertex shader
        {
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 7 * IntPtr.Size);  // #7 VSSetShader
            var vsSetShader = Marshal.GetDelegateForFunctionPointer<VSSetShaderDelegate>(methodPtr);
            vsSetShader(device, vertexShader);
        }

        // Set pixel shader
        {
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 5 * IntPtr.Size);  // #5 PSSetShader
            var psSetShader = Marshal.GetDelegateForFunctionPointer<PSSetShaderDelegate>(methodPtr);
            psSetShader(device, pixelShader);
        }

        // Draw
        {
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // #9 Draw
            var draw = Marshal.GetDelegateForFunctionPointer<DrawDelegate>(methodPtr);
            draw(device, vertexCount, 0);
        }

        // Present
        {
            IntPtr swapChainVTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(swapChainVTable, 8 * IntPtr.Size);  // #8 Present
            var present = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(methodPtr);
            present(swapChain, 0, 0);
        }
    }

    [STAThread]
    static int Main(string[] args)
    {
        return WinMain(args);
    }
}

