import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Memory;
import com.sun.jna.Structure;
import com.sun.jna.WString;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.util.Arrays;
import java.util.List;

public class Hello {
    // Win32 constants
    static final int CS_HREDRAW = 0x0002;
    static final int CS_VREDRAW = 0x0001;
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int CW_USEDEFAULT = 0x80000000;
    static final int SW_SHOWDEFAULT = 10;
    static final int WM_PAINT = 0x000F;
    static final int WM_DESTROY = 0x0002;
    static final int WM_QUIT = 0x0012;
    static final int PM_REMOVE = 0x0001;
    static final int COLOR_WINDOW = 5;
    static final int IDC_ARROW = 32512;

    // D3D10 constants
    static final int D3D10_DRIVER_TYPE_HARDWARE = 1;
    static final int D3D10_DRIVER_TYPE_WARP = 2;
    static final int D3D10_DRIVER_TYPE_REFERENCE = 3;
    static final int D3D10_SDK_VERSION = 29;
    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_R32G32B32_FLOAT = 6;
    static final int DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    static final int D3D10_BIND_VERTEX_BUFFER = 0x1;
    static final int D3D10_USAGE_DEFAULT = 0;
    static final int D3D10_INPUT_PER_VERTEX_DATA = 0;
    static final int D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    static final int D3DCOMPILE_ENABLE_STRICTNESS = 0x800;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    // D3D10 objects (stored as Pointer)
    static Pointer g_hWnd;
    static Pointer g_pd3dDevice;
    static Pointer g_pSwapChain;
    static Pointer g_pRenderTargetView;
    static Pointer g_pVertexShader;
    static Pointer g_pPixelShader;
    static Pointer g_pVertexLayout;
    static Pointer g_pVertexBuffer;

    // IID_ID3D10Texture2D = {9B7E4C04-342C-4106-A19F-4F2704F689F0}
    static final byte[] IID_ID3D10Texture2D = new byte[] {
        (byte)0x04, (byte)0x4c, (byte)0x7e, (byte)0x9b,
        (byte)0x2c, (byte)0x34,
        (byte)0x06, (byte)0x41,
        (byte)0xa1, (byte)0x9f,
        (byte)0x4f, (byte)0x27, (byte)0x04, (byte)0xf6, (byte)0x89, (byte)0xf0
    };

    // ----------------------------
    // Win32 Structures
    // ----------------------------
    public static class WNDCLASSEX extends Structure {
        public int cbSize;
        public int style;
        public WndProcCallback lpfnWndProc;
        public int cbClsExtra;
        public int cbWndExtra;
        public Pointer hInstance;
        public Pointer hIcon;
        public Pointer hCursor;
        public Pointer hbrBackground;
        public WString lpszMenuName;
        public WString lpszClassName;
        public Pointer hIconSm;

        public WNDCLASSEX() {
            cbSize = size();
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                "cbSize", "style", "lpfnWndProc", "cbClsExtra", "cbWndExtra",
                "hInstance", "hIcon", "hCursor", "hbrBackground",
                "lpszMenuName", "lpszClassName", "hIconSm"
            );
        }
    }

    public static class MSG extends Structure {
        public Pointer hWnd;
        public int message;
        public Pointer wParam;
        public Pointer lParam;
        public int time;
        public int x;
        public int y;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("hWnd", "message", "wParam", "lParam", "time", "x", "y");
        }
    }

    public static class RECT extends Structure {
        public int left;
        public int top;
        public int right;
        public int bottom;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("left", "top", "right", "bottom");
        }
    }

    // ----------------------------
    // D3D10 Structures
    // ----------------------------
    public static class DXGI_SWAP_CHAIN_DESC extends Structure {
        public int BufferDescWidth;
        public int BufferDescHeight;
        public int BufferDescRefreshRateNumerator;
        public int BufferDescRefreshRateDenominator;
        public int BufferDescFormat;
        public int BufferDescScanlineOrdering;
        public int BufferDescScaling;
        public int SampleDescCount;
        public int SampleDescQuality;
        public int BufferUsage;
        public int BufferCount;
        public Pointer OutputWindow;  // Changed from long to Pointer
        public int Windowed;
        public int SwapEffect;
        public int Flags;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList(
                "BufferDescWidth", "BufferDescHeight",
                "BufferDescRefreshRateNumerator", "BufferDescRefreshRateDenominator",
                "BufferDescFormat", "BufferDescScanlineOrdering", "BufferDescScaling",
                "SampleDescCount", "SampleDescQuality",
                "BufferUsage", "BufferCount", "OutputWindow", "Windowed", "SwapEffect", "Flags"
            );
        }
    }

    public static class D3D10_VIEWPORT extends Structure {
        public int TopLeftX;
        public int TopLeftY;
        public int Width;
        public int Height;
        public float MinDepth;
        public float MaxDepth;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("TopLeftX", "TopLeftY", "Width", "Height", "MinDepth", "MaxDepth");
        }
    }

    // ----------------------------
    // Callback interface for WndProc
    // ----------------------------
    public interface WndProcCallback extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

    // ----------------------------
    // Kernel32 interface
    // ----------------------------
    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetModuleHandleW(WString lpModuleName);
    }

    // ----------------------------
    // User32 interface
    // ----------------------------
    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class, W32APIOptions.DEFAULT_OPTIONS);

        int RegisterClassExW(WNDCLASSEX lpWndClass);
        Pointer CreateWindowExW(int dwExStyle, WString lpClassName, WString lpWindowName,
                               int dwStyle, int x, int y, int nWidth, int nHeight,
                               Pointer hWndParent, Pointer hMenu, Pointer hInstance, Pointer lpParam);
        boolean ShowWindow(Pointer hWnd, int nCmdShow);
        boolean PeekMessageW(MSG lpMsg, Pointer hWnd, int wMsgFilterMin, int wMsgFilterMax, int wRemoveMsg);
        boolean TranslateMessage(MSG lpMsg);
        Pointer DispatchMessageW(MSG lpMsg);
        Pointer DefWindowProcW(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
        void PostQuitMessage(int nExitCode);
        Pointer LoadCursorW(Pointer hInstance, int lpCursorName);
        boolean AdjustWindowRect(RECT lpRect, int dwStyle, boolean bMenu);
    }

    // ----------------------------
    // D3D10.dll interface
    // ----------------------------
    public interface D3D10 extends StdCallLibrary {
        D3D10 INSTANCE = Native.load("d3d10", D3D10.class);

        int D3D10CreateDeviceAndSwapChain(
            Pointer pAdapter,
            int DriverType,
            Pointer Software,
            int Flags,
            int SDKVersion,
            DXGI_SWAP_CHAIN_DESC pSwapChainDesc,
            PointerByReference ppSwapChain,
            PointerByReference ppDevice
        );
    }

    // ----------------------------
    // D3DCompiler.dll interface
    // ----------------------------
    public interface D3DCompiler extends StdCallLibrary {
        D3DCompiler INSTANCE = Native.load("d3dcompiler_47", D3DCompiler.class);

        int D3DCompile(
            Pointer pSrcData,
            int SrcDataSize,
            String pSourceName,
            Pointer pDefines,
            Pointer pInclude,
            String pEntrypoint,
            String pTarget,
            int Flags1,
            int Flags2,
            PointerByReference ppCode,
            PointerByReference ppErrorMsgs
        );
    }

    // ----------------------------
    // WndProc implementation
    // ----------------------------
    static WndProcCallback wndProc = new WndProcCallback() {
        @Override
        public Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
            switch (uMsg) {
                case WM_DESTROY:
                    User32.INSTANCE.PostQuitMessage(0);
                    return Pointer.createConstant(0);
                default:
                    return User32.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
            }
        }
    };

    public static void main(String[] args) {
        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        WString className = new WString("HelloClass");

        // Register window class
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = wndProc;
        wc.hInstance = hInstance;
        wc.hCursor = User32.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = Pointer.createConstant(COLOR_WINDOW + 1);
        wc.lpszClassName = className;

        int atom = User32.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) {
            System.err.println("RegisterClassExW failed");
            return;
        }

        // Adjust window rect
        RECT rc = new RECT();
        rc.left = 0;
        rc.top = 0;
        rc.right = WIDTH;
        rc.bottom = HEIGHT;
        User32.INSTANCE.AdjustWindowRect(rc, WS_OVERLAPPEDWINDOW, false);

        // Create window
        g_hWnd = User32.INSTANCE.CreateWindowExW(
            0,
            className,
            new WString("Hello, World!"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            null, null, hInstance, null
        );

        if (g_hWnd == null) {
            System.err.println("CreateWindowExW failed");
            return;
        }

        User32.INSTANCE.ShowWindow(g_hWnd, SW_SHOWDEFAULT);

        // Initialize D3D10
        if (!initDevice()) {
            System.err.println("Failed to initialize D3D10");
            cleanupDevice();
            return;
        }

        System.out.println("D3D10 initialized successfully!");

        // Message loop
        MSG msg = new MSG();
        boolean bQuit = false;
        while (!bQuit) {
            if (User32.INSTANCE.PeekMessageW(msg, null, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    bQuit = true;
                } else {
                    User32.INSTANCE.TranslateMessage(msg);
                    User32.INSTANCE.DispatchMessageW(msg);
                }
            } else {
                render();
            }
        }

        // Cleanup
        cleanupDevice();
    }

    static boolean initDevice() {
        // Create swap chain description
        DXGI_SWAP_CHAIN_DESC sd = new DXGI_SWAP_CHAIN_DESC();
        sd.BufferDescWidth = WIDTH;
        sd.BufferDescHeight = HEIGHT;
        sd.BufferDescRefreshRateNumerator = 60;
        sd.BufferDescRefreshRateDenominator = 1;
        sd.BufferDescFormat = DXGI_FORMAT_R8G8B8A8_UNORM;
        sd.SampleDescCount = 1;
        sd.SampleDescQuality = 0;
        sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        sd.BufferCount = 1;
        sd.OutputWindow = g_hWnd;  // Pointer instead of long
        sd.Windowed = 1;

        PointerByReference ppSwapChain = new PointerByReference();
        PointerByReference ppDevice = new PointerByReference();

        int[] driverTypes = { D3D10_DRIVER_TYPE_HARDWARE, D3D10_DRIVER_TYPE_WARP, D3D10_DRIVER_TYPE_REFERENCE };

        int hr = -1;
        for (int driverType : driverTypes) {
            hr = D3D10.INSTANCE.D3D10CreateDeviceAndSwapChain(
                null, driverType, null, 0,
                D3D10_SDK_VERSION,
                sd, ppSwapChain, ppDevice
            );

            if (hr >= 0) {
                System.out.println("D3D10 device created with driver type: " + driverType);
                break;
            }
        }

        if (hr < 0) {
            System.err.println("D3D10CreateDeviceAndSwapChain failed: 0x" + Integer.toHexString(hr));
            return false;
        }

        g_pSwapChain = ppSwapChain.getValue();
        g_pd3dDevice = ppDevice.getValue();

        System.out.println("SwapChain: " + g_pSwapChain);
        System.out.println("Device: " + g_pd3dDevice);

        // Get back buffer
        PointerByReference ppBackBuffer = new PointerByReference();
        Memory iidTexture2D = new Memory(16);
        iidTexture2D.write(0, IID_ID3D10Texture2D, 0, 16);

        // IDXGISwapChain::GetBuffer (vtable index 9)
        hr = callCOM(g_pSwapChain, 9, 0, iidTexture2D, ppBackBuffer);
        if (hr < 0) {
            System.err.println("GetBuffer failed: 0x" + Integer.toHexString(hr));
            return false;
        }
        Pointer pBackBuffer = ppBackBuffer.getValue();
        System.out.println("BackBuffer: " + pBackBuffer);

        // Create render target view
        // ID3D10Device::CreateRenderTargetView (vtable index 76)
        PointerByReference ppRTV = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 76, pBackBuffer, null, ppRTV);
        if (hr < 0) {
            System.err.println("CreateRenderTargetView failed: 0x" + Integer.toHexString(hr));
            return false;
        }
        g_pRenderTargetView = ppRTV.getValue();
        System.out.println("RenderTargetView: " + g_pRenderTargetView);

        // Release back buffer
        callCOMRelease(pBackBuffer);

        // Set render target
        // ID3D10Device::OMSetRenderTargets (vtable index 24)
        Memory ppRTVArray = new Memory(Native.POINTER_SIZE);
        ppRTVArray.setPointer(0, g_pRenderTargetView);
        callCOMVoid(g_pd3dDevice, 24, 1, ppRTVArray, null);

        // Set viewport
        D3D10_VIEWPORT vp = new D3D10_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;

        // ID3D10Device::RSSetViewports (vtable index 30)
        vp.write();
        callCOMVoid(g_pd3dDevice, 30, 1, vp.getPointer());

        // Compile and create shaders
        if (!createShaders()) {
            return false;
        }

        // Create vertex buffer
        if (!createVertexBuffer()) {
            return false;
        }

        return true;
    }

    static boolean createShaders() {
        // Vertex shader source
        String vsSource = 
            "struct VS_INPUT { float4 Pos : POSITION; float4 Color : COLOR; };\n" +
            "struct PS_INPUT { float4 Pos : SV_POSITION; float4 Color : COLOR; };\n" +
            "PS_INPUT VS(VS_INPUT input) {\n" +
            "  PS_INPUT output;\n" +
            "  output.Pos = input.Pos;\n" +
            "  output.Color = input.Color;\n" +
            "  return output;\n" +
            "}\n";

        // Pixel shader source
        String psSource = 
            "struct PS_INPUT { float4 Pos : SV_POSITION; float4 Color : COLOR; };\n" +
            "float4 PS(PS_INPUT input) : SV_Target {\n" +
            "  return input.Color;\n" +
            "}\n";

        // Compile vertex shader (use vs_4_0 for D3D10)
        PointerByReference ppVSBlob = new PointerByReference();
        PointerByReference ppErrors = new PointerByReference();

        Memory vsData = new Memory(vsSource.length() + 1);
        vsData.setString(0, vsSource);

        int hr = D3DCompiler.INSTANCE.D3DCompile(
            vsData, vsSource.length(), null, null, null,
            "VS", "vs_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0,
            ppVSBlob, ppErrors
        );

        if (hr < 0) {
            if (ppErrors.getValue() != null) {
                Pointer errBlob = ppErrors.getValue();
                Pointer errMsg = callCOMGetBufferPointer(errBlob);
                System.err.println("VS compile error: " + errMsg.getString(0));
                callCOMRelease(errBlob);
            }
            return false;
        }
        System.out.println("Vertex shader compiled");

        Pointer pVSBlob = ppVSBlob.getValue();
        Pointer vsCode = callCOMGetBufferPointer(pVSBlob);
        long vsSize = callCOMGetBufferSize(pVSBlob);

        // ID3D10Device::CreateVertexShader (vtable index 79)
        PointerByReference ppVS = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 79, vsCode, vsSize, ppVS);
        if (hr < 0) {
            System.err.println("CreateVertexShader failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pVSBlob);
            return false;
        }
        g_pVertexShader = ppVS.getValue();
        System.out.println("VertexShader: " + g_pVertexShader);

        // Create input layout
        int elemSize = 32; // size of D3D10_INPUT_ELEMENT_DESC on 64-bit
        Memory layoutDesc = new Memory(elemSize * 2);
        
        // Element 0: POSITION
        Memory posName = new Memory(16);
        posName.setString(0, "POSITION");
        layoutDesc.setPointer(0, posName);
        layoutDesc.setInt(8, 0);                      // SemanticIndex
        layoutDesc.setInt(12, DXGI_FORMAT_R32G32B32_FLOAT); // Format
        layoutDesc.setInt(16, 0);                     // InputSlot
        layoutDesc.setInt(20, 0);                     // AlignedByteOffset
        layoutDesc.setInt(24, D3D10_INPUT_PER_VERTEX_DATA);
        layoutDesc.setInt(28, 0);

        // Element 1: COLOR
        Memory colorName = new Memory(16);
        colorName.setString(0, "COLOR");
        layoutDesc.setPointer(elemSize, colorName);
        layoutDesc.setInt(elemSize + 8, 0);
        layoutDesc.setInt(elemSize + 12, DXGI_FORMAT_R32G32B32A32_FLOAT);
        layoutDesc.setInt(elemSize + 16, 0);
        layoutDesc.setInt(elemSize + 20, 12);         // AlignedByteOffset (3 floats = 12 bytes)
        layoutDesc.setInt(elemSize + 24, D3D10_INPUT_PER_VERTEX_DATA);
        layoutDesc.setInt(elemSize + 28, 0);

        // ID3D10Device::CreateInputLayout (vtable index 78)
        PointerByReference ppLayout = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 78, layoutDesc, 2, vsCode, vsSize, ppLayout);
        if (hr < 0) {
            System.err.println("CreateInputLayout failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pVSBlob);
            return false;
        }
        g_pVertexLayout = ppLayout.getValue();
        System.out.println("InputLayout: " + g_pVertexLayout);

        callCOMRelease(pVSBlob);

        // Compile pixel shader (use ps_4_0 for D3D10)
        PointerByReference ppPSBlob = new PointerByReference();
        Memory psData = new Memory(psSource.length() + 1);
        psData.setString(0, psSource);

        hr = D3DCompiler.INSTANCE.D3DCompile(
            psData, psSource.length(), null, null, null,
            "PS", "ps_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0,
            ppPSBlob, ppErrors
        );

        if (hr < 0) {
            if (ppErrors.getValue() != null) {
                Pointer errBlob = ppErrors.getValue();
                Pointer errMsg = callCOMGetBufferPointer(errBlob);
                System.err.println("PS compile error: " + errMsg.getString(0));
                callCOMRelease(errBlob);
            }
            return false;
        }
        System.out.println("Pixel shader compiled");

        Pointer pPSBlob = ppPSBlob.getValue();
        Pointer psCode = callCOMGetBufferPointer(pPSBlob);
        long psSize = callCOMGetBufferSize(pPSBlob);

        // ID3D10Device::CreatePixelShader (vtable index 82)
        PointerByReference ppPS = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 82, psCode, psSize, ppPS);
        if (hr < 0) {
            System.err.println("CreatePixelShader failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pPSBlob);
            return false;
        }
        g_pPixelShader = ppPS.getValue();
        System.out.println("PixelShader: " + g_pPixelShader);

        callCOMRelease(pPSBlob);

        // Set input layout
        // ID3D10Device::IASetInputLayout (vtable index 11)
        callCOMVoid(g_pd3dDevice, 11, g_pVertexLayout);

        return true;
    }

    static boolean createVertexBuffer() {
        // Vertex data: x, y, z, r, g, b, a
        float[] vertices = {
             0.0f,  0.5f, 0.5f,  1.0f, 0.0f, 0.0f, 1.0f,  // top (red)
             0.5f, -0.5f, 0.5f,  0.0f, 1.0f, 0.0f, 1.0f,  // right (green)
            -0.5f, -0.5f, 0.5f,  0.0f, 0.0f, 1.0f, 1.0f   // left (blue)
        };

        Memory vertexData = new Memory(vertices.length * 4);
        for (int i = 0; i < vertices.length; i++) {
            vertexData.setFloat(i * 4, vertices[i]);
        }

        // D3D10_BUFFER_DESC (20 bytes, no StructureByteStride)
        Memory bufferDesc = new Memory(20);
        bufferDesc.setInt(0, vertices.length * 4);  // ByteWidth
        bufferDesc.setInt(4, D3D10_USAGE_DEFAULT);
        bufferDesc.setInt(8, D3D10_BIND_VERTEX_BUFFER);
        bufferDesc.setInt(12, 0); // CPUAccessFlags
        bufferDesc.setInt(16, 0); // MiscFlags

        // D3D10_SUBRESOURCE_DATA
        Memory initData = new Memory(Native.POINTER_SIZE + 8);
        initData.setPointer(0, vertexData);
        initData.setInt(Native.POINTER_SIZE, 0);
        initData.setInt(Native.POINTER_SIZE + 4, 0);

        // ID3D10Device::CreateBuffer (vtable index 71)
        PointerByReference ppBuffer = new PointerByReference();
        int hr = callCOM(g_pd3dDevice, 71, bufferDesc, initData, ppBuffer);
        if (hr < 0) {
            System.err.println("CreateBuffer failed: 0x" + Integer.toHexString(hr));
            return false;
        }
        g_pVertexBuffer = ppBuffer.getValue();
        System.out.println("VertexBuffer: " + g_pVertexBuffer);

        // Set vertex buffer
        int stride = 7 * 4; // 7 floats per vertex
        int offset = 0;

        Memory ppBuffers = new Memory(Native.POINTER_SIZE);
        ppBuffers.setPointer(0, g_pVertexBuffer);
        Memory strides = new Memory(4);
        strides.setInt(0, stride);
        Memory offsets = new Memory(4);
        offsets.setInt(0, offset);

        // ID3D10Device::IASetVertexBuffers (vtable index 12)
        callCOMVoid(g_pd3dDevice, 12, 0, 1, ppBuffers, strides, offsets);

        // Set primitive topology
        // ID3D10Device::IASetPrimitiveTopology (vtable index 18)
        callCOMVoid(g_pd3dDevice, 18, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        return true;
    }

    static void render() {
        // Clear render target (white background)
        Memory clearColor = new Memory(16);
        clearColor.setFloat(0, 1.0f);  // R
        clearColor.setFloat(4, 1.0f);  // G
        clearColor.setFloat(8, 1.0f);  // B
        clearColor.setFloat(12, 1.0f); // A

        // ID3D10Device::ClearRenderTargetView (vtable index 35)
        callCOMVoid(g_pd3dDevice, 35, g_pRenderTargetView, clearColor);

        // Ensure pipeline state is set every frame
        // OMSetRenderTargets (vtable index 24)
        Memory ppRTVArray = new Memory(Native.POINTER_SIZE);
        ppRTVArray.setPointer(0, g_pRenderTargetView);
        callCOMVoid(g_pd3dDevice, 24, 1, ppRTVArray, null);

        // Viewport (vtable index 30)
        D3D10_VIEWPORT vp = new D3D10_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;
        vp.write();
        callCOMVoid(g_pd3dDevice, 30, 1, vp.getPointer());

        // Input layout (vtable index 11)
        callCOMVoid(g_pd3dDevice, 11, g_pVertexLayout);

        // Vertex buffer (vtable index 12)
        int stride = 7 * 4;
        int offset = 0;
        Memory ppBuffers = new Memory(Native.POINTER_SIZE);
        ppBuffers.setPointer(0, g_pVertexBuffer);
        Memory strides = new Memory(4);
        strides.setInt(0, stride);
        Memory offsets = new Memory(4);
        offsets.setInt(0, offset);
        callCOMVoid(g_pd3dDevice, 12, 0, 1, ppBuffers, strides, offsets);

        // Topology (vtable index 18)
        callCOMVoid(g_pd3dDevice, 18, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Set shaders
        // ID3D10Device::VSSetShader (vtable index 7)
        callCOMVoid(g_pd3dDevice, 7, g_pVertexShader);

        // ID3D10Device::PSSetShader (vtable index 5)
        callCOMVoid(g_pd3dDevice, 5, g_pPixelShader);

        // Draw
        // ID3D10Device::Draw (vtable index 9)
        callCOMVoid(g_pd3dDevice, 9, 3, 0);

        // Present
        // IDXGISwapChain::Present (vtable index 8)
        callCOM(g_pSwapChain, 8, 0, 0);
    }

    static void cleanupDevice() {
        if (g_pd3dDevice != null) {
            // ID3D10Device::ClearState (vtable index 69)
            callCOMVoid(g_pd3dDevice, 69);
        }

        if (g_pVertexBuffer != null) { callCOMRelease(g_pVertexBuffer); g_pVertexBuffer = null; }
        if (g_pVertexLayout != null) { callCOMRelease(g_pVertexLayout); g_pVertexLayout = null; }
        if (g_pVertexShader != null) { callCOMRelease(g_pVertexShader); g_pVertexShader = null; }
        if (g_pPixelShader != null) { callCOMRelease(g_pPixelShader); g_pPixelShader = null; }
        if (g_pRenderTargetView != null) { callCOMRelease(g_pRenderTargetView); g_pRenderTargetView = null; }
        if (g_pSwapChain != null) { callCOMRelease(g_pSwapChain); g_pSwapChain = null; }
        if (g_pd3dDevice != null) { callCOMRelease(g_pd3dDevice); g_pd3dDevice = null; }
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
        callCOM(obj, 2);
    }

    static Pointer callCOMGetBufferPointer(Pointer blob) {
        Pointer vtable = blob.getPointer(0);
        Pointer func = vtable.getPointer(3 * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        return (Pointer) f.invoke(Pointer.class, new Object[]{ blob });
    }

    static long callCOMGetBufferSize(Pointer blob) {
        Pointer vtable = blob.getPointer(0);
        Pointer func = vtable.getPointer(4 * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        return (Long) f.invoke(long.class, new Object[]{ blob });
    }
}