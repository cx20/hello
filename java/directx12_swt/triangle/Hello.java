// Java + SWT + JNA : DirectX 12 triangle (no external wrapper libs)
// - Creates an SWT Shell (HWND) and renders a colored triangle via D3D12 + DXGI.
// - Uses "manual COM vtable calls" similar to the C sample provided by the user.
// - Enables D3D12 debug layer (ID3D12Debug) when available; also tries ID3D12InfoQueue.
//
// Build (example):
//   javac -cp <swt_jar>;<jna_jar>;.; Hello.java
// Run:
//   java  -cp <swt_jar>;<jna_jar>;.; Hello
//
// Notes:
// - Requires Windows 10/11 + D3D12 capable GPU/driver.
// - Requires d3d12.dll, dxgi.dll, d3dcompiler_47.dll present (normally on Windows).
// - Expects hello.hlsl in current working directory (same as your C sample).
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
    // On Windows x64, all functions (including COM methods) use the Microsoft x64 calling convention.
    // This corresponds to Function.C_CONVENTION (the default) in JNA, NOT ALT_CONVENTION (stdcall).
    // stdcall (ALT_CONVENTION) is only for 32-bit Windows.
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



// Some D3D12 methods return small structs BY VALUE (e.g., D3D12_CPU_DESCRIPTOR_HANDLE).
// On Win64 this is still a "struct return" ABI, which JNA must be told explicitly.
static long comCallCpuHandle(Pointer comObj, int index) {
    // D3D12_CPU_DESCRIPTOR_HANDLE is 8 bytes (SIZE_T ptr) on Win64.
    // Calling the COM method as a plain 64-bit integer return is reliable with JNA.
    return comCallLong(comObj, index);
}
    
    // Robust resolver for ID3D12DescriptorHeap vtable indices:
// - ID3D12DescriptorHeap has methods: GetDesc, GetCPUDescriptorHandleForHeapStart, GetGPUDescriptorHandleForHeapStart.
// - Different hand-written vtable tables are often off-by-one; to avoid calling the GPU-handle method on a non
//   shader-visible heap (which triggers debug-layer errors), we first resolve GetDesc by sanity-checking the returned
//   descriptor heap description, then derive the CPU-handle index as (GetDescIndex + 1).
static int resolveDescriptorHeapGetDescIndex(Pointer heap) {
    System.out.println("[DEBUG] resolveDescriptorHeapGetDescIndex: heap=" + heap);
    int[] candidates = new int[] {
        VT.ID3D12DescriptorHeap_GetDesc,
        VT.ID3D12DescriptorHeap_GetDesc + 1,
        VT.ID3D12DescriptorHeap_GetDesc - 1
    };
    for (int idx : candidates) {
        try {
            System.out.println("[DEBUG] Trying GetDesc vtable index: " + idx);
            D3D12_DESCRIPTOR_HEAP_DESC.ByValue desc = comCallStructByValue(heap, idx, D3D12_DESCRIPTOR_HEAP_DESC.ByValue.class);
            System.out.println("[DEBUG] GetDesc returned: desc=" + desc + ", Type=" + (desc != null ? desc.Type : "null") + ", NumDescriptors=" + (desc != null ? desc.NumDescriptors : "null") + ", Flags=" + (desc != null ? desc.Flags : "null") + ", NodeMask=" + (desc != null ? desc.NodeMask : "null"));
            // Sanity checks (RTV heap in this sample): Type==D3D12_DESCRIPTOR_HEAP_TYPE_RTV(2), Flags==NONE(0),
            // NumDescriptors==FRAMES(2), NodeMask==0. We keep checks broad to allow small edits.
            if (desc != null
                    && desc.Type >= 0 && desc.Type <= 4
                    && desc.NumDescriptors > 0 && desc.NumDescriptors <= 8192
                    && desc.Flags >= 0 && desc.Flags <= 0xFF
                    && desc.NodeMask >= 0 && desc.NodeMask <= 0xFF) {
                System.out.println("[DEBUG] Resolved GetDesc index: " + idx);
                return idx;
            } else {
                System.out.println("[DEBUG] Sanity check failed for index " + idx);
            }
        } catch (Throwable t) {
            // Bad vtable index can cause "Invalid memory access" (JNA Error) or other issues; ignore and try next.
            System.out.println("[DEBUG] Exception for index " + idx + ": " + t.getClass().getSimpleName() + " - " + t.getMessage());
        }
    }
    System.out.println("[DEBUG] Failed to resolve GetDesc index, returning -1");
    return -1;
}

static long getCpuHandleStart(Pointer heap) {
    System.out.println("[DEBUG] getCpuHandleStart: heap=" + heap);
    
    // GetCPUDescriptorHandleForHeapStart takes an output parameter, not a return value.
    // Signature: void GetCPUDescriptorHandleForHeapStart(D3D12_CPU_DESCRIPTOR_HANDLE* pRetVal)
    int idxCPU = VT.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart;
    System.out.println("[DEBUG] Using vtable index: " + idxCPU);

    try {
        System.out.println("[DEBUG] Calling GetCPUDescriptorHandleForHeapStart with output parameter");
        
        // Allocate a structure to receive the result
        D3D12_CPU_DESCRIPTOR_HANDLE handle = new D3D12_CPU_DESCRIPTOR_HANDLE();
        handle.write(); // Ensure memory is allocated
        
        // Call the method: void GetCPUDescriptorHandleForHeapStart(this, D3D12_CPU_DESCRIPTOR_HANDLE* pRetVal)
        comCallVoid(heap, idxCPU, handle.getPointer());
        
        // Read back the result
        handle.read();
        
        long ptr = handle.ptr;
        System.out.println("[DEBUG] Returned ptr: 0x" + Long.toHexString(ptr));
        if (ptr != 0) {
            System.out.println("DescriptorHeap CPU handle start: vtblIndex=" + idxCPU + " ptr=0x" + Long.toHexString(ptr));
        } else {
            System.out.println("[DEBUG] WARNING: GetCPUDescriptorHandleForHeapStart returned ptr=0");
        }
        return ptr;
    } catch (Throwable t) {
        System.out.println("[DEBUG] Exception in getCpuHandleStart: " + t.getClass().getSimpleName() + " - " + t.getMessage());
        t.printStackTrace();
        return 0;
    }
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
            // "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
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

    // Helper: pass REFIID as pointer explicitly (avoids JNA Structure-by-value ambiguity)
    static Pointer REFIID(GUID g) {
        g.write();
        return g.getPointer();
    }

    // D3D12 / DXGI IIDs (stable)
    static final GUID IID_IDXGIFactory4      = new GUID("1bc6ea02-ef36-464f-bf0c-21ca39e5168a");
    static final GUID IID_IDXGISwapChain3    = new GUID("94d99bdb-f1f8-4ab0-b236-7da0170edab1");
    static final GUID IID_ID3D12Device       = new GUID("189819f1-1db6-4b57-be54-1821339b85f7");
    static final GUID IID_ID3D12CommandQueue = new GUID("0ec870a6-5d7e-4c22-8cfc-5baae07616ed");
    static final GUID IID_ID3D12DescriptorHeap = new GUID("8efb471d-616c-4f49-90f7-127bb763fa51");
    static final GUID IID_ID3D12Resource     = new GUID("696442be-a72e-4059-bc79-5b5c98040fad");
    static final GUID IID_ID3D12CommandAllocator = new GUID("6102dee4-af59-4b09-b999-b44d73f09b24");
    static final GUID IID_ID3D12GraphicsCommandList = new GUID("5b160d0f-ac1b-4185-8ba8-b3ae42a5a455");
    static final GUID IID_ID3D12CommandList  = new GUID("7116d91c-e7e4-47ce-b8c6-ec8168f437e5");
    static final GUID IID_ID3D12Fence        = new GUID("0a753dcf-c4d8-4b91-adf6-be5a60d95a76");
    static final GUID IID_ID3D12RootSignature = new GUID("c54a6b66-72df-4ee8-8be5-a946a1429214");
    static final GUID IID_ID3D12PipelineState = new GUID("765a30f3-f624-4c6f-a828-ace948622445");
    static final GUID IID_ID3D12Debug        = new GUID("344488b7-6846-474b-b989-f027448245e0");
    static final GUID IID_ID3D12InfoQueue    = new GUID("0742a90b-c387-483f-b946-30a7e4e61458");

    // ========= Minimal structs =========
    public static class D3D12_COMMAND_QUEUE_DESC extends Structure {
        public int Type;       // D3D12_COMMAND_LIST_TYPE_*
        public int Priority;
        public int Flags;      // D3D12_COMMAND_QUEUE_FLAG_*
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
        public Pointer OutputWindow; // HWND
        public int Windowed;         // BOOL
        public int SwapEffect;
        public int Flags;
        @Override protected java.util.List<String> getFieldOrder() {
            return java.util.Arrays.asList("BufferDesc","SampleDesc","BufferUsage","BufferCount","OutputWindow","Windowed","SwapEffect","Flags");
        }
    }

    public static class D3D12_DESCRIPTOR_HEAP_DESC extends Structure {
        public int Type;   // D3D12_DESCRIPTOR_HEAP_TYPE_*
        public int NumDescriptors;
        public int Flags;  // D3D12_DESCRIPTOR_HEAP_FLAG_*
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

    // ===== PSO Structures (using JNA @Structure.FieldOrder) =====
    
    @Structure.FieldOrder({"pShaderBytecode", "BytecodeLength"})
    public static class D3D12_SHADER_BYTECODE extends Structure {
        public Pointer pShaderBytecode;
        public long BytecodeLength;  // SIZE_T on x64 is 8 bytes
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
        public Pointer pResource; // ID3D12Resource*
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
        // union: we only use Transition
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

    // ========= D3DCompiler (D3DCompileFromFile) =========
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

    // ========= A few D3D12 / DXGI constants =========
    static final int WIDTH = 640;
    static final int HEIGHT = 480;
    static final int FRAMES = 2;

    // Feature levels
    static final int D3D_FEATURE_LEVEL_12_0 = 0xC000;

    // D3D12 command list types
    static final int D3D12_COMMAND_LIST_TYPE_DIRECT = 0;

    // DXGI format
    static final int DXGI_FORMAT_R8G8B8A8_UNORM = 28;
    static final int DXGI_FORMAT_UNKNOWN = 0;

    // Swap effect
    static final int DXGI_SWAP_EFFECT_DISCARD = 0x0;
        static final int DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 0x3;
    static final int DXGI_SWAP_EFFECT_FLIP_DISCARD = 0x4;
// Buffer usage (same as your C: 1L << (1+4) -> DXGI_USAGE_RENDER_TARGET_OUTPUT)
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;

    // D3D12 descriptor heap type
    static final int D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2;
    static final int D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;

    // D3D12 heap type
    static final int D3D12_HEAP_TYPE_UPLOAD = 1;

    // D3D12 resource dimension/layout
    static final int D3D12_RESOURCE_DIMENSION_BUFFER = 1;
    static final int D3D12_TEXTURE_LAYOUT_ROW_MAJOR = 1;

    // D3D12 resource states
    static final int D3D12_RESOURCE_STATE_PRESENT = 0;
    static final int D3D12_RESOURCE_STATE_RENDER_TARGET = 0x4;
    static final int D3D12_RESOURCE_STATE_GENERIC_READ = 0x1;

    // Barrier
    static final int D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
    static final int D3D12_RESOURCE_BARRIER_FLAG_NONE = 0;
    static final int D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;

    // Topology
    static final int D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4; // D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST

    // Root signature
    static final int D3D_ROOT_SIGNATURE_VERSION_1 = 1;
    static final int D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1;

    // ========= VTable indices (from the user's vtable.txt) =========
    static final class VT {
        // IUnknown
        static final int QI = 0;
        static final int ADDREF = 1;
        static final int RELEASE = 2;

        // IDXGIFactory::CreateSwapChain
        static final int IDXGIFactory_CreateSwapChain = 10;

        // IDXGISwapChain
        static final int IDXGISwapChain_Present = 8;
        static final int IDXGISwapChain_GetBuffer = 9;

        // IDXGISwapChain3
        static final int IDXGISwapChain3_GetCurrentBackBufferIndex = 36;

        // ID3D12Device
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

        // ID3D12DescriptorHeap
        // method: GetCPUDescriptorHandleForHeapStart is NOT in vtable list above; it is on ID3D12DescriptorHeap:
        // It is usually index 9 after ID3D12Pageable; in your C sample it casts to function pointer.
        // We'll resolve it by vtable index from docs pattern:
        // IUnknown(0-2), ID3D12Object(3-6), ID3D12DeviceChild(7), ID3D12Pageable(8), then:
        // #9 ID3D12DescriptorHeap::GetDesc, #10 GetCPUDescriptorHandleForHeapStart, #11 GetGPUDescriptorHandleForHeapStart
        static final int ID3D12DescriptorHeap_GetDesc = 8;
static final int ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart = 9;
static final int ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart = 10;
// ID3D12CommandAllocator
        static final int ID3D12CommandAllocator_Reset = 8;

        // ID3D12GraphicsCommandList
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

        // ID3D12CommandQueue
        static final int ID3D12CommandQueue_ExecuteCommandLists = 10;
        static final int ID3D12CommandQueue_Signal = 14;

        // ID3D12Fence
        static final int ID3D12Fence_GetCompletedValue = 8;
        static final int ID3D12Fence_SetEventOnCompletion = 9;

        // ID3D12Resource (we need Map/Unmap/GetGPUVirtualAddress)
        // IUnknown(0-2), ID3D12Object(3-6), ID3D12DeviceChild(7), ID3D12Pageable(8),
        // ID3D12Resource:
        // #9 Map, #10 Unmap, #11 GetDesc, #12 GetGPUVirtualAddress, ...
        static final int ID3D12Resource_Map = 8;
        static final int ID3D12Resource_Unmap = 9;
        static final int ID3D12Resource_GetGPUVirtualAddress = 11;
    }

    // ========= D3DBlob (ID3DBlob) methods (GetBufferPointer/GetBufferSize) =========
    // ID3D10Blob / ID3DBlob vtbl: IUnknown(0-2), GetBufferPointer=3, GetBufferSize=4
    static final int VT_ID3DBlob_GetBufferPointer = 3;
    static final int VT_ID3DBlob_GetBufferSize = 4;

    // ========= Globals =========
    static Pointer pFactory;       // IDXGIFactory4*
    static Pointer pSwapChain3;    // IDXGISwapChain3*
    static Pointer pDevice;        // ID3D12Device*
    static Pointer pQueue;         // ID3D12CommandQueue*
    static Pointer pRtvHeap;       // ID3D12DescriptorHeap*
    static Pointer pCmdAlloc;      // ID3D12CommandAllocator*
    static Pointer pCmdList;       // ID3D12GraphicsCommandList*
    static Pointer pFence;         // ID3D12Fence*
    static long fenceValue = 1;
    static Pointer fenceEvent;     // HANDLE
    static int frameIndex = 0;

    static Pointer[] pRenderTargets = new Pointer[FRAMES]; // ID3D12Resource*[2]
    static int rtvDescriptorSize = 0;
    static long[] rtvHandles = new long[FRAMES]; // D3D12_CPU_DESCRIPTOR_HANDLE ptr values for each backbuffer RTV

    static Pointer pRootSig;
    static Pointer pPSO;
    static Pointer pVertexBuffer; // ID3D12Resource*
    static D3D12_VERTEX_BUFFER_VIEW vbView = new D3D12_VERTEX_BUFFER_VIEW();

    // Debug
    static Pointer pD3D12Debug;
    static Pointer pInfoQueue;

    // ========= Kernel32 for events =========
    public interface Kernel32 extends Library {
        Kernel32 INSTANCE = Native.load("kernel32", Kernel32.class);
        Pointer CreateEventW(Pointer lpEventAttributes, int bManualReset, int bInitialState, WString lpName);
        int CloseHandle(Pointer hObject);
        int WaitForSingleObject(Pointer hHandle, int dwMilliseconds);
    }
    static final int WAIT_OBJECT_0 = 0;
    static final int INFINITE = 0xFFFFFFFF;

    // ========= Main =========
    public static void main(String[] args) {
        Display display = new Display();
        Shell shell = new Shell(display);
        shell.setText("Hello, World!");
        shell.setSize(WIDTH, HEIGHT);
        shell.open();

        long hwndLong = shell.handle; // SWT Win32 HWND
        Pointer hwnd = new Pointer(hwndLong);

        System.out.println("HWND=0x" + Long.toHexString(hwndLong));

        initD3D12(hwnd);

        // Basic render loop (SWT pump + render)
        while (!shell.isDisposed()) {
            while (display.readAndDispatch()) {}
            render();
            // keep CPU low
            display.sleep();
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
                // ID3D12Debug::EnableDebugLayer is vtbl index:
                // IUnknown(0-2), ID3D12Debug::EnableDebugLayer is #3
                comCallVoid(pD3D12Debug, 3);
                System.out.println("D3D12 debug layer enabled");
            } else {
                System.out.println(String.format("D3D12GetDebugInterface not available: 0x%08X (continuing without debug layer)", hr));
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

            // ID3D12InfoQueue (optional) via QueryInterface
            PointerByReference ppIQ = new PointerByReference();
            hr = comCallInt(pDevice, VT.QI, REFIID(IID_ID3D12InfoQueue), ppIQ);
            if (hr == S_OK) {
                pInfoQueue = ppIQ.getValue();
                System.out.println("ID3D12InfoQueue: " + pInfoQueue);
                // You can add SetBreakOnSeverity etc by vtable indices if needed.
            } else {
                System.out.println(String.format("ID3D12InfoQueue not available: 0x%08X", hr));
            }
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
            System.out.println("CommandQueue: " + pQueue);
        }

        // 5) SwapChain (legacy DXGI_SWAP_CHAIN_DESC like your C sample)
        {
            DXGI_SWAP_CHAIN_DESC sc = new DXGI_SWAP_CHAIN_DESC();
            sc.BufferDesc.Width = WIDTH;
            sc.BufferDesc.Height = HEIGHT;
            sc.BufferDesc.RefreshRate.Numerator = 0;
            sc.BufferDesc.RefreshRate.Denominator = 0;
            sc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            sc.BufferDesc.ScanlineOrdering = 0;
            sc.BufferDesc.Scaling = 0;
            sc.SampleDesc.Count = 1;
            sc.SampleDesc.Quality = 0;
            sc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
            sc.BufferCount = FRAMES;
            sc.OutputWindow = hwnd;
            sc.Windowed = 1;
            sc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
            sc.Flags = 0;
            sc.write();

            // IDXGIFactory::CreateSwapChain(factory, IUnknown* pDevice, desc, IDXGISwapChain**)
            PointerByReference ppSwap = new PointerByReference();
            int hr = comCallInt(pFactory, VT.IDXGIFactory_CreateSwapChain, pQueue, sc.getPointer(), ppSwap);
            checkHR(hr, "CreateSwapChain");
            Pointer pSwapChain = ppSwap.getValue();

            // QueryInterface to IDXGISwapChain3
            PointerByReference ppSwap3 = new PointerByReference();
            hr = comCallInt(pSwapChain, VT.QI, REFIID(IID_IDXGISwapChain3), ppSwap3);
            checkHR(hr, "SwapChain::QueryInterface(IDXGISwapChain3)");
            pSwapChain3 = ppSwap3.getValue();

            // release base swapchain
            comCallInt(pSwapChain, VT.RELEASE);

            // frame index
            frameIndex = (int)comCallInt(pSwapChain3, VT.IDXGISwapChain3_GetCurrentBackBufferIndex);
            System.out.println("SwapChain3: " + pSwapChain3 + " frameIndex=" + frameIndex);
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

            // ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart returns D3D12_CPU_DESCRIPTOR_HANDLE BY VALUE (8 bytes).
            // On x64 we can safely treat it as a 64-bit integer (RAX) in JNA.
            long rtvStart = getCpuHandleStart(pRtvHeap);
            if (rtvStart == 0) throw new RuntimeException("GetCPUDescriptorHandleForHeapStart returned 0");

            for (int i = 0; i < FRAMES; i++) {
                PointerByReference ppRT = new PointerByReference();
                hr = comCallInt(pSwapChain3, VT.IDXGISwapChain_GetBuffer, i, REFIID(IID_ID3D12Resource), ppRT);
                checkHR(hr, "SwapChain::GetBuffer");
                pRenderTargets[i] = ppRT.getValue();

                rtvHandles[i] = rtvStart + (long)i * (long)rtvDescriptorSize;

                // ID3D12Device::CreateRenderTargetView takes the CPU descriptor handle BY VALUE.
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
            pCmdList = ppCL.getValue(); // actually ID3D12GraphicsCommandList* compatible

            // Close once (same pattern as many samples)
            comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Close);
        }

        // 8) Root signature + PSO
        createPipelineState();

        // 9) Vertex buffer (upload heap)
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
        // Root signature: empty, allow IA input layout
        // D3D12_ROOT_SIGNATURE_DESC:
        // UINT NumParameters (4), [pad 4], D3D12_ROOT_PARAMETER* pParameters (8),
        // UINT NumStaticSamplers (4), [pad 4], D3D12_STATIC_SAMPLER_DESC* pStaticSamplers (8),
        // D3D12_ROOT_SIGNATURE_FLAGS Flags (4), [pad 4]
        // Total: 40 bytes on x64
        Memory rsDesc = new Memory(40);
        rsDesc.clear();
        long o = 0;
        rsDesc.setInt((int)o, 0); o += 4; // NumParameters
        o = (o + 7) & ~7; // align to 8
        rsDesc.setPointer((int)o, Pointer.NULL); o += PTR_SIZE; // pParameters
        rsDesc.setInt((int)o, 0); o += 4; // NumStaticSamplers
        o = (o + 7) & ~7; // align to 8
        rsDesc.setPointer((int)o, Pointer.NULL); o += PTR_SIZE; // pStaticSamplers
        rsDesc.setInt((int)o, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT); // Flags

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

        // Compile shaders from hello.hlsl (same as the C sample)
        PointerByReference ppVS = new PointerByReference();
        PointerByReference ppPS = new PointerByReference();
        int compileFlags = 0; // add D3DCOMPILE_DEBUG if you want
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "VSMain", "vs_5_0", compileFlags, 0, ppVS, new PointerByReference());
        checkHR(hr, "D3DCompileFromFile(VS)");
        hr = D3DCompiler.INSTANCE.D3DCompileFromFile(new WString("hello.hlsl"), Pointer.NULL, Pointer.NULL, "PSMain", "ps_5_0", compileFlags, 0, ppPS, new PointerByReference());
        checkHR(hr, "D3DCompileFromFile(PS)");
        Pointer blobVS = ppVS.getValue();
        Pointer blobPS = ppPS.getValue();

        long vsPtr = comCallLong(blobVS, VT_ID3DBlob_GetBufferPointer);
        long vsSize = comCallLong(blobVS, VT_ID3DBlob_GetBufferSize);
        long psPtr = comCallLong(blobPS, VT_ID3DBlob_GetBufferPointer);
        long psSize = comCallLong(blobPS, VT_ID3DBlob_GetBufferSize);

        // Create semantic name strings (keep references to prevent GC)
        Memory semPos = new Memory(9); semPos.setString(0, "POSITION", "ASCII");
        Memory semCol = new Memory(6); semCol.setString(0, "COLOR", "ASCII");

        // Build input layout structure  
        int D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0;
        int elemSize = PTR_SIZE + 4*6; // pointer + 6 UINTs
        Memory layout = new Memory((long)elemSize * 2);
        layout.clear();

        // element 0: POSITION (float3)
        long base0 = 0;
        layout.setPointer(base0 + 0, semPos);
        layout.setInt(base0 + PTR_SIZE + 0, 0);               // SemanticIndex
        layout.setInt(base0 + PTR_SIZE + 4, 6);               // DXGI_FORMAT_R32G32B32_FLOAT
        layout.setInt(base0 + PTR_SIZE + 8, 0);               // InputSlot
        layout.setInt(base0 + PTR_SIZE + 12, 0);              // AlignedByteOffset
        layout.setInt(base0 + PTR_SIZE + 16, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA);
        layout.setInt(base0 + PTR_SIZE + 20, 0);              // InstanceDataStepRate

        // element 1: COLOR (float4)
        long base1 = (long)elemSize;
        layout.setPointer(base1 + 0, semCol);
        layout.setInt(base1 + PTR_SIZE + 0, 0);
        layout.setInt(base1 + PTR_SIZE + 4, 2);               // DXGI_FORMAT_R32G32B32A32_FLOAT
        layout.setInt(base1 + PTR_SIZE + 8, 0);
        layout.setInt(base1 + PTR_SIZE + 12, 12);             // offset 12
        layout.setInt(base1 + PTR_SIZE + 16, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA);
        layout.setInt(base1 + PTR_SIZE + 20, 0);

        // Build D3D12_GRAPHICS_PIPELINE_STATE_DESC using JNA Structure
        System.out.println("[DEBUG] VS: ptr=0x" + Long.toHexString(vsPtr) + " size=" + vsSize);
        System.out.println("[DEBUG] PS: ptr=0x" + Long.toHexString(psPtr) + " size=" + psSize);
        
        D3D12_GRAPHICS_PIPELINE_STATE_DESC psoDesc = new D3D12_GRAPHICS_PIPELINE_STATE_DESC();
        psoDesc.pRootSignature = pRootSig;
        
        // Ensure nested structures are initialized
        if (psoDesc.VS == null) psoDesc.VS = new D3D12_SHADER_BYTECODE();
        if (psoDesc.PS == null) psoDesc.PS = new D3D12_SHADER_BYTECODE();
        if (psoDesc.DS == null) psoDesc.DS = new D3D12_SHADER_BYTECODE();
        if (psoDesc.HS == null) psoDesc.HS = new D3D12_SHADER_BYTECODE();
        if (psoDesc.GS == null) psoDesc.GS = new D3D12_SHADER_BYTECODE();
        
        // Set VS and PS bytecode (use pointers directly)
        psoDesc.VS.pShaderBytecode = new Pointer(vsPtr);
        psoDesc.VS.BytecodeLength = vsSize;
        psoDesc.PS.pShaderBytecode = new Pointer(psPtr);
        psoDesc.PS.BytecodeLength = psSize;
        
        // DS, HS, GS are left as null/0 (default)
        
        psoDesc.BlendState.AlphaToCoverageEnable = 0;
        psoDesc.BlendState.IndependentBlendEnable = 0;
        psoDesc.BlendState.RenderTarget[0].RenderTargetWriteMask = (byte)0x0F;
        
        psoDesc.SampleMask = 0xFFFFFFFF;
        
        psoDesc.RasterizerState.FillMode = 3;  // D3D12_FILL_MODE_SOLID
        psoDesc.RasterizerState.CullMode = 3;  // D3D12_CULL_MODE_BACK
        psoDesc.RasterizerState.FrontCounterClockwise = 0;
        psoDesc.RasterizerState.DepthBias = 0;
        psoDesc.RasterizerState.DepthBiasClamp = 0.0f;
        psoDesc.RasterizerState.SlopeScaledDepthBias = 0.0f;
        psoDesc.RasterizerState.DepthClipEnable = 1;
        psoDesc.RasterizerState.MultisampleEnable = 0;
        psoDesc.RasterizerState.AntialiasedLineEnable = 0;
        psoDesc.RasterizerState.ForcedSampleCount = 0;
        psoDesc.RasterizerState.ConservativeRaster = 0;
        
        // DepthStencilState - leave as zeros
        
        // InputLayout - disabled since we use SV_VertexID instead of vertex buffer
        psoDesc.InputLayout.pInputElementDescs = Pointer.NULL;
        psoDesc.InputLayout.NumElements = 0;
        
        psoDesc.IBStripCutValue = 0;
        psoDesc.PrimitiveTopologyType = 3;  // D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
        psoDesc.NumRenderTargets = 1;
        psoDesc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        // RTVFormats[1..7] are left as DXGI_FORMAT_UNKNOWN (0)
        psoDesc.DSVFormat = DXGI_FORMAT_UNKNOWN;
        psoDesc.SampleDesc.Count = 1;
        psoDesc.SampleDesc.Quality = 0;
        psoDesc.NodeMask = 0;
        // CachedPSO - leave as null/0
        psoDesc.Flags = 0;
        
        psoDesc.write();  // Write structure to memory

        PointerByReference ppPSO = new PointerByReference();
        System.out.println("[DEBUG] Calling CreateGraphicsPipelineState...");
        
        // Call CreateGraphicsPipelineState: HRESULT CreateGraphicsPipelineState(const D3D12_GRAPHICS_PIPELINE_STATE_DESC *pDesc, REFIID riid, void **ppPipelineState)
        hr = comCallInt(pDevice, VT.ID3D12Device_CreateGraphicsPipelineState, psoDesc.getPointer(), REFIID(IID_ID3D12PipelineState), ppPSO);
        checkHR(hr, "CreateGraphicsPipelineState");
        pPSO = ppPSO.getValue();

        // Release blobs
        comCallInt(blobSig, VT.RELEASE);
        comCallInt(blobVS, VT.RELEASE);
        comCallInt(blobPS, VT.RELEASE);
    }

    // Helper to build a D3D12_GRAPHICS_PIPELINE_STATE_DESC memory blob with correct offsets for x64.
    // This is the only "delicate" part; it matches the common MSVC layout.


    static void createVertexBuffer() {
        // vertices: position.xyz + color.rgba (float)
        float[] verts = new float[] {
                0.0f,  0.5f, 0.0f,   1f,0f,0f,1f,
                0.5f, -0.5f, 0.0f,   0f,1f,0f,1f,
               -0.5f, -0.5f, 0.0f,   0f,0f,1f,1f
        };
        int strideBytes = (3+4)*4;
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
        System.out.println("[DEBUG] CreateCommittedResource returned: 0x" + Integer.toHexString(hr));
        checkHR(hr, "CreateCommittedResource(VertexBuffer)");
        pVertexBuffer = pp.getValue();
        System.out.println("[DEBUG] Created VertexBuffer: " + pVertexBuffer);
        if (pVertexBuffer == null || pVertexBuffer == Pointer.NULL) {
            throw new RuntimeException("VertexBuffer is null!");
        }

        // Create a temporary CPU-side buffer for vertex data
        Memory vertexData = new Memory(sizeBytes);
        ByteBuffer bb = vertexData.getByteBuffer(0, sizeBytes).order(ByteOrder.LITTLE_ENDIAN);
        for (float v : verts) bb.putFloat(v);

        // Try to Map the buffer and copy data
        D3D12_RANGE readRange = new D3D12_RANGE();
        readRange.Begin = 0;
        readRange.End = 0;  // NULL range for write
        readRange.write();

        PointerByReference ppMapData = new PointerByReference();
        hr = comCallInt(pVertexBuffer, VT.ID3D12Resource_Map, 0, readRange.getPointer(), ppMapData);
        System.out.println("[DEBUG] Map attempt returned: 0x" + Integer.toHexString(hr));
        
        if (hr == S_OK) {
            Pointer mapPtr = ppMapData.getValue();
            System.out.println("[DEBUG] Map succeeded! Data pointer: " + mapPtr);
            
            ByteBuffer dstBuffer = mapPtr.getByteBuffer(0, sizeBytes).order(ByteOrder.LITTLE_ENDIAN);
            // Copy vertex data
            bb.rewind();
            for (float v : verts) dstBuffer.putFloat(v);

            // Unmap with write range
            D3D12_RANGE writeRange = new D3D12_RANGE();
            writeRange.Begin = 0;
            writeRange.End = sizeBytes;
            writeRange.write();
            comCallVoid(pVertexBuffer, VT.ID3D12Resource_Unmap, 0, writeRange.getPointer());
            System.out.println("[DEBUG] Unmap done");
        } else {
            System.out.println("[DEBUG] Map failed: 0x" + Integer.toHexString(hr) + 
                             " (vertex buffer will be empty)");
        }

        long gpuVA = comCallLong(pVertexBuffer, VT.ID3D12Resource_GetGPUVirtualAddress);

        vbView.BufferLocation = gpuVA;
        vbView.SizeInBytes = sizeBytes;
        vbView.StrideInBytes = strideBytes;
        vbView.write();
    }

    static void render() {
        // Reset allocator and command list
        checkHR(comCallInt(pCmdAlloc, VT.ID3D12CommandAllocator_Reset), "CommandAllocator::Reset");
        checkHR(comCallInt(pCmdList, VT.ID3D12GraphicsCommandList_Reset, pCmdAlloc, pPSO), "CommandList::Reset");

        // Root signature + viewport/scissor
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

        // RTV handle for current frame (precomputed during init)
        long rtv = rtvHandles[frameIndex];

        // Clear + bind RTV
        float[] clear = new float[] { 1f, 1f, 1f, 1f }; // white background
        Memory clearMem = new Memory(4 * 4);
        clearMem.write(0, clear, 0, 4);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_ClearRenderTargetView, rtv, clearMem, 0, Pointer.NULL);

        // OMSetRenderTargets
        Memory rtvArray = new Memory(8);
        rtvArray.setLong(0, rtv);
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_OMSetRenderTargets, 1, rtvArray, 1, Pointer.NULL);

        // IA setup
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Draw
        comCallVoid(pCmdList, VT.ID3D12GraphicsCommandList_DrawInstanced, 3, 1, 0, 0);

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

        // Present
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
        // Wait one more frame to be safe
        try { waitForPreviousFrame(); } catch (Throwable t) {}

        if (fenceEvent != null && Pointer.nativeValue(fenceEvent) != 0) {
            Kernel32.INSTANCE.CloseHandle(fenceEvent);
            fenceEvent = null;
        }

        // Release in reverse-ish order
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