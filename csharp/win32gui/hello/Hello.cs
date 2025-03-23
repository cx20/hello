using System;
using System.Runtime.InteropServices;
 
class Hello
{
    [StructLayout(LayoutKind.Sequential)]
    struct POINT
    {
        public int x;
        public int y;
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
 
    const uint WS_OVERLAPPED = 0x00000000;
    const uint WS_POPUP = 0x80000000;
    const uint WS_CHILD = 0x40000000;
    const uint WS_MINIMIZE = 0x20000000;
    const uint WS_VISIBLE = 0x10000000;
    const uint WS_DISABLED = 0x08000000;
    const uint WS_CLIPSIBLINGS = 0x04000000;
    const uint WS_CLIPCHILDREN = 0x02000000;
    const uint WS_MAXIMIZE = 0x01000000;
    const uint WS_CAPTION = 0x00C00000; // WS_BORDER | WS_DLGFRAME
    const uint WS_BORDER = 0x00800000;
    const uint WS_DLGFRAME = 0x00400000;
    const uint WS_VSCROLL = 0x00200000;
    const uint WS_HSCROLL = 0x00100000;
    const uint WS_SYSMENU = 0x00080000;
    const uint WS_THICKFRAME = 0x00040000;
    const uint WS_GROUP = 0x00020000;
    const uint WS_TABSTOP = 0x00010000;
 
    const uint WS_MINIMIZEBOX = 0x00020000;
    const uint WS_MAXIMIZEBOX = 0x00010000;
 
    const uint WS_TILED = WS_OVERLAPPED;
    const uint WS_ICONIC = WS_MINIMIZE;
    const uint WS_SIZEBOX = WS_THICKFRAME;
    const uint WS_TILEDWINDOW = WS_OVERLAPPEDWINDOW;
 
    const uint WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
    const uint WS_POPUPWINDOW = WS_POPUP | WS_BORDER | WS_SYSMENU;
    const uint WS_CHILDWINDOW = WS_CHILD;
 
    const uint WM_CREATE = 0x0001;
    const uint WM_DESTROY = 0x0002;
    const uint WM_PAINT = 0x000F;
    const uint WM_CLOSE = 0x0010;
    const uint WM_COMMAND = 0x0111;
 
    const uint COLOR_WINDOW = 5;
    const uint COLOR_BTNFACE = 15;
 
    const uint CS_VREDRAW = 0x0001;
    const uint CS_HREDRAW = 0x0002;
 
    const int CW_USEDEFAULT = -2147483648; // ((uint)0x80000000)
 
    const uint SW_SHOWDEFAULT = 10;
 
    const int IDI_APPLICATION = 32512;
    const int IDC_ARROW = 32512;
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr LoadCursor(IntPtr hInstance, IntPtr lpCursorName);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern short RegisterClassEx(ref WNDCLASSEX pcWndClassEx);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle, int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool ShowWindow(IntPtr hWnd, uint nCmdShow);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern bool UpdateWindow(IntPtr hWnd);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
 
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int TranslateMessage([In] ref MSG lpMsg);
 
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
 
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    static extern IntPtr GetModuleHandle(string lpModuleName);
 
    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        PAINTSTRUCT ps = new PAINTSTRUCT();
        IntPtr hdc;
        string strMessage = "Hello, Win32 GUI(C#) World!";
 
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
 
    static int WinMain(string[] args)
    {
        IntPtr hInstance = Marshal.GetHINSTANCE(typeof(Hello).Module);
        const string CLASS_NAME = "helloWindow";
        const string WINDOW_NAME = "Hello, World!";
 
        WNDCLASSEX wcex = new WNDCLASSEX();
        wcex.cbSize = (uint)Marshal.SizeOf(wcex);
        wcex.style = CS_HREDRAW | CS_VREDRAW;
        wcex.lpfnWndProc = new WndProcDelegate(WndProc);
        wcex.cbClsExtra = 0;
        wcex.cbWndExtra = 0;
        wcex.hInstance = hInstance;
        wcex.hIcon = LoadIcon(hInstance, new IntPtr(IDI_APPLICATION));
        wcex.hCursor = LoadIcon(hInstance, new IntPtr(IDC_ARROW));
        wcex.hbrBackground = new IntPtr(COLOR_WINDOW + 1);
        wcex.lpszMenuName = "";
        wcex.lpszClassName = CLASS_NAME;
        wcex.hIconSm = IntPtr.Zero;
 
        RegisterClassEx(ref wcex);
 
        IntPtr hWnd = CreateWindowEx(
            0,
            wcex.lpszClassName,
            WINDOW_NAME,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            IntPtr.Zero,
            IntPtr.Zero,
            wcex.hInstance,
            IntPtr.Zero);
 
        ShowWindow(hWnd, SW_SHOWDEFAULT);
        UpdateWindow(hWnd);
 
        MSG msg = new MSG();
        while (GetMessage(out msg, IntPtr.Zero, 0, 0) != 0)
        {
            TranslateMessage(ref msg);
            DispatchMessage(ref msg);
        }
 
        return (int)msg.wParam;
    }
 
    [STAThread]
    static int Main(string[] args)
    {
        return WinMain( args );
    }
}
