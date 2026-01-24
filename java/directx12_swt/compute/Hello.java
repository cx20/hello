// Java + SWT + JNA : DirectX 12 Compute Shader Harmonograph
// - Uses compute shader to calculate harmonograph points
// - Renders points using graphics pipeline
// - Requires hello.hlsl in current working directory
//
// Build:
//   javac -cp <swt_jar>;<jna_jar>;. Hello.java
// Run:
//   java  -cp <swt_jar>;<jna_jar>;. Hello
//
import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

import com.sun.jna.*;
import com.sun.jna.ptr.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Random;

public class Hello {

    // ========= Win32 / HRESULT =========
    static final int S_OK = 0;

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

    // ========= GUID (REFIID) =========
    public static class GUID extends Structure {
        public int Data1;
        public short Data2;
        public short Data3;
        public byte[] Data4 = new byte[8];

        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Data1","Data2","Data3","Data4");
        }

        public GUID() {}
        public GUID(String s) { fromString(s); }

        public void fromString(String s) {
            String[] parts = s.split("-");
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

    // ========= JNA Structures =========
    public static class DXGI_SAMPLE_DESC extends Structure {
        public int Count;
        public int Quality;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Count","Quality");
        }
    }

    public static class DXGI_MODE_DESC extends Structure {
        public int Width, Height;
        public int RefreshRateNumerator, RefreshRateDenominator;
        public int Format, ScanlineOrdering, Scaling;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Width","Height","RefreshRateNumerator","RefreshRateDenominator","Format","ScanlineOrdering","Scaling");
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
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("BufferDesc","SampleDesc","BufferUsage","BufferCount","OutputWindow","Windowed","SwapEffect","Flags");
        }
    }

    public static class D3D12_COMMAND_QUEUE_DESC extends Structure {
        public int Type;
        public int Priority;
        public int Flags;
        public int NodeMask;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","Priority","Flags","NodeMask");
        }
    }

    public static class D3D12_DESCRIPTOR_HEAP_DESC extends Structure {
        public int Type;
        public int NumDescriptors;
        public int Flags;
        public int NodeMask;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","NumDescriptors","Flags","NodeMask");
        }
    }

    public static class D3D12_HEAP_PROPERTIES extends Structure {
        public int Type;
        public int CPUPageProperty;
        public int MemoryPoolPreference;
        public int CreationNodeMask;
        public int VisibleNodeMask;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","CPUPageProperty","MemoryPoolPreference","CreationNodeMask","VisibleNodeMask");
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

    public static class D3D12_RANGE extends Structure {
        public long Begin;
        public long End;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Begin","End");
        }
    }

    public static class D3D12_VIEWPORT extends Structure {
        public float TopLeftX, TopLeftY;
        public float Width, Height;
        public float MinDepth, MaxDepth;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("TopLeftX","TopLeftY","Width","Height","MinDepth","MaxDepth");
        }
    }

    public static class D3D12_RECT extends Structure {
        public int left, top, right, bottom;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("left","top","right","bottom");
        }
    }

    public static class D3D12_RESOURCE_TRANSITION_BARRIER extends Structure {
        public Pointer pResource;
        public int Subresource;
        public int StateBefore;
        public int StateAfter;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("pResource","Subresource","StateBefore","StateAfter");
        }
    }

    public static class D3D12_RESOURCE_BARRIER extends Structure {
        public int Type;
        public int Flags;
        public D3D12_RESOURCE_TRANSITION_BARRIER Transition = new D3D12_RESOURCE_TRANSITION_BARRIER();
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","Flags","Transition");
        }
    }

    // PSO Structures
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

    @Structure.FieldOrder({"pRootSignature", "CS", "NodeMask", "CachedPSO", "Flags"})
    public static class D3D12_COMPUTE_PIPELINE_STATE_DESC extends Structure {
        public Pointer pRootSignature;
        public D3D12_SHADER_BYTECODE CS = new D3D12_SHADER_BYTECODE();
        public int NodeMask;
        public D3D12_CACHED_PIPELINE_STATE CachedPSO = new D3D12_CACHED_PIPELINE_STATE();
        public int Flags;
    }

    // ========= D3DCompiler =========
    public interface D3DCompiler extends Library {
        D3DCompiler INSTANCE = Native.load("d3dcompiler_47", D3DCompiler.class);
        int D3DCompileFromFile(WString pFileName, Pointer pDefines, Pointer pInclude,
                String pEntrypoint, String pTarget, int Flags1, int Flags2,
                PointerByReference ppCode, PointerByReference ppErrorMsgs);
    }

    // ========= DXGI / D3D12 exports =========
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

    // ========= Kernel32 =========
    public interface Kernel32 extends Library {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class);
        Pointer CreateEventW(Pointer lpEventAttributes, int bManualReset, int bInitialState, WString lpName);
        int CloseHandle(Pointer hObject);
        int WaitForSingleObject(Pointer hHandle, int dwMilliseconds);
    }
    static final int INFINITE = 0xFFFFFFFF;

    // ========= Constants =========
    static final int WIDTH = 800;
    static final int HEIGHT = 600;
    static final int FRAMES = 2;
    static final int VERTEX_COUNT = 100000;

    static final int D3D_FEATURE_LEVEL_12_0 = 0xC000;
    static final int D3D12_COMMAND_LIST_TYPE_DIRECT = 0;

    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_UNKNOWN = 0;

    static final int DXGI_SWAP_EFFECT_FLIP_DISCARD = 0x4;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;

    static final int D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
    static final int D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1;

    static final int D3D12_HEAP_TYPE_DEFAULT = 1;
    static final int D3D12_HEAP_TYPE_UPLOAD = 2;

    static final int D3D12_RESOURCE_DIMENSION_BUFFER = 1;
    static final int D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1;

    static final int D3D12_RESOURCE_STATE_COMMON = 0;
    static final int D3D12_RESOURCE_STATE_PRESENT = 0;
    static final int D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4;
    static final int D3D12_RESOURCE_STATE_UNORDERED_ACCESS = 0x8;
    static final int D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 0x40;
    static final int D3D12_RESOURCE_STATE_GENERIC_READ = 0x1 | 0x2 | 0x40 | 0x80 | 0x200 | 0x800;

    static final int D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
    static final int D3D12_RESOURCE_BARRIER_FLAG_NONE = 0;
    static final int D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;

    static final int D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x4;

    static final int D3D_PRIMITIVE_TOPOLOGY_LINESTRIP = 3;
    static final int D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE = 2;

    static final int D3D_ROOT_SIGNATURE_VERSION_1 = 1;
    static final int D3D12_ROOT_SIGNATURE_FLAG_NONE = 0;

    static final int D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0;
    static final int D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1;
    static final int D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2;

    static final int D3D12_SRV_DIMENSION_BUFFER = 1;
    static final int D3D12_UAV_DIMENSION_BUFFER = 1;

    static final int D3D12_FILL_MODE_SOLID = 3;
    static final int D3D12_CULL_MODE_NONE = 1;

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
        static final int ID3D12Device_CreateComputePipelineState = 11;
        static final int ID3D12Device_CreateCommandList = 12;
        static final int ID3D12Device_CreateDescriptorHeap = 14;
        static final int ID3D12Device_GetDescriptorHandleIncrementSize = 15;
        static final int ID3D12Device_CreateRootSignature = 16;
        static final int ID3D12Device_CreateConstantBufferView = 17;
        static final int ID3D12Device_CreateShaderResourceView = 18;
        static final int ID3D12Device_CreateUnorderedAccessView = 19;
        static final int ID3D12Device_CreateRenderTargetView = 20;
        static final int ID3D12Device_CreateCommittedResource = 27;
        static final int ID3D12Device_CreateFence = 36;

        static final int ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart = 9;
        static final int ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart = 10;

        static final int ID3D12CommandAllocator_Reset = 8;

        static final int ID3D12GraphicsCommandList_Close = 9;
        static final int ID3D12GraphicsCommandList_Reset = 10;
        static final int ID3D12GraphicsCommandList_DrawInstanced = 12;
        static final int ID3D12GraphicsCommandList_Dispatch = 14;
        static final int ID3D12GraphicsCommandList_IASetPrimitiveTopology = 20;
        static final int ID3D12GraphicsCommandList_RSSetViewports = 21;
        static final int ID3D12GraphicsCommandList_RSSetScissorRects = 22;
        static final int ID3D12GraphicsCommandList_ResourceBarrier = 26;
        static final int ID3D12GraphicsCommandList_SetDescriptorHeaps = 28;
        static final int ID3D12GraphicsCommandList_SetComputeRootSignature = 29;
        static final int ID3D12GraphicsCommandList_SetGraphicsRootSignature = 30;
        static final int ID3D12GraphicsCommandList_SetComputeRootDescriptorTable = 31;
        static final int ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable = 32;
        static final int ID3D12GraphicsCommandList_OMSetRenderTargets = 46;
        static final int ID3D12GraphicsCommandList_ClearRenderTargetView = 48;

        static final int ID3D12CommandQueue_ExecuteCommandLists = 10;
        static final int ID3D12CommandQueue_Signal = 14;

        static final int ID3D12Fence_GetCompletedValue = 8;
        static final int ID3D12Fence_SetEventOnCompletion = 9;

        static final int ID3D12Resource_Map = 8;
        static final int ID3D12Resource_GetGPUVirtualAddress = 11;
    }

    static final int VT_ID3DBlob_GetBufferPointer = 3;
    static final int VT_ID3DBlob_GetBufferSize = 4;

    // ========= Globals =========
    static Pointer pFactory;
    static Pointer pSwapChain3;
    static Pointer pDevice;
    static Pointer pQueue;
    static Pointer pRtvHeap;
    static Pointer pSrvUavHeap;
    static Pointer pCmdAlloc;
    static Pointer pComputeCmdAlloc;
    static Pointer pCmdList;
    static Pointer pComputeCmdList;
    static Pointer pFence;
    static long fenceValue = 1;
    static Pointer fenceEvent;
    static int frameIndex = 0;

    static Pointer[] pRenderTargets = new Pointer[FRAMES];
    static int rtvDescriptorSize = 0;
    static int srvUavDescriptorSize = 0;
    static long[] rtvHandles = new long[FRAMES];

    static Pointer pComputeRootSig;
    static Pointer pGraphicsRootSig;
    static Pointer pComputePSO;
    static Pointer pGraphicsPSO;

    static Pointer pPositionBuffer;
    static Pointer pColorBuffer;
    static Pointer pConstantBuffer;
    static Pointer constantBufferDataBegin;

    static Pointer pD3D12Debug;

    // Harmonograph parameters
    static Random rand = new Random();
    static float A1 = 50f, f1 = 3.001f, p1 = 0f, d1 = 0.004f;
    static float A2 = 50f, f2 = 2.0f, p2 = 0f, d2 = 0.0065f;
    static float A3 = 50f, f3 = 3.0f, p3 = (float)(Math.PI/2), d3 = 0.008f;
    static float A4 = 50f, f4 = 2.0f, p4 = (float)(Math.PI/2), d4 = 0.019f;
    static final float PI2 = (float)(Math.PI * 2);

    // Performance
    static long frameCount = 0;
    static long lastFpsUpdateTime = 0;
    static double currentFps = 0;
    static Shell shellRef;

    // ========= Helper functions =========
    static long getCpuHandleStart(Pointer heap) {
        Memory handle = new Memory(8);
        comCallVoid(heap, VT.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart, handle);
        return handle.getLong(0);
    }

    static long getGpuHandleStart(Pointer heap) {
        Memory handle = new Memory(8);
        comCallVoid(heap, VT.ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart, handle);
        return handle.getLong(0);
    }

    // ========= Main =========
    public static void main(String[] args) {
        Display display = new Display();
        Shell shell = new Shell(display);
        shell.setText("Harmonograph - DirectX 12 Compute / Java");
        shell.setSize(WIDTH, HEIGHT);
        shell.open();

        long hwndLong = shell.handle;
        Pointer hwnd = new Pointer(hwndLong);

        System.out.println("HWND=0x" + Long.toHexString(hwndLong));

        shellRef = shell;

        initD3D12(hwnd);

        lastFpsUpdateTime = System.nanoTime();

        System.out.println("\n=== Harmonograph Compute Shader Demo ===\n");

        while (!shell.isDisposed()) {
            while (display.readAndDispatch()) {}
            render();
        }

        cleanup();
        display.dispose();
    }

    static void initD3D12(Pointer hwnd) {
        // 1) Debug layer
        {
            PointerByReference ppDbg = new PointerByReference();
            int hr = D3D12.INSTANCE.D3D12GetDebugInterface(REFIID(IID_ID3D12Debug), ppDbg);
            if (hr == S_OK) {
                pD3D12Debug = ppDbg.getValue();
                comCallVoid(pD3D12Debug, 3);
                System.out.println("D3D12 debug layer enabled");
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
        }

        // 4) Command queue
        {
            D3D12_COMMAND_QUEUE_DESC qd = new D3D12_COMMAND_QUEUE_DESC();
            qd.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
            qd.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandQueue, qd.getPointer(), REFIID(IID_ID3D12CommandQueue), pp);
            checkHR(hr, "CreateCommandQueue");
            pQueue = pp.getValue();
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
            checkHR(hr, "QueryInterface(IDXGISwapChain3)");
            pSwapChain3 = ppSwap3.getValue();
            comCallInt(pSwapChain, VT.RELEASE);

            frameIndex = comCallInt(pSwapChain3, VT.IDXGISwapChain3_GetCurrentBackBufferIndex);
        }

        // 6) RTV heap
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

            for (int i = 0; i < FRAMES; i++) {
                PointerByReference ppRT = new PointerByReference();
                hr = comCallInt(pSwapChain3, VT.IDXGISwapChain_GetBuffer, i, REFIID(IID_ID3D12Resource), ppRT);
                checkHR(hr, "SwapChain::GetBuffer");
                pRenderTargets[i] = ppRT.getValue();

                rtvHandles[i] = rtvStart + (long)i * rtvDescriptorSize;
                comCallVoid(pDevice, VT.ID3D12Device_CreateRenderTargetView, pRenderTargets[i], Pointer.NULL, rtvHandles[i]);
            }
        }

        // 7) SRV/UAV/CBV heap (shader visible) - 5 descriptors: UAV x2, SRV x2, CBV x1
        {
            D3D12_DESCRIPTOR_HEAP_DESC hd = new D3D12_DESCRIPTOR_HEAP_DESC();
            hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
            hd.NumDescriptors = 5;
            hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
            hd.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateDescriptorHeap, hd.getPointer(), REFIID(IID_ID3D12DescriptorHeap), pp);
            checkHR(hr, "CreateDescriptorHeap(SRV/UAV)");
            pSrvUavHeap = pp.getValue();

            srvUavDescriptorSize = comCallInt(pDevice, VT.ID3D12Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
        }

        // 8) Command allocators
        {
            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandAllocator,
                    D3D12_COMMAND_LIST_TYPE_DIRECT, REFIID(IID_ID3D12CommandAllocator), pp);
            checkHR(hr, "CreateCommandAllocator(Graphics)");
            pCmdAlloc = pp.getValue();

            pp = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandAllocator,
                    D3D12_COMMAND_LIST_TYPE_DIRECT, REFIID(IID_ID3D12CommandAllocator), pp);
            checkHR(hr, "CreateCommandAllocator(Compute)");
            pComputeCmdAlloc = pp.getValue();
        }

        // 9) Create root signatures and PSOs
        createRootSignatures();
        createPipelineStates();

        // 10) Create buffers
        createBuffers();

        // 11) Create command lists
        {
            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandList,
                    0, D3D12_COMMAND_LIST_TYPE_DIRECT, pCmdAlloc, pGraphicsPSO, REFIID(IID_ID3D12GraphicsCommandList), pp);
            checkHR(hr, "CreateCommandList(Graphics)");
            pCmdList = pp.getValue();
            comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close);

            pp = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandList,
                    0, D3D12_COMMAND_LIST_TYPE_DIRECT, pComputeCmdAlloc, pComputePSO, REFIID(IID_ID3D12GraphicsCommandList), pp);
            checkHR(hr, "CreateCommandList(Compute)");
            pComputeCmdList = pp.getValue();
            comCallInt(pComputeCmdList, VT.ID3D12GraphicsCommandList_Close);
        }

        // 12) Fence
        {
            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateFence, 0L, 0, REFIID(IID_ID3D12Fence), pp);
            checkHR(hr, "CreateFence");
            pFence = pp.getValue();
            fenceValue = 1;
            fenceEvent = Kernel32.INSTANCE.CreateEventW(Pointer.NULL, 0, 0, null);
        }

        System.out.println("D3D12 initialized OK");
    }

    static void createRootSignatures() {
        // === Compute Root Signature ===
        {
            Memory uavRange = new Memory(20);
            uavRange.clear();
            uavRange.setInt(0, D3D12_DESCRIPTOR_RANGE_TYPE_UAV);
            uavRange.setInt(4, 2);
            uavRange.setInt(8, 0);
            uavRange.setInt(12, 0);
            uavRange.setInt(16, -1);

            Memory cbvRange = new Memory(20);
            cbvRange.clear();
            cbvRange.setInt(0, D3D12_DESCRIPTOR_RANGE_TYPE_CBV);
            cbvRange.setInt(4, 1);
            cbvRange.setInt(8, 0);
            cbvRange.setInt(12, 0);
            cbvRange.setInt(16, -1);

            Memory rootParams = new Memory(64);
            rootParams.clear();
            rootParams.setInt(0, 0);
            rootParams.setInt(8, 1);
            rootParams.setPointer(16, uavRange);
            rootParams.setInt(24, 0);
            rootParams.setInt(32, 0);
            rootParams.setInt(40, 1);
            rootParams.setPointer(48, cbvRange);
            rootParams.setInt(56, 0);

            Memory rsDesc = new Memory(40);
            rsDesc.clear();
            rsDesc.setInt(0, 2);
            rsDesc.setPointer(8, rootParams);
            rsDesc.setInt(16, 0);
            rsDesc.setPointer(24, Pointer.NULL);
            rsDesc.setInt(32, D3D12_ROOT_SIGNATURE_FLAG_NONE);

            PointerByReference ppSig = new PointerByReference();
            PointerByReference ppErr = new PointerByReference();
            int hr = D3D12.INSTANCE.D3D12SerializeRootSignature(rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, ppSig, ppErr);
            if (hr < 0 && ppErr.getValue() != null) {
                long errPtr = comCallLong(ppErr.getValue(), VT_ID3DBlob_GetBufferPointer);
                System.err.println("Compute root signature error: " + new Pointer(errPtr).getString(0));
            }
            checkHR(hr, "D3D12SerializeRootSignature(Compute)");

            Pointer blobSig = ppSig.getValue();
            long sigPtr = comCallLong(blobSig, VT_ID3DBlob_GetBufferPointer);
            long sigSize = comCallLong(blobSig, VT_ID3DBlob_GetBufferSize);

            PointerByReference ppRS = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateRootSignature,
                    0, new Pointer(sigPtr), new NativeLong(sigSize), REFIID(IID_ID3D12RootSignature), ppRS);
            checkHR(hr, "CreateRootSignature(Compute)");
            pComputeRootSig = ppRS.getValue();

            comCallInt(blobSig, VT.RELEASE);
        }

        // === Graphics Root Signature ===
        {
            Memory srvRange = new Memory(20);
            srvRange.clear();
            srvRange.setInt(0, D3D12_DESCRIPTOR_RANGE_TYPE_SRV);
            srvRange.setInt(4, 2);
            srvRange.setInt(8, 0);
            srvRange.setInt(12, 0);
            srvRange.setInt(16, -1);

            Memory cbvRange = new Memory(20);
            cbvRange.clear();
            cbvRange.setInt(0, D3D12_DESCRIPTOR_RANGE_TYPE_CBV);
            cbvRange.setInt(4, 1);
            cbvRange.setInt(8, 0);
            cbvRange.setInt(12, 0);
            cbvRange.setInt(16, -1);

            Memory rootParams = new Memory(64);
            rootParams.clear();
            rootParams.setInt(0, 0);
            rootParams.setInt(8, 1);
            rootParams.setPointer(16, srvRange);
            rootParams.setInt(24, 1);
            rootParams.setInt(32, 0);
            rootParams.setInt(40, 1);
            rootParams.setPointer(48, cbvRange);
            rootParams.setInt(56, 1);

            Memory rsDesc = new Memory(40);
            rsDesc.clear();
            rsDesc.setInt(0, 2);
            rsDesc.setPointer(8, rootParams);
            rsDesc.setInt(16, 0);
            rsDesc.setPointer(24, Pointer.NULL);
            rsDesc.setInt(32, D3D12_ROOT_SIGNATURE_FLAG_NONE);

            PointerByReference ppSig = new PointerByReference();
            PointerByReference ppErr = new PointerByReference();
            int hr = D3D12.INSTANCE.D3D12SerializeRootSignature(rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, ppSig, ppErr);
            checkHR(hr, "D3D12SerializeRootSignature(Graphics)");

            Pointer blobSig = ppSig.getValue();
            long sigPtr = comCallLong(blobSig, VT_ID3DBlob_GetBufferPointer);
            long sigSize = comCallLong(blobSig, VT_ID3DBlob_GetBufferSize);

            PointerByReference ppRS = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateRootSignature,
                    0, new Pointer(sigPtr), new NativeLong(sigSize), REFIID(IID_ID3D12RootSignature), ppRS);
            checkHR(hr, "CreateRootSignature(Graphics)");
            pGraphicsRootSig = ppRS.getValue();

            comCallInt(blobSig, VT.RELEASE);
        }

        System.out.println("Root signatures created");
    }

    static void createPipelineStates() {
        PointerByReference ppCS = new PointerByReference();
        PointerByReference ppVS = new PointerByReference();
        PointerByReference ppPS = new PointerByReference();
        PointerByReference ppErr = new PointerByReference();

        int hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "CSMain", "cs_5_0", 0, 0, ppCS, ppErr);
        if (hr < 0 && ppErr.getValue() != null) {
            long errPtr = comCallLong(ppErr.getValue(), VT_ID3DBlob_GetBufferPointer);
            System.err.println("CS compile error: " + new Pointer(errPtr).getString(0));
        }
        checkHR(hr, "D3DCompileFromFile(CS)");

        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "VSMain", "vs_5_0", 0, 0, ppVS, ppErr);
        checkHR(hr, "D3DCompileFromFile(VS)");

        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "PSMain", "ps_5_0", 0, 0, ppPS, ppErr);
        checkHR(hr, "D3DCompileFromFile(PS)");

        Pointer blobCS = ppCS.getValue();
        Pointer blobVS = ppVS.getValue();
        Pointer blobPS = ppPS.getValue();

        long csPtr = comCallLong(blobCS, VT_ID3DBlob_GetBufferPointer);
        long csSize = comCallLong(blobCS, VT_ID3DBlob_GetBufferSize);
        long vsPtr = comCallLong(blobVS, VT_ID3DBlob_GetBufferPointer);
        long vsSize = comCallLong(blobVS, VT_ID3DBlob_GetBufferSize);
        long psPtr = comCallLong(blobPS, VT_ID3DBlob_GetBufferPointer);
        long psSize = comCallLong(blobPS, VT_ID3DBlob_GetBufferSize);

        // === Compute PSO ===
        {
            D3D12_COMPUTE_PIPELINE_STATE_DESC psoDesc = new D3D12_COMPUTE_PIPELINE_STATE_DESC();
            psoDesc.pRootSignature = pComputeRootSig;
            psoDesc.CS.pShaderBytecode = new Pointer(csPtr);
            psoDesc.CS.BytecodeLength = csSize;
            psoDesc.write();

            PointerByReference ppPSO = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateComputePipelineState, psoDesc.getPointer(), REFIID(IID_ID3D12PipelineState), ppPSO);
            checkHR(hr, "CreateComputePipelineState");
            pComputePSO = ppPSO.getValue();
        }

        // === Graphics PSO ===
        {
            D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC();
            psoDesc.pRootSignature = pGraphicsRootSig;
            psoDesc.VS.pShaderBytecode = new Pointer(vsPtr);
            psoDesc.VS.BytecodeLength = vsSize;
            psoDesc.PS.pShaderBytecode = new Pointer(psPtr);
            psoDesc.PS.BytecodeLength = psSize;
            psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = 0xF;
            psoDesc.SampleMask = 0xFFFFFFFF;
            psoDesc.RasterizerState.FillMode = D3D12_FILL_MODE_SOLID;
            psoDesc.RasterizerState.CullMode = D3D12_CULL_MODE_NONE;
            psoDesc.RasterizerState.DepthClipEnable = 1;
            psoDesc.DepthStencilState.DepthEnable = 0;
            psoDesc.InputLayout.pInputElementDescs = Pointer.NULL;
            psoDesc.InputLayout.NumElements = 0;
            psoDesc.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE;
            psoDesc.NumRenderTargets = 1;
            psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
            psoDesc.SampleDesc.Count = 1;
            psoDesc.write();

            PointerByReference ppPSO = new PointerByReference();
            hr = comCallInt(pDevice, VT.ID3D12Device_CreateGraphicsPipelineState, psoDesc.getPointer(), REFIID(IID_ID3D12PipelineState), ppPSO);
            checkHR(hr, "CreateGraphicsPipelineState");
            pGraphicsPSO = ppPSO.getValue();
        }

        comCallInt(blobCS, VT.RELEASE);
        comCallInt(blobVS, VT.RELEASE);
        comCallInt(blobPS, VT.RELEASE);

        System.out.println("Pipeline states created");
    }

    static void createBuffers() {
        int bufferSize = VERTEX_COUNT * 16;

        D3D12_HEAP_PROPERTIES defaultHeap = new D3D12_HEAP_PROPERTIES();
        defaultHeap.Type = D3D12_HEAP_TYPE_DEFAULT;
        defaultHeap.CreationNodeMask = 1;
        defaultHeap.VisibleNodeMask = 1;
        defaultHeap.write();

        D3D12_HEAP_PROPERTIES uploadHeap = new D3D12_HEAP_PROPERTIES();
        uploadHeap.Type = D3D12_HEAP_TYPE_UPLOAD;
        uploadHeap.CreationNodeMask = 1;
        uploadHeap.VisibleNodeMask = 1;
        uploadHeap.write();

        D3D12_RESOURCE_DESC bufferDesc = new D3D12_RESOURCE_DESC();
        bufferDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        bufferDesc.Width = bufferSize;
        bufferDesc.Height = 1;
        bufferDesc.DepthOrArraySize = 1;
        bufferDesc.MipLevels = 1;
        bufferDesc.Format = DXGI_FORMAT_UNKNOWN;
        bufferDesc.SampleDesc.Count = 1;
        bufferDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        bufferDesc.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
        bufferDesc.write();

        {
            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                    defaultHeap.getPointer(), 0, bufferDesc.getPointer(), D3D12_RESOURCE_STATE_COMMON, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
            checkHR(hr, "CreateCommittedResource(PositionBuffer)");
            pPositionBuffer = pp.getValue();
        }

        {
            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                    defaultHeap.getPointer(), 0, bufferDesc.getPointer(), D3D12_RESOURCE_STATE_COMMON, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
            checkHR(hr, "CreateCommittedResource(ColorBuffer)");
            pColorBuffer = pp.getValue();
        }

        {
            D3D12_RESOURCE_DESC cbDesc = new D3D12_RESOURCE_DESC();
            cbDesc.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
            cbDesc.Width = 256;
            cbDesc.Height = 1;
            cbDesc.DepthOrArraySize = 1;
            cbDesc.MipLevels = 1;
            cbDesc.Format = DXGI_FORMAT_UNKNOWN;
            cbDesc.SampleDesc.Count = 1;
            cbDesc.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
            cbDesc.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                    uploadHeap.getPointer(), 0, cbDesc.getPointer(), D3D12_RESOURCE_STATE_GENERIC_READ, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
            checkHR(hr, "CreateCommittedResource(ConstantBuffer)");
            pConstantBuffer = pp.getValue();

            D3D12_RANGE readRange = new D3D12_RANGE();
            readRange.Begin = 0;
            readRange.End = 0;
            readRange.write();
            PointerByReference ppMap = new PointerByReference();
            hr = comCallInt(pConstantBuffer, VT.ID3D12Resource_Map, 0, readRange.getPointer(), ppMap);
            checkHR(hr, "Map(ConstantBuffer)");
            constantBufferDataBegin = ppMap.getValue();
        }

        long cpuHandle = getCpuHandleStart(pSrvUavHeap);

        // UAV 0, 1
        {
            Memory uavDesc = new Memory(40);
            uavDesc.clear();
            uavDesc.setInt(0, DXGI_FORMAT_UNKNOWN);
            uavDesc.setInt(4, D3D12_UAV_DIMENSION_BUFFER);
            uavDesc.setLong(8, 0);
            uavDesc.setInt(16, VERTEX_COUNT);
            uavDesc.setInt(20, 16);

            comCallVoid(pDevice, VT.ID3D12Device_CreateUnorderedAccessView, pPositionBuffer, Pointer.NULL, uavDesc, cpuHandle);
            cpuHandle += srvUavDescriptorSize;
            comCallVoid(pDevice, VT.ID3D12Device_CreateUnorderedAccessView, pColorBuffer, Pointer.NULL, uavDesc, cpuHandle);
            cpuHandle += srvUavDescriptorSize;
        }

        // SRV 0, 1
        {
            Memory srvDesc = new Memory(40);
            srvDesc.clear();
            srvDesc.setInt(0, DXGI_FORMAT_UNKNOWN);
            srvDesc.setInt(4, D3D12_SRV_DIMENSION_BUFFER);
            srvDesc.setInt(8, 0x1688);
            srvDesc.setLong(16, 0);
            srvDesc.setInt(24, VERTEX_COUNT);
            srvDesc.setInt(28, 16);

            comCallVoid(pDevice, VT.ID3D12Device_CreateShaderResourceView, pPositionBuffer, srvDesc, cpuHandle);
            cpuHandle += srvUavDescriptorSize;
            comCallVoid(pDevice, VT.ID3D12Device_CreateShaderResourceView, pColorBuffer, srvDesc, cpuHandle);
            cpuHandle += srvUavDescriptorSize;
        }

        // CBV
        {
            long gpuVA = comCallLong(pConstantBuffer, VT.ID3D12Resource_GetGPUVirtualAddress);
            Memory cbvDesc = new Memory(16);
            cbvDesc.setLong(0, gpuVA);
            cbvDesc.setInt(8, 256);
            comCallVoid(pDevice, VT.ID3D12Device_CreateConstantBufferView, cbvDesc, cpuHandle);
        }

        System.out.println("Buffers and views created");
    }

    static void render() {
        f1 = (f1 + (float)rand.nextDouble() / 200f) % 10f;
        f2 = (f2 + (float)rand.nextDouble() / 200f) % 10f;
        p1 += (PI2 * 0.5f / 360f);

        ByteBuffer cb = constantBufferDataBegin.getByteBuffer(0, 96).order(ByteOrder.LITTLE_ENDIAN);
        cb.putFloat(0, A1);  cb.putFloat(4, f1);  cb.putFloat(8, p1);  cb.putFloat(12, d1);
        cb.putFloat(16, A2); cb.putFloat(20, f2); cb.putFloat(24, p2); cb.putFloat(28, d2);
        cb.putFloat(32, A3); cb.putFloat(36, f3); cb.putFloat(40, p3); cb.putFloat(44, d3);
        cb.putFloat(48, A4); cb.putFloat(52, f4); cb.putFloat(56, p4); cb.putFloat(60, d4);
        cb.putInt(64, VERTEX_COUNT);
        cb.putFloat(68, 0); cb.putFloat(72, 0); cb.putFloat(76, 0);
        cb.putFloat(80, (float)WIDTH);
        cb.putFloat(84, (float)HEIGHT);

        // ========= Compute Pass =========
        checkHR(comCallInt(pComputeCmdAlloc, VT.ID3D12CommandAllocator_Reset), "ComputeAllocator::Reset");
        checkHR(comCallInt(pComputeCmdList, VT.ID3D12GraphicsCommandList_Reset, pComputeCmdAlloc, pComputePSO), "ComputeCmdList::Reset");

        Memory ppHeaps = new Memory(PTR_SIZE);
        ppHeaps.setPointer(0, pSrvUavHeap);
        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_SetDescriptorHeaps, 1, ppHeaps);
        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_SetComputeRootSignature, pComputeRootSig);

        long gpuHandle = getGpuHandleStart(pSrvUavHeap);
        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_SetComputeRootDescriptorTable, 0, gpuHandle);
        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_SetComputeRootDescriptorTable, 1, gpuHandle + srvUavDescriptorSize * 4);

        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_Dispatch, (VERTEX_COUNT + 63) / 64, 1, 1);

        D3D12_RESOURCE_BARRIER b1 = new D3D12_RESOURCE_BARRIER();
        b1.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b1.Transition.pResource = pPositionBuffer;
        b1.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b1.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
        b1.Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
        b1.write();

        D3D12_RESOURCE_BARRIER b2 = new D3D12_RESOURCE_BARRIER();
        b2.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b2.Transition.pResource = pColorBuffer;
        b2.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b2.Transition.StateBefore = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
        b2.Transition.StateAfter = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
        b2.write();

        Memory barriers = new Memory(b1.size() * 2);
        barriers.write(0, b1.getPointer().getByteArray(0, b1.size()), 0, b1.size());
        barriers.write(b1.size(), b2.getPointer().getByteArray(0, b2.size()), 0, b2.size());
        comCallVoid(pComputeCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 2, barriers);

        checkHR(comCallInt(pComputeCmdList, VT.ID3D12GraphicsCommandList_Close), "ComputeCmdList::Close");

        Memory ppLists = new Memory(PTR_SIZE);
        ppLists.setPointer(0, pComputeCmdList);
        comCallVoid(pQueue, VT.ID3D12CommandQueue_ExecuteCommandLists, 1, ppLists);

        // ========= Graphics Pass =========
        checkHR(comCallInt(pCmdAlloc, VT.ID3D12CommandAllocator_Reset), "GraphicsAllocator::Reset");
        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Reset, pCmdAlloc, pGraphicsPSO), "GraphicsCmdList::Reset");

        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetDescriptorHeaps, 1, ppHeaps);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootSignature, pGraphicsRootSig);

        gpuHandle = getGpuHandleStart(pSrvUavHeap);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable, 0, gpuHandle + srvUavDescriptorSize * 2);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable, 1, gpuHandle + srvUavDescriptorSize * 4);

        D3D12_VIEWPORT vp = new D3D12_VIEWPORT();
        vp.Width = WIDTH; vp.Height = HEIGHT; vp.MaxDepth = 1;
        vp.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetViewports, 1, vp.getPointer());

        D3D12_RECT sc = new D3D12_RECT();
        sc.right = WIDTH; sc.bottom = HEIGHT;
        sc.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetScissorRects, 1, sc.getPointer());

        D3D12_RESOURCE_BARRIER rtBarrier = new D3D12_RESOURCE_BARRIER();
        rtBarrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        rtBarrier.Transition.pResource = pRenderTargets[frameIndex];
        rtBarrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        rtBarrier.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, rtBarrier.getPointer());

        long rtv = rtvHandles[frameIndex];
        float[] clearColor = {0.05f, 0.05f, 0.1f, 1f};
        Memory clearMem = new Memory(16);
        clearMem.write(0, clearColor, 0, 4);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ClearRenderTargetView, rtv, clearMem, 0, Pointer.NULL);

        Memory rtvArray = new Memory(8);
        rtvArray.setLong(0, rtv);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_OMSetRenderTargets, 1, rtvArray, 0, Pointer.NULL);

        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_DrawInstanced, VERTEX_COUNT, 1, 0, 0);

        rtBarrier.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        rtBarrier.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        rtBarrier.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, rtBarrier.getPointer());

        b1.Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
        b1.Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
        b1.write();
        b2.Transition.StateBefore = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
        b2.Transition.StateAfter = D3D12_RESOURCE_STATE_UNORDERED_ACCESS;
        b2.write();
        barriers.write(0, b1.getPointer().getByteArray(0, b1.size()), 0, b1.size());
        barriers.write(b1.size(), b2.getPointer().getByteArray(0, b2.size()), 0, b2.size());
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 2, barriers);

        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close), "GraphicsCmdList::Close");

        ppLists.setPointer(0, pCmdList);
        comCallVoid(pQueue, VT.ID3D12CommandQueue_ExecuteCommandLists, 1, ppLists);

        comCallInt(pSwapChain3, VT.IDXGISwapChain_Present, 1, 0);

        waitForPreviousFrame();

        frameCount++;
        long now = System.nanoTime();
        if (now - lastFpsUpdateTime >= 500_000_000L) {
            currentFps = frameCount * 1_000_000_000.0 / (now - lastFpsUpdateTime);
            frameCount = 0;
            lastFpsUpdateTime = now;
            if (shellRef != null && !shellRef.isDisposed()) {
                shellRef.setText(String.format("Harmonograph - DX12 Compute / Java | FPS: %.1f | Vertices: %d", currentFps, VERTEX_COUNT));
            }
        }
    }

    static void waitForPreviousFrame() {
        long fence = fenceValue;
        checkHR(comCallInt(pQueue, VT.ID3D12CommandQueue_Signal, pFence, fence), "Signal");
        fenceValue++;

        long completed = comCallLong(pFence, VT.ID3D12Fence_GetCompletedValue);
        if (Long.compareUnsigned(completed, fence) < 0) {
            checkHR(comCallInt(pFence, VT.ID3D12Fence_SetEventOnCompletion, fence, fenceEvent), "SetEventOnCompletion");
            Kernel32.INSTANCE.WaitForSingleObject(fenceEvent, INFINITE);
        }

        frameIndex = comCallInt(pSwapChain3, VT.IDXGISwapChain3_GetCurrentBackBufferIndex);
    }

    static void cleanup() {
        try { waitForPreviousFrame(); } catch (Throwable t) {}
        if (fenceEvent != null) Kernel32.INSTANCE.CloseHandle(fenceEvent);
        safeRelease(pConstantBuffer);
        safeRelease(pColorBuffer);
        safeRelease(pPositionBuffer);
        for (int i = 0; i < FRAMES; i++) safeRelease(pRenderTargets[i]);
        safeRelease(pComputeCmdList);
        safeRelease(pCmdList);
        safeRelease(pComputeCmdAlloc);
        safeRelease(pCmdAlloc);
        safeRelease(pComputePSO);
        safeRelease(pGraphicsPSO);
        safeRelease(pComputeRootSig);
        safeRelease(pGraphicsRootSig);
        safeRelease(pSrvUavHeap);
        safeRelease(pRtvHeap);
        safeRelease(pFence);
        safeRelease(pQueue);
        safeRelease(pSwapChain3);
        safeRelease(pFactory);
        safeRelease(pD3D12Debug);
        safeRelease(pDevice);
    }

    static void safeRelease(Pointer p) {
        if (p != null && Pointer.nativeValue(p) != 0) {
            try { comCallInt(p, VT.RELEASE); } catch (Throwable t) {}
        }
    }
}
