$source = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.IO;
using System.Reflection;    

public class Hello
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

    const uint WM_CREATE = 0x0001;
    const uint WM_DESTROY = 0x0002;
    const uint WM_PAINT = 0x000F;
    const uint WM_CLOSE = 0x0010;
    const uint WM_COMMAND = 0x0111;

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
    static extern bool GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

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

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr LoadLibrary(string libname);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern bool FreeLibrary(IntPtr hModule);

    const uint DXGI_FORMAT_UNKNOWN = 0;
    const uint DXGI_FORMAT_R32G32B32A32_TYPELESS = 1;
    const uint DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    const uint DXGI_FORMAT_R32G32B32A32_UINT = 3;
    const uint DXGI_FORMAT_R32G32B32A32_SINT = 4;
    const uint DXGI_FORMAT_R32G32B32_TYPELESS = 5;
    const uint DXGI_FORMAT_R32G32B32_FLOAT = 6;
    const uint DXGI_FORMAT_R32G32B32_UINT = 7;
    const uint DXGI_FORMAT_R32G32B32_SINT = 8;
    const uint DXGI_FORMAT_R16G16B16A16_TYPELESS = 9;
    const uint DXGI_FORMAT_R16G16B16A16_FLOAT = 10;
    const uint DXGI_FORMAT_R32G32_FLOAT = 16;
    const uint DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    const uint DXGI_FORMAT_R8G8B8A8_UINT = 30;
    const uint DXGI_FORMAT_R8G8B8A8_SNORM = 29;
    const uint DXGI_FORMAT_R8G8B8A8_SINT = 31;
    const uint DXGI_FORMAT_R32_FLOAT = 41;

    const uint DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    const uint DXGI_SCALING_STRETCH = 0;

    const int  DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED = 0;
    const uint DXGI_MODE_SCALING_UNSPECIFIED = 0;
    const uint DXGI_MODE_SCALING_CENTERED = 1;
    const uint DXGI_MODE_SCALING_STRETCH = 2;
    const uint DXGI_SCANLINE_ORDERING_UNSPECIFIED = 0;
    
    const uint DXGI_SWAP_EFFECT_DISCARD = 0;
    const uint DXGI_SWAP_EFFECT_SEQUENTIAL = 1;
    const uint DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;
    const uint DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;

    const uint DXGI_SWAP_CHAIN_FLAG_NONPREROTATED = 1;
    const uint DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH = 2;
    const uint DXGI_SWAP_CHAIN_FLAG_GDI_COMPATIBLE = 4;
    const uint DXGI_SWAP_CHAIN_FLAG_RESTRICTED_CONTENT = 8;
    const uint DXGI_SWAP_CHAIN_FLAG_RESTRICT_SHARED_RESOURCE_DRIVER = 16;
    const uint DXGI_SWAP_CHAIN_FLAG_DISPLAY_ONLY = 32;
    const uint DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = 64;
    const uint DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING = 512;  // 0x200

    const uint DXGI_PRESENT_NONE                  = 0x00000000;
    const uint DXGI_PRESENT_TEST                  = 0x00000001;
    const uint DXGI_PRESENT_DO_NOT_SEQUENCE       = 0x00000002;
    const uint DXGI_PRESENT_RESTART               = 0x00000004;
    const uint DXGI_PRESENT_DO_NOT_WAIT           = 0x00000008;
    const uint DXGI_PRESENT_STEREO_PREFER_RIGHT   = 0x00000010;
    const uint DXGI_PRESENT_STEREO_TEMPORARY_MONO = 0x00000020;
    const uint DXGI_PRESENT_RESTRICT_TO_OUTPUT    = 0x00000040;
    const uint DXGI_PRESENT_USE_DURATION          = 0x00000100;

    const int  D3D_DRIVER_TYPE_HARDWARE = 1;
    const uint D3D_FEATURE_LEVEL_11_0 = 0xb000;
    const uint D3D_FEATURE_LEVEL_10_1 = 0xa100;
    const uint D3D_FEATURE_LEVEL_10_0 = 0xa000;
    const uint D3D_FEATURE_LEVEL_9_3  = 0x9300;
    const uint D3D_FEATURE_LEVEL_9_2  = 0x9200;
    const uint D3D_FEATURE_LEVEL_9_1  = 0x9100;

    const uint D3D11_SDK_VERSION = 7;
    const uint D3D11_BIND_VERTEX_BUFFER = 0x1;
    const uint D3D11_USAGE_DEFAULT = 0;
    const uint D3D11_BIND_CONSTANT_BUFFER = 0x4;
    const uint D3D11_CREATE_DEVICE_DEBUG = 0x2;

    const uint D3DCOMPILE_DEBUG = 1;
    const uint D3DCOMPILE_SKIP_OPTIMIZATION = (1 << 2);
    const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

    [DllImport("d3d11.dll")]
    static extern int D3D11CreateDevice(
        IntPtr pAdapter,
        int DriverType,
        IntPtr Software,
        uint Flags,
        [In, MarshalAs(UnmanagedType.LPArray)] uint[] pFeatureLevels,
        uint FeatureLevels,
        uint SDKVersion,
        out IntPtr ppDevice,
        out IntPtr pFeatureLevel,
        out IntPtr ppImmediateContext
    );

    [DllImport("d3d11.dll", CallingConvention = CallingConvention.StdCall, SetLastError = true)]
    static extern int D3D11CreateDeviceAndSwapChain(
        IntPtr pAdapter,
        int DriverType,
        IntPtr Software,
        uint Flags,
        [In, MarshalAs(UnmanagedType.LPArray)] uint[] pFeatureLevels,
        uint FeatureLevels,
        uint SDKVersion,
        [In] ref DXGI_SWAP_CHAIN_DESC pSwapChainDesc,
        out IntPtr ppSwapChain,
        out IntPtr ppDevice,
        out IntPtr pFeatureLevel,
        out IntPtr ppImmediateContext
    );

    [UnmanagedFunctionPointer(CallingConvention.ThisCall)]
    delegate int CreateRenderTargetViewDelegate(
        [In] IntPtr pDevice,
        [In] IntPtr pResource,
        [In] IntPtr pDesc,
        [Out] out IntPtr ppRTView
    );

    static int CreateRenderTargetView(
        IntPtr device,
        IntPtr pResource,
        IntPtr pDesc,
        out IntPtr ppRTView)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[CreateRenderTargetView] - Start");
            
            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size); // vTable #9 ID3D11Device::CreateRenderTargetView

            var createRTV = Marshal.GetDelegateForFunctionPointer<CreateRenderTargetViewDelegate>(methodPtr);
            
            ppRTView = IntPtr.Zero;

            int result = createRTV(device, pResource, IntPtr.Zero, out ppRTView);

            if (result < 0)
            {
                ppRTView = IntPtr.Zero;
                return result;
            }

            if (ppRTView == IntPtr.Zero)
            {
                return -1;
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
            ppRTView = IntPtr.Zero;
            return -1;
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void OMSetRenderTargetsDelegate(
        IntPtr context,
        uint NumViews,
        [In] IntPtr[] ppRenderTargetViews,
        IntPtr pDepthStencilView
    );

    static void SetRenderTargets(IntPtr context, IntPtr renderTargetView)
    {
        try
        {
            //Console.WriteLine("----------------------------------------");
            //Console.WriteLine("[SetRenderTargets] - Start");

            if (context == IntPtr.Zero)
            {
                return;
            }
            if (renderTargetView == IntPtr.Zero)
            {
                return;
            }
            

            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr omSetRenderTargetsPtr = Marshal.ReadIntPtr(vTable, 33 * IntPtr.Size);  // vTable  #33 ID3D11DeviceContext::OMSetRenderTargets

            var omSetRenderTargets = Marshal.GetDelegateForFunctionPointer<OMSetRenderTargetsDelegate>(omSetRenderTargetsPtr);

            IntPtr[] rtViews = new IntPtr[1] { renderTargetView };
            
            omSetRenderTargets(context, 1, rtViews, IntPtr.Zero);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    [DllImport("dxgi.dll")]
    static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);

    static DXGI_SWAP_CHAIN_DESC1 swapChainDesc1;

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSwapChainDelegate(
        IntPtr factory,
        IntPtr pDevice,
        [In] ref DXGI_SWAP_CHAIN_DESC pDesc,
        out IntPtr ppSwapChain
    );

    static int CreateSwapChain(
        IntPtr factory,
        IntPtr pDevice,
        ref DXGI_SWAP_CHAIN_DESC pDesc,
        out IntPtr ppSwapChain)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[CreateSwapChain] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(factory);
            IntPtr createSwapChainPtr = Marshal.ReadIntPtr(vTable, 10 * IntPtr.Size);  // vTable #10 IDXGIFactory::CreateSwapChain

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainDelegate>(createSwapChainPtr);
            int result = createSwapChain(factory, pDevice, ref pDesc, out ppSwapChain);
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            ppSwapChain = IntPtr.Zero;
            return -1;
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSwapChainForHwndDelegate(
        IntPtr factory,
        IntPtr pDevice,
        IntPtr hWnd,
        [In] ref DXGI_SWAP_CHAIN_DESC1 pDesc,
        IntPtr pFullscreenDesc,
        IntPtr pRestrictToOutput,
        out IntPtr ppSwapChain
    );


    static int CreateSwapChainForHwnd(
        IntPtr factory,
        IntPtr pDevice,
        IntPtr hWnd,
        ref DXGI_SWAP_CHAIN_DESC1 pDesc,
        IntPtr pFullscreenDesc,
        IntPtr pRestrictToOutput,
        out IntPtr ppSwapChain)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateSwapChainForHwnd] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(factory);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size); // vTable #15 IDXGIFactory2::CreateSwapChainForHwnd

            var createSwapChain = Marshal.GetDelegateForFunctionPointer<CreateSwapChainForHwndDelegate>(methodPtr);
            int result = createSwapChain(factory, pDevice, hWnd, ref pDesc, pFullscreenDesc, pRestrictToOutput, out ppSwapChain);
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            ppSwapChain = IntPtr.Zero;
            return -1;
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int GetBufferDelegate(
        [In] IntPtr swapChain,
        [In] uint Buffer,
        [In] ref Guid riid,
        [Out] out IntPtr ppSurface
    );

    static int GetBuffer(IntPtr swapChain, uint buffer, ref Guid riid, out IntPtr ppSurface)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[GetBuffer] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 IDXGISwapChain::GetBuffer

            if (methodPtr == IntPtr.Zero)
            {
                ppSurface = IntPtr.Zero;
                return -1;
            }

            var getBuffer = Marshal.GetDelegateForFunctionPointer<GetBufferDelegate>(methodPtr);

            int result = getBuffer(swapChain, buffer, ref riid, out ppSurface);
            
            return result;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            ppSurface = IntPtr.Zero;
            return -1;
        }
    }


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
    struct DXGI_SWAP_CHAIN_DESC1
    {
        public uint Width;
        public uint Height;
        public uint Format;
        public bool Stereo;
        public DXGI_SAMPLE_DESC SampleDesc;
        public uint BufferUsage;
        public uint BufferCount;
        public uint Scaling;
        public uint SwapEffect;
        public uint AlphaMode;
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

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct D3D11_RENDER_TARGET_VIEW_DESC
    {
        public uint Format;           // DXGI_FORMAT
        public uint ViewDimension;    // D3D11_RTV_DIMENSION
        public RTV_Texture2D Texture2D;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    struct RTV_Texture2D
    {
        public uint MipSlice;
    }


    [StructLayout(LayoutKind.Sequential)]
    struct Vertex
    {
        public float X, Y, Z;    // position
        public float R, G, B, A; // color
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)] 
    struct D3D11_BUFFER_DESC
    {
        public uint ByteWidth;
        public uint Usage;
        public uint BindFlags;
        public uint CPUAccessFlags;
        public uint MiscFlags;
        public uint StructureByteStride;
    }


    [StructLayout(LayoutKind.Sequential)]
    public struct D3D11_SUBRESOURCE_DATA
    {
        public IntPtr pSysMem;
        public uint SysMemPitch;
        public uint SysMemSlicePitch;
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int QueryInterfaceDelegate(IntPtr thisPtr, ref Guid riid, out IntPtr ppvObject);
   
    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        PAINTSTRUCT ps = new PAINTSTRUCT();
        IntPtr hdc;
        string strMessage = "Hello, DirectX11(C#) World!";
 
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

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateBufferDelegate(
        [In] IntPtr device,
        [In] ref D3D11_BUFFER_DESC pDesc,
        [In] ref D3D11_SUBRESOURCE_DATA pInitialData,
        [Out] out IntPtr ppBuffer
    );
    
    static IntPtr CreateBuffer(IntPtr device, uint bindFlags, int byteWidth, Vertex[] data)
    {
        try 
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[CreateBuffer] - Start");

            var bufferDesc = new D3D11_BUFFER_DESC
            {
                ByteWidth = (uint)Marshal.SizeOf<Vertex>() * 3,
                Usage = D3D11_USAGE_DEFAULT,
                BindFlags = D3D11_BIND_VERTEX_BUFFER,
                CPUAccessFlags = 0,
                MiscFlags = 0,
                StructureByteStride = (uint)Marshal.SizeOf<Vertex>()
            };


            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);

            if (methodPtr == IntPtr.Zero)
            {
                return IntPtr.Zero;
            }

            GCHandle handle = GCHandle.Alloc(data, GCHandleType.Pinned);
            try
            {
                var initData = new D3D11_SUBRESOURCE_DATA
                {
                    pSysMem = handle.AddrOfPinnedObject(),
                    SysMemPitch = 0,
                    SysMemSlicePitch = 0
                };

                var createBuffer = Marshal.GetDelegateForFunctionPointer<CreateBufferDelegate>(methodPtr);
                IntPtr buffer;
                int result = createBuffer(device, ref bufferDesc, ref initData, out buffer);

                if (result < 0)
                {
                    return IntPtr.Zero;
                }

                return buffer;
            }
            finally
            {
                if (handle.IsAllocated)
                    handle.Free();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return IntPtr.Zero;
        }
    }

    [DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int D3DCompile(
        [MarshalAs(UnmanagedType.LPStr)] string srcData,
        IntPtr srcDataSize,
        [MarshalAs(UnmanagedType.LPStr)] string sourceName,
        IntPtr defines,
        IntPtr include,
        [MarshalAs(UnmanagedType.LPStr)] string entryPoint,
        [MarshalAs(UnmanagedType.LPStr)] string target,
        uint flags1,
        uint flags2,
        out IntPtr code,
        out IntPtr errorMsgs
    );
    
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

    [ComImport]
    [Guid("8ba5fb08-5195-40e2-ac58-0d989c3a0102")] // IID_ID3DBlob
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface ID3DBlob
    {
        IntPtr GetBufferPointer();
        int GetBufferSize();
    }
        
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferPointerDelegate(IntPtr pBlob);

    static IntPtr GetBufferPointerFromBlob(IntPtr pBlob)
    {
        if (pBlob == IntPtr.Zero)
        {
            return IntPtr.Zero;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(pBlob);
            IntPtr getBufferPointerPtr = Marshal.ReadIntPtr(vTable, 3 * IntPtr.Size);  // vTable #3 ID3DBlob::GetBufferPointer

            var getBufferPointer = Marshal.GetDelegateForFunctionPointer<GetBufferPointerDelegate>(getBufferPointerPtr);

            IntPtr bufferPointer = getBufferPointer(pBlob);

            return bufferPointer;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return IntPtr.Zero;
        }
    }
    
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate IntPtr GetBufferSizeDelegate(IntPtr pBlob);

    static int GetBufferSizeFromBlob(IntPtr pBlob)
    {
        if (pBlob == IntPtr.Zero)
        {
            return 0;
        }

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(pBlob);
            IntPtr getBufferSizePtr = Marshal.ReadIntPtr(vTable, 4 * IntPtr.Size); // vTable #4 ID3DBlob::GetBufferSize
            var getBufferSize = Marshal.GetDelegateForFunctionPointer<GetBufferSizeDelegate>(getBufferSizePtr);

            return (int)getBufferSize(pBlob);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return 0;
        }
    }


    static IntPtr CompileShaderFromFile(string filename, string entryPoint, string profile)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CompileShaderFromFile] - Start");

        Console.WriteLine("Compiling shader: " + filename);

        IntPtr shaderBlob = IntPtr.Zero;
        IntPtr errorBlob = IntPtr.Zero;

        try
        {
            uint compileFlags = D3DCOMPILE_ENABLE_STRICTNESS;
    #if DEBUG
            compileFlags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
    #endif

            int result = D3DCompileFromFile(
                filename,
                IntPtr.Zero,      // defines
                IntPtr.Zero,      // include interface
                entryPoint,       // entry point
                profile,          // target profile
                compileFlags,     // flags1
                0,                // flags2
                out shaderBlob,
                out errorBlob
            );

            Console.WriteLine("D3DCompileFromFile result: " + result);

            if (result < 0)
            {
                if (errorBlob != IntPtr.Zero)
                {
                    string errorMsg = GetBlobString(errorBlob);

                   Console.WriteLine("Shader compilation error: " + errorMsg);
                }
                return IntPtr.Zero;
            }

            return shaderBlob;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return IntPtr.Zero;
        }
        finally
        {
            if (errorBlob != IntPtr.Zero)
            {
                Marshal.Release(errorBlob);
            }
        }
    }
    
    static string GetBlobString(IntPtr blob)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[GetBlobString] - Start");

        try
        {
            if (blob == IntPtr.Zero) 
            {
                return null;
            }

            int size = GetBlobSize(blob);
            if (size <= 0)
            {
                return null;
            }

            IntPtr ptr = Marshal.ReadIntPtr(blob, 12);
            if (ptr == IntPtr.Zero)
            {
                return null;
            }

            return Marshal.PtrToStringAnsi(ptr, size);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return null;
        }
    }

    static int GetBlobSize(IntPtr blob)
    {
        try
        {
            if (blob == IntPtr.Zero) return 0;
            return Marshal.ReadInt32(blob, 8);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return 0;
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateVertexShaderDelegate(
        IntPtr device,
        IntPtr pShaderBytecode,
        IntPtr BytecodeLength,
        IntPtr pClassLinkage,
        out IntPtr ppVertexShader
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreatePixelShaderDelegate(
        IntPtr device,
        IntPtr pShaderBytecode,
        IntPtr BytecodeLength,
        IntPtr pClassLinkage,
        out IntPtr ppPixelShader
    );

    [StructLayout(LayoutKind.Sequential)]
    struct D3D11_INPUT_ELEMENT_DESC
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

    [StructLayout(LayoutKind.Sequential)]
    public struct D3D11_VIEWPORT
    {
        public float TopLeftX;
        public float TopLeftY;
        public float Width;
        public float Height;
        public float MinDepth;
        public float MaxDepth;
    }
    
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void RSSetViewportsDelegate(
        IntPtr context,
        uint numViewports,
        ref D3D11_VIEWPORT viewport
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearRenderTargetViewDelegate(
        IntPtr context,
        IntPtr pRenderTargetView,
        [MarshalAs(UnmanagedType.LPArray, SizeConst = 4)]
        float[] ColorRGBA
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetVertexBuffersDelegate(
        IntPtr context,
        uint StartSlot,
        uint NumBuffers,
        [In] IntPtr[] ppVertexBuffers,
        [In] uint[] pStrides,
        [In] uint[] pOffsets
    );


    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void VSSetShaderDelegate(
        IntPtr context,
        IntPtr pVertexShader,
        IntPtr[] ppClassInstances,
        uint NumClassInstances
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void PSSetShaderDelegate(
        IntPtr context,
        IntPtr pPixelShader,
        IntPtr[] ppClassInstances,
        uint NumClassInstances
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetInputLayoutDelegate(
        [In] IntPtr context,
        [In] IntPtr inputLayout
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void IASetPrimitiveTopologyDelegate(
        IntPtr context,
        uint Topology
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DrawDelegate(
        IntPtr context,
        uint VertexCount,
        uint StartVertexLocation
    );

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateInputLayoutDelegate(
        IntPtr device,
        [In] D3D11_INPUT_ELEMENT_DESC[] pInputElementDescs,
        uint NumElements,
        IntPtr pShaderBytecodeWithInputSignature,
        IntPtr BytecodeLength,
        out IntPtr ppInputLayout
    );

    static IntPtr CreateInputLayout(IntPtr device, IntPtr vsBlob)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateInputLayout] - Start");

        try
        {
            var inputElements = new[]
            {
                new D3D11_INPUT_ELEMENT_DESC
                {
                    SemanticName = "POSITION",
                    SemanticIndex = 0,
                    Format = DXGI_FORMAT_R32G32B32_FLOAT,
                    InputSlot = 0,
                    AlignedByteOffset = 0,
                    InputSlotClass = 0,
                    InstanceDataStepRate = 0
                },
                new D3D11_INPUT_ELEMENT_DESC
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

            if (shaderBytecode == IntPtr.Zero || bytecodeLength == 0)
            {
                return IntPtr.Zero;
            }

            IntPtr vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 11 * IntPtr.Size);  // vTable #11 ID3D11Device::CreateInputLayout

            var createInputLayout = Marshal.GetDelegateForFunctionPointer<CreateInputLayoutDelegate>(methodPtr);

            IntPtr inputLayout;
            int result = createInputLayout(
                device,
                inputElements,
                (uint)inputElements.Length,
                shaderBytecode,
                (IntPtr)bytecodeLength,
                out inputLayout
            );

            if (result < 0)
            {
                return IntPtr.Zero;
            }

            if (inputLayout == IntPtr.Zero)
            {
                return IntPtr.Zero;
            }

            return inputLayout;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);

            return IntPtr.Zero;
        }
    }


    static int GetFormatSize(uint format)
    {
        switch (format)
        {
            case DXGI_FORMAT_R32G32B32A32_FLOAT: return 16;  // 4 * 4 bytes
            case DXGI_FORMAT_R32G32B32_FLOAT: return 12;     // 3 * 4 bytes
            case DXGI_FORMAT_R32G32_FLOAT: return 8;         // 2 * 4 bytes
            case DXGI_FORMAT_R32_FLOAT: return 4;            // 1 * 4 bytes
            default: return 0;
        }
    }

    static void SetViewport(IntPtr context, ref D3D11_VIEWPORT viewport)
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[SetViewport] - Start");

        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr rsSetViewportsPtr = Marshal.ReadIntPtr(vTable, 44 * IntPtr.Size);  // vTable #44 ID3D11DeviceContext::RSSetViewports

            var rsSetViewports = Marshal.GetDelegateForFunctionPointer<RSSetViewportsDelegate>(rsSetViewportsPtr);

            rsSetViewports(context, 1, ref viewport);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    static void ClearRenderTarget(IntPtr context, IntPtr renderTargetView, float[] clearColor)
    {
        //Console.WriteLine("----------------------------------------");
        //Console.WriteLine("[ClearRenderTarget] - Start");

        try 
        {
            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr clearRenderTargetViewPtr = Marshal.ReadIntPtr(vTable, 50 * IntPtr.Size); // vTable #50 ID3D11DeviceContext::ClearRenderTargetView

            var clearRenderTargetView = Marshal.GetDelegateForFunctionPointer<ClearRenderTargetViewDelegate>(clearRenderTargetViewPtr);

            clearRenderTargetView(context, renderTargetView, clearColor);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    static void BindVertexBuffer(IntPtr context, IntPtr vertexBuffer, uint stride, uint offset)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[BindVertexBuffer] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr iaSetVertexBuffersPtr = Marshal.ReadIntPtr(vTable, 18 * IntPtr.Size);  // vTable #18 ID3D11DeviceContext::IASetVertexBuffers
            var iaSetVertexBuffers = Marshal.GetDelegateForFunctionPointer<IASetVertexBuffersDelegate>(iaSetVertexBuffersPtr);

            IntPtr[] buffers = new IntPtr[] { vertexBuffer };
            uint[] strides = new uint[] { stride };
            uint[] offsets = new uint[] { offset };

            iaSetVertexBuffers(context, 0, 1, buffers, strides, offsets);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    static void SetLayout(IntPtr context, IntPtr inputLayout)
    {
        try
        {
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[SetLayout] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr iaSetInputLayoutPtr = Marshal.ReadIntPtr(vTable, 17 * IntPtr.Size);  // vTable #17 ID3D11DeviceContext::IASetInputLayout
        
            var iaSetInputLayout = Marshal.GetDelegateForFunctionPointer<IASetInputLayoutDelegate>(iaSetInputLayoutPtr);

            iaSetInputLayout(context, inputLayout);

            IntPtr iaSetPrimitiveTopologyPtr = Marshal.ReadIntPtr(vTable, 24 * IntPtr.Size); // vTable #24 ID3D11DeviceContext::IASetPrimitiveTopology
            var iaSetPrimitiveTopology = Marshal.GetDelegateForFunctionPointer<IASetPrimitiveTopologyDelegate>(iaSetPrimitiveTopologyPtr);
            const uint D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
            iaSetPrimitiveTopology(context, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }


    static void SetShader(IntPtr context, IntPtr vertexShader, IntPtr pixelShader)
    {
        try
        {
            //Console.WriteLine("----------------------------------------");
            //Console.WriteLine("[SetShader] - Start");

            IntPtr vTable = Marshal.ReadIntPtr(context);

            IntPtr vsSetShaderPtr = Marshal.ReadIntPtr(vTable, 11 * IntPtr.Size);  // vTable #11 ID3D11DeviceContext::VSSetShader
            var vsSetShader = Marshal.GetDelegateForFunctionPointer<VSSetShaderDelegate>(vsSetShaderPtr);
            vsSetShader(context, vertexShader, null, 0);

            IntPtr psSetShaderPtr = Marshal.ReadIntPtr(vTable, 9 * IntPtr.Size);  // vTable #9 ID3D11DeviceContext::PSSetShader
            var psSetShader = Marshal.GetDelegateForFunctionPointer<PSSetShaderDelegate>(psSetShaderPtr);
            psSetShader(context, pixelShader, null, 0);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }


    static void DrawContext(IntPtr context, uint vertexCount, uint startVertexLocation)
    {
        //Console.WriteLine("----------------------------------------");
        //Console.WriteLine("[DrawContext] - Start");
        
        try
        {
            IntPtr vTable = Marshal.ReadIntPtr(context);
            IntPtr drawPtr = Marshal.ReadIntPtr(vTable, 13 * IntPtr.Size);  // vTable #13 ID3D11DeviceContext::Draw

            if (vertexCount == 0)
            {
                return;
            }

            var draw = Marshal.GetDelegateForFunctionPointer<DrawDelegate>(drawPtr);

            draw(context, vertexCount, startVertexLocation);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int PresentDelegate(
        [In] IntPtr pSwapChain,
        [In] uint SyncInterval,
        [In] uint Flags
    );

    static void Present(IntPtr swapChain)
    {
        //Console.WriteLine("----------------------------------------");
        //Console.WriteLine("[Present] - Start");

        try
        {
            const uint DXGI_PRESENT_NONE = 0;
            
            IntPtr vTable = Marshal.ReadIntPtr(swapChain);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 8 * IntPtr.Size);  // vTable #8 IDXGISwapChain::Present
            
            var presentMethod = Marshal.GetDelegateForFunctionPointer<PresentDelegate>(methodPtr);

            int result = presentMethod(swapChain, 1, DXGI_PRESENT_NONE);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    static void ReleaseResources(IntPtr swapChain, IntPtr device, IntPtr context,
        IntPtr renderTargetView, IntPtr vertexBuffer, IntPtr vertexShader, 
        IntPtr pixelShader, IntPtr inputLayout, IntPtr backBuffer)
    {
        if (renderTargetView != IntPtr.Zero) Marshal.Release(renderTargetView);
        if (vertexBuffer != IntPtr.Zero) Marshal.Release(vertexBuffer);
        if (vertexShader != IntPtr.Zero) Marshal.Release(vertexShader);
        if (pixelShader != IntPtr.Zero) Marshal.Release(pixelShader);
        if (inputLayout != IntPtr.Zero) Marshal.Release(inputLayout);
        if (backBuffer != IntPtr.Zero) Marshal.Release(backBuffer);
        if (context != IntPtr.Zero) Marshal.Release(context);
        if (device != IntPtr.Zero) Marshal.Release(device);
        if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
    }

    static int WinMain()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[Main] - Start");

        IntPtr hwnd = CreateWindow();
        if (hwnd == IntPtr.Zero)
        {
            return 0;
        }

        ShowWindow(hwnd, 1); // SW_SHOWNORMAL

        uint[] featureLevels = new uint[]
        {
            D3D_FEATURE_LEVEL_11_0,
            D3D_FEATURE_LEVEL_10_1,
            D3D_FEATURE_LEVEL_10_0,
            D3D_FEATURE_LEVEL_9_3,
            D3D_FEATURE_LEVEL_9_2,
            D3D_FEATURE_LEVEL_9_1
        };

        int result;

        IntPtr device, context;
        IntPtr featureLevel;
        uint flags = D3D11_CREATE_DEVICE_DEBUG;

        result = D3D11CreateDevice(
            IntPtr.Zero,
            D3D_DRIVER_TYPE_HARDWARE,
            IntPtr.Zero,
            flags,
            featureLevels,
            (uint)featureLevels.Length,
            D3D11_SDK_VERSION,
            out device,
            out featureLevel,
            out context
        );

        if (result < 0)
        {
            return 0;
        }

        IntPtr factory = IntPtr.Zero;
        int factoryResult;

        Guid factoryIID = new Guid("770aae78-f26f-4dba-a829-253c83d1b387"); // IID_IDXGIFactory1
        factoryResult = CreateDXGIFactory1(ref factoryIID, out factory);

        if (factoryResult < 0 || factory == IntPtr.Zero)
        {
            return 0;
        }

        IntPtr factory2 = IntPtr.Zero;
        Guid factory2IID = new Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0"); // IID_IDXGIFactory2

        IntPtr vTable = Marshal.ReadIntPtr(factory);
        IntPtr queryInterfacePtr = Marshal.ReadIntPtr(vTable, 0);    // vTable #0 IUnknown::QeuryInterface

        var queryInterface = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(queryInterfacePtr);
        int hr = queryInterface(factory, ref factory2IID, out factory2);

        if (hr < 0)
        {
            Marshal.Release(factory);
            return 0;
        }

        Marshal.Release(factory);
        factory = factory2;

        swapChainDesc1 = new DXGI_SWAP_CHAIN_DESC1
        {
            Width = 800,
            Height = 600,
            Format = DXGI_FORMAT_R8G8B8A8_UNORM,
            Stereo = false,
            SampleDesc = new DXGI_SAMPLE_DESC { Count = 1, Quality = 0 },
            BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
            BufferCount = 2,
            Scaling = DXGI_SCALING_STRETCH,
            SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
            AlphaMode = 0,
            Flags = 0
        };

        IntPtr swapChain;
        result = CreateSwapChainForHwnd(
            factory,
            device,
            hwnd,
            ref swapChainDesc1,
            IntPtr.Zero,
            IntPtr.Zero,
            out swapChain
        );

        if (result < 0 || swapChain == IntPtr.Zero)
        {
            if (factory != IntPtr.Zero) Marshal.Release(factory);
            if (device != IntPtr.Zero) Marshal.Release(device);
            if (context != IntPtr.Zero) Marshal.Release(context);
            return 0;
        }

        IntPtr backBuffer;
        Guid IID_ID3D11Texture2D = new Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c");

        result = GetBuffer(
            swapChain,
            0,
            ref IID_ID3D11Texture2D,
            out backBuffer
        );

        if (result < 0 || backBuffer == IntPtr.Zero)
        {
            if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
            if (factory != IntPtr.Zero) Marshal.Release(factory);
            if (device != IntPtr.Zero) Marshal.Release(device);
            if (context != IntPtr.Zero) Marshal.Release(context);
            return 0;
        }

        IntPtr renderTargetView;
        result = CreateRenderTargetView(
            device,
            backBuffer,
            IntPtr.Zero,
            out renderTargetView
        );

        if (result < 0)
        {
            if (backBuffer != IntPtr.Zero) Marshal.Release(backBuffer);
            if (swapChain != IntPtr.Zero) Marshal.Release(swapChain);
            if (device != IntPtr.Zero) Marshal.Release(device);
            if (context != IntPtr.Zero) Marshal.Release(context);
            return 0;
        }

        var vertices = new[]
        {
            new Vertex { X =  0.0f, Y =  0.5f, Z = 0.0f, R = 1.0f, G = 0.0f, B = 0.0f, A = 1.0f },
            new Vertex { X =  0.5f, Y = -0.5f, Z = 0.0f, R = 0.0f, G = 1.0f, B = 0.0f, A = 1.0f },
            new Vertex { X = -0.5f, Y = -0.5f, Z = 0.0f, R = 0.0f, G = 0.0f, B = 1.0f, A = 1.0f }
        };

        int vertexBufferSize = Marshal.SizeOf<Vertex>() * vertices.Length;
        IntPtr vertexBuffer = CreateBuffer(device, D3D11_BIND_VERTEX_BUFFER, vertexBufferSize, vertices);

        if (vertexBuffer == IntPtr.Zero)
        {
            return 0;
        }

        IntPtr vsBlob = CompileShaderFromFile("hello.fx", "VS", "vs_4_0");
        if (vsBlob == IntPtr.Zero)
        {
            Console.WriteLine("Failed to compile vertex shader");
            return 0;
        }

        IntPtr vertexShader;
        {
            IntPtr codePtr = GetBufferPointerFromBlob(vsBlob);
            int size = GetBufferSizeFromBlob(vsBlob);


            if (codePtr == IntPtr.Zero || size == 0)
            {
                Marshal.Release(vsBlob);
                return 0;
            }

            vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 12 * IntPtr.Size);  // vTable #12 ID3D11Device::CreateVertexShader
            var createVS = Marshal.GetDelegateForFunctionPointer<CreateVertexShaderDelegate>(methodPtr);

            result = createVS(
                device,
                codePtr,
                (IntPtr)size,
                IntPtr.Zero,
                out vertexShader
            );

            if (result < 0)
            {
                Marshal.Release(vsBlob);
                return 0;
            }
        }

        IntPtr inputLayout = CreateInputLayout(device, vsBlob);
        if (inputLayout == IntPtr.Zero)
        {
            Marshal.Release(vertexShader);
            Marshal.Release(vsBlob);
            return 0;
        }

        IntPtr psBlob = CompileShaderFromFile("hello.fx", "PS", "ps_4_0");
        if (psBlob == IntPtr.Zero)
        {
            Console.WriteLine("Failed to compile pixel shader");

            Marshal.Release(vertexShader);
            Marshal.Release(vsBlob);
            Marshal.Release(inputLayout);
            return 0;
        }

        IntPtr pixelShader;
        {
            IntPtr codePtr = GetBufferPointerFromBlob(psBlob);
            int size = GetBufferSizeFromBlob(psBlob);

            vTable = Marshal.ReadIntPtr(device);
            IntPtr methodPtr = Marshal.ReadIntPtr(vTable, 15 * IntPtr.Size);  // vTable #15 ID3D11Device::CreatePixelShader
            
            Console.WriteLine("----------------------------------------");
            Console.WriteLine("[CreatePixelShader] - Start");

            var createPS = Marshal.GetDelegateForFunctionPointer<CreatePixelShaderDelegate>(methodPtr);
            
            result = createPS(
                device,
                (IntPtr)codePtr,
                (IntPtr)size,
                IntPtr.Zero,
                out pixelShader
            );

            if (result < 0)
            {
                Marshal.Release(psBlob);
                Marshal.Release(vertexShader);
                Marshal.Release(vsBlob);
                Marshal.Release(inputLayout);
                return 0;
            }
        }

        Marshal.Release(vsBlob);
        Marshal.Release(psBlob);

        D3D11_VIEWPORT viewport = new D3D11_VIEWPORT
        {
            Width = 800,
            Height = 600,
            MinDepth = 0.0f,
            MaxDepth = 1.0f,
            TopLeftX = 0,
            TopLeftY = 0
        };

        SetRenderTargets(context, renderTargetView);
        SetViewport(context, ref viewport);
        SetLayout(context, inputLayout);

        uint stride = (uint)Marshal.SizeOf<Vertex>();
        uint offset = 0;
        BindVertexBuffer(context, vertexBuffer, stride, offset);

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
                Render(context, renderTargetView, vertexShader, pixelShader, inputLayout, ref viewport, swapChain, vertexBuffer, vertices);
            }
        }

        ReleaseResources(swapChain, device, context, renderTargetView, vertexBuffer, 
                        vertexShader, pixelShader, inputLayout, backBuffer);
        
        return 0;

    }
    
    static void Render(
        IntPtr context, 
        IntPtr renderTargetView, 
        IntPtr vertexShader, 
        IntPtr pixelShader, 
        IntPtr inputLayout, 
        ref D3D11_VIEWPORT viewport,
        IntPtr swapChain, 
        IntPtr vertexBuffer, 
        Vertex[] vertices
    ) 
    {
        try
        {
            //Console.WriteLine("----------------------------------------");
            //Console.WriteLine("[Render] - Start");
            
            SetRenderTargets(context, renderTargetView);

            float[] clearColor = new float[] { 1.0f, 1.0f, 1.0f, 1.0f };
            ClearRenderTarget(context, renderTargetView, clearColor);

            SetShader(context, vertexShader, pixelShader);

            DrawContext(context, (uint)vertices.Length, 0);

            Present(swapChain);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Stack trace: " + ex.StackTrace);
        }
    }

    static IntPtr CreateWindow()
    {
        Console.WriteLine("----------------------------------------");
        Console.WriteLine("[CreateWindow] - Start");

        const string CLASS_NAME = "MyDXWindowClass";
        const string WINDOW_NAME = "Helo, World!";

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
            hCursor = LoadCursor(IntPtr.Zero, (int)IDC_ARROW),
            hbrBackground = IntPtr.Zero,
            lpszMenuName = null,
            lpszClassName = CLASS_NAME,
            hIconSm = IntPtr.Zero
        };

        ushort atom = RegisterClassEx(ref wndClassEx);
        int error = Marshal.GetLastWin32Error();

        if (atom == 0)
        {
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

        error = Marshal.GetLastWin32Error();
        
        if (hwnd == IntPtr.Zero)
        {
            return IntPtr.Zero;
        }

        if (hwnd != IntPtr.Zero)
        {
            StringBuilder sb = new StringBuilder(100);
            GetWindowText(hwnd, sb, sb.Capacity);
            
            StringBuilder className_sb = new StringBuilder(100);
            GetClassName(hwnd, className_sb, className_sb.Capacity);
        }
                
        return hwnd;
    }

    [STAThread]
    public static int Main()
    {
        return WinMain();
    }
}
"@
Add-Type -Language CSharp -TypeDefinition $source -ReferencedAssemblies ("System.Drawing", "System.Windows.Forms" )
[void][Hello]::Main()
