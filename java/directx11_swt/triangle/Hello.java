import org.eclipse.swt.internal.Callback;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.internal.win32.WNDCLASS;
import org.eclipse.swt.internal.win32.MSG;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Structure;
import com.sun.jna.Memory;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;

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

    // D3D11 constants
    static final int D3D_DRIVER_TYPE_HARDWARE = 1;
    static final int D3D_DRIVER_TYPE_WARP = 2;
    static final int D3D_DRIVER_TYPE_REFERENCE = 3;
    static final int D3D_FEATURE_LEVEL_11_0 = 0xb000;
    static final int D3D11_SDK_VERSION = 7;
    static final int D3D11_CREATE_DEVICE_DEBUG = 0x2;
    static final int D3D11_RLDO_DETAIL = 0x2; // D3D11_RLDO_DETAIL
    static final int DXGI_ERROR_SDK_COMPONENT_MISSING = 0x887A002D;
    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_R32G32B32_FLOAT = 6;
    static final int DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    static final int D3D11_BIND_VERTEX_BUFFER = 0x1;
    static final int D3D11_USAGE_DEFAULT = 0;
    static final int D3D11_INPUT_PER_VERTEX_DATA = 0;
    static final int D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    static final int D3DCOMPILE_ENABLE_STRICTNESS = 0x800;

    static final int WIDTH = 640;
    static final int HEIGHT = 480;

    static Callback wndProcCallback;
    static long g_hWnd;

    // D3D11 objects (stored as Pointer)
    static Pointer g_pd3dDevice;
    static Pointer g_pImmediateContext;
    static Pointer g_pSwapChain;
    static Pointer g_pRenderTargetView;
    static Pointer g_pVertexShader;
    static Pointer g_pPixelShader;
    static Pointer g_pVertexLayout;
    static Pointer g_pVertexBuffer;

    // Optional debug interfaces (available when debug layer is enabled)
    static Pointer g_pD3D11Debug;
    static Pointer g_pInfoQueue;

    // D3D11.dll interface
    public interface D3D11 extends StdCallLibrary {
        D3D11 INSTANCE = Native.load("d3d11", D3D11.class);

        int D3D11CreateDeviceAndSwapChain(
            Pointer pAdapter,
            int DriverType,
            Pointer Software,
            int Flags,
            int[] pFeatureLevels,
            int FeatureLevels,
            int SDKVersion,
            DXGI_SWAP_CHAIN_DESC pSwapChainDesc,
            PointerByReference ppSwapChain,
            PointerByReference ppDevice,
            int[] pFeatureLevel,
            PointerByReference ppImmediateContext
        );
    }

    // D3DCompiler.dll interface
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

    // User32.dll interface
    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class);

        boolean AdjustWindowRect(RECT_JNA lpRect, int dwStyle, boolean bMenu);
    }

    // RECT structure for JNA
    public static class RECT_JNA extends Structure {
        public int left;
        public int top;
        public int right;
        public int bottom;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("left", "top", "right", "bottom");
        }
    }

    // DXGI_SWAP_CHAIN_DESC structure
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
        public long OutputWindow;
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

    // D3D11_BUFFER_DESC structure
    public static class D3D11_BUFFER_DESC extends Structure {
        public int ByteWidth;
        public int Usage;
        public int BindFlags;
        public int CPUAccessFlags;
        public int MiscFlags;
        public int StructureByteStride;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("ByteWidth", "Usage", "BindFlags", "CPUAccessFlags", "MiscFlags", "StructureByteStride");
        }
    }

    // D3D11_SUBRESOURCE_DATA structure
    public static class D3D11_SUBRESOURCE_DATA extends Structure {
        public Pointer pSysMem;
        public int SysMemPitch;
        public int SysMemSlicePitch;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("pSysMem", "SysMemPitch", "SysMemSlicePitch");
        }
    }

    // D3D11_INPUT_ELEMENT_DESC structure
    public static class D3D11_INPUT_ELEMENT_DESC extends Structure {
        public String SemanticName;
        public int SemanticIndex;
        public int Format;
        public int InputSlot;
        public int AlignedByteOffset;
        public int InputSlotClass;
        public int InstanceDataStepRate;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("SemanticName", "SemanticIndex", "Format", "InputSlot", 
                                 "AlignedByteOffset", "InputSlotClass", "InstanceDataStepRate");
        }
    }

    // D3D11_VIEWPORT structure
    public static class D3D11_VIEWPORT extends Structure {
        public float TopLeftX;
        public float TopLeftY;
        public float Width;
        public float Height;
        public float MinDepth;
        public float MaxDepth;

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("TopLeftX", "TopLeftY", "Width", "Height", "MinDepth", "MaxDepth");
        }
    }

    // IID definitions
    // {6f15aacf-d208-4e89-9ab4-489535d34f9c}
    static final byte[] IID_ID3D11Texture2D = new byte[] {
        // IID_ID3D11Texture2D = {6f15aaf2-d208-4e89-9ab4-489535d34f9c}
        (byte)0xf2, (byte)0xaa, (byte)0x15, (byte)0x6f,  // Data1 (little-endian)
        (byte)0x08, (byte)0xd2,                          // Data2 (little-endian)
        (byte)0x89, (byte)0x4e,                          // Data3 (little-endian)
        (byte)0x9a, (byte)0xb4,                          // Data4[0-1]
        (byte)0x48, (byte)0x95, (byte)0x35, (byte)0xd3, (byte)0x4f, (byte)0x9c // Data4[2-7]
    };

    // IID_ID3D11Debug = {79cf2233-7536-4948-9d36-1e4692dc5760}
    static final byte[] IID_ID3D11Debug = new byte[] {
        (byte)0x33, (byte)0x22, (byte)0xcf, (byte)0x79,
        (byte)0x36, (byte)0x75,
        (byte)0x48, (byte)0x49,
        (byte)0x9d, (byte)0x36,
        (byte)0x1e, (byte)0x46, (byte)0x92, (byte)0xdc, (byte)0x57, (byte)0x60
    };

    // IID_ID3D11InfoQueue = {6543dbb6-1b48-42f5-ab82-e97ec74326f6}
    static final byte[] IID_ID3D11InfoQueue = new byte[] {
        (byte)0xb6, (byte)0xdb, (byte)0x43, (byte)0x65,
        (byte)0x48, (byte)0x1b,
        (byte)0xf5, (byte)0x42,
        (byte)0xab, (byte)0x82,
        (byte)0xe9, (byte)0x7e, (byte)0xc7, (byte)0x43, (byte)0x26, (byte)0xf6
    };

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

        // Adjust window rect
        RECT_JNA rc = new RECT_JNA();
        rc.left = 0;
        rc.top = 0;
        rc.right = WIDTH;
        rc.bottom = HEIGHT;
        User32.INSTANCE.AdjustWindowRect(rc, WS_OVERLAPPEDWINDOW, false);

        // Create window
        char[] windowName = "Hello, World!\0".toCharArray();
        g_hWnd = OS.CreateWindowEx(
            0,
            className,
            windowName,
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            0, 0, hInstance, null
        );

        OS.ShowWindow(g_hWnd, SW_SHOWDEFAULT);

        // Initialize D3D11
        if (!initDevice()) {
            System.err.println("Failed to initialize D3D11");
            cleanupDevice();
            return;
        }

        System.out.println("D3D11 initialized successfully!");

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
        cleanupDevice();
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
        sd.OutputWindow = g_hWnd;
        sd.Windowed = 1;

        PointerByReference ppSwapChain = new PointerByReference();
        PointerByReference ppDevice = new PointerByReference();
        PointerByReference ppContext = new PointerByReference();
        int[] featureLevel = new int[1];
        int[] featureLevels = { D3D_FEATURE_LEVEL_11_0 };

        int[] driverTypes = { D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE };

        // Prefer enabling the debug layer (if installed). Fallback to retail if missing.
        int createFlagsPreferred = D3D11_CREATE_DEVICE_DEBUG;
        boolean debugLayerEnabled = false;

        int hr = -1;
        for (int driverType : driverTypes) {
            // First try with debug layer enabled
            hr = D3D11.INSTANCE.D3D11CreateDeviceAndSwapChain(
                null, driverType, null, createFlagsPreferred,
                featureLevels, 1, D3D11_SDK_VERSION,
                sd, ppSwapChain, ppDevice, featureLevel, ppContext
            );

            // If the debug layer is not installed, retry without it.
            if (hr == DXGI_ERROR_SDK_COMPONENT_MISSING) {
                hr = D3D11.INSTANCE.D3D11CreateDeviceAndSwapChain(
                    null, driverType, null, 0,
                    featureLevels, 1, D3D11_SDK_VERSION,
                    sd, ppSwapChain, ppDevice, featureLevel, ppContext
                );
            } else if (hr >= 0) {
                debugLayerEnabled = true;
            }

            if (hr >= 0) {
                System.out.println("D3D11 device created with driver type: " + driverType + " (debug=" + debugLayerEnabled + ")");
                break;
            }
        }

        if (hr < 0) {
            System.err.println("D3D11CreateDeviceAndSwapChain failed: 0x" + Integer.toHexString(hr));
            return false;
        }

        g_pSwapChain = ppSwapChain.getValue();
        g_pd3dDevice = ppDevice.getValue();
        g_pImmediateContext = ppContext.getValue();

        System.out.println("SwapChain: " + g_pSwapChain);
        System.out.println("Device: " + g_pd3dDevice);
        System.out.println("Context: " + g_pImmediateContext);

        // Enable D3D11 debug interfaces (ID3D11Debug / ID3D11InfoQueue) when available
        initDebugInterfaces();

        // Get back buffer
        PointerByReference ppBackBuffer = new PointerByReference();
        Memory iidTexture2D = new Memory(16);
        iidTexture2D.write(0, IID_ID3D11Texture2D, 0, 16);

        // IDXGISwapChain::GetBuffer (vtable index 9)
        hr = callCOM(g_pSwapChain, 9, 0, iidTexture2D, ppBackBuffer);
        if (hr < 0) {
            System.err.println("GetBuffer failed: 0x" + Integer.toHexString(hr));
            return false;
        }
        Pointer pBackBuffer = ppBackBuffer.getValue();
        System.out.println("BackBuffer: " + pBackBuffer);

        // Create render target view
        // ID3D11Device::CreateRenderTargetView (vtable index 9)
        PointerByReference ppRTV = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 9, pBackBuffer, null, ppRTV);
        if (hr < 0) {
            System.err.println("CreateRenderTargetView failed: 0x" + Integer.toHexString(hr));
            return false;
        }
        g_pRenderTargetView = ppRTV.getValue();
        System.out.println("RenderTargetView: " + g_pRenderTargetView);

        // Release back buffer
        callCOMRelease(pBackBuffer);

        // Set render target
        // ID3D11DeviceContext::OMSetRenderTargets (vtable index 33)
        Memory ppRTVArray = new Memory(Native.POINTER_SIZE);
        ppRTVArray.setPointer(0, g_pRenderTargetView);
        callCOMVoid(g_pImmediateContext, 33, 1, ppRTVArray, null);

        // Set viewport
        D3D11_VIEWPORT vp = new D3D11_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;

        // ID3D11DeviceContext::RSSetViewports (vtable index 44)
        vp.write();
        // ID3D11DeviceContext::RSSetViewports (vtable index 44)
        callCOMVoid(g_pImmediateContext, 44, 1, vp.getPointer());

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

        // Compile vertex shader
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

        // ID3D11Device::CreateVertexShader (vtable index 12)
        PointerByReference ppVS = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 12, vsCode, vsSize, null, ppVS);
        if (hr < 0) {
            System.err.println("CreateVertexShader failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pVSBlob);
            return false;
        }
        g_pVertexShader = ppVS.getValue();
        System.out.println("VertexShader: " + g_pVertexShader);

        // Create input layout
        // D3D11_INPUT_ELEMENT_DESC array (need to create in native memory)
        int elemSize = 32; // size of D3D11_INPUT_ELEMENT_DESC on 64-bit
        Memory layoutDesc = new Memory(elemSize * 2);
        
        // Element 0: POSITION
        Memory posName = new Memory(16);
        posName.setString(0, "POSITION");
        layoutDesc.setPointer(0, posName);           // SemanticName
        layoutDesc.setInt(8, 0);                      // SemanticIndex
        layoutDesc.setInt(12, DXGI_FORMAT_R32G32B32_FLOAT); // Format
        layoutDesc.setInt(16, 0);                     // InputSlot
        layoutDesc.setInt(20, 0);                     // AlignedByteOffset
        layoutDesc.setInt(24, D3D11_INPUT_PER_VERTEX_DATA); // InputSlotClass
        layoutDesc.setInt(28, 0);                     // InstanceDataStepRate

        // Element 1: COLOR
        Memory colorName = new Memory(16);
        colorName.setString(0, "COLOR");
        layoutDesc.setPointer(elemSize, colorName);   // SemanticName
        layoutDesc.setInt(elemSize + 8, 0);           // SemanticIndex
        layoutDesc.setInt(elemSize + 12, DXGI_FORMAT_R32G32B32A32_FLOAT); // Format
        layoutDesc.setInt(elemSize + 16, 0);          // InputSlot
        layoutDesc.setInt(elemSize + 20, 12);         // AlignedByteOffset (3 floats = 12 bytes)
        layoutDesc.setInt(elemSize + 24, D3D11_INPUT_PER_VERTEX_DATA);
        layoutDesc.setInt(elemSize + 28, 0);

        // ID3D11Device::CreateInputLayout (vtable index 11)
        PointerByReference ppLayout = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 11, layoutDesc, 2, vsCode, vsSize, ppLayout);
        if (hr < 0) {
            System.err.println("CreateInputLayout failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pVSBlob);
            return false;
        }
        g_pVertexLayout = ppLayout.getValue();
        System.out.println("InputLayout: " + g_pVertexLayout);

        callCOMRelease(pVSBlob);

        // Compile pixel shader
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

        // ID3D11Device::CreatePixelShader (vtable index 15)
        PointerByReference ppPS = new PointerByReference();
        hr = callCOM(g_pd3dDevice, 15, psCode, psSize, null, ppPS);
        if (hr < 0) {
            System.err.println("CreatePixelShader failed: 0x" + Integer.toHexString(hr));
            callCOMRelease(pPSBlob);
            return false;
        }
        g_pPixelShader = ppPS.getValue();
        System.out.println("PixelShader: " + g_pPixelShader);

        callCOMRelease(pPSBlob);

        // Set input layout
        // ID3D11DeviceContext::IASetInputLayout (vtable index 17)
        callCOMVoid(g_pImmediateContext, 17, g_pVertexLayout);

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

        // D3D11_BUFFER_DESC
        Memory bufferDesc = new Memory(24);
        bufferDesc.setInt(0, vertices.length * 4);  // ByteWidth
        bufferDesc.setInt(4, D3D11_USAGE_DEFAULT);  // Usage
        bufferDesc.setInt(8, D3D11_BIND_VERTEX_BUFFER); // BindFlags
        bufferDesc.setInt(12, 0); // CPUAccessFlags
        bufferDesc.setInt(16, 0); // MiscFlags
        bufferDesc.setInt(20, 0); // StructureByteStride

        // D3D11_SUBRESOURCE_DATA
        Memory initData = new Memory(Native.POINTER_SIZE + 8);
        initData.setPointer(0, vertexData);
        initData.setInt(Native.POINTER_SIZE, 0);
        initData.setInt(Native.POINTER_SIZE + 4, 0);

        // ID3D11Device::CreateBuffer (vtable index 3)
        PointerByReference ppBuffer = new PointerByReference();
        int hr = callCOM(g_pd3dDevice, 3, bufferDesc, initData, ppBuffer);
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

        // ID3D11DeviceContext::IASetVertexBuffers (vtable index 18)
        callCOMVoid(g_pImmediateContext, 18, 0, 1, ppBuffers, strides, offsets);

        // Set primitive topology
        // ID3D11DeviceContext::IASetPrimitiveTopology (vtable index 24)
        callCOMVoid(g_pImmediateContext, 24, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        return true;
    }

    

    static void initDebugInterfaces() {
        g_pD3D11Debug = null;
        g_pInfoQueue = null;

        if (g_pd3dDevice == null) return;

        // Query ID3D11Debug
        PointerByReference ppDbg = new PointerByReference();
        Memory iidDbg = new Memory(16);
        iidDbg.write(0, IID_ID3D11Debug, 0, 16);

        int hr = callCOM(g_pd3dDevice, 0, iidDbg, ppDbg); // IUnknown::QueryInterface
        if (hr >= 0) {
            g_pD3D11Debug = ppDbg.getValue();
            System.out.println("ID3D11Debug: " + g_pD3D11Debug);
        } else {
            System.out.println("ID3D11Debug not available (hr=0x" + Integer.toHexString(hr) + ")");
        }

        // Query ID3D11InfoQueue (optional)
        PointerByReference ppIQ = new PointerByReference();
        Memory iidIQ = new Memory(16);
        iidIQ.write(0, IID_ID3D11InfoQueue, 0, 16);

        hr = callCOM(g_pd3dDevice, 0, iidIQ, ppIQ);
        if (hr >= 0) {
            g_pInfoQueue = ppIQ.getValue();
            System.out.println("ID3D11InfoQueue: " + g_pInfoQueue);
        } else {
            System.out.println("ID3D11InfoQueue not available (hr=0x" + Integer.toHexString(hr) + ")");
        }
    }

static void render() {
        // Clear render target (white background)
        Memory clearColor = new Memory(16);
        clearColor.setFloat(0, 1.0f);  // R
        clearColor.setFloat(4, 1.0f);  // G
        clearColor.setFloat(8, 1.0f);  // B
        clearColor.setFloat(12, 1.0f); // A

        // ID3D11DeviceContext::ClearRenderTargetView (vtable index 50)
        callCOMVoid(g_pImmediateContext, 50, g_pRenderTargetView, clearColor);

        // Ensure pipeline state is set every frame (robust against any state loss)
        // OMSetRenderTargets
        Memory ppRTVArray = new Memory(Native.POINTER_SIZE);
        ppRTVArray.setPointer(0, g_pRenderTargetView);
        callCOMVoid(g_pImmediateContext, 33, 1, ppRTVArray, null);

        // Viewport
        D3D11_VIEWPORT vp = new D3D11_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;
        vp.write();
        callCOMVoid(g_pImmediateContext, 44, 1, vp.getPointer());

        // Input layout
        callCOMVoid(g_pImmediateContext, 17, g_pVertexLayout);

        // Vertex buffer
        int stride = 7 * 4;
        int offset = 0;
        Memory ppBuffers = new Memory(Native.POINTER_SIZE);
        ppBuffers.setPointer(0, g_pVertexBuffer);
        Memory strides = new Memory(4);
        strides.setInt(0, stride);
        Memory offsets = new Memory(4);
        offsets.setInt(0, offset);
        callCOMVoid(g_pImmediateContext, 18, 0, 1, ppBuffers, strides, offsets);

        // Topology
        callCOMVoid(g_pImmediateContext, 24, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Set shaders
        // ID3D11DeviceContext::VSSetShader (vtable index 11)
        callCOMVoid(g_pImmediateContext, 11, g_pVertexShader, null, 0);

        // ID3D11DeviceContext::PSSetShader (vtable index 9)
        callCOMVoid(g_pImmediateContext, 9, g_pPixelShader, null, 0);

        // Draw
        // ID3D11DeviceContext::Draw (vtable index 13)
        callCOMVoid(g_pImmediateContext, 13, 3, 0);

        // Present
        // IDXGISwapChain::Present (vtable index 8)
        callCOM(g_pSwapChain, 8, 0, 0);
    }

    static void cleanupDevice() {
        if (g_pImmediateContext != null) {
            // ID3D11DeviceContext::ClearState (vtable index 110)
            callCOMVoid(g_pImmediateContext, 110);
        }

        if (g_pVertexBuffer != null) { callCOMRelease(g_pVertexBuffer); g_pVertexBuffer = null; }
        if (g_pVertexLayout != null) { callCOMRelease(g_pVertexLayout); g_pVertexLayout = null; }
        if (g_pVertexShader != null) { callCOMRelease(g_pVertexShader); g_pVertexShader = null; }
        if (g_pPixelShader != null) { callCOMRelease(g_pPixelShader); g_pPixelShader = null; }
        if (g_pRenderTargetView != null) { callCOMRelease(g_pRenderTargetView); g_pRenderTargetView = null; }
        if (g_pSwapChain != null) { callCOMRelease(g_pSwapChain); g_pSwapChain = null; }
        if (g_pImmediateContext != null) { callCOMRelease(g_pImmediateContext); g_pImmediateContext = null; }

        // Emit a live-object report before releasing the device.
        if (g_pD3D11Debug != null) {
            // ID3D11Debug::ReportLiveDeviceObjects (vtable index 10)
            callCOMVoid(g_pD3D11Debug, 10, D3D11_RLDO_DETAIL);
        }

        if (g_pd3dDevice != null) { callCOMRelease(g_pd3dDevice); g_pd3dDevice = null; }
        if (g_pInfoQueue != null) { callCOMRelease(g_pInfoQueue); g_pInfoQueue = null; }
        if (g_pD3D11Debug != null) { callCOMRelease(g_pD3D11Debug); g_pD3D11Debug = null; }
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

    static Pointer callCOMGetBufferPointer(Pointer blob) {
        // ID3DBlob::GetBufferPointer is vtable index 3
        Pointer vtable = blob.getPointer(0);
        Pointer func = vtable.getPointer(3 * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        return (Pointer) f.invoke(Pointer.class, new Object[]{ blob });
    }

    static long callCOMGetBufferSize(Pointer blob) {
        // ID3DBlob::GetBufferSize is vtable index 4
        Pointer vtable = blob.getPointer(0);
        Pointer func = vtable.getPointer(4 * Native.POINTER_SIZE);
        com.sun.jna.Function f = com.sun.jna.Function.getFunction(func, com.sun.jna.Function.ALT_CONVENTION);
        return (Long) f.invoke(long.class, new Object[]{ blob });
    }
}
