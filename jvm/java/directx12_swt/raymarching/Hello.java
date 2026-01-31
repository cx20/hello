// Java + SWT + JNA : DirectX 12 Raymarching
// - Creates an SWT Shell (HWND) and renders raymarching via D3D12 + DXGI.
// - Uses "manual COM vtable calls" similar to the C sample.
// - Requires hello.hlsl with raymarching shader in current working directory.
//
// Build (example):
//   javac -cp <swt_jar>;<jna_jar>;. Hello.java
// Run:
//   java  -cp <swt_jar>;<jna_jar>;. Hello
//
// Notes:
// - Requires Windows 10/11 + D3D12 capable GPU/driver.
// - Requires d3d12.dll, dxgi.dll, d3dcompiler_47.dll present (normally on Windows).
// - Expects hello.hlsl in current working directory.
//
import org.eclipse.swt.SWT;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

import com.sun.jna.*;
import com.sun.jna.ptr.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public class Hello {

    // ========= Win32 / HRESULT =========
    static final int S_OK = 0;
    static final int E_FAIL = 0x80004005;
    static final int DXGI_ERROR_SDK_COMPONENT_MISSING = 0x887A002D;

    static void checkHR(int hr, String what) {
        if (hr < 0) { // FAILED(hr)
            throw new RuntimeException(String.format("%s failed: 0x%08X", what, hr));
        }
    }

    // ========= Calling convention =========
    static final int CC = Function.C_CONVENTION; // Windows x64 calling convention

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
        Object o = f.invoke(retType, argv);
        return (T)o;
    }

    static long getCpuHandleStart(Pointer heap) {
        int idxCPU = VT.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart;
        D3D12_CPU_DESCRIPTOR_HANDLE handle = new D3D12_CPU_DESCRIPTOR_HANDLE();
        handle.write();
        comCallVoid(heap, idxCPU, handle.getPointer());
        handle.read();
        return handle.ptr;
    }

    static long getGpuHandleStart(Pointer heap) {
        int idxGPU = VT.ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart;
        D3D12_GPU_DESCRIPTOR_HANDLE handle = new D3D12_GPU_DESCRIPTOR_HANDLE();
        handle.write();
        comCallVoid(heap, idxGPU, handle.getPointer());
        handle.read();
        return handle.ptr;
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

    // ========= Minimal structs =========
    public static class D3D12_COMMAND_QUEUE_DESC extends Structure {
        public int Type;
        public int Priority;
        public int Flags;
        public int NodeMask;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","Priority","Flags","NodeMask");
        }
    }

    public static class DXGI_RATIONAL extends Structure {
        public int Numerator;
        public int Denominator;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Numerator","Denominator");
        }
    }

    public static class DXGI_MODE_DESC extends Structure {
        public int Width;
        public int Height;
        public DXGI_RATIONAL RefreshRate = new DXGI_RATIONAL();
        public int Format;
        public int ScanlineOrdering;
        public int Scaling;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Width","Height","RefreshRate","Format","ScanlineOrdering","Scaling");
        }
    }

    public static class DXGI_SAMPLE_DESC extends Structure {
        public int Count;
        public int Quality;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Count","Quality");
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

    public static class D3D12_DESCRIPTOR_HEAP_DESC extends Structure {
        public int Type;
        public int NumDescriptors;
        public int Flags;
        public int NodeMask;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Type","NumDescriptors","Flags","NodeMask");
        }

        public static class ByValue extends D3D12_DESCRIPTOR_HEAP_DESC implements Structure.ByValue {}
    }

    public static class D3D12_CPU_DESCRIPTOR_HANDLE extends Structure {
        public long ptr;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("ptr");
        }
        public static class ByValue extends D3D12_CPU_DESCRIPTOR_HANDLE implements Structure.ByValue {}
    }

    public static class D3D12_GPU_DESCRIPTOR_HANDLE extends Structure {
        public long ptr;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("ptr");
        }
        public static class ByValue extends D3D12_GPU_DESCRIPTOR_HANDLE implements Structure.ByValue {}
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

    public static class D3D12_RANGE extends Structure {
        public long Begin;
        public long End;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("Begin","End");
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

    // ===== PSO Structures =====
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

    public static class D3D12_VERTEX_BUFFER_VIEW extends Structure {
        public long BufferLocation;
        public int SizeInBytes;
        public int StrideInBytes;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("BufferLocation","SizeInBytes","StrideInBytes");
        }
    }

    public static class D3D12_CONSTANT_BUFFER_VIEW_DESC extends Structure {
        public long BufferLocation;
        public int SizeInBytes;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("BufferLocation","SizeInBytes");
        }
    }

    // ========= D3DCompiler =========
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

    // ========= Constants =========
    static final int WIDTH = 800;
    static final int HEIGHT = 600;
    static final int FRAMES = 2;

    static final int D3D_FEATURE_LEVEL_12_0 = 0xC000;
    static final int D3D12_COMMAND_LIST_TYPE_DIRECT = 0;

    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_R32G32_FLOAT = 16;
    static final int DXGI_FORMAT_UNKNOWN = 0;

    static final int DXGI_SWAP_EFFECT_FLIP_DISCARD = 0x4;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;

    static final int D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
    static final int D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1;

    static final int D3D12_HEAP_TYPE_UPLOAD = 2;

    static final int D3D12_RESOURCE_DIMENSION_BUFFER = 1;
    static final int D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1;

    static final int D3D12_RESOURCE_STATE_PRESENT = 0;
    static final int D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4;
    static final int D3D12_RESOURCE_STATE_GENERIC_READ = 0x1 | 0x2 | 0x40 | 0x80 | 0x200 | 0x800;

    static final int D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
    static final int D3D12_RESOURCE_BARRIER_FLAG_NONE = 0;
    static final int D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;

    static final int D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

    static final int D3D_ROOT_SIGNATURE_VERSION_1 = 1;
    static final int D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1;

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
        static final int ID3D12Device_CreateConstantBufferView = 17;
        static final int ID3D12Device_CreateRenderTargetView = 20;
        static final int ID3D12Device_CreateCommittedResource = 27;
        static final int ID3D12Device_CreateFence = 36;

        static final int ID3D12DescriptorHeap_GetDesc = 8;
        static final int ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart = 9;
        static final int ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart = 10;

        static final int ID3D12CommandAllocator_Reset = 8;

        static final int ID3D12GraphicsCommandList_Close = 9;
        static final int ID3D12GraphicsCommandList_Reset = 10;
        static final int ID3D12GraphicsCommandList_DrawInstanced = 12;
        static final int ID3D12GraphicsCommandList_IASetPrimitiveTopology = 20;
        static final int ID3D12GraphicsCommandList_RSSetViewports = 21;
        static final int ID3D12GraphicsCommandList_RSSetScissorRects = 22;
        static final int ID3D12GraphicsCommandList_ResourceBarrier = 26;
        static final int ID3D12GraphicsCommandList_SetDescriptorHeaps = 28;
        static final int ID3D12GraphicsCommandList_SetGraphicsRootSignature = 30;
        static final int ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable = 32;
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
    static Pointer pFactory;
    static Pointer pSwapChain3;
    static Pointer pDevice;
    static Pointer pQueue;
    static Pointer pRtvHeap;
    static Pointer pCbvHeap;
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
    static Pointer pConstantBuffer;
    static D3D12_VERTEX_BUFFER_VIEW vbView = new D3D12_VERTEX_BUFFER_VIEW();
    static Pointer constantBufferDataBegin;

    static Pointer pD3D12Debug;
    static Pointer pInfoQueue;

    static long startTimeNanos;

    // Performance measurement
    static long frameCount = 0;
    static long lastFpsUpdateTime = 0;
    static double currentFps = 0;
    static double avgFrameTimeMs = 0;
    static double cpuTimeMs = 0;
    static double gpuWaitTimeMs = 0;
    static Shell shellRef;

    // ========= Kernel32 =========
    public interface Kernel32 extends Library {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class);
        Pointer CreateEventW(Pointer lpEventAttributes, int bManualReset, int bInitialState, WString lpName);
        int CloseHandle(Pointer hObject);
        int WaitForSingleObject(Pointer hHandle, int dwMilliseconds);
    }
    static final int INFINITE = 0xFFFFFFFF;

    // ========= Main =========
    public static void main(String[] args) {
        Display display = new Display();
        Shell shell = new Shell(display);
        shell.setText("Raymarching - DirectX 12 / Java");
        shell.setSize(WIDTH, HEIGHT);
        shell.open();

        long hwndLong = shell.handle;
        Pointer hwnd = new Pointer(hwndLong);

        System.out.println("HWND=0x" + Long.toHexString(hwndLong));

        shellRef = shell;  // Store reference for title update

        initD3D12(hwnd);

        startTimeNanos = System.nanoTime();
        lastFpsUpdateTime = startTimeNanos;

        System.out.println("\n=== Performance Monitoring Started ===");
        System.out.println("FPS and timing info will be shown in window title and console.\n");

        // Active rendering loop (no sleep for smooth animation)
        while (!shell.isDisposed()) {
            // Process SWT events without blocking
            while (display.readAndDispatch()) {}
            
            // Render frame
            render();
            
            // No sleep - render as fast as possible (VSync will limit)
        }

        cleanup();
        display.dispose();
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
            D3D12_COMMAND_QUEUE_DESC q = new D3D12_COMMAND_QUEUE_DESC();
            q.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
            q.Priority = 0;
            q.Flags = 0;
            q.NodeMask = 0;
            q.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommandQueue, q.getPointer(), REFIID(IID_ID3D12CommandQueue), pp);
            checkHR(hr, "CreateCommandQueue");
            pQueue = pp.getValue();
        }

        // 5) SwapChain
        {
            DXGI_SWAP_CHAIN_DESC sc = new DXGI_SWAP_CHAIN_DESC();
            sc.BufferDesc.Width = WIDTH;
            sc.BufferDesc.Height = HEIGHT;
            sc.BufferDesc.RefreshRate.Numerator = 0;
            sc.BufferDesc.RefreshRate.Denominator = 0;
            sc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            sc.SampleDesc.Count = 1;
            sc.SampleDesc.Quality = 0;
            sc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
            sc.BufferCount = FRAMES;
            sc.OutputWindow = hwnd;
            sc.Windowed = 1;
            sc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
            sc.Flags = 0;
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
        }

        // 6) RTV heap + render targets
        {
            D3D12_DESCRIPTOR_HEAP_DESC hd = new D3D12_DESCRIPTOR_HEAP_DESC();
            hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
            hd.NumDescriptors = FRAMES;
            hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
            hd.NodeMask = 0;
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

        // 7) CBV heap (shader visible)
        {
            D3D12_DESCRIPTOR_HEAP_DESC hd = new D3D12_DESCRIPTOR_HEAP_DESC();
            hd.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
            hd.NumDescriptors = 1;
            hd.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
            hd.NodeMask = 0;
            hd.write();

            PointerByReference pp = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateDescriptorHeap, hd.getPointer(), REFIID(IID_ID3D12DescriptorHeap), pp);
            checkHR(hr, "CreateDescriptorHeap(CBV)");
            pCbvHeap = pp.getValue();
        }

        // 8) Command allocator + command list
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

        // 9) Root signature + PSO
        createPipelineState();

        // 10) Vertex buffer
        createVertexBuffer();

        // 11) Constant buffer
        createConstantBuffer();

        // 12) Fence
        {
            PointerByReference ppF = new PointerByReference();
            int hr = comCallInt(pDevice, VT.ID3D12Device_CreateFence, 0L, 0, REFIID(IID_ID3D12Fence), ppF);
            checkHR(hr, "CreateFence");
            pFence = ppF.getValue();
            fenceValue = 1;
            fenceEvent = Kernel32.INSTANCE.CreateEventW(Pointer.NULL, 0, 0, null);
        }

        System.out.println("D3D12 initialized OK");
    }

    static void createPipelineState() {
        // Root signature with CBV descriptor table
        // D3D12_DESCRIPTOR_RANGE (20 bytes, packed)
        // { RangeType(4), NumDescriptors(4), BaseShaderRegister(4), RegisterSpace(4), OffsetInDescriptorsFromTableStart(4) }
        Memory cbvRange = new Memory(20);
        cbvRange.clear();
        cbvRange.setInt(0, 2);    // RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_CBV
        cbvRange.setInt(4, 1);    // NumDescriptors
        cbvRange.setInt(8, 0);    // BaseShaderRegister (b0)
        cbvRange.setInt(12, 0);   // RegisterSpace
        cbvRange.setInt(16, 0xFFFFFFFF); // D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND

        // D3D12_ROOT_PARAMETER on x64 (32 bytes):
        // offset 0:  ParameterType (4 bytes)
        // offset 4:  padding (4 bytes to align union to 8)
        // offset 8:  union start - DescriptorTable.NumDescriptorRanges (4 bytes)
        // offset 12: padding within DescriptorTable (4 bytes)
        // offset 16: DescriptorTable.pDescriptorRanges (8 bytes)
        // offset 24: ShaderVisibility (4 bytes)
        // offset 28: padding (4 bytes)
        Memory rootParam = new Memory(32);
        rootParam.clear();
        rootParam.setInt(0, 0);    // ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE
        // offset 4-7: padding
        rootParam.setInt(8, 1);    // DescriptorTable.NumDescriptorRanges
        // offset 12-15: padding within DescriptorTable
        rootParam.setPointer(16, cbvRange); // DescriptorTable.pDescriptorRanges
        rootParam.setInt(24, 0);   // ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL

        // D3D12_ROOT_SIGNATURE_DESC on x64 (40 bytes):
        // offset 0:  NumParameters (4 bytes)
        // offset 4:  padding (4 bytes)
        // offset 8:  pParameters (8 bytes)
        // offset 16: NumStaticSamplers (4 bytes)
        // offset 20: padding (4 bytes)
        // offset 24: pStaticSamplers (8 bytes)
        // offset 32: Flags (4 bytes)
        // offset 36: padding (4 bytes)
        Memory rsDesc = new Memory(40);
        rsDesc.clear();
        rsDesc.setInt(0, 1);       // NumParameters
        rsDesc.setPointer(8, rootParam); // pParameters
        rsDesc.setInt(16, 0);      // NumStaticSamplers
        rsDesc.setPointer(24, Pointer.NULL); // pStaticSamplers
        rsDesc.setInt(32, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT); // Flags

        PointerByReference ppSig = new PointerByReference();
        PointerByReference ppErr = new PointerByReference();
        int hr = D3D12.INSTANCE.D3D12SerializeRootSignature(rsDesc, D3D_ROOT_SIGNATURE_VERSION_1, ppSig, ppErr);
        if (hr < 0 && ppErr.getValue() != null) {
            Pointer errBlob = ppErr.getValue();
            long errPtr = comCallLong(errBlob, VT_ID3DBlob_GetBufferPointer);
            String errMsg = new Pointer(errPtr).getString(0);
            System.err.println("Root signature error: " + errMsg);
        }
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
        PointerByReference ppVSErr = new PointerByReference();
        PointerByReference ppPSErr = new PointerByReference();
        
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "VSMain", "vs_5_0", 0, 0, ppVS, ppVSErr);
        if (hr < 0 && ppVSErr.getValue() != null) {
            long errPtr = comCallLong(ppVSErr.getValue(), VT_ID3DBlob_GetBufferPointer);
            System.err.println("VS compile error: " + new Pointer(errPtr).getString(0));
        }
        checkHR(hr, "D3DCompileFromFile(VS)");
        
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "PSMain", "ps_5_0", 0, 0, ppPS, ppPSErr);
        if (hr < 0 && ppPSErr.getValue() != null) {
            long errPtr = comCallLong(ppPSErr.getValue(), VT_ID3DBlob_GetBufferPointer);
            System.err.println("PS compile error: " + new Pointer(errPtr).getString(0));
        }
        checkHR(hr, "D3DCompileFromFile(PS)");

        Pointer blobVS = ppVS.getValue();
        Pointer blobPS = ppPS.getValue();

        long vsPtr = comCallLong(blobVS, VT_ID3DBlob_GetBufferPointer);
        long vsSize = comCallLong(blobVS, VT_ID3DBlob_GetBufferSize);
        long psPtr = comCallLong(blobPS, VT_ID3DBlob_GetBufferPointer);
        long psSize = comCallLong(blobPS, VT_ID3DBlob_GetBufferSize);

        // Input layout (position only, float2)
        Memory semPos = new Memory(9); semPos.setString(0, "POSITION", "ASCII");

        int elemSize = PTR_SIZE + 4*6;
        Memory layout = new Memory(elemSize);
        layout.clear();
        layout.setPointer(0, semPos);
        layout.setInt(PTR_SIZE + 0, 0);    // SemanticIndex
        layout.setInt(PTR_SIZE + 4, DXGI_FORMAT_R32G32_FLOAT); // Format
        layout.setInt(PTR_SIZE + 8, 0);    // InputSlot
        layout.setInt(PTR_SIZE + 12, 0);   // AlignedByteOffset
        layout.setInt(PTR_SIZE + 16, 0);   // D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
        layout.setInt(PTR_SIZE + 20, 0);   // InstanceDataStepRate

        // PSO desc
        D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC();
        psoDesc.pRootSignature = pRootSig;
        
        psoDesc.VS.pShaderBytecode = new Pointer(vsPtr);
        psoDesc.VS.BytecodeLength = vsSize;
        psoDesc.PS.pShaderBytecode = new Pointer(psPtr);
        psoDesc.PS.BytecodeLength = psSize;
        
        psoDesc.BlendState.AlphaToCoverageEnable = 0;
        psoDesc.BlendState.IndependentBlendEnable = 0;
        psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = (byte)0x0F;
        
        psoDesc.SampleMask = 0xFFFFFFFF;
        
        psoDesc.RasterizerState.FillMode = 3;  // D3D12_FILL_MODE_SOLID
        psoDesc.RasterizerState.CullMode = 1;  // D3D12_CULL_MODE_NONE
        psoDesc.RasterizerState.FrontCounterClockwise = 0;
        psoDesc.RasterizerState.DepthBias = 0;
        psoDesc.RasterizerState.DepthBiasClamp = 0.0f;
        psoDesc.RasterizerState.SlopeScaledDepthBias = 0.0f;
        psoDesc.RasterizerState.DepthClipEnable = 1;
        
        // Disable depth test
        psoDesc.DepthStencilState.DepthEnable = 0;
        
        psoDesc.InputLayout.pInputElementDescs = layout;
        psoDesc.InputLayout.NumElements = 1;
        
        psoDesc.PrimitiveTopologyType = 3;  // D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
        psoDesc.NumRenderTargets = 1;
        psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        psoDesc.DSVFormat = DXGI_FORMAT_UNKNOWN;
        psoDesc.SampleDesc.Count = 1;
        psoDesc.SampleDesc.Quality = 0;
        psoDesc.NodeMask = 0;
        psoDesc.Flags = 0;
        
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
        // Fullscreen quad (2 triangles, 6 vertices)
        // Position only (float2) - NDC coordinates
        float[] verts = new float[] {
            -1.0f,  1.0f,  // top-left
             1.0f,  1.0f,  // top-right
            -1.0f, -1.0f,  // bottom-left
             1.0f,  1.0f,  // top-right
             1.0f, -1.0f,  // bottom-right
            -1.0f, -1.0f   // bottom-left
        };
        int strideBytes = 2 * 4;  // float2
        int sizeBytes = verts.length * 4;

        D3D12_HEAP_PROPERTIES hp = new D3D12_HEAP_PROPERTIES();
        hp.Type = D3D12_HEAP_TYPE_UPLOAD;
        hp.CPUPageProperty = 0;
        hp.MemoryPoolPreference = 0;
        hp.CreationNodeMask = 1;
        hp.VisibleNodeMask = 1;
        hp.write();

        D3D12_RESOURCE_DESC rd = new D3D12_RESOURCE_DESC();
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Alignment = 0;
        rd.Width = sizeBytes;
        rd.Height = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels = 1;
        rd.Format = DXGI_FORMAT_UNKNOWN;
        rd.SampleDesc.Count = 1;
        rd.SampleDesc.Quality = 0;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        rd.Flags = 0;
        rd.write();

        PointerByReference pp = new PointerByReference();
        int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                hp.getPointer(), 0, rd.getPointer(),
                D3D12_RESOURCE_STATE_GENERIC_READ, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
        checkHR(hr, "CreateCommittedResource(VertexBuffer)");
        pVertexBuffer = pp.getValue();

        // Map and copy
        D3D12_RANGE readRange = new D3D12_RANGE();
        readRange.Begin = 0;
        readRange.End = 0;
        readRange.write();

        PointerByReference ppMapData = new PointerByReference();
        hr = comCallInt(pVertexBuffer, VT.ID3D12Resource_Map, 0, readRange.getPointer(), ppMapData);
        checkHR(hr, "Map(VertexBuffer)");

        Pointer mapPtr = ppMapData.getValue();
        ByteBuffer dstBuffer = mapPtr.getByteBuffer(0, sizeBytes).order(ByteOrder.LITTLE_ENDIAN);
        for (float v : verts) dstBuffer.putFloat(v);

        D3D12_RANGE writeRange = new D3D12_RANGE();
        writeRange.Begin = 0;
        writeRange.End = sizeBytes;
        writeRange.write();
        comCallVoid(pVertexBuffer, VT.ID3D12Resource_Unmap, 0, writeRange.getPointer());

        long gpuVA = comCallLong(pVertexBuffer, VT.ID3D12Resource_GetGPUVirtualAddress);

        vbView.BufferLocation = gpuVA;
        vbView.SizeInBytes = sizeBytes;
        vbView.StrideInBytes = strideBytes;
        vbView.write();
    }

    static void createConstantBuffer() {
        // 256 bytes aligned (D3D12 requirement)
        int sizeBytes = 256;

        D3D12_HEAP_PROPERTIES hp = new D3D12_HEAP_PROPERTIES();
        hp.Type = D3D12_HEAP_TYPE_UPLOAD;
        hp.CPUPageProperty = 0;
        hp.MemoryPoolPreference = 0;
        hp.CreationNodeMask = 1;
        hp.VisibleNodeMask = 1;
        hp.write();

        D3D12_RESOURCE_DESC rd = new D3D12_RESOURCE_DESC();
        rd.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        rd.Alignment = 0;
        rd.Width = sizeBytes;
        rd.Height = 1;
        rd.DepthOrArraySize = 1;
        rd.MipLevels = 1;
        rd.Format = DXGI_FORMAT_UNKNOWN;
        rd.SampleDesc.Count = 1;
        rd.SampleDesc.Quality = 0;
        rd.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        rd.Flags = 0;
        rd.write();

        PointerByReference pp = new PointerByReference();
        int hr = comCallInt(pDevice, VT.ID3D12Device_CreateCommittedResource,
                hp.getPointer(), 0, rd.getPointer(),
                D3D12_RESOURCE_STATE_GENERIC_READ, Pointer.NULL, REFIID(IID_ID3D12Resource), pp);
        checkHR(hr, "CreateCommittedResource(ConstantBuffer)");
        pConstantBuffer = pp.getValue();

        // Map (keep mapped)
        D3D12_RANGE readRange = new D3D12_RANGE();
        readRange.Begin = 0;
        readRange.End = 0;
        readRange.write();

        PointerByReference ppMapData = new PointerByReference();
        hr = comCallInt(pConstantBuffer, VT.ID3D12Resource_Map, 0, readRange.getPointer(), ppMapData);
        checkHR(hr, "Map(ConstantBuffer)");
        constantBufferDataBegin = ppMapData.getValue();

        // Create CBV
        long gpuVA = comCallLong(pConstantBuffer, VT.ID3D12Resource_GetGPUVirtualAddress);

        D3D12_CONSTANT_BUFFER_VIEW_DESC cbvDesc = new D3D12_CONSTANT_BUFFER_VIEW_DESC();
        cbvDesc.BufferLocation = gpuVA;
        cbvDesc.SizeInBytes = sizeBytes;
        cbvDesc.write();

        long cbvCpuHandle = getCpuHandleStart(pCbvHeap);
        comCallVoid(pDevice, VT.ID3D12Device_CreateConstantBufferView, cbvDesc.getPointer(), cbvCpuHandle);
    }

    static void render() {
        long frameStartTime = System.nanoTime();
        
        // Update constant buffer
        float elapsedTime = (float)((System.nanoTime() - startTimeNanos) / 1_000_000_000.0);
        ByteBuffer cb = constantBufferDataBegin.getByteBuffer(0, 16).order(ByteOrder.LITTLE_ENDIAN);
        cb.putFloat(0, elapsedTime);          // iTime
        cb.putFloat(4, (float)WIDTH);         // iResolution.x
        cb.putFloat(8, (float)HEIGHT);        // iResolution.y
        cb.putFloat(12, 0.0f);                // padding

        // Reset allocator and command list
        checkHR(comCallInt(pCmdAlloc, VT.ID3D12CommandAllocator_Reset), "CommandAllocator::Reset");
        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Reset, pCmdAlloc, pPSO), "CommandList::Reset");

        // Set root signature
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootSignature, pRootSig);

        // Set descriptor heaps
        Memory ppHeaps = new Memory(PTR_SIZE);
        ppHeaps.setPointer(0, pCbvHeap);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetDescriptorHeaps, 1, ppHeaps);

        // Set root descriptor table
        long gpuHandle = getGpuHandleStart(pCbvHeap);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable, 0, gpuHandle);

        // Viewport
        D3D12_VIEWPORT vp = new D3D12_VIEWPORT();
        vp.TopLeftX = 0;
        vp.TopLeftY = 0;
        vp.Width = WIDTH;
        vp.Height = HEIGHT;
        vp.MinDepth = 0.0f;
        vp.MaxDepth = 1.0f;
        vp.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetViewports, 1, vp.getPointer());

        // Scissor
        D3D12_RECT sc = new D3D12_RECT();
        sc.left = 0; sc.top = 0; sc.right = WIDTH; sc.bottom = HEIGHT;
        sc.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_RSSetScissorRects, 1, sc.getPointer());

        // Barrier: Present -> RenderTarget
        D3D12_RESOURCE_BARRIER b1 = new D3D12_RESOURCE_BARRIER();
        b1.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b1.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        b1.Transition.pResource = pRenderTargets[frameIndex];
        b1.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b1.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        b1.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        b1.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, b1.getPointer());

        // RTV handle
        long rtv = rtvHandles[frameIndex];

        // Clear
        float[] clear = new float[] { 0f, 0f, 0f, 1f };
        Memory clearMem = new Memory(16);
        clearMem.write(0, clear, 0, 4);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ClearRenderTargetView, rtv, clearMem, 0, Pointer.NULL);

        // OMSetRenderTargets
        Memory rtvArray = new Memory(8);
        rtvArray.setLong(0, rtv);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_OMSetRenderTargets, 1, rtvArray, 1, Pointer.NULL);

        // IA setup
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_IASetVertexBuffers, 0, 1, vbView.getPointer());

        // Draw (6 vertices for fullscreen quad)
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_DrawInstanced, 6, 1, 0, 0);

        // Barrier: RenderTarget -> Present
        D3D12_RESOURCE_BARRIER b2 = new D3D12_RESOURCE_BARRIER();
        b2.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        b2.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
        b2.Transition.pResource = pRenderTargets[frameIndex];
        b2.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        b2.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        b2.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        b2.write();
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ResourceBarrier, 1, b2.getPointer());

        // Close and execute
        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close), "CommandList::Close");

        Memory ppLists = new Memory(PTR_SIZE);
        ppLists.setPointer(0, pCmdList);
        comCallVoid(pQueue, VT.ID3D12CommandQueue_ExecuteCommandLists, 1, ppLists);

        // Measure CPU time (before Present and GPU wait)
        long cpuEndTime = System.nanoTime();
        cpuTimeMs = (cpuEndTime - frameStartTime) / 1_000_000.0;

        // Present (VSync disabled for max performance measurement, set to 1 for VSync)
        comCallInt(pSwapChain3, VT.IDXGISwapChain_Present, 0, 0);

        // GPU synchronization
        long gpuWaitStart = System.nanoTime();
        waitForPreviousFrame();
        long gpuWaitEnd = System.nanoTime();
        gpuWaitTimeMs = (gpuWaitEnd - gpuWaitStart) / 1_000_000.0;

        // Frame timing
        long frameEndTime = System.nanoTime();
        double frameTimeMs = (frameEndTime - frameStartTime) / 1_000_000.0;
        frameCount++;

        // Update FPS every 500ms
        long now = System.nanoTime();
        long timeSinceLastUpdate = now - lastFpsUpdateTime;
        if (timeSinceLastUpdate >= 500_000_000L) { // 500ms
            currentFps = frameCount * 1_000_000_000.0 / timeSinceLastUpdate;
            avgFrameTimeMs = timeSinceLastUpdate / 1_000_000.0 / frameCount;
            frameCount = 0;
            lastFpsUpdateTime = now;

            // Update window title with performance info
            if (shellRef != null && !shellRef.isDisposed()) {
                String title = String.format("Raymarching - DX12/Java | FPS: %.1f | Frame: %.2fms | CPU: %.2fms | GPU Wait: %.2fms",
                    currentFps, avgFrameTimeMs, cpuTimeMs, gpuWaitTimeMs);
                shellRef.setText(title);
            }

            // Print to console every update
            System.out.printf("FPS: %6.1f | Frame: %6.2fms | CPU: %5.2fms | GPU Wait: %6.2fms | iTime: %.2fs%n",
                currentFps, avgFrameTimeMs, cpuTimeMs, gpuWaitTimeMs, elapsedTime);
        }
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

        safeRelease(pConstantBuffer);
        safeRelease(pVertexBuffer);
        for (int i=0;i<FRAMES;i++) safeRelease(pRenderTargets[i]);
        safeRelease(pCmdList);
        safeRelease(pCmdAlloc);
        safeRelease(pCbvHeap);
        safeRelease(pRtvHeap);
        safeRelease(pPSO);
        safeRelease(pRootSig);
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
