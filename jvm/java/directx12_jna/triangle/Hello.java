// Java + JNA : DirectX 12 triangle (no SWT, pure Win32 + JNA)
// - Creates a Win32 window and renders a colored triangle via D3D12 + DXGI.
// - Uses "manual COM vtable calls" similar to the C sample.
// - Enables D3D12 debug layer (ID3D12Debug) when available.
//
// Build:
//   javac -cp jna.jar;. Hello.java
// Run:
//   java -cp jna.jar;. Hello
//
// Notes:
// - Requires Windows 10/11 + D3D12 capable GPU/driver.
// - Requires d3d12.dll, dxgi.dll, d3dcompiler_47.dll present.
// - Expects hello.hlsl in current working directory.

import com.sun.jna.*;
import com.sun.jna.ptr.*;
import com.sun.jna.win32.StdCallLibrary;
import com.sun.jna.win32.W32APIOptions;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;
import java.util.List;

public class Hello {

    // ========= Win32 constants =========
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

    // ========= HRESULT =========
    static final int S_OK = 0;
    static final int E_FAIL = 0x80004005;
    static final int DXGI_ERROR_SDK_COMPONENT_MISSING = 0x887A002D;

    static void checkHR(int hr, String what) {
        if (hr < 0) {
            throw new RuntimeException(String.format("%s failed: 0x%08X", what, hr));
        }
    }

    // ========= Calling convention =========
    static final int CC = Function.C_CONVENTION;

    // ========= Pointer helpers =========
    static int PTR_SIZE = Native.POINTER_SIZE;

    static Pointer vtbl(Pointer comObj) {
        return comObj.getPointer(0);
    }

    static Pointer vfunc(Pointer comObj, int index) {
        return vtbl(comObj).getPointer((long)index * PTR_SIZE);
    }

    static int comCallInt(Pointer comObj, int index, Object... args) {
        Pointer fp = vfunc(comObj, index);
        Function f = Function.getFunction(fp, CC);
        Object[] argv = new Object[args.length + 1];
        argv[0] = comObj;
        System.arraycopy(args, 0, argv, 1, args.length);
        return (Integer)f.invoke(int.class, argv);
    }

    static long comCallLong(Pointer comObj, int index, Object... args) {
        Pointer fp = vfunc(comObj, index);
        Function f = Function.getFunction(fp, CC);
        Object[] argv = new Object[args.length + 1];
        argv[0] = comObj;
        System.arraycopy(args, 0, argv, 1, args.length);
        return (Long)f.invoke(long.class, argv);
    }

    static void comCallVoid(Pointer comObj, int index, Object... args) {
        Pointer fp = vfunc(comObj, index);
        Function f = Function.getFunction(fp, CC);
        Object[] argv = new Object[args.length + 1];
        argv[0] = comObj;
        System.arraycopy(args, 0, argv, 1, args.length);
        f.invoke(void.class, argv);
    }

    @SuppressWarnings("unchecked")
    static <T extends Structure> T comCallStructByValue(Pointer comObj, int index, Class<T> retType, Object... args) {
        Pointer fp = vfunc(comObj, index);
        Function f = Function.getFunction(fp, CC);
        Object[] argv = new Object[args.length + 1];
        argv[0] = comObj;
        System.arraycopy(args, 0, argv, 1, args.length);
        return (T)f.invoke(retType, argv);
    }

    static long getCpuHandleStart(Pointer heap) {
        int idxCPU = VT.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart;
        D3D12_CPU_DESCRIPTOR_HANDLE handle = new D3D12_CPU_DESCRIPTOR_HANDLE();
        handle.write();
        comCallVoid(heap, idxCPU, handle.getPointer());
        handle.read();
        return handle.ptr;
    }

    // ========= Win32 Structures =========
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

    // ========= WndProc callback =========
    public interface WndProcCallback extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

    // ========= Kernel32 interface =========
    public interface Kernel32 extends StdCallLibrary {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class, W32APIOptions.DEFAULT_OPTIONS);

        Pointer GetModuleHandleW(WString lpModuleName);
        Pointer CreateEventW(Pointer lpEventAttributes, int bManualReset, int bInitialState, WString lpName);
        int CloseHandle(Pointer hObject);
        int WaitForSingleObject(Pointer hHandle, int dwMilliseconds);
    }

    // ========= User32 interface =========
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
    }

    // ========= GUID (REFIID) =========
    public static class GUID extends Structure {
        public int Data1;
        public short Data2;
        public short Data3;
        public byte[] Data4 = new byte[8];

        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Data1","Data2","Data3","Data4");
        }

        public GUID() {}
        public GUID(String s) { fromString(s); }

        public void fromString(String s) {
            String[] parts = s.split("-");
            if (parts.length != 5) throw new IllegalArgumentException("bad guid: " + s);
            Data1 = (int)Long.parseLong(parts[0], 16);
            Data2 = (short)Integer.parseInt(parts[1], 16);
            Data3 = (short)Integer.parseInt(parts[2], 16);
            String p3 = parts[3];
            String p4 = parts[4];
            Data4[0] = (byte)Integer.parseInt(p3.substring(0,2), 16);
            Data4[1] = (byte)Integer.parseInt(p3.substring(2,4), 16);
            for (int i=0;i<6;i++) {
                Data4[2+i] = (byte)Integer.parseInt(p4.substring(i*2, i*2+2), 16);
            }
            write();
        }
    }

    static Pointer REFIID(GUID g) {
        g.write();
        return g.getPointer();
    }

    // D3D12 / DXGI IIDs
    static final GUID IID_IDXGIFactory4      = new GUID("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
    static final GUID IID_IDXGISwapChain3    = new GUID("94d99bdb-f1f8-4ab0-b236-7da0170edab1");
    static final GUID IID_ID3D12Device       = new GUID("189819f1-1db6-4b57-be54-1821339b85f7");
    static final GUID IID_ID3D12CommandQueue = new GUID("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static final GUID IID_ID3D12DescriptorHeap = new GUID("8efb471d-616c-4f49-90f7-127bb763fa51");
    static final GUID IID_ID3D12Resource     = new GUID("696442be-a72e-4059-bc79-5b5c98040fad");
    static final GUID IID_ID3D12CommandAllocator = new GUID("6102dee4-af59-4b09-b999-b44d73f09b24");
    static final GUID IID_ID3D12GraphicsCommandList = new GUID("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static final GUID IID_ID3D12Fence        = new GUID("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
    static final GUID IID_ID3D12RootSignature = new GUID("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static final GUID IID_ID3D12PipelineState = new GUID("765a30f3-f624-4c6f-a828-ace948622445");
    static final GUID IID_ID3D12Debug        = new GUID("344488b7-6846-474b-b989-f027448245e0");
    static final GUID IID_ID3D12InfoQueue    = new GUID("0742a90b-c387-483f-b946-30a7e4e61458");

    // ========= D3D12 Structures =========
    public static class D3D12_COMMAND_QUEUE_DESC extends Structure {
        public int Type;
        public int Priority;
        public int Flags;
        public int NodeMask;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Type","Priority","Flags","NodeMask");
        }
    }

    public static class DXGI_RATIONAL extends Structure {
        public int Numerator;
        public int Denominator;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Numerator","Denominator");
        }
    }

    public static class DXGI_MODE_DESC extends Structure {
        public int Width;
        public int Height;
        public DXGI_RATIONAL RefreshRate = new DXGI_RATIONAL();
        public int Format;
        public int ScanlineOrdering;
        public int Scaling;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Width","Height","RefreshRate","Format","ScanlineOrdering","Scaling");
        }
    }

    public static class DXGI_SAMPLE_DESC extends Structure {
        public int Count;
        public int Quality;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Count","Quality");
        }
    }

    public static class DXGI_SWAP_CHAIN_DESC extends Structure {
        public DXGI_MODE_DESC BufferDesc = new DXGI_MODE_DESC();
        public DXGI_SAMPLE_DESC SampleDesc = new DXGI_SAMPLE_DESC();
        public int BufferUsage;
        public int BufferCount;
        public Pointer OutputWindow;
        public int Windowed;
        public int SwapEffect;
        public int Flags;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("BufferDesc","SampleDesc","BufferUsage","BufferCount","OutputWindow","Windowed","SwapEffect","Flags");
        }
    }

    public static class D3D12_DESCRIPTOR_HEAP_DESC extends Structure {
        public int Type;
        public int NumDescriptors;
        public int Flags;
        public int NodeMask;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Type","NumDescriptors","Flags","NodeMask");
        }
        public static class ByValue extends D3D12_DESCRIPTOR_HEAP_DESC implements Structure.ByValue {}
    }

    public static class D3D12_CPU_DESCRIPTOR_HANDLE extends Structure {
        public long ptr;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("ptr");
        }
        public static class ByValue extends D3D12_CPU_DESCRIPTOR_HANDLE implements Structure.ByValue {}
    }

    public static class D3D12_VIEWPORT extends Structure {
        public float TopLeftX, TopLeftY;
        public float Width, Height;
        public float MinDepth, MaxDepth;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("TopLeftX","TopLeftY","Width","Height","MinDepth","MaxDepth");
        }
    }

    public static class D3D12_RECT extends Structure {
        public int left, top, right, bottom;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("left","top","right","bottom");
        }
    }

    public static class D3D12_RANGE extends Structure {
        public long Begin;
        public long End;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Begin","End");
        }
    }

    public static class D3D12_HEAP_PROPERTIES extends Structure {
        public int Type;
        public int CPUPageProperty;
        public int MemoryPoolPreference;
        public int CreationNodeMask;
        public int VisibleNodeMask;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Type","CPUPageProperty","MemoryPoolPreference","CreationNodeMask","VisibleNodeMask");
        }
    }

    @Structure.FieldOrder({"Dimension","Alignment","Width","Height","DepthOrArraySize","MipLevels","Format","SampleDesc","Layout","Flags"})
    public static class D3D12_RESOURCE_DESC extends Structure {
        public int Dimension;
        public long Alignment;
        public long Width;
        public int Height;
        public short DepthOrArraySize;
        public short MipLevels;
        public int Format;
        public DXGI_SAMPLE_DESC SampleDesc = new DXGI_SAMPLE_DESC();
        public int Layout;
        public int Flags;
    }

    @Structure.FieldOrder({"pShaderBytecode", "BytecodeLength"})
    public static class D3D12_SHADER_BYTECODE extends Structure {
        public Pointer pShaderBytecode;
        public long BytecodeLength;
    }

    @Structure.FieldOrder({"pSODeclaration", "NumEntries", "pBufferStrides", "NumStrides", "RasterizedStream"})
    public static class D3D12_STREAM_OUTPUT_DESC extends Structure {
        public Pointer pSODeclaration;
        public int NumEntries;
        public Pointer pBufferStrides;
        public int NumStrides;
        public int RasterizedStream;
    }

    @Structure.FieldOrder({"BlendEnable", "LogicOpEnable", "SrcBlend", "DestBlend", "BlendOp", 
                           "SrcBlendAlpha", "DestBlendAlpha", "BlendOpAlpha", "LogicOp", "RenderTargetWriteMask"})
    public static class D3D12_RENDER_TARGET_BLEND_DESC extends Structure {
        public int BlendEnable;
        public int LogicOpEnable;
        public int SrcBlend;
        public int DestBlend;
        public int BlendOp;
        public int SrcBlendAlpha;
        public int DestBlendAlpha;
        public int BlendOpAlpha;
        public int LogicOp;
        public byte RenderTargetWriteMask;
    }

    @Structure.FieldOrder({"AlphaToCoverageEnable", "IndependentBlendEnable", "RenderTarget"})
    public static class D3D12_BLEND_DESC extends Structure {
        public int AlphaToCoverageEnable;
        public int IndependentBlendEnable;
        public D3D12_RENDER_TARGET_BLEND_DESC[] RenderTarget = new D3D12_RENDER_TARGET_BLEND_DESC[8];

        public D3D12_BLEND_DESC() {
            for (int i = 0; i < 8; i++) {
                RenderTarget[i] = new D3D12_RENDER_TARGET_BLEND_DESC();
            }
        }
    }

    @Structure.FieldOrder({"FillMode", "CullMode", "FrontCounterClockwise", "DepthBias", "DepthBiasClamp", 
                           "SlopeScaledDepthBias", "DepthClipEnable", "MultisampleEnable", "AntialiasedLineEnable", 
                           "ForcedSampleCount", "ConservativeRaster"})
    public static class D3D12_RASTERIZER_DESC extends Structure {
        public int FillMode;
        public int CullMode;
        public int FrontCounterClockwise;
        public int DepthBias;
        public float DepthBiasClamp;
        public float SlopeScaledDepthBias;
        public int DepthClipEnable;
        public int MultisampleEnable;
        public int AntialiasedLineEnable;
        public int ForcedSampleCount;
        public int ConservativeRaster;
    }

    @Structure.FieldOrder({"StencilFailOp", "StencilDepthFailOp", "StencilPassOp", "StencilFunc"})
    public static class D3D12_DEPTH_STENCILOP_DESC extends Structure {
        public int StencilFailOp;
        public int StencilDepthFailOp;
        public int StencilPassOp;
        public int StencilFunc;
    }

    @Structure.FieldOrder({"DepthEnable", "DepthWriteMask", "DepthFunc", "StencilEnable", 
                           "StencilReadMask", "StencilWriteMask", "FrontFace", "BackFace"})
    public static class D3D12_DEPTH_STENCIL_DESC extends Structure {
        public int DepthEnable;
        public int DepthWriteMask;
        public int DepthFunc;
        public int StencilEnable;
        public byte StencilReadMask;
        public byte StencilWriteMask;
        public D3D12_DEPTH_STENCILOP_DESC FrontFace = new D3D12_DEPTH_STENCILOP_DESC();
        public D3D12_DEPTH_STENCILOP_DESC BackFace = new D3D12_DEPTH_STENCILOP_DESC();
    }

    @Structure.FieldOrder({"pInputElementDescs", "NumElements"})
    public static class D3D12_INPUT_LAYOUT_DESC extends Structure {
        public Pointer pInputElementDescs;
        public int NumElements;
    }

    @Structure.FieldOrder({"pCachedBlob", "CachedBlobSizeInBytes"})
    public static class D3D12_CACHED_PIPELINE_STATE extends Structure {
        public Pointer pCachedBlob;
        public long CachedBlobSizeInBytes;
    }

    @Structure.FieldOrder({"pRootSignature", "VS", "PS", "DS", "HS", "GS", "StreamOutput", "BlendState", "SampleMask", "RasterizerState", "DepthStencilState", "InputLayout", "IBStripCutValue", "PrimitiveTopologyType", "NumRenderTargets", "RTVFormats", "DSVFormat", "SampleDesc", "NodeMask", "CachedPSO", "Flags"})
    public static class D3D12_GRAPHICS_PIPELINE_STATE_DESC extends Structure {
        public Pointer pRootSignature;
        public D3D12_SHADER_BYTECODE VS = new D3D12_SHADER_BYTECODE();
        public D3D12_SHADER_BYTECODE PS = new D3D12_SHADER_BYTECODE();
        public D3D12_SHADER_BYTECODE DS = new D3D12_SHADER_BYTECODE();
        public D3D12_SHADER_BYTECODE HS = new D3D12_SHADER_BYTECODE();
        public D3D12_SHADER_BYTECODE GS = new D3D12_SHADER_BYTECODE();
        public D3D12_STREAM_OUTPUT_DESC StreamOutput = new D3D12_STREAM_OUTPUT_DESC();
        public D3D12_BLEND_DESC BlendState = new D3D12_BLEND_DESC();
        public int SampleMask;
        public D3D12_RASTERIZER_DESC RasterizerState = new D3D12_RASTERIZER_DESC();
        public D3D12_DEPTH_STENCIL_DESC DepthStencilState = new D3D12_DEPTH_STENCIL_DESC();
        public D3D12_INPUT_LAYOUT_DESC InputLayout = new D3D12_INPUT_LAYOUT_DESC();
        public int IBStripCutValue;
        public int PrimitiveTopologyType;
        public int NumRenderTargets;
        public int[] RTVFormats = new int[8];
        public int DSVFormat;
        public DXGI_SAMPLE_DESC SampleDesc = new DXGI_SAMPLE_DESC();
        public int NodeMask;
        public D3D12_CACHED_PIPELINE_STATE CachedPSO = new D3D12_CACHED_PIPELINE_STATE();
        public int Flags;
    }

    public static class D3D12_RESOURCE_TRANSITION_BARRIER extends Structure {
        public Pointer pResource;
        public int Subresource;
        public int StateBefore;
        public int StateAfter;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("pResource","Subresource","StateBefore","StateAfter");
        }
    }

    public static class D3D12_RESOURCE_BARRIER extends Structure {
        public int Type;
        public int Flags;
        public D3D12_RESOURCE_TRANSITION_BARRIER Transition = new D3D12_RESOURCE_TRANSITION_BARRIER();
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Type","Flags","Transition");
        }
    }

    public static class D3D12_VERTEX_BUFFER_VIEW extends Structure {
        public long BufferLocation;
        public int SizeInBytes;
        public int StrideInBytes;
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("BufferLocation","SizeInBytes","StrideInBytes");
        }
    }

    // ========= D3DCompiler / DXGI / D3D12 exports =========
    public interface D3DCompiler extends Library {
        D3DCompiler INSTANCE = Native.load("d3dcompiler_47", D3DCompiler.class);

        int D3DCompileFromFile(
                WString pFileName,
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

    public interface DXGI extends Library {
        DXGI INSTANCE = Native.load("dxgi", DXGI.class);
        int CreateDXGIFactory1(Pointer riid, PointerByReference ppFactory);
    }

    public interface D3D12 extends Library {
        D3D12 INSTANCE = Native.load("d3d12", D3D12.class);
        int D3D12CreateDevice(Pointer pAdapter, int MinimumFeatureLevel, Pointer riid, PointerByReference ppDevice);
        int D3D12GetDebugInterface(Pointer riid, PointerByReference ppvDebug);
        int D3D12SerializeRootSignature(Pointer pRootSignature, int Version, PointerByReference ppBlob, PointerByReference ppErrorBlob);
    }

    // ========= Constants =========
    static final int WIDTH = 640;
    static final int HEIGHT = 480;
    static final int FRAMES = 2;

    static final int D3D_FEATURE_LEVEL_12_0 = 0xC000;
    static final int D3D12_COMMAND_LIST_TYPE_DIRECT = 0;
    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_UNKNOWN = 0;
    static final int DXGI_SWAP_EFFECT_FLIP_DISCARD = 0x4;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;
    static final int D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;
    static final int D3D12_HEAP_TYPE_UPLOAD = 1;
    static final int D3D12_RESOURCE_DIMENSION_BUFFER = 1;
    static final int D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1;
    static final int D3D12_RESOURCE_STATE_PRESENT = 0;
    static final int D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4;
    static final int D3D12_RESOURCE_STATE_GENERIC_READ = 0x1;
    static final int D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
    static final int D3D12_RESOURCE_BARRIER_FLAG_NONE = 0;
    static final int D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;
    static final int D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    static final int D3D_ROOT_SIGNATURE_VERSION_1 = 1;
    static final int D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1;
    static final int INFINITE = 0xFFFFFFFF;

    // ========= VTable indices =========
    static final class VT {
        static final int QI = 0;
        static final int ADDREF = 1;
        static final int RELEASE = 2;

        static final int IDXGIFactory_CreateSwapChain = 10;
        static final int IDXGISwapChain_Present = 8;
        static final int IDXGISwapChain_GetBuffer = 9;
        static final int IDXGISwapChain3_GetCurrentBackBufferIndex = 36;

        static final int ID3D12Device_CreateCommandQueue = 8;
        static final int ID3D12Device_CreateCommandAllocator = 9;
        static final int ID3D12Device_CreateGraphicsPipelineState = 10;
        static final int ID3D12Device_CreateCommandList = 12;
        static final int ID3D12Device_CreateDescriptorHeap = 14;
        static final int ID3D12Device_GetDescriptorHandleIncrementSize = 15;
        static final int ID3D12Device_CreateRootSignature = 16;
        static final int ID3D12Device_CreateRenderTargetView = 20;
        static final int ID3D12Device_CreateCommittedResource = 27;
        static final int ID3D12Device_CreateFence = 36;

        static final int ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart = 9;

        static final int ID3D12CommandAllocator_Reset = 8;

        static final int ID3D12GraphicsCommandList_Close = 9;
        static final int ID3D12GraphicsCommandList_Reset = 10;
        static final int ID3D12GraphicsCommandList_DrawInstanced = 12;
        static final int ID3D12GraphicsCommandList_IASetPrimitiveTopology = 20;
        static final int ID3D12GraphicsCommandList_RSSetViewports = 21;
        static final int ID3D12GraphicsCommandList_RSSetScissorRects = 22;
        static final int ID3D12GraphicsCommandList_ResourceBarrier = 26;
        static final int ID3D12GraphicsCommandList_SetGraphicsRootSignature = 30;
        static final int ID3D12GraphicsCommandList_IASetVertexBuffers = 44;
        static final int ID3D12GraphicsCommandList_OMSetRenderTargets = 46;
        static final int ID3D12GraphicsCommandList_ClearRenderTargetView = 48;

        static final int ID3D12CommandQueue_ExecuteCommandLists = 10;
        static final int ID3D12CommandQueue_Signal = 14;

        static final int ID3D12Fence_GetCompletedValue = 8;
        static final int ID3D12Fence_SetEventOnCompletion = 9;

        static final int ID3D12Resource_Map = 8;
        static final int ID3D12Resource_Unmap = 9;
        static final int ID3D12Resource_GetGPUVirtualAddress = 11;
    }

    static final int VT_ID3DBlob_GetBufferPointer = 3;
    static final int VT_ID3DBlob_GetBufferSize = 4;

    // ========= Globals =========
    static Pointer g_hWnd;
    static Pointer pFactory;
    static Pointer pSwapChain3;
    static Pointer pDevice;
    static Pointer pQueue;
    static Pointer pRtvHeap;
    static Pointer pCmdAlloc;
    static Pointer pCmdList;
    static Pointer pFence;
    static long fenceValue = 1;
    static Pointer fenceEvent;
    static int frameIndex = 0;

    static Pointer[] pRenderTargets = new Pointer[FRAMES];
    static int rtvDescriptorSize = 0;
    static long[] rtvHandles = new long[FRAMES];

    static Pointer pRootSig;
    static Pointer pPSO;
    static Pointer pVertexBuffer;
    static D3D12_VERTEX_BUFFER_VIEW vbView = new D3D12_VERTEX_BUFFER_VIEW();

    static Pointer pD3D12Debug;
    static Pointer pInfoQueue;

    // ========= WndProc implementation =========
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

    // ========= Main =========
    public static void main(String[] args) {
        Pointer hInstance = Kernel32.INSTANCE.GetModuleHandleW(null);

        WString className = new WString("HelloD3D12Class");

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

        // Create window
        g_hWnd = User32.INSTANCE.CreateWindowExW(
            0,
            className,
            new WString("Hello, World!"),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT,
            WIDTH, HEIGHT,
            null, null, hInstance, null
        );

        if (g_hWnd == null) {
            System.err.println("CreateWindowExW failed");
            return;
        }

        User32.INSTANCE.ShowWindow(g_hWnd, SW_SHOWDEFAULT);

        System.out.println("HWND=" + g_hWnd);

        initD3D12(g_hWnd);

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

        cleanup();
    }

    static void initD3D12(Pointer hwnd) {
        // 1) Debug layer (optional)
        {
            PointerByReference ppDbg = new PointerByReference();
            int hr = D3D12.INSTANCE.D3D12GetDebugInterface(REFIID(IID_ID3D12Debug), ppDbg);
            if (hr == S_OK) {
                pD3D12Debug = ppDbg.getValue();
                comCallVoid(pD3D12Debug, 3);
                System.out.println("D3D12 debug layer enabled");
            } else {
                System.out.println(String.format("D3D12GetDebugInterface not available: 0x%08X", hr));
            }
        }

        // 2) Factory
        {
            PointerByReference pp = new PointerByReference();
            int hr = DXGI.INSTANCE.CreateDXGIFactory1(REFIID(IID_IDXGIFactory4), pp);
            checkHR(hr, "CreateDXGIFactory1");
            pFactory = pp.getValue();
        }

        // 3) Device
        {
            PointerByReference pp = new PointerByReference();
            int hr = D3D12.INSTANCE.D3D12CreateDevice(Pointer.NULL, D3D_FEATURE_LEVEL_12_0, REFIID(IID_ID3D12Device), pp);
            checkHR(hr, "D3D12CreateDevice");
            pDevice = pp.getValue();
            System.out.println("Device: " + pDevice);

            PointerByReference ppIQ = new PointerByReference();
            hr = comCallInt(pDevice, VT.QI, REFIID(IID_ID3D12InfoQueue), ppIQ);
            if (hr == S_OK) {
                pInfoQueue = ppIQ.getValue();
                System.out.println("ID3D12InfoQueue: " + pInfoQueue);
            }
        }

        // 4) Command queue
        {
            D3D12_COMMAND_QUEUE_DESC q = new D3D12_COMMAND_QUEUE_DESC();
            q.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
            q.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandQueue, q.getPointer(), REFIID(IID_ID3D12CommandQueue), pp);
            checkHR(hr, "CreateCommandQueue");
            pQueue = pp.getValue();
            System.out.println("CommandQueue: " + pQueue);
        }

        // 5) SwapChain
        {
            DXGI_SWAP_CHAIN_DESC sc = new DXGI_SWAP_CHAIN_DESC();
            sc.BufferDesc.Width = WIDTH;
            sc.BufferDesc.Height = HEIGHT;
            sc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            sc.SampleDesc.Count = 1;
            sc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
            sc.BufferCount = FRAMES;
            sc.OutputWindow = hwnd;
            sc.Windowed = 1;
            sc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
            sc.write();

            PointerByReference ppSwap = new PointerByReference();
            int hr = comCallInt(pFactory, VT.IDXGIFactory_CreateSwapChain, pQueue, sc.getPointer(), ppSwap);
            checkHR(hr, "CreateSwapChain");
            Pointer pSwapChain = ppSwap.getValue();

            PointerByReference ppSwap3 = new PointerByReference();
            hr = comCallInt(pSwapChain, VT.QI, REFIID(IID_IDXGISwapChain3), ppSwap3);
            checkHR(hr, "SwapChain::QueryInterface(IDXGISwapChain3)");
            pSwapChain3 = ppSwap3.getValue();

            comCallInt(pSwapChain, VT.RELEASE);

            frameIndex = comCallInt(pSwapChain3, VT.IDXGISwapChain3_GetCurrentBackBufferIndex);
            System.out.println("SwapChain3: " + pSwapChain3 + " frameIndex=" + frameIndex);
        }

        // 6) RTV heap + render targets
        {
            D3D12_DESCRIPTOR_HEAP_DESC hd = new D3D12_DESCRIPTOR_HEAP_DESC();
            hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
            hd.NumDescriptors = FRAMES;
            hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
            hd.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateDescriptorHeap, hd.getPointer(), REFIID(IID_ID3D12DescriptorHeap), pp);
            checkHR(hr, "CreateDescriptorHeap(RTV)");
            pRtvHeap = pp.getValue();

            rtvDescriptorSize = comCallInt(pDevice, VT.ID3D12Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

            long rtvStart = getCpuHandleStart(pRtvHeap);
            if (rtvStart == 0) throw new RuntimeException("GetCPUDescriptorHandleForHeapStart returned 0");

            for (int i = 0; i < FRAMES; i++) {
                PointerByReference ppRT = new PointerByReference();
                hr = comCallInt(pSwapChain3, VT.IDXGISwapChain_GetBuffer, i, REFIID(IID_ID3D12Resource), ppRT);
                checkHR(hr, "SwapChain::GetBuffer");
                pRenderTargets[i] = ppRT.getValue();

                rtvHandles[i] = rtvStart + (long)i * (long)rtvDescriptorSize;

                comCallVoid(pDevice, VT.ID3D12Device_CreateRenderTargetView, pRenderTargets[i], Pointer.NULL, rtvHandles[i]);
            }
        }
        
        // 7) Command allocator + command list
        {
            PointerByReference ppA = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandAllocator,
                    D3D12_COMMAND_LIST_TYPE_DIRECT, REFIID(IID_ID3D12CommandAllocator), ppA);
            checkHR(hr, "CreateCommandAllocator");
            pCmdAlloc = ppA.getValue();

            PointerByReference ppCL = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandList,
                    0, D3D12_COMMAND_LIST_TYPE_DIRECT, pCmdAlloc, Pointer.NULL, REFIID(IID_ID3D12GraphicsCommandList), ppCL);
            checkHR(hr, "CreateCommandList");
            pCmdList = ppCL.getValue();

            comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close);
        }

        // 8) Root signature + PSO
        createPipelineState();

        // 9) Vertex buffer
        createVertexBuffer();

        // 10) Fence
        {
            PointerByReference ppF = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateFence, 0L, 0, REFIID(IID_ID3D12Fence), ppF);
            checkHR(hr, "CreateFence");
            pFence = ppF.getValue();
            fenceValue = 1;
            fenceEvent = Kernel32.INSTANCE.CreateEventW(Pointer.NULL, 0, 0, null);
            if (fenceEvent == null || Pointer.nativeValue(fenceEvent) == 0) {
                throw new RuntimeException("CreateEventW failed");
            }
        }

        System.out.println("D3D12 initialized OK");
    }

    static void createPipelineState() {
        // Root signature
        Memory rsDesc = new Memory(40);
        rsDesc.clear();
        long o = 0;
        rsDesc.setInt((int)o, 0); o += 4;
        o = (o + 7) & ~7;
        rsDesc.setPointer((int)o, Pointer.NULL); o += PTR_SIZE;
        rsDesc.setInt((int)o, 0); o += 4;
        o = (o + 7) & ~7;
        rsDesc.setPointer((int)o, Pointer.NULL); o += PTR_SIZE;
        rsDesc.setInt((int)o, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT);

        PointerByReference ppSig = new PointerByReference();
        PointerByReference ppErr = new PointerByReference();
        int hr = D3D12.INSTANCE.D3D12SerializeRootSignature(rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, ppSig, ppErr);
        checkHR(hr, "D3D12SerializeRootSignature");
        Pointer blobSig = ppSig.getValue();

        long sigPtr = comCallLong(blobSig, VT_ID3DBlob_GetBufferPointer);
        long sigSize = comCallLong(blobSig, VT_ID3DBlob_GetBufferSize);

        PointerByReference ppRS = new PointerByReference();
        hr = comCallInt(pDevice, VT.ID3D12Device_CreateRootSignature,
                0, new Pointer(sigPtr), new NativeLong(sigSize), REFIID(IID_ID3D12RootSignature), ppRS);
        checkHR(hr, "CreateRootSignature");
        pRootSig = ppRS.getValue();

        // Compile shaders
        PointerByReference ppVS = new PointerByReference();
        PointerByReference ppPS = new PointerByReference();
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "VSMain", "vs_5_0", 0, 0, ppVS, new PointerByReference());
        checkHR(hr, "D3DCompileFromFile(VS)");
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "PSMain", "ps_5_0", 0, 0, ppPS, new PointerByReference());
        checkHR(hr, "D3DCompileFromFile(PS)");
        Pointer blobVS = ppVS.getValue();
        Pointer blobPS = ppPS.getValue();

        long vsPtr = comCallLong(blobVS, VT_ID3DBlob_GetBufferPointer);
        long vsSize = comCallLong(blobVS, VT_ID3DBlob_GetBufferSize);
        long psPtr = comCallLong(blobPS, VT_ID3DBlob_GetBufferPointer);
        long psSize = comCallLong(blobPS, VT_ID3DBlob_GetBufferSize);

        // Build PSO descriptor
        D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC();
        psoDesc.pRootSignature = pRootSig;

        psoDesc.VS.pShaderBytecode = new Pointer(vsPtr);
        psoDesc.VS.BytecodeLength = vsSize;
        psoDesc.PS.pShaderBytecode = new Pointer(psPtr);
        psoDesc.PS.BytecodeLength = psSize;

        psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = (byte)0x0F;
        psoDesc.SampleMask = 0xFFFFFFFF;

        psoDesc.RasterizerState.FillMode = 3;
        psoDesc.RasterizerState.CullMode = 3;
        psoDesc.RasterizerState.DepthClipEnable = 1;

        psoDesc.InputLayout.pInputElementDescs = Pointer.NULL;
        psoDesc.InputLayout.NumElements = 0;

        psoDesc.PrimitiveTopologyType = 3;
        psoDesc.NumRenderTargets = 1;
        psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        psoDesc.SampleDesc.Count = 1;

        psoDesc.write();

        PointerByReference ppPSO = new PointerByReference();
        hr = comCallInt(pDevice, VT.ID3D12Device_CreateGraphicsPipelineState, psoDesc.getPointer(), REFIID(IID_ID3D12PipelineState), ppPSO);
        checkHR(hr, "CreateGraphicsPipelineState");
        pPSO = ppPSO.getValue();

        comCallInt(blobSig, VT.RELEASE);
        comCallInt(blobVS, VT.RELEASE);
        comCallInt(blobPS, VT.RELEASE);
    }

    static void createVertexBuffer() {
        float[] verts = new float[] {
                0.0f,  0.5f, 0.0f,   1f,0f,0f,1f,
                0.5f, -0.5f, 0.0f,   0f,1f,0f,1f,
               -0.5f, -0.5f, 0.0f,   0f,0f,1f,1f
        };
        int strideBytes = (3+4)*4;
        int sizeBytes = verts.length * 4;

        D3D12_HEAP_PROPERTIES hp = new D3D12_HEAP_PROPERTIES();
        hp.Type = D3D12_HEAP_TYPE_UPLOAD;
        hp.CreationNodeMask = 1;
        hp.VisibleNodeMask = 1;
        hp.write();

        D3D12_RESOURCE_DESC rd = new D3D12_RESOURCE_DESC();
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Width = sizeBytes;
        rd.Height = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels = 1;
        rd.Format = DXGI_FORMAT_UNKNOWN;
        rd.SampleDesc.Count = 1;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        rd.write();

        PointerByReference pp = new PointerByReference();
        int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                hp.getPointer(), 0, rd.getPointer(),
                D3D12_RESOURCE_STATE_GENERIC_READ, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
        checkHR(hr, "CreateCommittedResource(VertexBuffer)");
        pVertexBuffer = pp.getValue();

        Memory vertexData = new Memory(sizeBytes);
        ByteBuffer bb = vertexData.getByteBuffer(0, sizeBytes).order(ByteOrder.LITTLE_ENDIAN);
        for (float v : verts) bb.putFloat(v);

        D3D12_RANGE readRange = new D3D12_RANGE();
        readRange.Begin = 0;
        readRange.End = 0;
        readRange.write();

        PointerByReference ppMapData = new PointerByReference();
        hr = comCallInt(pVertexBuffer, VT.ID3D12Resource_Map, 0, readRange.getPointer(), ppMapData);

        if (hr == S_OK) {
            Pointer mapPtr = ppMapData.getValue();
            ByteBuffer dstBuffer = mapPtr.getByteBuffer(0, sizeBytes).order(ByteOrder.LITTLE_ENDIAN);
            bb.rewind();
            for (float v : verts) dstBuffer.putFloat(v);

            D3D12_RANGE writeRange = new D3D12_RANGE();
            writeRange.Begin = 0;
            writeRange.End = sizeBytes;
            writeRange.write();
            comCallVoid(pVertexBuffer, VT.ID3D12Resource_Unmap, 0, writeRange.getPointer());
        }

        long gpuVA = comCallLong(pVertexBuffer, VT.ID3D12Resource_GetGPUVirtualAddress);

        vbView.BufferLocation = gpuVA;
        vbView.SizeInBytes = sizeBytes;
        vbView.StrideInBytes = strideBytes;
        vbView.write();
    }

    static void render() {
        checkHR(comCallInt(pCmdAlloc, VT.ID3D12CommandAllocator_Reset), "CommandAllocator::Reset");
        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Reset, pCmdAlloc, pPSO), "CommandList::Reset");

        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootSignature, pRootSig);

        D3D12_VIEWPORT vp = new D3D12_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;
        vp.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetViewports, 1, vp.getPointer());

        D3D12_RECT sc = new D3D12_RECT();
        sc.left = 0; sc.top = 0; sc.right = WIDTH; sc.bottom = HEIGHT;
        sc.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetScissorRects, 1, sc.getPointer());

        D3D12_RESOURCE_BARRIER b1 = new D3D12_RESOURCE_BARRIER();
        b1.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b1.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        b1.Transition.pResource = pRenderTargets[frameIndex];
        b1.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b1.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        b1.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        b1.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, b1.getPointer());

        long rtv = rtvHandles[frameIndex];

        float[] clear = new float[] { 1f, 1f, 1f, 1f };
        Memory clearMem = new Memory(4 * 4);
        clearMem.write(0, clear, 0, 4);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ClearRenderTargetView, rtv, clearMem, 0, Pointer.NULL);

        Memory rtvArray = new Memory(8);
        rtvArray.setLong(0, rtv);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_OMSetRenderTargets, 1, rtvArray, 1, Pointer.NULL);

        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_DrawInstanced, 3, 1, 0, 0);

        D3D12_RESOURCE_BARRIER b2 = new D3D12_RESOURCE_BARRIER();
        b2.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b2.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        b2.Transition.pResource = pRenderTargets[frameIndex];
        b2.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b2.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        b2.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        b2.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, b2.getPointer());

        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close), "CommandList::Close");

        Memory ppLists = new Memory(PTR_SIZE);
        ppLists.setPointer(0, pCmdList);
        comCallVoid(pQueue, VT.ID3D12CommandQueue_ExecuteCommandLists, 1, ppLists);

        comCallInt(pSwapChain3, VT.IDXGISwapChain_Present, 0, 0);

        waitForPreviousFrame();
    }

    static void waitForPreviousFrame() {
        long fence = fenceValue;
        checkHR(comCallInt(pQueue, VT.ID3D12CommandQueue_Signal, pFence, fence), "CommandQueue::Signal");
        fenceValue++;

        long completed = comCallLong(pFence, VT.ID3D12Fence_GetCompletedValue);
        if (Long.compareUnsigned(completed, fence) < 0) {
            checkHR(comCallInt(pFence, VT.ID3D12Fence_SetEventOnCompletion, fence, fenceEvent), "Fence::SetEventOnCompletion");
            Kernel32.INSTANCE.WaitForSingleObject(fenceEvent, INFINITE);
        }

        frameIndex = comCallInt(pSwapChain3, VT.IDXGISwapChain3_GetCurrentBackBufferIndex);
    }

    static void cleanup() {
        try { waitForPreviousFrame(); } catch (Throwable t) {}

        if (fenceEvent != null && Pointer.nativeValue(fenceEvent) != 0) {
            Kernel32.INSTANCE.CloseHandle(fenceEvent);
            fenceEvent = null;
        }

        safeRelease(pVertexBuffer);
        for (int i=0;i<FRAMES;i++) safeRelease(pRenderTargets[i]);
        safeRelease(pCmdList);
        safeRelease(pCmdAlloc);
        safeRelease(pRtvHeap);
        safeRelease(pPSO);
        safeRelease(pRootSig);
        safeRelease(pFence);
        safeRelease(pQueue);
        safeRelease(pSwapChain3);
        safeRelease(pFactory);
        safeRelease(pInfoQueue);
        safeRelease(pD3D12Debug);
        safeRelease(pDevice);
    }

    static void safeRelease(Pointer p) {
        if (p != null && Pointer.nativeValue(p) != 0) {
            try { comCallInt(p, VT.RELEASE); } catch (Throwable t) {}
        }
    }
}
