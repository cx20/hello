$source = @"
using System;
using System.Runtime.InteropServices;

public class Hello
{
    #region Win32 Structures and Constants
    
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

    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    const uint WS_OVERLAPPEDWINDOW = 0x00CF0000;
    const uint WS_VISIBLE = 0x10000000;
    const uint CS_HREDRAW = 0x0002;
    const uint CS_VREDRAW = 0x0001;
    const uint WM_PAINT = 0x000F;
    const uint WM_SIZE = 0x0005;
    const uint WM_DESTROY = 0x0002;
    const int CW_USEDEFAULT = unchecked((int)0x80000000);
    const uint SW_SHOWDEFAULT = 10;
    const int IDI_APPLICATION = 32512;
    const int IDC_ARROW = 32512;
    const uint COLOR_WINDOW = 5;

    #endregion

    #region Win32 Imports

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr LoadCursor(IntPtr hInstance, IntPtr lpCursorName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern short RegisterClassEx(ref WNDCLASSEX lpwcx);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName,
        uint dwStyle, int x, int y, int nWidth, int nHeight,
        IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool ShowWindow(IntPtr hWnd, uint nCmdShow);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool UpdateWindow(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int TranslateMessage(ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DispatchMessage(ref MSG lpMsg);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern void PostQuitMessage(int nExitCode);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool ValidateRect(IntPtr hWnd, IntPtr lpRect);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr LoadLibrary(string lpFileName);

    [DllImport("kernel32.dll", CharSet = CharSet.Ansi)]
    static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);

    [DllImport("kernel32.dll")]
    static extern bool FreeLibrary(IntPtr hModule);

    #endregion

    #region Direct2D Structures

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_COLOR_F
    {
        public float r, g, b, a;
        public D2D1_COLOR_F(float r, float g, float b, float a) { this.r = r; this.g = g; this.b = b; this.a = a; }
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_POINT_2F
    {
        public float x, y;
        public D2D1_POINT_2F(float x, float y) { this.x = x; this.y = y; }
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_SIZE_U
    {
        public uint width, height;
        public D2D1_SIZE_U(uint w, uint h) { width = w; height = h; }
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_PIXEL_FORMAT
    {
        public uint format;
        public uint alphaMode;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_RENDER_TARGET_PROPERTIES
    {
        public uint type;
        public D2D1_PIXEL_FORMAT pixelFormat;
        public float dpiX, dpiY;
        public uint usage;
        public uint minLevel;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct D2D1_HWND_RENDER_TARGET_PROPERTIES
    {
        public IntPtr hwnd;
        public D2D1_SIZE_U pixelSize;
        public uint presentOptions;
    }

    #endregion

    #region Direct2D COM Delegates

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int D2D1CreateFactoryDelegate(uint factoryType, ref Guid riid, IntPtr pFactoryOptions, out IntPtr ppFactory);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateHwndRenderTargetDelegate(IntPtr factory, ref D2D1_RENDER_TARGET_PROPERTIES rtProps,
        ref D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps, out IntPtr renderTarget);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int CreateSolidColorBrushDelegate(IntPtr renderTarget, ref D2D1_COLOR_F color, IntPtr brushProps, out IntPtr brush);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void BeginDrawDelegate(IntPtr renderTarget);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int EndDrawDelegate(IntPtr renderTarget, out ulong tag1, out ulong tag2);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void ClearDelegate(IntPtr renderTarget, ref D2D1_COLOR_F color);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate void DrawLineDelegate(IntPtr renderTarget, D2D1_POINT_2F p0, D2D1_POINT_2F p1, IntPtr brush, float strokeWidth, IntPtr strokeStyle);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate int ResizeDelegate(IntPtr renderTarget, ref D2D1_SIZE_U size);

    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    delegate uint ReleaseDelegate(IntPtr obj);

    #endregion

    static IntPtr g_hD2D1;
    static IntPtr g_factory;
    static IntPtr g_renderTarget;
    static IntPtr g_brush;
    static WndProcDelegate g_wndProc;

    static readonly Guid IID_ID2D1Factory = new Guid("06152247-6f50-465a-9245-118bfd3b6007");

    static IntPtr WndProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        switch (msg)
        {
            case WM_PAINT:
                if (g_renderTarget != IntPtr.Zero) Draw();
                ValidateRect(hWnd, IntPtr.Zero);
                return IntPtr.Zero;

            case WM_SIZE:
                if (g_renderTarget != IntPtr.Zero)
                {
                    uint width = (uint)(lParam.ToInt64() & 0xFFFF);
                    uint height = (uint)((lParam.ToInt64() >> 16) & 0xFFFF);
                    var size = new D2D1_SIZE_U(width, height);
                    
                    IntPtr vt = Marshal.ReadIntPtr(g_renderTarget);
                    IntPtr resizePtr = Marshal.ReadIntPtr(vt, 58 * IntPtr.Size);  // #58 ID2D1HwndRenderTarget::Resize
                    var resize = Marshal.GetDelegateForFunctionPointer<ResizeDelegate>(resizePtr);
                    resize(g_renderTarget, ref size);
                }
                return IntPtr.Zero;

            case WM_DESTROY:
                PostQuitMessage(0);
                return IntPtr.Zero;
        }
        return DefWindowProc(hWnd, msg, wParam, lParam);
    }

    static void Draw()
    {
        IntPtr vt = Marshal.ReadIntPtr(g_renderTarget);

        // BeginDraw (#48)
        var beginDraw = Marshal.GetDelegateForFunctionPointer<BeginDrawDelegate>(Marshal.ReadIntPtr(vt, 48 * IntPtr.Size));
        beginDraw(g_renderTarget);

        // Clear (#47) - white
        var clear = Marshal.GetDelegateForFunctionPointer<ClearDelegate>(Marshal.ReadIntPtr(vt, 47 * IntPtr.Size));
        var white = new D2D1_COLOR_F(1, 1, 1, 1);
        clear(g_renderTarget, ref white);

        // DrawLine (#15) - triangle
        var drawLine = Marshal.GetDelegateForFunctionPointer<DrawLineDelegate>(Marshal.ReadIntPtr(vt, 15 * IntPtr.Size));
        var p1 = new D2D1_POINT_2F(320, 120);
        var p2 = new D2D1_POINT_2F(480, 360);
        var p3 = new D2D1_POINT_2F(160, 360);

        drawLine(g_renderTarget, p1, p2, g_brush, 2.0f, IntPtr.Zero);
        drawLine(g_renderTarget, p2, p3, g_brush, 2.0f, IntPtr.Zero);
        drawLine(g_renderTarget, p3, p1, g_brush, 2.0f, IntPtr.Zero);

        // EndDraw (#49)
        var endDraw = Marshal.GetDelegateForFunctionPointer<EndDrawDelegate>(Marshal.ReadIntPtr(vt, 49 * IntPtr.Size));
        ulong tag1, tag2;
        endDraw(g_renderTarget, out tag1, out tag2);
    }

    static bool InitDirect2D(IntPtr hWnd)
    {
        g_hD2D1 = LoadLibrary("d2d1.dll");
        if (g_hD2D1 == IntPtr.Zero) return false;

        IntPtr procAddr = GetProcAddress(g_hD2D1, "D2D1CreateFactory");
        if (procAddr == IntPtr.Zero) return false;

        var createFactory = Marshal.GetDelegateForFunctionPointer<D2D1CreateFactoryDelegate>(procAddr);
        Guid iid = IID_ID2D1Factory;
        int hr = createFactory(0, ref iid, IntPtr.Zero, out g_factory);
        if (hr < 0) return false;

        // Get client rect
        RECT rect;
        GetClientRect(hWnd, out rect);
        uint width = (uint)(rect.Right - rect.Left);
        uint height = (uint)(rect.Bottom - rect.Top);

        // CreateHwndRenderTarget (#14)
        var rtProps = new D2D1_RENDER_TARGET_PROPERTIES();
        var hwndProps = new D2D1_HWND_RENDER_TARGET_PROPERTIES
        {
            hwnd = hWnd,
            pixelSize = new D2D1_SIZE_U(width, height),
            presentOptions = 0
        };

        IntPtr vt = Marshal.ReadIntPtr(g_factory);
        IntPtr createHwndRTPtr = Marshal.ReadIntPtr(vt, 14 * IntPtr.Size);
        var createHwndRT = Marshal.GetDelegateForFunctionPointer<CreateHwndRenderTargetDelegate>(createHwndRTPtr);
        hr = createHwndRT(g_factory, ref rtProps, ref hwndProps, out g_renderTarget);
        if (hr < 0) return false;

        // CreateSolidColorBrush (#8) - blue
        vt = Marshal.ReadIntPtr(g_renderTarget);
        IntPtr createBrushPtr = Marshal.ReadIntPtr(vt, 8 * IntPtr.Size);
        var createBrush = Marshal.GetDelegateForFunctionPointer<CreateSolidColorBrushDelegate>(createBrushPtr);
        var blue = new D2D1_COLOR_F(0, 0, 1, 1);
        hr = createBrush(g_renderTarget, ref blue, IntPtr.Zero, out g_brush);
        
        return hr >= 0;
    }

    static void Cleanup()
    {
        if (g_brush != IntPtr.Zero)
        {
            IntPtr vt = Marshal.ReadIntPtr(g_brush);
            var release = Marshal.GetDelegateForFunctionPointer<ReleaseDelegate>(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size));
            release(g_brush);
            g_brush = IntPtr.Zero;
        }
        if (g_renderTarget != IntPtr.Zero)
        {
            IntPtr vt = Marshal.ReadIntPtr(g_renderTarget);
            var release = Marshal.GetDelegateForFunctionPointer<ReleaseDelegate>(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size));
            release(g_renderTarget);
            g_renderTarget = IntPtr.Zero;
        }
        if (g_factory != IntPtr.Zero)
        {
            IntPtr vt = Marshal.ReadIntPtr(g_factory);
            var release = Marshal.GetDelegateForFunctionPointer<ReleaseDelegate>(Marshal.ReadIntPtr(vt, 2 * IntPtr.Size));
            release(g_factory);
            g_factory = IntPtr.Zero;
        }
        if (g_hD2D1 != IntPtr.Zero)
        {
            FreeLibrary(g_hD2D1);
            g_hD2D1 = IntPtr.Zero;
        }
    }

    [STAThread]
    public static int Main()
    {
        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);
        g_wndProc = new WndProcDelegate(WndProc);

        var wcex = new WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf<WNDCLASSEX>(),
            style = CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc = g_wndProc,
            hInstance = hInstance,
            hIcon = LoadIcon(hInstance, new IntPtr(IDI_APPLICATION)),
            hCursor = LoadCursor(IntPtr.Zero, new IntPtr(IDC_ARROW)),
            hbrBackground = new IntPtr(COLOR_WINDOW + 1),
            lpszMenuName = "",
            lpszClassName = "HelloD2DClass"
        };

        RegisterClassEx(ref wcex);

        IntPtr hWnd = CreateWindowEx(0, wcex.lpszClassName, "Hello, Direct2D(PowerShell) World!",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);

        if (hWnd == IntPtr.Zero || !InitDirect2D(hWnd))
        {
            Console.WriteLine("Initialization failed");
            Cleanup();
            return 1;
        }

        ShowWindow(hWnd, SW_SHOWDEFAULT);
        UpdateWindow(hWnd);

        MSG msg;
        while (GetMessage(out msg, IntPtr.Zero, 0, 0) != 0)
        {
            TranslateMessage(ref msg);
            DispatchMessage(ref msg);
        }

        Cleanup();
        return (int)msg.wParam;
    }
}
"@

Add-Type -Language CSharp -TypeDefinition $source
[void][Hello]::Main()