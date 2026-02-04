import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Memory;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;

public class Hello {
    // Win32 constants
    static final int CS_HREDRAW = 0x0002;
    static final int CS_VREDRAW = 0x0001;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_DESTROY = 0x0002;
    static final int WM_QUIT = 0x0012;
    static final int PM_REMOVE = 0x0001;
    static final int COLOR_WINDOW = 5;
    static final int IDC_ARROW = 32512;

    // Direct3D9 constants
    static final int D3D_SDK_VERSION = 32;
    static final int D3DADAPTER_DEFAULT = 0;
    static final int D3DDEVTYPE_HAL = 1;
    static final int D3DCREATE_SOFTWARE_VERTEXPROCESSING = 0x00000020;
    static final int D3DFMT_UNKNOWN = 0;
    static final int D3DSWAPEFFECT_DISCARD = 1;
    static final int D3DMULTISAMPLE_NONE = 0;
    static final int D3DPOOL_DEFAULT = 0;
    static final int D3DCLEAR_TARGET = 0x00000001;
    static final int D3DPT_TRIANGLELIST = 4;

    // FVF (Flexible Vertex Format) flags
    static final int D3DFVF_XYZRHW = 0x004;
    static final int D3DFVF_DIFFUSE = 0x040;
    static final int D3DFVF_VERTEX = D3DFVF_XYZRHW | D3DFVF_DIFFUSE;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    static Callback wndProcCallback;
    static long g_hWnd;

    // D3D9 objects (stored as Pointer)
    static Pointer g_pD3D;
    static Pointer g_pd3dDevice;
    static Pointer g_pVertexBuffer;

    // IDirect3D9 vtable indices
    static final int IDirect3D9_CreateDevice = 16;

    // IDirect3DDevice9 vtable indices
    static final int IDirect3DDevice9_Present = 17;
    static final int IDirect3DDevice9_CreateVertexBuffer = 26;
    static final int IDirect3DDevice9_BeginScene = 41;
    static final int IDirect3DDevice9_EndScene = 42;
    static final int IDirect3DDevice9_Clear = 43;
    static final int IDirect3DDevice9_DrawPrimitive = 81;
    static final int IDirect3DDevice9_SetFVF = 89;
    static final int IDirect3DDevice9_SetStreamSource = 100;

    // IDirect3DVertexBuffer9 vtable indices
    static final int IDirect3DVertexBuffer9_Lock = 11;
    static final int IDirect3DVertexBuffer9_Unlock = 12;

    // d3d9.dll interface
    public interface D3D9 extends StdCallLibrary {
        D3D9 INSTANCE = Native.load("d3d9", D3D9.class);

        Pointer Direct3DCreate9(int SDKVersion);
    }

    public static void main(String[] args) {
        long hInstance = OS.GetModuleHandle(null);

        // Create callback function
        wndProcCallback = new Callback(Hello.class, "WndProc", 4);
        long wndProcAddress = wndProcCallback.getAddress();

        // Register window class
        char[] className = "HelloClass\0".toCharArray();

        WNDCLASS wc = new WNDCLASS();
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = wndProcAddress;
        wc.hInstance = hInstance;
        wc.hCursor = OS.LoadCursor(0, IDC_ARROW);
        wc.hbrBackground = COLOR_WINDOW + 1;
        wc.lpszClassName = OS.HeapAlloc(OS.GetProcessHeap(), OS.HEAP_ZERO_MEMORY, className.length * 2);
        OS.MoveMemory(wc.lpszClassName, className, className.length * 2);

        OS.RegisterClass(wc);

        // Create window
        char[] windowName = "Hello, World!\0".toCharArray();
        g_hWnd = OS.CreateWindowEx(
            0,
            className,
            windowName,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            0, 0, hInstance, null
        );

        OS.ShowWindow(g_hWnd, SW_SHOWDEFAULT);

        // Initialize D3D9
        if (!initD3D()) {
            System.err.println("Failed to initialize D3D9");
            cleanup();
            return;
        }

        // Initialize vertex buffer
        if (!initVB()) {
            System.err.println("Failed to create vertex buffer");
            cleanup();
            return;
        }

        System.out.println("D3D9 initialized successfully!");

        // Message loop
        MSG msg = new MSG();
        boolean bQuit = false;
        while (!bQuit) {
            if (OS.PeekMessage(msg, 0, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    bQuit = true;
                } else {
                    OS.TranslateMessage(msg);
                    OS.DispatchMessage(msg);
                }
            } else {
                render();
            }
        }

        // Cleanup
        cleanup();
        wndProcCallback.dispose();
        OS.HeapFree(OS.GetProcessHeap(), 0, wc.lpszClassName);
    }

    // Window procedure
    static long WndProc(long hWnd, long uMsg, long wParam, long lParam) {
        switch ((int) uMsg) {
            case WM_DESTROY:
                OS.PostMessage(hWnd, WM_QUIT, 0, 0);
                return 0;
            default:
                return OS.DefWindowProc(hWnd, (int) uMsg, wParam, lParam);
        }
    }

    static boolean initD3D() {
        // Create Direct3D9 object
        g_pD3D = D3D9.INSTANCE.Direct3DCreate9(D3D_SDK_VERSION);
        if (g_pD3D == null) {
            System.err.println("Direct3DCreate9 failed");
            return false;
        }
        System.out.println("IDirect3D9: " + g_pD3D);

        // D3DPRESENT_PARAMETERS structure layout on 64-bit:
        // HWND is 8 bytes and needs 8-byte alignment, so there's padding before it
        // Offset  Size  Field
        // 0       4     BackBufferWidth
        // 4       4     BackBufferHeight
        // 8       4     BackBufferFormat
        // 12      4     BackBufferCount
        // 16      4     MultiSampleType
        // 20      4     MultiSampleQuality
        // 24      4     SwapEffect
        // 28      4     (padding for HWND alignment)
        // 32      8     hDeviceWindow (HWND)
        // 40      4     Windowed
        // 44      4     EnableAutoDepthStencil
        // 48      4     AutoDepthStencilFormat
        // 52      4     Flags
        // 56      4     FullScreen_RefreshRateInHz
        // 60      4     PresentationInterval
        // Total: 64 bytes

        Memory d3dpp = new Memory(64);
        d3dpp.clear();

        // Set fields with correct 64-bit alignment
        d3dpp.setInt(0, 0);                      // BackBufferWidth (0 = use window size)
        d3dpp.setInt(4, 0);                      // BackBufferHeight
        d3dpp.setInt(8, D3DFMT_UNKNOWN);         // BackBufferFormat
        d3dpp.setInt(12, 0);                     // BackBufferCount
        d3dpp.setInt(16, D3DMULTISAMPLE_NONE);   // MultiSampleType
        d3dpp.setInt(20, 0);                     // MultiSampleQuality
        d3dpp.setInt(24, D3DSWAPEFFECT_DISCARD); // SwapEffect
        // offset 28: padding (4 bytes)
        d3dpp.setLong(32, g_hWnd);               // hDeviceWindow (HWND at offset 32)
        d3dpp.setInt(40, 1);                     // Windowed (TRUE)
        d3dpp.setInt(44, 0);                     // EnableAutoDepthStencil
        d3dpp.setInt(48, D3DFMT_UNKNOWN);        // AutoDepthStencilFormat
        d3dpp.setInt(52, 0);                     // Flags
        d3dpp.setInt(56, 0);                     // FullScreen_RefreshRateInHz
        d3dpp.setInt(60, 0);                     // PresentationInterval

        // IDirect3D9::CreateDevice
        // Use Pointer for HWND parameter
        PointerByReference ppDevice = new PointerByReference();
        Pointer hWndPtr = new Pointer(g_hWnd);
        
        int hr = callCOM(g_pD3D, IDirect3D9_CreateDevice,
            D3DADAPTER_DEFAULT,      // Adapter
            D3DDEVTYPE_HAL,          // DeviceType
            hWndPtr,                 // hFocusWindow (as Pointer)
            D3DCREATE_SOFTWARE_VERTEXPROCESSING, // BehaviorFlags
            d3dpp,                   // pPresentationParameters
            ppDevice                 // ppReturnedDeviceInterface
        );

        if (hr < 0) {
            System.err.println("IDirect3D9::CreateDevice failed: 0x" + Integer.toHexString(hr));
            return false;
        }

        g_pd3dDevice = ppDevice.getValue();
        System.out.println("IDirect3DDevice9: " + g_pd3dDevice);

        return true;
    }

    static boolean initVB() {
        // Vertex size: x(4) + y(4) + z(4) + rhw(4) + color(4) = 20 bytes
        int vertexSize = 20;
        int numVertices = 3;

        // Create vertex buffer
        // IDirect3DDevice9::CreateVertexBuffer
        PointerByReference ppVB = new PointerByReference();
        int hr = callCOM(g_pd3dDevice, IDirect3DDevice9_CreateVertexBuffer,
            numVertices * vertexSize,  // Length
            0,                         // Usage
            D3DFVF_VERTEX,             // FVF
            D3DPOOL_DEFAULT,           // Pool
            ppVB,                      // ppVertexBuffer
            null                       // pSharedHandle
        );

        if (hr < 0) {
            System.err.println("CreateVertexBuffer failed: 0x" + Integer.toHexString(hr));
            return false;
        }

        g_pVertexBuffer = ppVB.getValue();
        System.out.println("VertexBuffer: " + g_pVertexBuffer);

        // Lock vertex buffer
        // IDirect3DVertexBuffer9::Lock
        PointerByReference ppbData = new PointerByReference();
        hr = callCOM(g_pVertexBuffer, IDirect3DVertexBuffer9_Lock,
            0,                         // OffsetToLock
            numVertices * vertexSize,  // SizeToLock
            ppbData,                   // ppbData
            0                          // Flags
        );

        if (hr < 0) {
            System.err.println("Lock failed: 0x" + Integer.toHexString(hr));
            return false;
        }

        // Write vertex data
        Pointer pVertices = ppbData.getValue();

        // Vertex 0: Top (Red)
        pVertices.setFloat(0, 300.0f);     // x
        pVertices.setFloat(4, 100.0f);     // y
        pVertices.setFloat(8, 0.0f);       // z
        pVertices.setFloat(12, 1.0f);      // rhw
        pVertices.setInt(16, D3DCOLOR_XRGB(255, 0, 0)); // color (red)

        // Vertex 1: Bottom-right (Green)
        pVertices.setFloat(20, 500.0f);    // x
        pVertices.setFloat(24, 400.0f);    // y
        pVertices.setFloat(28, 0.0f);      // z
        pVertices.setFloat(32, 1.0f);      // rhw
        pVertices.setInt(36, D3DCOLOR_XRGB(0, 255, 0)); // color (green)

        // Vertex 2: Bottom-left (Blue)
        pVertices.setFloat(40, 100.0f);    // x
        pVertices.setFloat(44, 400.0f);    // y
        pVertices.setFloat(48, 0.0f);      // z
        pVertices.setFloat(52, 1.0f);      // rhw
        pVertices.setInt(56, D3DCOLOR_XRGB(0, 0, 255)); // color (blue)

        // Unlock vertex buffer
        // IDirect3DVertexBuffer9::Unlock
        callCOMVoid(g_pVertexBuffer, IDirect3DVertexBuffer9_Unlock);

        return true;
    }

    static void render() {
        if (g_pd3dDevice == null) {
            return;
        }

        // Clear (white background)
        // IDirect3DDevice9::Clear
        callCOM(g_pd3dDevice, IDirect3DDevice9_Clear,
            0,                          // Count
            null,                       // pRects
            D3DCLEAR_TARGET,            // Flags
            D3DCOLOR_XRGB(255, 255, 255), // Color (white)
            1.0f,                       // Z
            0                           // Stencil
        );

        // BeginScene
        int hr = callCOM(g_pd3dDevice, IDirect3DDevice9_BeginScene);
        if (hr >= 0) {
            // SetStreamSource
            callCOM(g_pd3dDevice, IDirect3DDevice9_SetStreamSource,
                0,                      // StreamNumber
                g_pVertexBuffer,        // pStreamData
                0,                      // OffsetInBytes
                20                      // Stride (vertex size)
            );

            // SetFVF
            callCOM(g_pd3dDevice, IDirect3DDevice9_SetFVF, D3DFVF_VERTEX);

            // DrawPrimitive
            callCOM(g_pd3dDevice, IDirect3DDevice9_DrawPrimitive,
                D3DPT_TRIANGLELIST,     // PrimitiveType
                0,                      // StartVertex
                1                       // PrimitiveCount
            );

            // EndScene
            callCOM(g_pd3dDevice, IDirect3DDevice9_EndScene);
        }

        // Present
        callCOM(g_pd3dDevice, IDirect3DDevice9_Present,
            null,   // pSourceRect
            null,   // pDestRect
            null,   // hDestWindowOverride (NULL = use device window)
            null    // pDirtyRegion
        );
    }

    static void cleanup() {
        if (g_pVertexBuffer != null) {
            callCOMRelease(g_pVertexBuffer);
            g_pVertexBuffer = null;
        }

        if (g_pd3dDevice != null) {
            callCOMRelease(g_pd3dDevice);
            g_pd3dDevice = null;
        }

        if (g_pD3D != null) {
            callCOMRelease(g_pD3D);
            g_pD3D = null;
        }
    }

    // D3DCOLOR_XRGB macro
    static int D3DCOLOR_XRGB(int r, int g, int b) {
        return 0xFF000000 | (r << 16) | (g << 8) | b;
    }

    // COM helper methods
    static int callCOM(Pointer obj, int vtableIndex, Object... args) {
        Pointer vtable = obj.getPointer(0);
        Pointer func = vtable.getPointer(vtableIndex * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        Object[] fullArgs = new Object[args.length + 1];
        fullArgs[0] = obj;
        System.arraycopy(args, 0, fullArgs, 1, args.length);
        return (Integer) f.invoke(int.class, fullArgs);
    }

    static void callCOMVoid(Pointer obj, int vtableIndex, Object... args) {
        Pointer vtable = obj.getPointer(0);
        Pointer func = vtable.getPointer(vtableIndex * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        Object[] fullArgs = new Object[args.length + 1];
        fullArgs[0] = obj;
        System.arraycopy(args, 0, fullArgs, 1, args.length);
        f.invoke(void.class, fullArgs);
    }

    static void callCOMRelease(Pointer obj) {
        // IUnknown::Release is vtable index 2
        callCOM(obj, 2);
    }
}