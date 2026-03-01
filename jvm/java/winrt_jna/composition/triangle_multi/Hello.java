// Hello.java
// OpenGL 4.6 + D3D11 + Vulkan 1.4 Triangles via Windows.UI.Composition (Win32 Desktop Interop)
// ALL COM/WinRT calls via vtable index. Java + JNA only.
//
// Build & Run:
//   javac -cp jna.jar Hello.java
//   java -cp ".;jna.jar" Hello
//
// Requirements:
//   - Windows 10+ with D3D11, OpenGL 4.6, Vulkan 1.4 capable GPU
//   - WGL_NV_DX_interop extension (NVIDIA or compatible)
//   - shaderc_shared.dll (from Vulkan SDK) in PATH or working directory
//   - hello.vert and hello.frag in working directory
//   - jna.jar (JNA 5.13+)
//
// forked from Hello.cs (C# vtable version)

import com.sun.jna.*;
import com.sun.jna.ptr.*;
import com.sun.jna.win32.StdCallLibrary;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

public class Hello {

    // ============================================================
    // Debug Logging
    // ============================================================
    static void dbg(String fn, String msg) {
        Kernel32Lib.INSTANCE.OutputDebugStringW(new WString("[" + fn + "] " + msg + "\n"));
    }
    static void dbgHR(String fn, String api, int hr) {
        dbg(fn, api + " failed hr=0x" + String.format("%08X", hr));
    }
    static void dbgPtr(String fn, String name, Pointer ptr) {
        dbg(fn, name + "=" + ptr);
    }

    // ============================================================
    // Native Libraries
    // ============================================================
    public interface Kernel32Lib extends StdCallLibrary {
        Kernel32Lib INSTANCE = Native.load("kernel32", Kernel32Lib.class);
        Pointer GetModuleHandleW(WString name);
        void OutputDebugStringW(WString msg);
        void Sleep(int ms);
        Pointer GetProcAddress(Pointer hModule, String procName);
        Pointer LoadLibraryW(WString name);
    }

    public interface User32Lib extends StdCallLibrary {
        User32Lib INSTANCE = Native.load("user32", User32Lib.class);
        int RegisterClassExW(WNDCLASSEX wc);
        Pointer CreateWindowExW(int exStyle, WString className, WString windowName,
                                int style, int x, int y, int w, int h,
                                Pointer parent, Pointer menu, Pointer hInst, Pointer param);
        boolean ShowWindow(Pointer hWnd, int cmd);
        boolean UpdateWindow(Pointer hWnd);
        boolean PeekMessageW(MSG msg, Pointer hWnd, int min, int max, int remove);
        boolean TranslateMessage(MSG msg);
        Pointer DispatchMessageW(MSG msg);
        Pointer DefWindowProcW(Pointer hWnd, int msg, Pointer wParam, Pointer lParam);
        void PostQuitMessage(int code);
        Pointer BeginPaint(Pointer hWnd, PAINTSTRUCT ps);
        boolean EndPaint(Pointer hWnd, PAINTSTRUCT ps);
        Pointer LoadCursorW(Pointer hInst, int id);
        Pointer GetDC(Pointer hWnd);
        int ReleaseDC(Pointer hWnd, Pointer hDC);
        boolean AdjustWindowRect(RECT rect, int style, boolean menu);
    }

    public interface GDI32Lib extends StdCallLibrary {
        GDI32Lib INSTANCE = Native.load("gdi32", GDI32Lib.class);
        int ChoosePixelFormat(Pointer hdc, PIXELFORMATDESCRIPTOR pfd);
        boolean SetPixelFormat(Pointer hdc, int format, PIXELFORMATDESCRIPTOR pfd);
    }

    public interface ComBaseDll extends StdCallLibrary {
        ComBaseDll INSTANCE = Native.load("combase", ComBaseDll.class);
        int RoInitialize(int initType);
        void RoUninitialize();
        int RoActivateInstance(Pointer hstring, PointerByReference instance);
        int WindowsCreateString(WString src, int len, PointerByReference hstring);
        int WindowsDeleteString(Pointer hstring);
    }

    public interface CoreMsgDll extends StdCallLibrary {
        CoreMsgDll INSTANCE = Native.load("CoreMessaging", CoreMsgDll.class);
        int CreateDispatcherQueueController(DispatcherQueueOptions opts, PointerByReference controller);
    }

    public interface D3D11Dll extends StdCallLibrary {
        D3D11Dll INSTANCE = Native.load("d3d11", D3D11Dll.class);
        int D3D11CreateDevice(Pointer adapter, int driverType, Pointer software, int flags,
                              int[] featureLevels, int featureLevelCount, int sdkVersion,
                              PointerByReference device, IntByReference featureLevel,
                              PointerByReference context);
    }

    public interface D3DCompilerDll extends StdCallLibrary {
        D3DCompilerDll INSTANCE = Native.load("d3dcompiler_47", D3DCompilerDll.class);
        int D3DCompile(String srcData, Pointer srcDataSize, String sourceName,
                       Pointer defines, Pointer include,
                       String entryPoint, String target,
                       int flags1, int flags2,
                       PointerByReference code, PointerByReference errorMsgs);
    }

    public interface OpenGL32Lib extends StdCallLibrary {
        OpenGL32Lib INSTANCE = Native.load("opengl32", OpenGL32Lib.class);
        Pointer wglCreateContext(Pointer hdc);
        int wglMakeCurrent(Pointer hdc, Pointer hglrc);
        int wglDeleteContext(Pointer hglrc);
        Pointer wglGetProcAddress(String name);
        void glClearColor(float r, float g, float b, float a);
        void glClear(int mask);
        void glViewport(int x, int y, int w, int h);
        void glDrawArrays(int mode, int first, int count);
        void glFlush();
    }

    public interface VulkanDll extends StdCallLibrary {
        VulkanDll INSTANCE = Native.load("vulkan-1", VulkanDll.class);
        int vkCreateInstance(Pointer ci, Pointer alloc, PointerByReference inst);
        int vkEnumeratePhysicalDevices(Pointer inst, IntByReference count, Pointer[] devs);
        void vkGetPhysicalDeviceQueueFamilyProperties(Pointer phys, IntByReference count, Pointer props);
        int vkCreateDevice(Pointer phys, Pointer ci, Pointer alloc, PointerByReference dev);
        void vkGetDeviceQueue(Pointer dev, int qf, int qi, PointerByReference queue);
        void vkGetPhysicalDeviceMemoryProperties(Pointer phys, Pointer memProps);
        int vkCreateImage(Pointer dev, Pointer ci, Pointer alloc, LongByReference img);
        void vkGetImageMemoryRequirements(Pointer dev, long img, Pointer reqs);
        int vkAllocateMemory(Pointer dev, Pointer ai, Pointer alloc, LongByReference mem);
        int vkBindImageMemory(Pointer dev, long img, long mem, long offset);
        int vkCreateImageView(Pointer dev, Pointer ci, Pointer alloc, LongByReference view);
        int vkCreateBuffer(Pointer dev, Pointer ci, Pointer alloc, LongByReference buf);
        void vkGetBufferMemoryRequirements(Pointer dev, long buf, Pointer reqs);
        int vkBindBufferMemory(Pointer dev, long buf, long mem, long offset);
        int vkCreateRenderPass(Pointer dev, Pointer ci, Pointer alloc, LongByReference rp);
        int vkCreateFramebuffer(Pointer dev, Pointer ci, Pointer alloc, LongByReference fb);
        int vkCreateShaderModule(Pointer dev, Pointer ci, Pointer alloc, LongByReference sm);
        void vkDestroyShaderModule(Pointer dev, long sm, Pointer alloc);
        int vkCreatePipelineLayout(Pointer dev, Pointer ci, Pointer alloc, LongByReference pl);
        int vkCreateGraphicsPipelines(Pointer dev, long cache, int count, Pointer ci, Pointer alloc, LongByReference pipe);
        int vkCreateCommandPool(Pointer dev, Pointer ci, Pointer alloc, PointerByReference pool);
        int vkAllocateCommandBuffers(Pointer dev, Pointer ai, PointerByReference cb);
        int vkCreateFence(Pointer dev, Pointer ci, Pointer alloc, LongByReference fence);
        int vkWaitForFences(Pointer dev, int count, long[] fences, int waitAll, long timeout);
        int vkResetFences(Pointer dev, int count, long[] fences);
        int vkResetCommandBuffer(Pointer cb, int flags);
        int vkBeginCommandBuffer(Pointer cb, Pointer bi);
        int vkEndCommandBuffer(Pointer cb);
        void vkCmdBeginRenderPass(Pointer cb, Pointer rpbi, int contents);
        void vkCmdEndRenderPass(Pointer cb);
        void vkCmdBindPipeline(Pointer cb, int bindPoint, long pipeline);
        void vkCmdDraw(Pointer cb, int vertexCount, int instanceCount, int firstVertex, int firstInstance);
        void vkCmdCopyImageToBuffer(Pointer cb, long img, int layout, long buf, int regionCount, Pointer regions);
        int vkQueueSubmit(Pointer queue, int count, Pointer si, long fence);
        int vkMapMemory(Pointer dev, long mem, long offset, long size, int flags, PointerByReference data);
        void vkUnmapMemory(Pointer dev, long mem);
        int vkDeviceWaitIdle(Pointer dev);
    }

    public interface ShadercDll extends Library {
        ShadercDll INSTANCE = Native.load("shaderc_shared", ShadercDll.class);
        Pointer shaderc_compiler_initialize();
        void shaderc_compiler_release(Pointer c);
        Pointer shaderc_compile_options_initialize();
        void shaderc_compile_options_release(Pointer o);
        void shaderc_compile_options_set_optimization_level(Pointer o, int level);
        Pointer shaderc_compile_into_spv(Pointer c, String src, Pointer srcLen,
                                         int shaderKind, String inputFile, String entryPoint, Pointer opts);
        int shaderc_result_get_compilation_status(Pointer r);
        Pointer shaderc_result_get_length(Pointer r);  // size_t
        Pointer shaderc_result_get_bytes(Pointer r);
        String shaderc_result_get_error_message(Pointer r);
        void shaderc_result_release(Pointer r);
    }

    // ============================================================
    // GUID structure (matches native 16-byte layout)
    // ============================================================
    public static class GUID extends Structure {
        public int    Data1;
        public short  Data2;
        public short  Data3;
        public byte[] Data4 = new byte[8];
        public GUID() {}
        public GUID(int d1, short d2, short d3, byte[] d4) {
            Data1 = d1; Data2 = d2; Data3 = d3;
            System.arraycopy(d4, 0, Data4, 0, 8);
        }
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("Data1", "Data2", "Data3", "Data4");
        }
    }

    // Helper to create GUID and write to native memory
    static Memory guidToMemory(GUID g) {
        Memory m = new Memory(16);
        m.setInt(0, g.Data1);
        m.setShort(4, g.Data2);
        m.setShort(6, g.Data3);
        m.write(8, g.Data4, 0, 8);
        return m;
    }

    // Parse GUID from string "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    static GUID guid(String s) {
        String[] p = s.split("-");
        int d1 = (int) Long.parseLong(p[0], 16);
        short d2 = (short) Integer.parseInt(p[1], 16);
        short d3 = (short) Integer.parseInt(p[2], 16);
        byte[] d4 = new byte[8];
        String rest = p[3] + p[4];
        for (int i = 0; i < 8; i++) d4[i] = (byte) Integer.parseInt(rest.substring(i*2, i*2+2), 16);
        return new GUID(d1, d2, d3, d4);
    }

    // ============================================================
    // Known GUIDs
    // ============================================================
    static final GUID IID_IDXGIDevice     = guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c");
    static final GUID IID_IDXGIFactory2   = guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0");
    static final GUID IID_ID3D11Texture2D = guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c");

    static final GUID IID_ICompositorDesktopInterop = guid("29E691FA-4567-4DCA-B319-D0F207EB6807");
    static final GUID IID_ICompositorInterop        = guid("25297D5C-3AD4-4C9C-B5CF-E36A38512330");

    static final GUID IID_ICompositor         = guid("B403CA50-7F8C-4E83-985F-CC45060036D8");
    static final GUID IID_ICompositionTarget  = guid("A1BEA8BA-D726-4663-8129-6B5E7927FFA6");
    static final GUID IID_IContainerVisual    = guid("02F6BC74-ED20-4773-AFE6-D49B4A93DB32");
    static final GUID IID_IVisualCollection   = guid("8B745505-FD3E-4A98-84A8-E949468C6BCB");
    static final GUID IID_ISpriteVisual       = guid("08E05581-1AD1-4F97-9757-402D76E4233B");
    static final GUID IID_IVisual             = guid("117E202D-A859-4C89-873B-C2AA566788E3");
    static final GUID IID_ICompositionBrush   = guid("AB0D7608-30C0-40E9-B568-B60A6BD1FB46");

    // ============================================================
    // Win32 / DXGI / D3D11 / GL / Vulkan Constants
    // ============================================================
    static final int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static final int WS_VISIBLE = 0x10000000;
    static final int WM_DESTROY = 0x0002;
    static final int WM_PAINT   = 0x000F;
    static final int WM_QUIT    = 0x0012;
    static final int PM_REMOVE  = 0x0001;
    static final int CS_OWNDC   = 0x0020;
    static final int IDC_ARROW  = 32512;
    static final int COLOR_WINDOW = 5;
    static final int SW_SHOW = 1;

    // DXGI
    static final int DXGI_FORMAT_R32G32B32_FLOAT    = 6;
    static final int DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
    static final int DXGI_FORMAT_B8G8R8A8_UNORM     = 87;
    static final int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
    static final int DXGI_SCALING_STRETCH     = 0;
    static final int DXGI_SWAP_EFFECT_FLIP_DISCARD = 4;
    static final int DXGI_ALPHA_MODE_IGNORE   = 0;

    // D3D11
    static final int D3D_DRIVER_TYPE_HARDWARE = 1;
    static final int D3D_FEATURE_LEVEL_11_0   = 0xb000;
    static final int D3D11_SDK_VERSION        = 7;
    static final int D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20;
    static final int D3D11_BIND_VERTEX_BUFFER = 0x1;
    static final int D3D11_USAGE_DEFAULT      = 0;
    static final int D3D11_USAGE_STAGING      = 3;
    static final int D3D11_CPU_ACCESS_WRITE   = 0x10000;
    static final int D3D11_MAP_WRITE          = 2;
    static final int D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;
    static final int D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);

    // OpenGL
    static final int GL_TRIANGLES      = 0x0004;
    static final int GL_FLOAT          = 0x1406;
    static final int GL_COLOR_BUFFER_BIT = 0x00004000;
    static final int GL_ARRAY_BUFFER   = 0x8892;
    static final int GL_STATIC_DRAW    = 0x88E4;
    static final int GL_FRAGMENT_SHADER = 0x8B30;
    static final int GL_VERTEX_SHADER  = 0x8B31;
    static final int GL_FRAMEBUFFER    = 0x8D40;
    static final int GL_RENDERBUFFER   = 0x8D41;
    static final int GL_COLOR_ATTACHMENT0 = 0x8CE0;
    static final int GL_LOWER_LEFT     = 0x8CA1;
    static final int GL_NEGATIVE_ONE_TO_ONE = 0x935E;
    static final int WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
    static final int WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
    static final int WGL_CONTEXT_PROFILE_MASK_ARB  = 0x9126;
    static final int WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
    static final int WGL_ACCESS_READ_WRITE_NV = 0x0001;

    // PFD
    static final int PFD_TYPE_RGBA      = 0;
    static final int PFD_DOUBLEBUFFER   = 1;
    static final int PFD_DRAW_TO_WINDOW = 4;
    static final int PFD_SUPPORT_OPENGL = 32;

    static final int PANEL_COUNT = 3;
    static final int WIDTH  = 320;
    static final int HEIGHT = 480;

    // ============================================================
    // JNA Structures
    // ============================================================
    public static class POINT extends Structure {
        public int X, Y;
        @Override protected List<String> getFieldOrder() { return Arrays.asList("X","Y"); }
    }
    public static class MSG extends Structure {
        public Pointer hWnd;
        public int message;
        public Pointer wParam;
        public Pointer lParam;
        public int time;
        public POINT pt = new POINT();
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("hWnd","message","wParam","lParam","time","pt");
        }
    }

    // WndProc callback (StdCall)
    public interface WndProcCallback extends StdCallLibrary.StdCallCallback {
        Pointer callback(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam);
    }

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
        public WNDCLASSEX() { cbSize = size(); }
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("cbSize","style","lpfnWndProc","cbClsExtra","cbWndExtra",
                "hInstance","hIcon","hCursor","hbrBackground","lpszMenuName","lpszClassName","hIconSm");
        }
    }

    public static class RECT extends Structure {
        public int Left, Top, Right, Bottom;
        @Override protected List<String> getFieldOrder() { return Arrays.asList("Left","Top","Right","Bottom"); }
    }

    public static class PAINTSTRUCT extends Structure {
        public Pointer hdc;
        public boolean fErase;
        public int left, top, right, bottom;
        public boolean fRestore;
        public boolean fIncUpdate;
        public byte[] rgbReserved = new byte[32];
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("hdc","fErase","left","top","right","bottom","fRestore","fIncUpdate","rgbReserved");
        }
    }

    public static class PIXELFORMATDESCRIPTOR extends Structure {
        public short nSize, nVersion;
        public int dwFlags;
        public byte iPixelType, cColorBits;
        public byte cRedBits, cRedShift, cGreenBits, cGreenShift, cBlueBits, cBlueShift;
        public byte cAlphaBits, cAlphaShift;
        public byte cAccumBits, cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits;
        public byte cDepthBits, cStencilBits, cAuxBuffers;
        public byte iLayerType, bReserved;
        public int dwLayerMask, dwVisibleMask, dwDamageMask;
        public PIXELFORMATDESCRIPTOR() { nSize = (short) size(); }
        @Override protected List<String> getFieldOrder() {
            return Arrays.asList("nSize","nVersion","dwFlags","iPixelType","cColorBits",
                "cRedBits","cRedShift","cGreenBits","cGreenShift","cBlueBits","cBlueShift",
                "cAlphaBits","cAlphaShift","cAccumBits","cAccumRedBits","cAccumGreenBits",
                "cAccumBlueBits","cAccumAlphaBits","cDepthBits","cStencilBits","cAuxBuffers",
                "iLayerType","bReserved","dwLayerMask","dwVisibleMask","dwDamageMask");
        }
    }

    public static class DispatcherQueueOptions extends Structure {
        public int dwSize, threadType, apartmentType;
        public DispatcherQueueOptions() { dwSize = size(); }
        @Override protected List<String> getFieldOrder() { return Arrays.asList("dwSize","threadType","apartmentType"); }
    }

    // ============================================================
    // COM vtable call helpers
    // ============================================================
    static final int PTR = Native.POINTER_SIZE;

    // Call COM method at vtable[index] -> returns HRESULT (int)
    static int comCall(Pointer pInterface, int vtblIndex, Object... extraArgs) {
        Pointer vtbl    = pInterface.getPointer(0);
        Pointer funcPtr = vtbl.getPointer((long) vtblIndex * PTR);
        Function func   = Function.getFunction(funcPtr, Function.ALT_CONVENTION);
        Object[] all = new Object[1 + extraArgs.length];
        all[0] = pInterface;
        System.arraycopy(extraArgs, 0, all, 1, extraArgs.length);
        return func.invokeInt(all);
    }

    // Call COM method returning void
    static void comCallVoid(Pointer pInterface, int vtblIndex, Object... extraArgs) {
        Pointer vtbl    = pInterface.getPointer(0);
        Pointer funcPtr = vtbl.getPointer((long) vtblIndex * PTR);
        Function func   = Function.getFunction(funcPtr, Function.ALT_CONVENTION);
        Object[] all = new Object[1 + extraArgs.length];
        all[0] = pInterface;
        System.arraycopy(extraArgs, 0, all, 1, extraArgs.length);
        func.invoke(void.class, all);
    }

    // Call COM method returning Pointer
    static Pointer comCallPtr(Pointer pInterface, int vtblIndex, Object... extraArgs) {
        Pointer vtbl    = pInterface.getPointer(0);
        Pointer funcPtr = vtbl.getPointer((long) vtblIndex * PTR);
        Function func   = Function.getFunction(funcPtr, Function.ALT_CONVENTION);
        Object[] all = new Object[1 + extraArgs.length];
        all[0] = pInterface;
        System.arraycopy(extraArgs, 0, all, 1, extraArgs.length);
        return (Pointer) func.invoke(Pointer.class, all);
    }

    static void comRelease(Pointer pInterface) {
        if (pInterface != null) comCall(pInterface, 2); // IUnknown::Release
    }

    // IUnknown::QueryInterface
    static int QI(Pointer pUnk, GUID iid, PointerByReference ppv) {
        Memory m = guidToMemory(iid);
        return comCall(pUnk, 0, m, ppv);
    }

    // ID3DBlob::GetBufferPointer (vtable #3), GetBufferSize (vtable #4)
    static Pointer blobPtr(Pointer blob) { return comCallPtr(blob, 3); }
    static Pointer blobSize(Pointer blob) { return comCallPtr(blob, 4); }

    // ============================================================
    // OpenGL extension function loader
    // ============================================================
    static Function glFunc(String name) {
        Pointer p = OpenGL32Lib.INSTANCE.wglGetProcAddress(name);
        if (p == null || Pointer.nativeValue(p) == 0)
            throw new RuntimeException("GL symbol not found: " + name);
        return Function.getFunction(p, Function.ALT_CONVENTION);
    }

    // ============================================================
    // HSTRING helpers (for WinRT activation)
    // ============================================================
    static Pointer createHString(String s) {
        PointerByReference phs = new PointerByReference();
        int hr = ComBaseDll.INSTANCE.WindowsCreateString(new WString(s), s.length(), phs);
        if (hr != 0) throw new RuntimeException("WindowsCreateString failed: 0x" + String.format("%08X", hr));
        return phs.getValue();
    }

    // ============================================================
    // Shaderc compilation helper
    // ============================================================
    static byte[] compileSPV(String src, int kind, String file) {
        Pointer comp = ShadercDll.INSTANCE.shaderc_compiler_initialize();
        Pointer opt  = ShadercDll.INSTANCE.shaderc_compile_options_initialize();
        ShadercDll.INSTANCE.shaderc_compile_options_set_optimization_level(opt, 2);
        try {
            int srcBytes = src.getBytes(java.nio.charset.StandardCharsets.UTF_8).length;
            Pointer res = ShadercDll.INSTANCE.shaderc_compile_into_spv(
                comp, src, new Pointer(srcBytes), kind, file, "main", opt);
            try {
                if (ShadercDll.INSTANCE.shaderc_result_get_compilation_status(res) != 0) {
                    String err = ShadercDll.INSTANCE.shaderc_result_get_error_message(res);
                    throw new RuntimeException("Shader compile: " + err);
                }
                long len = Pointer.nativeValue(ShadercDll.INSTANCE.shaderc_result_get_length(res));
                Pointer bytes = ShadercDll.INSTANCE.shaderc_result_get_bytes(res);
                byte[] data = bytes.getByteArray(0, (int)len);
                return data;
            } finally { ShadercDll.INSTANCE.shaderc_result_release(res); }
        } finally {
            ShadercDll.INSTANCE.shaderc_compile_options_release(opt);
            ShadercDll.INSTANCE.shaderc_compiler_release(comp);
        }
    }

    // ============================================================
    // Shader sources (HLSL for D3D11, GLSL for OpenGL)
    // ============================================================
    static final String VS_HLSL =
        "struct VSInput  { float3 pos : POSITION; float4 col : COLOR; };\n" +
        "struct VSOutput { float4 pos : SV_POSITION; float4 col : COLOR; };\n" +
        "VSOutput main(VSInput i) {\n" +
        "    VSOutput o;\n" +
        "    o.pos = float4(i.pos, 1);\n" +
        "    o.col = i.col;\n" +
        "    return o;\n" +
        "}\n";

    static final String PS_HLSL =
        "struct PSInput { float4 pos : SV_POSITION; float4 col : COLOR; };\n" +
        "float4 main(PSInput i) : SV_TARGET { return i.col; }\n";

    static final String VS_GLSL =
        "#version 460 core\n" +
        "in vec3 position;\n" +
        "in vec3 color;\n" +
        "out vec4 vColor;\n" +
        "void main() {\n" +
        "    gl_Position = vec4(position.x, -position.y, position.z, 1.0);\n" +
        "    vColor = vec4(color, 1.0);\n" +
        "}\n";

    static final String FS_GLSL =
        "#version 460 core\n" +
        "in vec4 vColor;\n" +
        "out vec4 outColor;\n" +
        "void main() {\n" +
        "    outColor = vColor;\n" +
        "}\n";

    // ============================================================
    // Global state
    // ============================================================
    static WndProcCallback wndProcCb; // prevent GC
    static Pointer g_hwnd;

    // Composition COM pointers
    static Pointer g_dqController;
    static Pointer g_compositor;
    static Pointer g_compositorUnk;
    static Pointer g_desktopTarget;
    static Pointer g_compTarget;
    static Pointer g_rootContainer;
    static Pointer g_rootVisual;
    static Pointer g_children;
    static Pointer[] g_spriteRaw    = new Pointer[PANEL_COUNT];
    static Pointer[] g_spriteVisual = new Pointer[PANEL_COUNT];
    static Pointer[] g_brush        = new Pointer[PANEL_COUNT];

    // OpenGL state
    static Pointer g_hDC, g_hGLRC;
    static Pointer g_dxInteropDevice;
    static Pointer g_dxInteropObject;
    static int g_fbo, g_rbo;
    static int[] g_vbo = new int[2];
    static int g_program;
    static int g_posAttrib, g_colAttrib;
    // GL extension function objects
    static Function fn_glGenBuffers, fn_glBindBuffer, fn_glBufferData;
    static Function fn_glCreateShader, fn_glShaderSource, fn_glCompileShader;
    static Function fn_glCreateProgram, fn_glAttachShader, fn_glLinkProgram, fn_glUseProgram;
    static Function fn_glGetAttribLocation;
    static Function fn_glEnableVertexAttribArray, fn_glVertexAttribPointer;
    static Function fn_glGenVertexArrays, fn_glBindVertexArray;
    static Function fn_glGenFramebuffers, fn_glBindFramebuffer;
    static Function fn_glFramebufferRenderbuffer, fn_glGenRenderbuffers;
    static Function fn_glClipControl;
    static Function fn_wglCreateContextAttribsARB;
    static Function fn_wglDXOpenDeviceNV, fn_wglDXCloseDeviceNV;
    static Function fn_wglDXRegisterObjectNV, fn_wglDXUnregisterObjectNV;
    static Function fn_wglDXLockObjectsNV, fn_wglDXUnlockObjectsNV;

    // Vulkan state
    static Pointer g_vkPhysicalDevice, g_vkDevice, g_vkQueue;
    static Pointer g_vkCommandPool, g_vkCommandBuffer;
    static Pointer g_stagingTexture, g_swapChainBackBuffer;
    static long g_vkImage, g_vkImageView, g_vkImageMemory;
    static long g_vkReadbackBuffer, g_vkReadbackMemory;
    static long g_vkRenderPass, g_vkFramebuffer;
    static long g_vkPipelineLayout, g_vkPipeline, g_vkFence;
    static int g_vkQueueFamily = -1;

    static boolean g_firstRender = true;

    // ============================================================
    // WndProc
    // ============================================================
    static Pointer wndProc(Pointer hWnd, int uMsg, Pointer wParam, Pointer lParam) {
        switch (uMsg) {
            case WM_PAINT: {
                PAINTSTRUCT ps = new PAINTSTRUCT();
                User32Lib.INSTANCE.BeginPaint(hWnd, ps);
                User32Lib.INSTANCE.EndPaint(hWnd, ps);
                return Pointer.createConstant(0);
            }
            case WM_DESTROY:
                dbg("WndProc", "WM_DESTROY received");
                User32Lib.INSTANCE.PostQuitMessage(0);
                return Pointer.createConstant(0);
            default:
                return User32Lib.INSTANCE.DefWindowProcW(hWnd, uMsg, wParam, lParam);
        }
    }

    // ============================================================
    // CreateAppWindow
    // ============================================================
    static Pointer createAppWindow() {
        final String FN = "CreateAppWindow";
        dbg(FN, "begin");
        Pointer hInstance = Kernel32Lib.INSTANCE.GetModuleHandleW(null);

        wndProcCb = (hWnd, uMsg, wParam, lParam) -> wndProc(hWnd, uMsg, wParam, lParam);

        WString className = new WString("Win32CompTriangle");
        WNDCLASSEX wc = new WNDCLASSEX();
        wc.style = CS_OWNDC;
        wc.lpfnWndProc = wndProcCb;
        wc.hInstance = hInstance;
        wc.hCursor = User32Lib.INSTANCE.LoadCursorW(null, IDC_ARROW);
        wc.hbrBackground = Pointer.createConstant(COLOR_WINDOW + 1);
        wc.lpszClassName = className;

        int atom = User32Lib.INSTANCE.RegisterClassExW(wc);
        if (atom == 0) { dbg(FN, "RegisterClassExW failed"); return null; }

        RECT rc = new RECT();
        rc.Right = WIDTH * PANEL_COUNT;
        rc.Bottom = HEIGHT;
        User32Lib.INSTANCE.AdjustWindowRect(rc, WS_OVERLAPPEDWINDOW, false);

        Pointer hwnd = User32Lib.INSTANCE.CreateWindowExW(0,
            className,
            new WString("OpenGL + D3D11 + Vulkan via Windows.UI.Composition (Java+JNA)"),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100, 100, rc.Right - rc.Left, rc.Bottom - rc.Top,
            null, null, hInstance, null);

        if (hwnd == null) { dbg(FN, "CreateWindowExW failed"); return null; }
        dbgPtr(FN, "hwnd", hwnd);

        User32Lib.INSTANCE.ShowWindow(hwnd, SW_SHOW);
        User32Lib.INSTANCE.UpdateWindow(hwnd);
        dbg(FN, "ok");
        return hwnd;
    }

    // ============================================================
    // InitD3D11
    //   Creates device, swap chain (for D3D11 panel), RTV, shaders, vertex buffer
    // ============================================================
    static Pointer g_d3dDevice, g_d3dContext, g_d3dSwapChain;
    static Pointer g_rtv, g_vs, g_ps, g_inputLayout, g_vertexBuffer;

    static int initD3D11() {
        final String FN = "InitD3D11";
        dbg(FN, "begin");

        // 1) D3D11CreateDevice
        int[] featureLevels = { D3D_FEATURE_LEVEL_11_0 };
        PointerByReference pDevice = new PointerByReference();
        IntByReference pFL = new IntByReference();
        PointerByReference pCtx = new PointerByReference();
        int hr = D3D11Dll.INSTANCE.D3D11CreateDevice(
            null, D3D_DRIVER_TYPE_HARDWARE, null,
            D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            featureLevels, featureLevels.length, D3D11_SDK_VERSION,
            pDevice, pFL, pCtx);
        if (hr < 0) { dbgHR(FN, "D3D11CreateDevice", hr); return hr; }
        g_d3dDevice  = pDevice.getValue();
        g_d3dContext = pCtx.getValue();
        dbgPtr(FN, "Device", g_d3dDevice);

        // 2) QI -> IDXGIDevice
        PointerByReference pDxgiDev = new PointerByReference();
        hr = QI(g_d3dDevice, IID_IDXGIDevice, pDxgiDev);
        if (hr < 0) { dbgHR(FN, "QI(IDXGIDevice)", hr); return hr; }
        Pointer dxgiDev = pDxgiDev.getValue();

        // 3) IDXGIDevice::GetAdapter (vt#7)
        PointerByReference pAdapter = new PointerByReference();
        hr = comCall(dxgiDev, 7, pAdapter);
        if (hr < 0) { dbgHR(FN, "GetAdapter", hr); return hr; }
        Pointer adapter = pAdapter.getValue();

        // 4) IDXGIAdapter::GetParent -> IDXGIFactory2 (vt#6)
        PointerByReference pFactory = new PointerByReference();
        hr = comCall(adapter, 6, guidToMemory(IID_IDXGIFactory2), pFactory);
        comRelease(adapter);
        if (hr < 0) { dbgHR(FN, "GetParent(IDXGIFactory2)", hr); return hr; }
        Pointer factory = pFactory.getValue();

        // 5) IDXGIFactory2::CreateSwapChainForComposition (vt#24)
        Memory scDesc = createSwapChainDesc();
        PointerByReference pSC = new PointerByReference();
        hr = comCall(factory, 24, g_d3dDevice, scDesc, Pointer.NULL, pSC);
        comRelease(factory);
        comRelease(dxgiDev);
        if (hr < 0) { dbgHR(FN, "CreateSwapChainForComposition", hr); return hr; }
        g_d3dSwapChain = pSC.getValue();
        dbgPtr(FN, "SwapChain", g_d3dSwapChain);

        // 6) IDXGISwapChain::GetBuffer(0) (vt#9)
        PointerByReference pBB = new PointerByReference();
        hr = comCall(g_d3dSwapChain, 9, 0, guidToMemory(IID_ID3D11Texture2D), pBB);
        if (hr < 0) { dbgHR(FN, "GetBuffer", hr); return hr; }
        Pointer backBuf = pBB.getValue();

        // 7) ID3D11Device::CreateRenderTargetView (vt#9)
        PointerByReference pRTV = new PointerByReference();
        hr = comCall(g_d3dDevice, 9, backBuf, Pointer.NULL, pRTV);
        comRelease(backBuf);
        if (hr < 0) { dbgHR(FN, "CreateRTV", hr); return hr; }
        g_rtv = pRTV.getValue();

        // 8) Compile HLSL shaders
        PointerByReference pVsBlob = new PointerByReference();
        PointerByReference pPsBlob = new PointerByReference();
        PointerByReference pErr    = new PointerByReference();

        hr = D3DCompilerDll.INSTANCE.D3DCompile(
            VS_HLSL, new Pointer(VS_HLSL.length()), null, null, null,
            "main", "vs_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, pVsBlob, pErr);
        if (pErr.getValue() != null) comRelease(pErr.getValue());
        if (hr < 0) { dbgHR(FN, "D3DCompile(VS)", hr); return hr; }
        Pointer vsBlob = pVsBlob.getValue();

        hr = D3DCompilerDll.INSTANCE.D3DCompile(
            PS_HLSL, new Pointer(PS_HLSL.length()), null, null, null,
            "main", "ps_4_0", D3DCOMPILE_ENABLE_STRICTNESS, 0, pPsBlob, pErr);
        if (pErr.getValue() != null) comRelease(pErr.getValue());
        if (hr < 0) { dbgHR(FN, "D3DCompile(PS)", hr); return hr; }
        Pointer psBlob = pPsBlob.getValue();

        // 9) ID3D11Device::CreateVertexShader (vt#12)
        Pointer vsBlobData = blobPtr(vsBlob);
        Pointer vsBlobSize = blobSize(vsBlob);
        PointerByReference pVS = new PointerByReference();
        hr = comCall(g_d3dDevice, 12, vsBlobData, vsBlobSize, Pointer.NULL, pVS);
        if (hr < 0) { dbgHR(FN, "CreateVertexShader", hr); return hr; }
        g_vs = pVS.getValue();

        // 10) ID3D11Device::CreatePixelShader (vt#15)
        Pointer psBlobData = blobPtr(psBlob);
        Pointer psBlobSize = blobSize(psBlob);
        PointerByReference pPS = new PointerByReference();
        hr = comCall(g_d3dDevice, 15, psBlobData, psBlobSize, Pointer.NULL, pPS);
        if (hr < 0) { dbgHR(FN, "CreatePixelShader", hr); return hr; }
        g_ps = pPS.getValue();

        // 11) ID3D11Device::CreateInputLayout (vt#11)
        //     D3D11_INPUT_ELEMENT_DESC: [LPCSTR SemanticName(ptr), UINT SemanticIndex,
        //     UINT Format, UINT InputSlot, UINT AlignedByteOffset, UINT InputSlotClass, UINT InstanceDataStepRate]
        //     Each element = ptr + 6*int = 8 + 24 = 32 bytes on 64-bit
        int elemSize = PTR + 6 * 4;
        Memory elems = new Memory(elemSize * 2);
        elems.clear();
        // POSITION
        Memory semPos = new Memory(16); semPos.setString(0, "POSITION");
        elems.setPointer(0, semPos);                               // SemanticName
        elems.setInt(PTR, 0);                                      // SemanticIndex
        elems.setInt(PTR + 4, DXGI_FORMAT_R32G32B32_FLOAT);       // Format
        elems.setInt(PTR + 8, 0);                                  // InputSlot
        elems.setInt(PTR + 12, 0);                                 // AlignedByteOffset
        elems.setInt(PTR + 16, 0);                                 // InputSlotClass
        elems.setInt(PTR + 20, 0);                                 // InstanceDataStepRate
        // COLOR
        Memory semCol = new Memory(16); semCol.setString(0, "COLOR");
        elems.setPointer(elemSize, semCol);
        elems.setInt(elemSize + PTR, 0);
        elems.setInt(elemSize + PTR + 4, DXGI_FORMAT_R32G32B32A32_FLOAT);
        elems.setInt(elemSize + PTR + 8, 0);
        elems.setInt(elemSize + PTR + 12, 12);                     // offset = 3 floats * 4
        elems.setInt(elemSize + PTR + 16, 0);
        elems.setInt(elemSize + PTR + 20, 0);

        PointerByReference pIL = new PointerByReference();
        hr = comCall(g_d3dDevice, 11, elems, 2, vsBlobData, vsBlobSize, pIL);
        comRelease(vsBlob);
        comRelease(psBlob);
        if (hr < 0) { dbgHR(FN, "CreateInputLayout", hr); return hr; }
        g_inputLayout = pIL.getValue();

        // 12) ID3D11Device::CreateBuffer (vt#3)
        //     Vertex: float3 pos + float4 color = 7 floats * 4 = 28 bytes per vertex
        float[] verts = {
            0.0f,  0.5f, 0.5f,  1,0,0,1,  // top    (red)
            0.5f, -0.5f, 0.5f,  0,1,0,1,  // right  (green)
           -0.5f, -0.5f, 0.5f,  0,0,1,1,  // left   (blue)
        };
        int byteWidth = verts.length * 4;
        Memory vertData = new Memory(byteWidth);
        vertData.write(0, verts, 0, verts.length);

        // D3D11_BUFFER_DESC: UINT ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride
        Memory bd = new Memory(24); bd.clear();
        bd.setInt(0, byteWidth);                 // ByteWidth
        bd.setInt(4, D3D11_USAGE_DEFAULT);       // Usage
        bd.setInt(8, D3D11_BIND_VERTEX_BUFFER);  // BindFlags

        // D3D11_SUBRESOURCE_DATA: Pointer pSysMem, UINT SysMemPitch, UINT SysMemSlicePitch
        Memory sd = new Memory(PTR + 8); sd.clear();
        sd.setPointer(0, vertData);

        PointerByReference pVB = new PointerByReference();
        hr = comCall(g_d3dDevice, 3, bd, sd, pVB);
        if (hr < 0) { dbgHR(FN, "CreateBuffer", hr); return hr; }
        g_vertexBuffer = pVB.getValue();

        dbg(FN, "ok (all steps completed)");
        return 0;
    }

    // DXGI_SWAP_CHAIN_DESC1 as raw memory (matching C struct layout)
    static Memory createSwapChainDesc() {
        // UINT Width,Height,Format; BOOL Stereo; DXGI_SAMPLE_DESC(Count,Quality);
        // UINT BufferUsage,BufferCount,Scaling,SwapEffect,AlphaMode,Flags;
        // Total: 12*4 = 48 bytes
        Memory m = new Memory(48); m.clear();
        m.setInt(0,  WIDTH);                           // Width
        m.setInt(4,  HEIGHT);                          // Height
        m.setInt(8,  DXGI_FORMAT_B8G8R8A8_UNORM);     // Format
        m.setInt(12, 0);                               // Stereo
        m.setInt(16, 1);                               // SampleDesc.Count
        m.setInt(20, 0);                               // SampleDesc.Quality
        m.setInt(24, DXGI_USAGE_RENDER_TARGET_OUTPUT); // BufferUsage
        m.setInt(28, 2);                               // BufferCount
        m.setInt(32, DXGI_SCALING_STRETCH);            // Scaling
        m.setInt(36, DXGI_SWAP_EFFECT_FLIP_DISCARD);   // SwapEffect
        m.setInt(40, DXGI_ALPHA_MODE_IGNORE);          // AlphaMode
        m.setInt(44, 0);                               // Flags
        return m;
    }

    // Create a separate swap chain for composition (used by GL and VK panels)
    static Pointer createSwapChainForComposition() {
        PointerByReference pDxgiDev = new PointerByReference();
        int hr = QI(g_d3dDevice, IID_IDXGIDevice, pDxgiDev);
        if (hr < 0) return null;

        PointerByReference pAdapter = new PointerByReference();
        hr = comCall(pDxgiDev.getValue(), 7, pAdapter);
        if (hr < 0) { comRelease(pDxgiDev.getValue()); return null; }

        PointerByReference pFactory = new PointerByReference();
        hr = comCall(pAdapter.getValue(), 6, guidToMemory(IID_IDXGIFactory2), pFactory);
        comRelease(pAdapter.getValue());
        if (hr < 0) { comRelease(pDxgiDev.getValue()); return null; }

        Memory scDesc = createSwapChainDesc();
        PointerByReference pSC = new PointerByReference();
        hr = comCall(pFactory.getValue(), 24, g_d3dDevice, scDesc, Pointer.NULL, pSC);
        comRelease(pFactory.getValue());
        comRelease(pDxgiDev.getValue());
        if (hr < 0) return null;
        return pSC.getValue();
    }

    // ============================================================
    // InitOpenGLInterop
    //   Sets up OpenGL 4.6 context, WGL_NV_DX_interop, FBO
    // ============================================================
    static int initOpenGLInterop(Pointer swapChain) {
        final String FN = "InitOpenGLInterop";
        dbg(FN, "begin");

        g_hDC = User32Lib.INSTANCE.GetDC(g_hwnd);
        if (g_hDC == null) return -1;

        PIXELFORMATDESCRIPTOR pfd = new PIXELFORMATDESCRIPTOR();
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
        pfd.iPixelType = (byte) PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cAlphaBits = 8;
        pfd.cDepthBits = 24;

        int format = GDI32Lib.INSTANCE.ChoosePixelFormat(g_hDC, pfd);
        if (format == 0) return -1;
        if (!GDI32Lib.INSTANCE.SetPixelFormat(g_hDC, format, pfd)) return -1;

        // Create temporary legacy GL context
        Pointer tmp = OpenGL32Lib.INSTANCE.wglCreateContext(g_hDC);
        if (tmp == null) return -1;
        OpenGL32Lib.INSTANCE.wglMakeCurrent(g_hDC, tmp);

        // Load wglCreateContextAttribsARB and create 4.6 core context
        fn_wglCreateContextAttribsARB = glFunc("wglCreateContextAttribsARB");
        int[] attrs = {
            WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
            WGL_CONTEXT_MINOR_VERSION_ARB, 6,
            WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0
        };
        g_hGLRC = (Pointer) fn_wglCreateContextAttribsARB.invoke(Pointer.class,
            new Object[]{ g_hDC, Pointer.NULL, attrs });
        if (g_hGLRC == null) return -1;
        OpenGL32Lib.INSTANCE.wglMakeCurrent(g_hDC, g_hGLRC);
        OpenGL32Lib.INSTANCE.wglDeleteContext(tmp);

        // Load GL extension functions
        fn_glGenBuffers      = glFunc("glGenBuffers");
        fn_glBindBuffer      = glFunc("glBindBuffer");
        fn_glBufferData      = glFunc("glBufferData");
        fn_glCreateShader    = glFunc("glCreateShader");
        fn_glShaderSource    = glFunc("glShaderSource");
        fn_glCompileShader   = glFunc("glCompileShader");
        fn_glCreateProgram   = glFunc("glCreateProgram");
        fn_glAttachShader    = glFunc("glAttachShader");
        fn_glLinkProgram     = glFunc("glLinkProgram");
        fn_glUseProgram      = glFunc("glUseProgram");
        fn_glGetAttribLocation      = glFunc("glGetAttribLocation");
        fn_glEnableVertexAttribArray = glFunc("glEnableVertexAttribArray");
        fn_glVertexAttribPointer     = glFunc("glVertexAttribPointer");
        fn_glGenVertexArrays  = glFunc("glGenVertexArrays");
        fn_glBindVertexArray  = glFunc("glBindVertexArray");
        fn_glGenFramebuffers  = glFunc("glGenFramebuffers");
        fn_glBindFramebuffer  = glFunc("glBindFramebuffer");
        fn_glFramebufferRenderbuffer = glFunc("glFramebufferRenderbuffer");
        fn_glGenRenderbuffers = glFunc("glGenRenderbuffers");
        fn_glClipControl      = glFunc("glClipControl");

        fn_wglDXOpenDeviceNV       = glFunc("wglDXOpenDeviceNV");
        fn_wglDXCloseDeviceNV      = glFunc("wglDXCloseDeviceNV");
        fn_wglDXRegisterObjectNV   = glFunc("wglDXRegisterObjectNV");
        fn_wglDXUnregisterObjectNV = glFunc("wglDXUnregisterObjectNV");
        fn_wglDXLockObjectsNV      = glFunc("wglDXLockObjectsNV");
        fn_wglDXUnlockObjectsNV    = glFunc("wglDXUnlockObjectsNV");

        // Set clip control (upper-left origin to match D3D/Vulkan)
        fn_glClipControl.invoke(void.class, new Object[]{ GL_LOWER_LEFT, GL_NEGATIVE_ONE_TO_ONE });

        // Open D3D11 device for interop
        g_dxInteropDevice = (Pointer) fn_wglDXOpenDeviceNV.invoke(Pointer.class,
            new Object[]{ g_d3dDevice });
        if (g_dxInteropDevice == null) { dbg(FN, "wglDXOpenDeviceNV failed"); return -1; }

        // Get swap chain back buffer
        PointerByReference pBB = new PointerByReference();
        int hr = comCall(swapChain, 9, 0, guidToMemory(IID_ID3D11Texture2D), pBB);
        if (hr < 0) { dbgHR(FN, "GetBuffer", hr); return hr; }
        Pointer backBuffer = pBB.getValue();

        // Create GL renderbuffer and register with DX interop
        int[] rbo = new int[1];
        fn_glGenRenderbuffers.invoke(void.class, new Object[]{ 1, rbo });
        g_rbo = rbo[0];
        g_dxInteropObject = (Pointer) fn_wglDXRegisterObjectNV.invoke(Pointer.class,
            new Object[]{ g_dxInteropDevice, backBuffer, g_rbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV });
        comRelease(backBuffer);
        if (g_dxInteropObject == null) { dbg(FN, "wglDXRegisterObjectNV failed"); return -1; }

        // Create FBO and attach the shared renderbuffer
        int[] fbo = new int[1];
        fn_glGenFramebuffers.invoke(void.class, new Object[]{ 1, fbo });
        g_fbo = fbo[0];
        fn_glBindFramebuffer.invoke(void.class, new Object[]{ GL_FRAMEBUFFER, g_fbo });
        fn_glFramebufferRenderbuffer.invoke(void.class,
            new Object[]{ GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, g_rbo });
        fn_glBindFramebuffer.invoke(void.class, new Object[]{ GL_FRAMEBUFFER, 0 });

        // Create VAO and VBOs for triangle
        int[] vao = new int[1];
        fn_glGenVertexArrays.invoke(void.class, new Object[]{ 1, vao });
        fn_glBindVertexArray.invoke(void.class, new Object[]{ vao[0] });

        fn_glGenBuffers.invoke(void.class, new Object[]{ 2, g_vbo });

        float[] vertices = { -0.5f,-0.5f,0f,  0.5f,-0.5f,0f,  0f,0.5f,0f };
        float[] colors   = {  0f,0f,1f,       0f,1f,0f,        1f,0f,0f };

        fn_glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, g_vbo[0] });
        fn_glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER,
            new Pointer(vertices.length * 4), vertices, GL_STATIC_DRAW });
        fn_glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, g_vbo[1] });
        fn_glBufferData.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER,
            new Pointer(colors.length * 4), colors, GL_STATIC_DRAW });

        // Compile GLSL shaders and create program
        int vs = (int) fn_glCreateShader.invokeInt(new Object[]{ GL_VERTEX_SHADER });
        fn_glShaderSource.invoke(void.class, new Object[]{ vs, 1, new String[]{ VS_GLSL }, null });
        fn_glCompileShader.invoke(void.class, new Object[]{ vs });

        int fs = (int) fn_glCreateShader.invokeInt(new Object[]{ GL_FRAGMENT_SHADER });
        fn_glShaderSource.invoke(void.class, new Object[]{ fs, 1, new String[]{ FS_GLSL }, null });
        fn_glCompileShader.invoke(void.class, new Object[]{ fs });

        g_program = fn_glCreateProgram.invokeInt(new Object[]{});
        fn_glAttachShader.invoke(void.class, new Object[]{ g_program, vs });
        fn_glAttachShader.invoke(void.class, new Object[]{ g_program, fs });
        fn_glLinkProgram.invoke(void.class, new Object[]{ g_program });
        fn_glUseProgram.invoke(void.class, new Object[]{ g_program });

        g_posAttrib = fn_glGetAttribLocation.invokeInt(new Object[]{ g_program, "position" });
        g_colAttrib = fn_glGetAttribLocation.invokeInt(new Object[]{ g_program, "color" });
        fn_glEnableVertexAttribArray.invoke(void.class, new Object[]{ g_posAttrib });
        fn_glEnableVertexAttribArray.invoke(void.class, new Object[]{ g_colAttrib });

        dbg(FN, "ok");
        return 0;
    }

    // ============================================================
    // InitVulkan
    //   Offscreen Vulkan rendering -> readback -> copy to D3D11 staging texture
    // ============================================================
    static void initVulkan(Pointer swapChain) throws Exception {
        final String FN = "InitVulkan";
        dbg(FN, "begin");

        // VkApplicationInfo
        Memory appName = new Memory(8); appName.setString(0, "vk14");
        Memory ai = new Memory(48); ai.clear();
        ai.setInt(0, 0);                            // sType = VK_STRUCTURE_TYPE_APPLICATION_INFO
        ai.setPointer(PTR == 8 ? 8 : 4, null);      // pNext
        ai.setPointer(PTR == 8 ? 16 : 8, appName);   // pApplicationName
        // apiVersion = VK_MAKE_API_VERSION(0, 1, 4, 0) = (1<<22) | (4<<12)
        int apiVer = (1 << 22) | (4 << 12);
        // Use the layout: sType(4) + pad + pNext(ptr) + pAppName(ptr) + appVer(4) + pEngName(ptr) + engVer(4) + apiVer(4)
        // On 64-bit: offsets 0,8,16,24,28,32,40,44 -- but this gets complex with alignment.
        // Safer approach: build with known offsets for 64-bit
        // VkApplicationInfo size on 64-bit = 48 bytes
        Memory vkAI = new Memory(48); vkAI.clear();
        vkAI.setInt(0, 0);               // sType
        // pNext at 8
        vkAI.setPointer(16, appName);     // pApplicationName
        // appVersion at 24
        // pEngineName at 32 (null)
        // engineVersion at 40
        vkAI.setInt(44, apiVer);          // apiVersion

        // VkInstanceCreateInfo (on 64-bit = 64 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) pad(20) pApplicationInfo(24) ...
        Memory ici = new Memory(64); ici.clear();
        ici.setInt(0, 1);                 // sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
        ici.setPointer(24, vkAI);         // pApplicationInfo (offset 24 on 64-bit)

        PointerByReference pInst = new PointerByReference();
        if (VulkanDll.INSTANCE.vkCreateInstance(ici, null, pInst) != 0)
            throw new Exception("vkCreateInstance failed");
        Pointer vkInstance = pInst.getValue();

        // Enumerate physical devices
        IntByReference count = new IntByReference(0);
        VulkanDll.INSTANCE.vkEnumeratePhysicalDevices(vkInstance, count, null);
        Pointer[] devs = new Pointer[count.getValue()];
        VulkanDll.INSTANCE.vkEnumeratePhysicalDevices(vkInstance, count, devs);
        g_vkPhysicalDevice = devs[0];

        // Find graphics queue family
        IntByReference qc = new IntByReference(0);
        VulkanDll.INSTANCE.vkGetPhysicalDeviceQueueFamilyProperties(g_vkPhysicalDevice, qc, null);
        // VkQueueFamilyProperties: queueFlags(4), queueCount(4), timestampValidBits(4), minImageTransferGranularity(3*4) = 24 bytes
        Memory qProps = new Memory(24 * qc.getValue());
        VulkanDll.INSTANCE.vkGetPhysicalDeviceQueueFamilyProperties(g_vkPhysicalDevice, qc, qProps);
        for (int i = 0; i < qc.getValue(); i++) {
            int flags = qProps.getInt(i * 24);
            if ((flags & 1) != 0) { g_vkQueueFamily = i; break; } // VK_QUEUE_GRAPHICS_BIT
        }
        if (g_vkQueueFamily < 0) throw new Exception("No graphics queue");

        // Create Vulkan device
        Memory prio = new Memory(4); prio.setFloat(0, 1.0f);
        // VkDeviceQueueCreateInfo (on 64-bit = 40 bytes)
        Memory qci = new Memory(40); qci.clear();
        qci.setInt(0, 2);                    // sType
        qci.setInt(16, 0);                    // flags
        qci.setInt(20, g_vkQueueFamily);      // queueFamilyIndex
        qci.setInt(24, 1);                    // queueCount
        qci.setPointer(32, prio);             // pQueuePriorities

        // VkDeviceCreateInfo (on 64-bit = 72 bytes)
        Memory dci = new Memory(72); dci.clear();
        dci.setInt(0, 3);                     // sType
        dci.setInt(20, 1);                    // queueCreateInfoCount
        dci.setPointer(24, qci);              // pQueueCreateInfos

        PointerByReference pDev = new PointerByReference();
        if (VulkanDll.INSTANCE.vkCreateDevice(g_vkPhysicalDevice, dci, null, pDev) != 0)
            throw new Exception("vkCreateDevice failed");
        g_vkDevice = pDev.getValue();

        PointerByReference pQueue = new PointerByReference();
        VulkanDll.INSTANCE.vkGetDeviceQueue(g_vkDevice, g_vkQueueFamily, 0, pQueue);
        g_vkQueue = pQueue.getValue();

        // Get physical device memory properties
        // VkPhysicalDeviceMemoryProperties is large (~520 bytes)
        Memory memProps = new Memory(520); memProps.clear();
        VulkanDll.INSTANCE.vkGetPhysicalDeviceMemoryProperties(g_vkPhysicalDevice, memProps);

        // Create offscreen image (R8G8B8A8_UNORM = format 37 for VK; B8G8R8A8_UNORM = 44)
        // Using format 44 to match D3D11's B8G8R8A8_UNORM
        // VkImageCreateInfo (on 64-bit = 88 bytes)
        Memory imgCI = new Memory(88); imgCI.clear();
        imgCI.setInt(0, 14);              // sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
        imgCI.setInt(16, 0);              // flags
        imgCI.setInt(20, 1);              // imageType = 2D (VK_IMAGE_TYPE_2D = 1)
        imgCI.setInt(24, 44);             // format = B8G8R8A8_UNORM
        imgCI.setInt(28, WIDTH);          // extent.width
        imgCI.setInt(32, HEIGHT);         // extent.height
        imgCI.setInt(36, 1);              // extent.depth
        imgCI.setInt(40, 1);              // mipLevels
        imgCI.setInt(44, 1);              // arrayLayers
        imgCI.setInt(48, 1);              // samples = VK_SAMPLE_COUNT_1_BIT
        // tiling = 0 (OPTIMAL), usage = 0x11 (COLOR_ATTACHMENT | TRANSFER_SRC)
        imgCI.setInt(56, 0x11);           // usage

        LongByReference pImg = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateImage(g_vkDevice, imgCI, null, pImg) != 0)
            throw new Exception("vkCreateImage failed");
        g_vkImage = pImg.getValue();

        // Allocate and bind image memory
        // VkMemoryRequirements: size(8), alignment(8), memoryTypeBits(4) = 24 bytes (with padding)
        Memory imgReqs = new Memory(24); imgReqs.clear();
        VulkanDll.INSTANCE.vkGetImageMemoryRequirements(g_vkDevice, g_vkImage, imgReqs);
        long imgSize = imgReqs.getLong(0);
        int imgMemBits = imgReqs.getInt(16);

        int imgMemIdx = findMemoryType(memProps, imgMemBits, 1); // DEVICE_LOCAL

        // VkMemoryAllocateInfo: sType(4)+pad+pNext(ptr)+allocationSize(8)+memoryTypeIndex(4) = 32 bytes
        Memory mai = new Memory(32); mai.clear();
        mai.setInt(0, 5);              // sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
        mai.setLong(PTR == 8 ? 16 : 8, imgSize);
        mai.setInt(PTR == 8 ? 24 : 16, imgMemIdx);

        LongByReference pImgMem = new LongByReference();
        if (VulkanDll.INSTANCE.vkAllocateMemory(g_vkDevice, mai, null, pImgMem) != 0)
            throw new Exception("vkAllocateMemory(image) failed");
        g_vkImageMemory = pImgMem.getValue();
        VulkanDll.INSTANCE.vkBindImageMemory(g_vkDevice, g_vkImage, g_vkImageMemory, 0);

        // Create image view
        // VkImageViewCreateInfo (on 64-bit: 80 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) pad(20) image(24) viewType(32)
        //         format(36) componentMapping(40..55) subresourceRange(56..75)
        Memory ivCI = new Memory(80); ivCI.clear();
        ivCI.setInt(0, 15);             // sType
        ivCI.setLong(24, g_vkImage);    // image (offset 24, uint64 aligned)
        ivCI.setInt(32, 1);             // viewType = 2D
        ivCI.setInt(36, 44);            // format
        // componentMapping at 40-55: all identity (0) from clear
        // subresourceRange at 56-75:
        ivCI.setInt(56, 1);             // aspectMask = COLOR
        ivCI.setInt(60, 0);             // baseMipLevel
        ivCI.setInt(64, 1);             // levelCount
        ivCI.setInt(68, 0);             // baseArrayLayer
        ivCI.setInt(72, 1);             // layerCount

        LongByReference pImgView = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateImageView(g_vkDevice, ivCI, null, pImgView) != 0)
            throw new Exception("vkCreateImageView failed");
        g_vkImageView = pImgView.getValue();

        // Create readback buffer
        long readSize = (long) WIDTH * HEIGHT * 4;
        // VkBufferCreateInfo (on 64-bit: 56 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) pad(20) size(24) usage(32) ...
        Memory bufCI = new Memory(56); bufCI.clear();
        bufCI.setInt(0, 12);              // sType
        bufCI.setLong(24, readSize);      // size (offset 24, VkDeviceSize = uint64)
        bufCI.setInt(32, 2);              // usage = TRANSFER_DST

        LongByReference pBuf = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateBuffer(g_vkDevice, bufCI, null, pBuf) != 0)
            throw new Exception("vkCreateBuffer failed");
        g_vkReadbackBuffer = pBuf.getValue();

        Memory bufReqs = new Memory(24); bufReqs.clear();
        VulkanDll.INSTANCE.vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuffer, bufReqs);
        long bufSize = bufReqs.getLong(0);
        int bufMemBits = bufReqs.getInt(16);

        int bufMemIdx = findMemoryType(memProps, bufMemBits, 6); // HOST_VISIBLE | HOST_COHERENT

        Memory bai = new Memory(32); bai.clear();
        bai.setInt(0, 5);
        bai.setLong(PTR == 8 ? 16 : 8, bufSize);
        bai.setInt(PTR == 8 ? 24 : 16, bufMemIdx);

        LongByReference pBufMem = new LongByReference();
        if (VulkanDll.INSTANCE.vkAllocateMemory(g_vkDevice, bai, null, pBufMem) != 0)
            throw new Exception("vkAllocateMemory(buffer) failed");
        g_vkReadbackMemory = pBufMem.getValue();
        VulkanDll.INSTANCE.vkBindBufferMemory(g_vkDevice, g_vkReadbackBuffer, g_vkReadbackMemory, 0);

        // Create render pass
        // VkAttachmentDescription: 9 * uint = 36 bytes
        Memory att = new Memory(36); att.clear();
        att.setInt(4, 44);    // format
        att.setInt(8, 1);     // samples
        att.setInt(12, 1);    // loadOp = CLEAR
        att.setInt(16, 0);    // storeOp = STORE
        att.setInt(20, 2);    // stencilLoadOp = DONT_CARE
        att.setInt(24, 1);    // stencilStoreOp = DONT_CARE
        att.setInt(32, 6);    // finalLayout = TRANSFER_SRC_OPTIMAL

        // VkAttachmentReference: 2 * uint = 8 bytes
        Memory aRef = new Memory(8); aRef.clear();
        aRef.setInt(0, 0);   // attachment
        aRef.setInt(4, 2);   // layout = COLOR_ATTACHMENT_OPTIMAL

        // VkSubpassDescription (on 64-bit: 72 bytes)
        Memory sub = new Memory(72); sub.clear();
        sub.setInt(12, 0);              // inputAttachmentCount
        sub.setInt(PTR == 8 ? 24 : 16, 1);  // colorAttachmentCount
        sub.setPointer(PTR == 8 ? 32 : 20, aRef); // pColorAttachments

        // VkRenderPassCreateInfo (on 64-bit: 64 bytes)
        Memory rpCI = new Memory(64); rpCI.clear();
        rpCI.setInt(0, 38);              // sType
        rpCI.setInt(PTR == 8 ? 16 : 8, 0); // flags
        rpCI.setInt(PTR == 8 ? 20 : 12, 1); // attachmentCount
        rpCI.setPointer(PTR == 8 ? 24 : 16, att); // pAttachments
        rpCI.setInt(PTR == 8 ? 32 : 20, 1); // subpassCount
        rpCI.setPointer(PTR == 8 ? 40 : 24, sub); // pSubpasses

        LongByReference pRP = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateRenderPass(g_vkDevice, rpCI, null, pRP) != 0)
            throw new Exception("vkCreateRenderPass failed");
        g_vkRenderPass = pRP.getValue();

        // Create framebuffer
        Memory fbAtts = new Memory(8); fbAtts.setLong(0, g_vkImageView);
        // VkFramebufferCreateInfo (on 64-bit: 64 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) pad(20) renderPass(24)
        //         attachmentCount(32) pad(36) pAttachments(40) width(48) height(52) layers(56)
        Memory fbCI = new Memory(64); fbCI.clear();
        fbCI.setInt(0, 37);                 // sType
        fbCI.setLong(24, g_vkRenderPass);    // renderPass (offset 24)
        fbCI.setInt(32, 1);                  // attachmentCount
        fbCI.setPointer(40, fbAtts);         // pAttachments
        fbCI.setInt(48, WIDTH);              // width
        fbCI.setInt(52, HEIGHT);             // height
        fbCI.setInt(56, 1);                  // layers

        LongByReference pFB = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateFramebuffer(g_vkDevice, fbCI, null, pFB) != 0)
            throw new Exception("vkCreateFramebuffer failed");
        g_vkFramebuffer = pFB.getValue();

        // Compile Vulkan shaders (SPIR-V via shaderc)
        String vertSrc = new String(Files.readAllBytes(Paths.get("hello.vert")));
        String fragSrc = new String(Files.readAllBytes(Paths.get("hello.frag")));
        byte[] vsSpv = compileSPV(vertSrc, 0, "hello.vert"); // 0 = vertex
        byte[] fsSpv = compileSPV(fragSrc, 1, "hello.frag"); // 1 = fragment

        long vsSM = createShaderModule(vsSpv);
        long fsSM = createShaderModule(fsSpv);

        // Pipeline shader stages
        Memory mainName = new Memory(8); mainName.setString(0, "main");
        // VkPipelineShaderStageCreateInfo (on 64-bit: 48 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) stage(20) module(24) pName(32) pSpec(40)
        Memory stages = new Memory(48 * 2); stages.clear();
        // Vertex stage
        stages.setInt(0, 18);                // sType
        stages.setInt(20, 1);                // stage = VERTEX_BIT (offset 20, not 16)
        stages.setLong(24, vsSM);            // module
        stages.setPointer(32, mainName);     // pName
        // Fragment stage
        stages.setInt(48, 18);
        stages.setInt(48 + 20, 0x10);        // stage = FRAGMENT_BIT
        stages.setLong(48 + 24, fsSM);
        stages.setPointer(48 + 32, mainName);

        // VkPipelineVertexInputStateCreateInfo (on 64-bit: 48 bytes)
        Memory viCI = new Memory(48); viCI.clear();
        viCI.setInt(0, 19);

        // VkPipelineInputAssemblyStateCreateInfo (on 64-bit: 32 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) topology(20) primitiveRestartEnable(24)
        Memory iaCI = new Memory(32); iaCI.clear();
        iaCI.setInt(0, 20);
        iaCI.setInt(20, 3);  // topology = TRIANGLE_LIST (offset 20, not 16)

        // VkViewport
        Memory vp = new Memory(24);
        vp.setFloat(0, 0); vp.setFloat(4, 0);
        vp.setFloat(8, WIDTH); vp.setFloat(12, HEIGHT);
        vp.setFloat(16, 0); vp.setFloat(20, 1);

        // VkRect2D scissor
        Memory sc = new Memory(16); sc.clear();
        sc.setInt(8, WIDTH); sc.setInt(12, HEIGHT);

        // VkPipelineViewportStateCreateInfo (on 64-bit: 48 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) viewportCount(20) pViewports(24) scissorCount(32) pad(36) pScissors(40)
        Memory vpCI = new Memory(48); vpCI.clear();
        vpCI.setInt(0, 22);
        vpCI.setInt(20, 1);           // viewportCount (offset 20, not 16)
        vpCI.setPointer(24, vp);
        vpCI.setInt(32, 1);           // scissorCount
        vpCI.setPointer(40, sc);

        // VkPipelineRasterizationStateCreateInfo (on 64-bit: 64 bytes)
        Memory rsCI = new Memory(64); rsCI.clear();
        rsCI.setInt(0, 23);
        rsCI.setFloat(56, 1.0f);      // lineWidth

        // VkPipelineMultisampleStateCreateInfo (on 64-bit: 48 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) rasterizationSamples(20) ...
        Memory msCI = new Memory(48); msCI.clear();
        msCI.setInt(0, 24);
        msCI.setInt(20, 1);            // rasterizationSamples = 1 (offset 20, not 16)

        // VkPipelineColorBlendAttachmentState: 8 * uint = 32 bytes
        Memory cbAtt = new Memory(32); cbAtt.clear();
        cbAtt.setInt(28, 0xF);         // colorWriteMask = RGBA

        // VkPipelineColorBlendStateCreateInfo (on 64-bit: 56 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) logicOpEnable(20) logicOp(24)
        //         attachmentCount(28) pAttachments(32) blendConstants(40..55)
        Memory cbCI = new Memory(56); cbCI.clear();
        cbCI.setInt(0, 26);
        cbCI.setInt(28, 1);            // attachmentCount (offset 28, not 20)
        cbCI.setPointer(32, cbAtt);    // pAttachments (offset 32, not 24)

        // Pipeline layout (empty)
        // VkPipelineLayoutCreateInfo (on 64-bit: 48 bytes)
        Memory plCI = new Memory(48); plCI.clear();
        plCI.setInt(0, 30);
        LongByReference pPL = new LongByReference();
        VulkanDll.INSTANCE.vkCreatePipelineLayout(g_vkDevice, plCI, null, pPL);
        g_vkPipelineLayout = pPL.getValue();

        // VkGraphicsPipelineCreateInfo (on 64-bit: 144 bytes)
        Memory gpCI = new Memory(144); gpCI.clear();
        gpCI.setInt(0, 28);                  // sType
        gpCI.setInt(20, 2);                   // stageCount
        gpCI.setPointer(24, stages);          // pStages
        gpCI.setPointer(32, viCI);            // pVertexInputState
        gpCI.setPointer(40, iaCI);            // pInputAssemblyState
        // pTessellationState at 48 = null
        gpCI.setPointer(56, vpCI);            // pViewportState
        gpCI.setPointer(64, rsCI);            // pRasterizationState
        gpCI.setPointer(72, msCI);            // pMultisampleState
        // pDepthStencilState at 80 = null
        gpCI.setPointer(88, cbCI);            // pColorBlendState
        // pDynamicState at 96 = null
        gpCI.setLong(104, g_vkPipelineLayout); // layout
        gpCI.setLong(112, g_vkRenderPass);     // renderPass
        // subpass at 120 = 0, basePipelineHandle at 128 = 0, basePipelineIndex at 136 = -1
        gpCI.setInt(136, -1);

        LongByReference pPipe = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateGraphicsPipelines(g_vkDevice, 0, 1, gpCI, null, pPipe) != 0)
            throw new Exception("vkCreateGraphicsPipelines failed");
        g_vkPipeline = pPipe.getValue();

        VulkanDll.INSTANCE.vkDestroyShaderModule(g_vkDevice, vsSM, null);
        VulkanDll.INSTANCE.vkDestroyShaderModule(g_vkDevice, fsSM, null);

        // Command pool and buffer
        // VkCommandPoolCreateInfo (on 64-bit: 24 bytes)
        Memory cpCI = new Memory(24); cpCI.clear();
        cpCI.setInt(0, 39);                  // sType
        cpCI.setInt(16, 2);                   // flags = RESET_COMMAND_BUFFER
        cpCI.setInt(20, g_vkQueueFamily);

        PointerByReference pPool = new PointerByReference();
        if (VulkanDll.INSTANCE.vkCreateCommandPool(g_vkDevice, cpCI, null, pPool) != 0)
            throw new Exception("vkCreateCommandPool failed");
        g_vkCommandPool = pPool.getValue();

        // VkCommandBufferAllocateInfo (on 64-bit: 32 bytes)
        Memory cbAI = new Memory(32); cbAI.clear();
        cbAI.setInt(0, 40);                  // sType
        cbAI.setPointer(16, g_vkCommandPool); // commandPool
        // level = 0 (PRIMARY), commandBufferCount at offset 28
        cbAI.setInt(28, 1);

        PointerByReference pCB = new PointerByReference();
        if (VulkanDll.INSTANCE.vkAllocateCommandBuffers(g_vkDevice, cbAI, pCB) != 0)
            throw new Exception("vkAllocateCommandBuffers failed");
        g_vkCommandBuffer = pCB.getValue();

        // Fence (signaled)
        // VkFenceCreateInfo: sType(0) pad(4) pNext(8) flags(16) -> 20 bytes
        Memory fCI = new Memory(24); fCI.clear();
        fCI.setInt(0, 8);                    // sType
        fCI.setInt(16, 1);                   // flags = SIGNALED (offset 16, not 12)

        LongByReference pFence = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateFence(g_vkDevice, fCI, null, pFence) != 0)
            throw new Exception("vkCreateFence failed");
        g_vkFence = pFence.getValue();

        // Create D3D11 staging texture for Vulkan readback copy
        g_stagingTexture = createStagingTexture();

        // Get swap chain back buffer for copy destination
        PointerByReference pSCBB = new PointerByReference();
        int hr = comCall(swapChain, 9, 0, guidToMemory(IID_ID3D11Texture2D), pSCBB);
        if (hr < 0) throw new Exception("GetBuffer failed hr=0x" + String.format("%08X", hr));
        g_swapChainBackBuffer = pSCBB.getValue();

        dbg(FN, "ok");
    }

    static long createShaderModule(byte[] spv) {
        // VkShaderModuleCreateInfo (on 64-bit: 40 bytes)
        // Layout: sType(0) pad(4) pNext(8) flags(16) pad(20) codeSize(24) pCode(32)
        Memory data = new Memory(spv.length);
        data.write(0, spv, 0, spv.length);
        Memory ci = new Memory(40); ci.clear();
        ci.setInt(0, 16);                         // sType
        ci.setLong(24, spv.length);                // codeSize (offset 24, size_t)
        ci.setPointer(32, data);                   // pCode (offset 32)
        LongByReference pSM = new LongByReference();
        if (VulkanDll.INSTANCE.vkCreateShaderModule(g_vkDevice, ci, null, pSM) != 0)
            throw new RuntimeException("vkCreateShaderModule failed");
        return pSM.getValue();
    }

    static int findMemoryType(Memory memProps, int bits, int required) {
        // memProps layout: memoryTypeCount(4) + memoryTypes[32](each 8 bytes: propertyFlags+heapIndex)
        int typeCount = memProps.getInt(0);
        for (int i = 0; i < typeCount; i++) {
            if ((bits & (1 << i)) == 0) continue;
            int props = memProps.getInt(4 + i * 8); // propertyFlags
            if ((props & required) == required) return i;
        }
        throw new RuntimeException("No suitable VK memory type");
    }

    static Pointer createStagingTexture() {
        // D3D11_TEXTURE2D_DESC (48 bytes, Pack=1 default)
        Memory desc = new Memory(48); desc.clear();
        desc.setInt(0, WIDTH);                         // Width
        desc.setInt(4, HEIGHT);                        // Height
        desc.setInt(8, 1);                             // MipLevels
        desc.setInt(12, 1);                            // ArraySize
        desc.setInt(16, DXGI_FORMAT_B8G8R8A8_UNORM);  // Format
        desc.setInt(20, 1);                            // SampleDesc.Count
        desc.setInt(24, 0);                            // SampleDesc.Quality
        desc.setInt(28, D3D11_USAGE_STAGING);          // Usage
        desc.setInt(32, 0);                            // BindFlags
        desc.setInt(36, D3D11_CPU_ACCESS_WRITE);       // CPUAccessFlags

        PointerByReference pTex = new PointerByReference();
        int hr = comCall(g_d3dDevice, 5, desc, Pointer.NULL, pTex); // CreateTexture2D (vt#5)
        if (hr < 0) throw new RuntimeException("CreateTexture2D(staging) failed hr=0x" + String.format("%08X", hr));
        return pTex.getValue();
    }

    // ============================================================
    // InitComposition
    //   Sets up Windows.UI.Composition visual tree with 3 panels
    // ============================================================
    static Pointer g_glSwapChain, g_vkSwapChain;

    static int addCompositionPanel(Pointer swapChain, float offsetX, int index) {
        final String FN = "AddPanel[" + index + "]";

        // QI compositor -> ICompositorInterop
        PointerByReference pCI = new PointerByReference();
        int hr = QI(g_compositorUnk, IID_ICompositorInterop, pCI);
        if (hr < 0) { dbgHR(FN, "QI(ICompositorInterop)", hr); return hr; }

        // ICompositorInterop::CreateCompositionSurfaceForSwapChain (vt#4)
        PointerByReference pSurface = new PointerByReference();
        hr = comCall(pCI.getValue(), 4, swapChain, pSurface);
        comRelease(pCI.getValue());
        if (hr < 0) { dbgHR(FN, "CreateCompSurfaceForSC", hr); return hr; }

        // ICompositor::CreateSurfaceBrushWithSurface (vt#24)
        PointerByReference pBrush = new PointerByReference();
        hr = comCall(g_compositor, 24, pSurface.getValue(), pBrush);
        comRelease(pSurface.getValue());
        if (hr < 0) return hr;

        // QI brush -> ICompositionBrush
        PointerByReference pCB = new PointerByReference();
        hr = QI(pBrush.getValue(), IID_ICompositionBrush, pCB);
        comRelease(pBrush.getValue());
        if (hr < 0) return hr;
        g_brush[index] = pCB.getValue();

        // ICompositor::CreateSpriteVisual (vt#22)
        PointerByReference pSV = new PointerByReference();
        hr = comCall(g_compositor, 22, pSV);
        if (hr < 0) return hr;
        g_spriteRaw[index] = pSV.getValue();

        // ISpriteVisual::put_Brush (vt#7)
        hr = comCall(g_spriteRaw[index], 7, g_brush[index]);
        if (hr < 0) return hr;

        // QI sprite -> IVisual
        PointerByReference pVis = new PointerByReference();
        hr = QI(g_spriteRaw[index], IID_IVisual, pVis);
        if (hr < 0) return hr;
        g_spriteVisual[index] = pVis.getValue();

        // IVisual::put_Size (vt#36) - takes Float2 by value (2 floats = 8 bytes)
        // On x64 Windows, small structs <= 8 bytes are passed in a single register (as long)
        long sizeVal = packFloat2(WIDTH, HEIGHT);
        hr = comCall(g_spriteVisual[index], 36, sizeVal);
        if (hr < 0) return hr;

        // IVisual::put_Offset (vt#21) - takes Float3 by value (3 floats = 12 bytes)
        // On x64 Windows, 12-byte struct is passed by pointer (hidden)
        Memory offset = new Memory(12);
        offset.setFloat(0, offsetX);
        offset.setFloat(4, 0.0f);
        offset.setFloat(8, 0.0f);
        hr = comCall(g_spriteVisual[index], 21, offset);
        if (hr < 0) return hr;

        // IVisualCollection::InsertAtTop (vt#9)
        hr = comCall(g_children, 9, g_spriteVisual[index]);
        return hr;
    }

    // Pack two floats into a single long for passing Float2 by value on x64
    static long packFloat2(float x, float y) {
        int ix = Float.floatToRawIntBits(x);
        int iy = Float.floatToRawIntBits(y);
        return ((long)iy << 32) | (ix & 0xFFFFFFFFL);
    }

    static int initComposition() {
        final String FN = "InitComposition";
        dbg(FN, "begin");

        int hr = ComBaseDll.INSTANCE.RoInitialize(0); // STA
        if (hr < 0 && hr != 1) return hr;

        // Create DispatcherQueueController
        DispatcherQueueOptions dqOpt = new DispatcherQueueOptions();
        dqOpt.threadType = 2;     // DQTYPE_THREAD_CURRENT
        dqOpt.apartmentType = 0;  // DQTAT_COM_NONE
        PointerByReference pDQ = new PointerByReference();
        hr = CoreMsgDll.INSTANCE.CreateDispatcherQueueController(dqOpt, pDQ);
        if (hr < 0) { dbgHR(FN, "CreateDispatcherQueueController", hr); return hr; }
        g_dqController = pDQ.getValue();

        // RoActivateInstance("Windows.UI.Composition.Compositor")
        String className = "Windows.UI.Composition.Compositor";
        Pointer hstr = createHString(className);
        PointerByReference pUnk = new PointerByReference();
        hr = ComBaseDll.INSTANCE.RoActivateInstance(hstr, pUnk);
        ComBaseDll.INSTANCE.WindowsDeleteString(hstr);
        if (hr < 0) { dbgHR(FN, "RoActivateInstance(Compositor)", hr); return hr; }
        g_compositorUnk = pUnk.getValue();

        // QI -> ICompositor
        PointerByReference pComp = new PointerByReference();
        hr = QI(g_compositorUnk, IID_ICompositor, pComp);
        if (hr < 0) return hr;
        g_compositor = pComp.getValue();

        // QI -> ICompositorDesktopInterop
        PointerByReference pDI = new PointerByReference();
        hr = QI(g_compositorUnk, IID_ICompositorDesktopInterop, pDI);
        if (hr < 0) return hr;

        // ICompositorDesktopInterop::CreateDesktopWindowTarget (vt#3)
        PointerByReference pDT = new PointerByReference();
        hr = comCall(pDI.getValue(), 3, g_hwnd, 0, pDT);
        comRelease(pDI.getValue());
        if (hr < 0) { dbgHR(FN, "CreateDesktopWindowTarget", hr); return hr; }
        g_desktopTarget = pDT.getValue();

        // QI -> ICompositionTarget
        PointerByReference pCT = new PointerByReference();
        hr = QI(g_desktopTarget, IID_ICompositionTarget, pCT);
        if (hr < 0) return hr;
        g_compTarget = pCT.getValue();

        // ICompositor::CreateContainerVisual (vt#9)
        PointerByReference pCV = new PointerByReference();
        hr = comCall(g_compositor, 9, pCV);
        if (hr < 0) return hr;
        g_rootContainer = pCV.getValue();

        // QI container -> IVisual (for setting as root)
        PointerByReference pRV = new PointerByReference();
        hr = QI(g_rootContainer, IID_IVisual, pRV);
        if (hr < 0) return hr;
        g_rootVisual = pRV.getValue();

        // ICompositionTarget::put_Root (vt#7)
        hr = comCall(g_compTarget, 7, g_rootVisual);
        if (hr < 0) return hr;

        // IContainerVisual::get_Children (vt#6)
        PointerByReference pChildren = new PointerByReference();
        hr = comCall(g_rootContainer, 6, pChildren);
        if (hr < 0) return hr;
        g_children = pChildren.getValue();

        // Add three composition panels: OpenGL, D3D11, Vulkan
        hr = addCompositionPanel(g_glSwapChain,  0.0f, 0);
        if (hr < 0) { dbgHR(FN, "AddPanel(GL)", hr); return hr; }
        hr = addCompositionPanel(g_d3dSwapChain, (float)WIDTH, 1);
        if (hr < 0) { dbgHR(FN, "AddPanel(D3D)", hr); return hr; }
        hr = addCompositionPanel(g_vkSwapChain,  (float)WIDTH * 2, 2);
        if (hr < 0) { dbgHR(FN, "AddPanel(VK)", hr); return hr; }

        dbg(FN, "ok");
        return 0;
    }

    // ============================================================
    // RenderOpenGL
    //   Renders triangle to FBO shared with D3D11 swap chain
    // ============================================================
    static void renderOpenGL() {
        OpenGL32Lib.INSTANCE.wglMakeCurrent(g_hDC, g_hGLRC);
        Pointer[] objs = { g_dxInteropObject };
        boolean locked = (boolean) fn_wglDXLockObjectsNV.invoke(boolean.class,
            new Object[]{ g_dxInteropDevice, 1, objs });
        if (!locked) return;

        try {
            fn_glBindFramebuffer.invoke(void.class, new Object[]{ GL_FRAMEBUFFER, g_fbo });
            OpenGL32Lib.INSTANCE.glViewport(0, 0, WIDTH, HEIGHT);
            OpenGL32Lib.INSTANCE.glClearColor(0.05f, 0.05f, 0.15f, 1f);
            OpenGL32Lib.INSTANCE.glClear(GL_COLOR_BUFFER_BIT);
            fn_glUseProgram.invoke(void.class, new Object[]{ g_program });

            fn_glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, g_vbo[0] });
            fn_glVertexAttribPointer.invoke(void.class,
                new Object[]{ g_posAttrib, 3, GL_FLOAT, false, 0, Pointer.NULL });
            fn_glBindBuffer.invoke(void.class, new Object[]{ GL_ARRAY_BUFFER, g_vbo[1] });
            fn_glVertexAttribPointer.invoke(void.class,
                new Object[]{ g_colAttrib, 3, GL_FLOAT, false, 0, Pointer.NULL });

            OpenGL32Lib.INSTANCE.glDrawArrays(GL_TRIANGLES, 0, 3);
            OpenGL32Lib.INSTANCE.glFlush();
            fn_glBindFramebuffer.invoke(void.class, new Object[]{ GL_FRAMEBUFFER, 0 });
        } finally {
            fn_wglDXUnlockObjectsNV.invoke(boolean.class,
                new Object[]{ g_dxInteropDevice, 1, objs });
        }

        // IDXGISwapChain::Present (vt#8)
        comCall(g_glSwapChain, 8, 1, 0);
    }

    // ============================================================
    // RenderD3D11
    //   Renders triangle using D3D11 pipeline
    // ============================================================
    static void renderD3D11() {
        Pointer ctx = g_d3dContext;

        try {
            // RSSetViewports (vt#44)
            Memory vp = new Memory(24);
            vp.setFloat(0, 0); vp.setFloat(4, 0);
            vp.setFloat(8, WIDTH); vp.setFloat(12, HEIGHT);
            vp.setFloat(16, 0); vp.setFloat(20, 1);
            comCallVoid(ctx, 44, 1, vp);

            // OMSetRenderTargets (vt#33)
            Memory rtvArr = new Memory(PTR);
            rtvArr.setPointer(0, g_rtv);
            comCallVoid(ctx, 33, 1, rtvArr, Pointer.NULL);

            // ClearRenderTargetView (vt#50)
            float[] clearColor = { 0.05f, 0.15f, 0.05f, 1f };
            comCallVoid(ctx, 50, g_rtv, clearColor);

            // IASetInputLayout (vt#17)
            comCallVoid(ctx, 17, g_inputLayout);

            // IASetVertexBuffers (vt#18)
            Memory vbs = new Memory(PTR); vbs.setPointer(0, g_vertexBuffer);
            int[] strides = { 28 }; // 7 floats * 4 bytes
            int[] offsets = { 0 };
            comCallVoid(ctx, 18, 0, 1, vbs, strides, offsets);

            // IASetPrimitiveTopology (vt#24)
            comCallVoid(ctx, 24, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

            // VSSetShader (vt#11)
            comCallVoid(ctx, 11, g_vs, (Pointer) null, 0);

            // PSSetShader (vt#9)
            comCallVoid(ctx, 9, g_ps, (Pointer) null, 0);

            // Draw (vt#13)
            comCallVoid(ctx, 13, 3, 0);

            // IDXGISwapChain::Present (vt#8)
            int hr = comCall(g_d3dSwapChain, 8, 1, 0);
            if (g_firstRender) {
                dbg("RenderD3D11", "first frame Present hr=0x" + String.format("%08X", hr));
                g_firstRender = false;
            }
        } catch (Exception ex) {
            dbg("RenderD3D11", "EXCEPTION: " + ex.getMessage());
        }
    }

    // ============================================================
    // RenderVulkan
    //   Offscreen render -> readback -> copy to D3D11 staging -> present
    // ============================================================
    static void renderVulkan() {
        long[] f = { g_vkFence };
        VulkanDll.INSTANCE.vkWaitForFences(g_vkDevice, 1, f, 1, Long.MAX_VALUE);
        VulkanDll.INSTANCE.vkResetFences(g_vkDevice, 1, f);
        VulkanDll.INSTANCE.vkResetCommandBuffer(g_vkCommandBuffer, 0);

        // Begin command buffer
        // VkCommandBufferBeginInfo (on 64-bit: 32 bytes)
        Memory bi = new Memory(32); bi.clear();
        bi.setInt(0, 42); // sType
        VulkanDll.INSTANCE.vkBeginCommandBuffer(g_vkCommandBuffer, bi);

        // Begin render pass
        // VkClearValue: float4 = 16 bytes
        Memory cv = new Memory(16);
        cv.setFloat(0, 0.15f); cv.setFloat(4, 0.05f);
        cv.setFloat(8, 0.05f); cv.setFloat(12, 1.0f);

        // VkRenderPassBeginInfo (on 64-bit: 64 bytes)
        Memory rpbi = new Memory(64); rpbi.clear();
        rpbi.setInt(0, 43);                   // sType
        rpbi.setLong(16, g_vkRenderPass);      // renderPass
        rpbi.setLong(24, g_vkFramebuffer);     // framebuffer
        // renderArea: offset(0,0), extent(W,H)
        rpbi.setInt(40, WIDTH);                // extent.width
        rpbi.setInt(44, HEIGHT);               // extent.height
        rpbi.setInt(48, 1);                    // clearValueCount
        rpbi.setPointer(56, cv);               // pClearValues

        VulkanDll.INSTANCE.vkCmdBeginRenderPass(g_vkCommandBuffer, rpbi, 0);
        VulkanDll.INSTANCE.vkCmdBindPipeline(g_vkCommandBuffer, 0, g_vkPipeline);
        VulkanDll.INSTANCE.vkCmdDraw(g_vkCommandBuffer, 3, 1, 0, 0);
        VulkanDll.INSTANCE.vkCmdEndRenderPass(g_vkCommandBuffer);

        // Copy image to readback buffer
        // VkBufferImageCopy (56 bytes)
        // Layout: bufferOffset(0,8) bufferRowLength(8) bufferImageHeight(12)
        //         imageSubresource: aspectMask(16) mipLevel(20) baseArrayLayer(24) layerCount(28)
        //         imageOffset: x(32) y(36) z(40)
        //         imageExtent: width(44) height(48) depth(52)
        Memory region = new Memory(56); region.clear();
        region.setInt(8, WIDTH);      // bufferRowLength
        region.setInt(12, HEIGHT);    // bufferImageHeight
        region.setInt(16, 1);         // aspectMask = COLOR
        region.setInt(28, 1);         // layerCount
        // imageOffset at 32-43 = (0,0,0) from clear
        region.setInt(44, WIDTH);     // imageExtent.width (offset 44, not 40)
        region.setInt(48, HEIGHT);    // imageExtent.height (offset 48, not 44)
        region.setInt(52, 1);         // imageExtent.depth (offset 52, not 48)

        VulkanDll.INSTANCE.vkCmdCopyImageToBuffer(g_vkCommandBuffer, g_vkImage,
            6, // TRANSFER_SRC_OPTIMAL
            g_vkReadbackBuffer, 1, region);
        VulkanDll.INSTANCE.vkEndCommandBuffer(g_vkCommandBuffer);

        // Submit
        // VkSubmitInfo (on 64-bit: 72 bytes)
        // Layout: sType(0) pad(4) pNext(8) waitSemaphoreCount(16) pad(20) pWaitSemaphores(24)
        //         pWaitDstStageMask(32) commandBufferCount(40) pad(44) pCommandBuffers(48)
        //         signalSemaphoreCount(56) pad(60) pSignalSemaphores(64)
        Memory cbPtrs = new Memory(PTR);
        cbPtrs.setPointer(0, g_vkCommandBuffer);
        Memory si = new Memory(72); si.clear();
        si.setInt(0, 4);         // sType
        si.setInt(40, 1);        // commandBufferCount (offset 40, not 32)
        si.setPointer(48, cbPtrs); // pCommandBuffers (offset 48, not 40)

        VulkanDll.INSTANCE.vkQueueSubmit(g_vkQueue, 1, si, g_vkFence);

        // Wait for completion and copy to D3D11
        VulkanDll.INSTANCE.vkWaitForFences(g_vkDevice, 1, f, 1, Long.MAX_VALUE);

        PointerByReference pSrc = new PointerByReference();
        VulkanDll.INSTANCE.vkMapMemory(g_vkDevice, g_vkReadbackMemory, 0,
            (long) WIDTH * HEIGHT * 4, 0, pSrc);
        Pointer src = pSrc.getValue();

        // Map D3D11 staging texture (ID3D11DeviceContext::Map vt#14)
        // D3D11_MAPPED_SUBRESOURCE: pData(ptr) + RowPitch(uint) + DepthPitch(uint)
        Memory mapped = new Memory(PTR + 8);
        int hr = comCall(g_d3dContext, 14, g_stagingTexture, 0, D3D11_MAP_WRITE, 0, mapped);
        if (hr >= 0) {
            Pointer dst = mapped.getPointer(0);
            int rowPitch = mapped.getInt(PTR);
            int srcPitch = WIDTH * 4;
            for (int y = 0; y < HEIGHT; y++) {
                dst.write((long)y * rowPitch, src.getByteArray((long)y * srcPitch, srcPitch), 0, srcPitch);
            }
            // Unmap (vt#15)
            comCallVoid(g_d3dContext, 15, g_stagingTexture, 0);
        }
        VulkanDll.INSTANCE.vkUnmapMemory(g_vkDevice, g_vkReadbackMemory);

        // CopyResource (vt#47): copy staging -> swap chain back buffer
        comCallVoid(g_d3dContext, 47, g_swapChainBackBuffer, g_stagingTexture);

        // Present (vt#8)
        comCall(g_vkSwapChain, 8, 1, 0);
    }

    // ============================================================
    // Cleanup
    // ============================================================
    static void cleanup() {
        final String FN = "Cleanup";
        dbg(FN, "begin");

        // OpenGL cleanup
        if (g_dxInteropObject != null && g_dxInteropDevice != null) {
            fn_wglDXUnregisterObjectNV.invoke(boolean.class,
                new Object[]{ g_dxInteropDevice, g_dxInteropObject });
        }
        if (g_dxInteropDevice != null) {
            fn_wglDXCloseDeviceNV.invoke(boolean.class, new Object[]{ g_dxInteropDevice });
        }
        OpenGL32Lib.INSTANCE.wglMakeCurrent(null, null);
        if (g_hGLRC != null) OpenGL32Lib.INSTANCE.wglDeleteContext(g_hGLRC);
        if (g_hDC != null) User32Lib.INSTANCE.ReleaseDC(g_hwnd, g_hDC);

        // Composition cleanup
        comRelease(g_children);
        for (int i = 0; i < PANEL_COUNT; i++) {
            comRelease(g_spriteVisual[i]);
            comRelease(g_spriteRaw[i]);
            comRelease(g_brush[i]);
        }
        comRelease(g_rootVisual);
        comRelease(g_rootContainer);
        comRelease(g_compTarget);
        comRelease(g_desktopTarget);
        comRelease(g_compositor);
        comRelease(g_compositorUnk);
        comRelease(g_dqController);

        // D3D11 cleanup
        comRelease(g_vertexBuffer);
        comRelease(g_inputLayout);
        comRelease(g_ps);
        comRelease(g_vs);
        comRelease(g_rtv);
        comRelease(g_d3dSwapChain);
        comRelease(g_glSwapChain);
        comRelease(g_vkSwapChain);
        comRelease(g_swapChainBackBuffer);
        comRelease(g_stagingTexture);
        if (g_vkDevice != null) VulkanDll.INSTANCE.vkDeviceWaitIdle(g_vkDevice);
        comRelease(g_d3dContext);
        comRelease(g_d3dDevice);

        dbg(FN, "ok");
    }

    // ============================================================
    // Entry Point
    // ============================================================
    public static void main(String[] args) {
        final String FN = "Main";
        dbg(FN, "========================================");
        dbg(FN, "OpenGL 4.6 + D3D11 + Vulkan 1.4 via Composition (Java+JNA vtable)");
        dbg(FN, "========================================");

        g_hwnd = createAppWindow();
        if (g_hwnd == null) { dbg(FN, "FATAL: createAppWindow failed"); return; }

        int hr = initD3D11();
        if (hr < 0) { dbg(FN, "FATAL: initD3D11 failed"); cleanup(); return; }

        g_glSwapChain = createSwapChainForComposition();
        if (g_glSwapChain == null) { dbg(FN, "FATAL: createSwapChain(GL) failed"); cleanup(); return; }
        g_vkSwapChain = createSwapChainForComposition();
        if (g_vkSwapChain == null) { dbg(FN, "FATAL: createSwapChain(VK) failed"); cleanup(); return; }

        hr = initOpenGLInterop(g_glSwapChain);
        if (hr < 0) { dbg(FN, "FATAL: initOpenGLInterop failed"); cleanup(); return; }

        try {
            initVulkan(g_vkSwapChain);
        } catch (Exception ex) {
            dbg(FN, "FATAL: initVulkan failed: " + ex.getMessage());
            cleanup();
            return;
        }

        hr = initComposition();
        if (hr < 0) { dbg(FN, "FATAL: initComposition failed"); cleanup(); return; }

        dbg(FN, "entering message loop");
        MSG msg = new MSG();
        while (true) {
            if (User32Lib.INSTANCE.PeekMessageW(msg, null, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) break;
                User32Lib.INSTANCE.TranslateMessage(msg);
                User32Lib.INSTANCE.DispatchMessageW(msg);
            } else {
                renderOpenGL();
                renderD3D11();
                renderVulkan();
            }
        }

        dbg(FN, "message loop ended");
        cleanup();
        dbg(FN, "exit");
    }
}
