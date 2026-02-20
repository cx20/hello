// Hello.cs
// OpenGL 4.6 + DirectX 11 + Vulkan 1.4 triangles composited via DirectComposition
// Compile: csc /target:winexe /unsafe Hello.cs
//
// Requirements:
//   Windows 8+ (DirectComposition), NVIDIA/AMD/Intel GPU with WGL_NV_DX_interop2
//   Vulkan SDK (shaderc_shared.dll + vulkan-1.dll), hello.vert/hello.frag in same folder

using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

// Win32
[StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
[StructLayout(LayoutKind.Sequential)] struct RECT  { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)]
struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public POINT pt; }
delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
struct WNDCLASSEX { public uint cbSize, style; public WndProcDelegate lpfnWndProc; public int cbClsExtra, cbWndExtra; public IntPtr hInstance, hIcon, hCursor, hbrBackground; public string lpszMenuName, lpszClassName; public IntPtr hIconSm; }
[StructLayout(LayoutKind.Sequential)]
struct PIXELFORMATDESCRIPTOR { public ushort nSize, nVersion; public uint dwFlags; public byte iPixelType, cColorBits, cRedBits, cRedShift, cGreenBits, cGreenShift, cBlueBits, cBlueShift, cAlphaBits, cAlphaShift, cAccumBits, cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits, cDepthBits, cStencilBits, cAuxBuffers, iLayerType, bReserved; public uint dwLayerMask, dwVisibleMask, dwDamageMask; }

// D3D11/DXGI
[StructLayout(LayoutKind.Sequential)] struct DXGI_SAMPLE_DESC { public uint Count, Quality; }
[StructLayout(LayoutKind.Sequential)] struct DXGI_SWAP_CHAIN_DESC1 { public uint Width, Height, Format; [MarshalAs(UnmanagedType.Bool)] public bool Stereo; public DXGI_SAMPLE_DESC SampleDesc; public uint BufferUsage, BufferCount, Scaling, SwapEffect, AlphaMode, Flags; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_TEXTURE2D_DESC { public uint Width, Height, MipLevels, ArraySize, Format; public DXGI_SAMPLE_DESC SampleDesc; public uint Usage, BindFlags, CPUAccessFlags, MiscFlags; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_MAPPED_SUBRESOURCE { public IntPtr pData; public uint RowPitch, DepthPitch; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_BUFFER_DESC { public uint ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_SUBRESOURCE_DATA { public IntPtr pSysMem; public uint SysMemPitch, SysMemSlicePitch; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_INPUT_ELEMENT_DESC { [MarshalAs(UnmanagedType.LPStr)] public string SemanticName; public uint SemanticIndex, Format, InputSlot, AlignedByteOffset, InputSlotClass, InstanceDataStepRate; }
[StructLayout(LayoutKind.Sequential)] struct D3D11_VIEWPORT { public float TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth; }
[StructLayout(LayoutKind.Sequential)] struct DxVertex { public float X, Y, Z, R, G, B, A; }

// COM delegates
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int QIDelegate(IntPtr self, ref Guid riid, out IntPtr ppv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateRTVDelegate(IntPtr d, IntPtr r, IntPtr desc, out IntPtr rtv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateBufferDelegate(IntPtr d, ref D3D11_BUFFER_DESC desc, ref D3D11_SUBRESOURCE_DATA data, out IntPtr buf);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateTex2DDelegate(IntPtr d, ref D3D11_TEXTURE2D_DESC desc, IntPtr init, out IntPtr tex);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateVSDelegate(IntPtr d, IntPtr bc, IntPtr sz, IntPtr lnk, out IntPtr vs);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreatePSDelegate(IntPtr d, IntPtr bc, IntPtr sz, IntPtr lnk, out IntPtr ps);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateILDelegate(IntPtr d, [In] D3D11_INPUT_ELEMENT_DESC[] e, uint n, IntPtr bc, IntPtr sz, out IntPtr il);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void PSSetDelegate(IntPtr c, IntPtr ps, IntPtr[] ci, uint n);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void VSSetDelegate(IntPtr c, IntPtr vs, IntPtr[] ci, uint n);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void DrawDelegate(IntPtr c, uint cnt, uint start);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int MapDelegate(IntPtr c, IntPtr r, uint sub, uint type, uint flags, out D3D11_MAPPED_SUBRESOURCE m);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void UnmapDelegate(IntPtr c, IntPtr r, uint sub);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetILDelegate(IntPtr c, IntPtr il);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetVBDelegate(IntPtr c, uint slot, uint n, IntPtr[] vbs, uint[] strides, uint[] offs);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetTopoDelegate(IntPtr c, uint topo);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void OMSetRTDelegate(IntPtr c, uint n, IntPtr[] rtvs, IntPtr dsv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void RSSetVPDelegate(IntPtr c, uint n, ref D3D11_VIEWPORT vp);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void CopyResDelegate(IntPtr c, IntPtr dst, IntPtr src);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void ClearRTVDelegate(IntPtr c, IntPtr rtv, [MarshalAs(UnmanagedType.LPArray, SizeConst=4)] float[] col);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int PresentDelegate(IntPtr sc, uint sync, uint flags);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetBufDelegate(IntPtr sc, uint buf, ref Guid iid, out IntPtr srf);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateSCCompDelegate(IntPtr fac, IntPtr dev, ref DXGI_SWAP_CHAIN_DESC1 desc, IntPtr restrict, out IntPtr sc);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr BlobPtrDelegate(IntPtr b);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr BlobSzDelegate(IntPtr b);
// DComp
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCCommitDelegate(IntPtr d);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCCreateTargetDelegate(IntPtr d, IntPtr hw, int top, out IntPtr t);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCCreateVisDelegate(IntPtr d, out IntPtr v);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCSetRootDelegate(IntPtr t, IntPtr v);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCSetOffXDelegate(IntPtr v, float x);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCSetOffYDelegate(IntPtr v, float y);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCSetContentDelegate(IntPtr v, IntPtr c);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int DCAddVisDelegate(IntPtr v, IntPtr ch, int above, IntPtr rf);
// GL
delegate void glGenBuffersD(int n, uint[] b); delegate void glBindBufferD(uint t, uint b);
delegate void glBufferDataD(uint t, int sz, float[] d, uint u); delegate uint glCreateShaderD(uint t);
delegate void glShaderSourceD(uint s, int c, string[] src, int[] len); delegate void glCompileShaderD(uint s);
delegate uint glCreateProgramD(); delegate void glAttachShaderD(uint p, uint s);
delegate void glLinkProgramD(uint p); delegate void glUseProgramD(uint p);
delegate uint glGetAttribLocationD(uint p, string n); delegate void glEnableVAD(uint i);
delegate void glVertexAttribPointerD(uint i, int sz, uint t, bool norm, int stride, IntPtr ptr);
delegate void glGenFBD(int n, uint[] f); delegate void glBindFBD(uint t, uint f);
delegate void glFBRBD(uint t, uint a, uint rt, uint rb); delegate void glGenRBD(int n, uint[] r);
delegate void glGenVAOD(int n, uint[] v); delegate void glBindVAOD(uint v);
delegate IntPtr wglCreateCtxARBD(IntPtr hdc, IntPtr sh, int[] a);
delegate IntPtr wglDXOpenD(IntPtr dx); delegate IntPtr wglDXRegD(IntPtr h, IntPtr dx, uint gl, uint t, uint a);
delegate int wglDXLockD(IntPtr h, int c, IntPtr[] o); delegate int wglDXUnlockD(IntPtr h, int c, IntPtr[] o);

// Vulkan structs
[StructLayout(LayoutKind.Sequential)] struct VkAppInfo { public uint sType; public IntPtr pNext, pAppName; public uint appVer; public IntPtr pEngName; public uint engVer, apiVer; }
[StructLayout(LayoutKind.Sequential)] struct VkInstCI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pAppInfo; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; }
[StructLayout(LayoutKind.Sequential)] struct VkDevQCI { public uint sType; public IntPtr pNext; public uint flags, qfi, qCnt; public IntPtr pPrio; }
[StructLayout(LayoutKind.Sequential)] struct VkDevCI { public uint sType; public IntPtr pNext; public uint flags, qciCnt; public IntPtr pQCI; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; public IntPtr pFeat; }
[StructLayout(LayoutKind.Sequential)] struct VkQFP { public uint qFlags, qCnt, tsVB, gW, gH, gD; }
[StructLayout(LayoutKind.Sequential)] struct VkMemReq { public ulong size, align; public uint memBits; }
[StructLayout(LayoutKind.Sequential)] struct VkMemAI { public uint sType; public IntPtr pNext; public ulong size; public uint memIdx; }
[StructLayout(LayoutKind.Sequential)] struct VkMemType { public uint propFlags, heapIdx; }
[StructLayout(LayoutKind.Sequential, Pack=4)] unsafe struct VkPhysMemProps { public uint typeCnt; public fixed byte types[256]; public uint heapCnt; public fixed byte heaps[256]; }
[StructLayout(LayoutKind.Sequential)] struct VkImgCI { public uint sType; public IntPtr pNext; public uint flags, imgType, fmt, eW, eH, eD, mip, arr, samples, tiling, usage, sharing, qfCnt; public IntPtr pQF; public uint initLayout; }
[StructLayout(LayoutKind.Sequential)] struct VkImgViewCI { public uint sType; public IntPtr pNext; public uint flags; public ulong img; public uint viewType, fmt, cR, cG, cB, cA, aspect, baseMip, lvlCnt, baseLayer, layerCnt; }
[StructLayout(LayoutKind.Sequential)] struct VkBufCI { public uint sType; public IntPtr pNext; public uint flags; public ulong size; public uint usage, sharing, qfCnt; public IntPtr pQF; }
[StructLayout(LayoutKind.Sequential)] struct VkAttDesc { public uint flags, fmt, samples, loadOp, storeOp, stLoadOp, stStoreOp, initLayout, finalLayout; }
[StructLayout(LayoutKind.Sequential)] struct VkAttRef { public uint att, layout; }
[StructLayout(LayoutKind.Sequential)] struct VkSubDesc { public uint flags, bp, iaCnt; public IntPtr pIA; public uint caCnt; public IntPtr pCA, pRA, pDA; public uint paCnt; public IntPtr pPA; }
[StructLayout(LayoutKind.Sequential)] struct VkRPCI { public uint sType; public IntPtr pNext; public uint flags, attCnt; public IntPtr pAtts; public uint subCnt; public IntPtr pSubs; public uint depCnt; public IntPtr pDeps; }
[StructLayout(LayoutKind.Sequential)] struct VkFBCI { public uint sType; public IntPtr pNext; public uint flags; public ulong rp; public uint attCnt; public IntPtr pAtts; public uint w, h, layers; }
[StructLayout(LayoutKind.Sequential)] struct VkSMCI { public uint sType; public IntPtr pNext; public uint flags; public UIntPtr codeSz; public IntPtr pCode; }
[StructLayout(LayoutKind.Sequential)] struct VkPSSCI { public uint sType; public IntPtr pNext; public uint flags, stage; public ulong module; public IntPtr pName, pSpec; }
[StructLayout(LayoutKind.Sequential)] struct VkPVICI { public uint sType; public IntPtr pNext; public uint flags, vbdCnt; public IntPtr pVBD; public uint vadCnt; public IntPtr pVAD; }
[StructLayout(LayoutKind.Sequential)] struct VkPIACI { public uint sType; public IntPtr pNext; public uint flags, topo, primRestart; }
[StructLayout(LayoutKind.Sequential)] struct VkViewport { public float x, y, w, h, minD, maxD; }
[StructLayout(LayoutKind.Sequential)] struct VkOff2D { public int x, y; }
[StructLayout(LayoutKind.Sequential)] struct VkExt2D { public uint w, h; }
[StructLayout(LayoutKind.Sequential)] struct VkRect2D { public VkOff2D off; public VkExt2D ext; }
[StructLayout(LayoutKind.Sequential)] struct VkPVPCI { public uint sType; public IntPtr pNext; public uint flags, vpCnt; public IntPtr pVP; public uint scCnt; public IntPtr pSC; }
[StructLayout(LayoutKind.Sequential)] struct VkPRCI { public uint sType; public IntPtr pNext; public uint flags, depthClamp, rastDiscard, polyMode, cullMode, frontFace, depthBias; public float dbConst, dbClamp, dbSlope, lineW; }
[StructLayout(LayoutKind.Sequential)] struct VkPMSCI { public uint sType; public IntPtr pNext; public uint flags, rSamples, sShading; public float minSS; public IntPtr pSM; public uint a2c, a2o; }
[StructLayout(LayoutKind.Sequential)] struct VkPCBAS { public uint blendEn, sCBF, dCBF, cbOp, sABF, dABF, abOp, wMask; }
[StructLayout(LayoutKind.Sequential)] unsafe struct VkPCBCI { public uint sType; public IntPtr pNext; public uint flags, logicOpEn, logicOp, attCnt; public IntPtr pAtts; public fixed float bc[4]; }
[StructLayout(LayoutKind.Sequential)] struct VkPLCI { public uint sType; public IntPtr pNext; public uint flags, slCnt; public IntPtr pSL; public uint pcCnt; public IntPtr pPC; }
[StructLayout(LayoutKind.Sequential)] struct VkGPCI { public uint sType; public IntPtr pNext; public uint flags, stageCnt; public IntPtr pStages, pVIS, pIAS, pTess, pVPS, pRast, pMS, pDS, pCBS, pDyn; public ulong layout, rp; public uint subpass; public ulong basePipe; public int basePipeIdx; }
[StructLayout(LayoutKind.Sequential)] struct VkCPCI { public uint sType; public IntPtr pNext; public uint flags, qfi; }
[StructLayout(LayoutKind.Sequential)] struct VkCBAI { public uint sType; public IntPtr pNext; public IntPtr pool; public uint level, cnt; }
[StructLayout(LayoutKind.Sequential)] struct VkCBBI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pInh; }
[StructLayout(LayoutKind.Sequential)] struct VkClearCol { public float r, g, b, a; }
[StructLayout(LayoutKind.Explicit)] struct VkClearVal { [FieldOffset(0)] public VkClearCol color; }
[StructLayout(LayoutKind.Sequential)] struct VkRPBI { public uint sType; public IntPtr pNext; public ulong rp, fb; public VkRect2D area; public uint cvCnt; public IntPtr pCV; }
[StructLayout(LayoutKind.Sequential)] struct VkFenceCI { public uint sType; public IntPtr pNext; public uint flags; }
[StructLayout(LayoutKind.Sequential)] struct VkSubmitInfo { public uint sType; public IntPtr pNext; public uint wsCnt; public IntPtr pWS, pWSM; public uint cbCnt; public IntPtr pCB; public uint ssCnt; public IntPtr pSS; }
[StructLayout(LayoutKind.Sequential)] struct VkBufImgCopy { public ulong bufOff; public uint bRL, bIH, aspect, mip, baseL, lCnt; public int oX, oY, oZ; public uint eW, eH, eD; }

// Shaderc
static class SC {
    const string L = "shaderc_shared.dll";
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr shaderc_compiler_initialize();
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern void shaderc_compiler_release(IntPtr c);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_options_initialize();
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern void shaderc_compile_options_release(IntPtr o);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern void shaderc_compile_options_set_optimization_level(IntPtr o, int l);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_into_spv(IntPtr c, [MarshalAs(UnmanagedType.LPStr)] string s, UIntPtr sz, int k, [MarshalAs(UnmanagedType.LPStr)] string fn, [MarshalAs(UnmanagedType.LPStr)] string ep, IntPtr o);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern int shaderc_result_get_compilation_status(IntPtr r);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern UIntPtr shaderc_result_get_length(IntPtr r);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_bytes(IntPtr r);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_error_message(IntPtr r);
    [DllImport(L, CallingConvention=CallingConvention.Cdecl)] public static extern void shaderc_result_release(IntPtr r);
    public static byte[] Compile(string src, int kind, string fname) {
        IntPtr c = shaderc_compiler_initialize(), o = shaderc_compile_options_initialize();
        shaderc_compile_options_set_optimization_level(o, 2);
        try { IntPtr r = shaderc_compile_into_spv(c, src, (UIntPtr)src.Length, kind, fname, "main", o);
            if (shaderc_result_get_compilation_status(r) != 0) { string e = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(r)); shaderc_result_release(r); throw new Exception("Shader: " + e); }
            int len = (int)(ulong)shaderc_result_get_length(r); byte[] d = new byte[len]; Marshal.Copy(shaderc_result_get_bytes(r), d, 0, len); shaderc_result_release(r); return d;
        } finally { shaderc_compile_options_release(o); shaderc_compiler_release(c); }
    }
}

class Hello {
    const int PW=320, PH=480;
    const uint WS_OVR=0xCF0000, WS_VIS=0x10000000, CS_OWN=0x20;
    const uint WM_DEST=2, WM_CLOSE=0x10, WM_QUIT=0x12, WM_KEY=0x100; const uint PM_REM=1; const int VK_ESC=0x1B;
    const uint DXGI_B8=87, DXGI_R32G32B32=6, DXGI_R32G32B32A32=2, DXGI_USAGE_RTO=0x20, DXGI_FLIP_SEQ=3, DXGI_ALPHA_PRE=1;
    const uint D3D_SDK=7, D3D_FL11=0xb000, D3D_BGRA=0x20, D3D_STAGING=3, D3D_BIND_VB=1, D3D_MAP_W=2, D3D_CPU_W=0x10000, D3D_TOPO_TRI=4;
    const uint GL_TRI=4, GL_FLT=0x1406, GL_COLBIT=0x4000, GL_ABuf=0x8892, GL_STATIC=0x88E4;
    const uint GL_VS=0x8B31, GL_FS=0x8B30, GL_FB=0x8D40, GL_RB=0x8D41, GL_CA0=0x8CE0, WGL_RW=1;

    [DllImport("user32.dll", CharSet=CharSet.Auto)] static extern ushort RegisterClassEx(ref WNDCLASSEX w);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] static extern IntPtr CreateWindowEx(uint ex, string cls, string ttl, uint st, int x, int y, int w, int h, IntPtr p, IntPtr m, IntPtr hi, IntPtr lp);
    [DllImport("user32.dll")] static extern bool PeekMessage(out MSG m, IntPtr h, uint mn, uint mx, uint rm);
    [DllImport("user32.dll")] static extern bool TranslateMessage(ref MSG m);
    [DllImport("user32.dll")] static extern IntPtr DispatchMessage(ref MSG m);
    [DllImport("user32.dll")] static extern void PostQuitMessage(int c);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProc(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern IntPtr LoadCursor(IntPtr h, int c);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern bool AdjustWindowRect(ref RECT r, uint s, bool m);
    [DllImport("kernel32.dll", CharSet=CharSet.Auto)] static extern IntPtr GetModuleHandle(string n);
    [DllImport("gdi32.dll")] static extern int ChoosePixelFormat(IntPtr h, ref PIXELFORMATDESCRIPTOR p);
    [DllImport("gdi32.dll")] static extern bool SetPixelFormat(IntPtr h, int f, ref PIXELFORMATDESCRIPTOR p);
    [DllImport("opengl32.dll")] static extern IntPtr wglCreateContext(IntPtr h);
    [DllImport("opengl32.dll")] static extern int wglMakeCurrent(IntPtr h, IntPtr g);
    [DllImport("opengl32.dll")] static extern int wglDeleteContext(IntPtr g);
    [DllImport("opengl32.dll")] static extern IntPtr wglGetProcAddress(string n);
    [DllImport("opengl32.dll")] static extern void glClearColor(float r, float g, float b, float a);
    [DllImport("opengl32.dll")] static extern void glClear(uint m);
    [DllImport("opengl32.dll")] static extern void glViewport(int x, int y, int w, int h);
    [DllImport("opengl32.dll")] static extern void glDrawArrays(uint m, int f, int c);
    [DllImport("opengl32.dll")] static extern void glFlush();
    [DllImport("d3d11.dll")] static extern int D3D11CreateDevice(IntPtr a, int dt, IntPtr sw, uint fl, uint[] lv, uint n, uint sdk, out IntPtr dev, out uint flOut, out IntPtr ctx);
    [DllImport("dxgi.dll")] static extern int CreateDXGIFactory1(ref Guid iid, out IntPtr fac);
    [DllImport("d3dcompiler_47.dll")] static extern int D3DCompile([MarshalAs(UnmanagedType.LPStr)] string src, IntPtr sz, [MarshalAs(UnmanagedType.LPStr)] string nm, IntPtr def, IntPtr inc, [MarshalAs(UnmanagedType.LPStr)] string ep, [MarshalAs(UnmanagedType.LPStr)] string tgt, uint f1, uint f2, out IntPtr code, out IntPtr err);
    [DllImport("dcomp.dll")] static extern int DCompositionCreateDevice(IntPtr dxgi, ref Guid iid, out IntPtr dcomp);
    [DllImport("vulkan-1.dll")] static extern int vkCreateInstance(ref VkInstCI ci, IntPtr a, out IntPtr i);
    [DllImport("vulkan-1.dll")] static extern int vkEnumeratePhysicalDevices(IntPtr i, ref uint c, IntPtr[] d);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr p, ref uint c, [Out] VkQFP[] q);
    [DllImport("vulkan-1.dll")] static extern int vkCreateDevice(IntPtr p, ref VkDevCI ci, IntPtr a, out IntPtr d);
    [DllImport("vulkan-1.dll")] static extern void vkGetDeviceQueue(IntPtr d, uint qf, uint qi, out IntPtr q);
    [DllImport("vulkan-1.dll")] static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr p, out VkPhysMemProps m);
    [DllImport("vulkan-1.dll")] static extern int vkCreateImage(IntPtr d, ref VkImgCI ci, IntPtr a, out ulong img);
    [DllImport("vulkan-1.dll")] static extern void vkGetImageMemoryRequirements(IntPtr d, ulong img, out VkMemReq r);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateMemory(IntPtr d, ref VkMemAI ai, IntPtr a, out ulong m);
    [DllImport("vulkan-1.dll")] static extern int vkBindImageMemory(IntPtr d, ulong img, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] static extern int vkCreateImageView(IntPtr d, ref VkImgViewCI ci, IntPtr a, out ulong v);
    [DllImport("vulkan-1.dll")] static extern int vkCreateBuffer(IntPtr d, ref VkBufCI ci, IntPtr a, out ulong b);
    [DllImport("vulkan-1.dll")] static extern void vkGetBufferMemoryRequirements(IntPtr d, ulong b, out VkMemReq r);
    [DllImport("vulkan-1.dll")] static extern int vkBindBufferMemory(IntPtr d, ulong b, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] static extern int vkCreateRenderPass(IntPtr d, ref VkRPCI ci, IntPtr a, out ulong rp);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFramebuffer(IntPtr d, ref VkFBCI ci, IntPtr a, out ulong fb);
    [DllImport("vulkan-1.dll")] static extern int vkCreateShaderModule(IntPtr d, ref VkSMCI ci, IntPtr a, out ulong sm);
    [DllImport("vulkan-1.dll")] static extern void vkDestroyShaderModule(IntPtr d, ulong sm, IntPtr a);
    [DllImport("vulkan-1.dll")] static extern int vkCreatePipelineLayout(IntPtr d, ref VkPLCI ci, IntPtr a, out ulong pl);
    [DllImport("vulkan-1.dll")] static extern int vkCreateGraphicsPipelines(IntPtr d, ulong cache, uint n, ref VkGPCI ci, IntPtr a, out ulong p);
    [DllImport("vulkan-1.dll")] static extern int vkCreateCommandPool(IntPtr d, ref VkCPCI ci, IntPtr a, out IntPtr p);
    [DllImport("vulkan-1.dll")] static extern int vkAllocateCommandBuffers(IntPtr d, ref VkCBAI ai, out IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern int vkCreateFence(IntPtr d, ref VkFenceCI ci, IntPtr a, out ulong f);
    [DllImport("vulkan-1.dll")] static extern int vkWaitForFences(IntPtr d, uint n, ulong[] f, uint all, ulong t);
    [DllImport("vulkan-1.dll")] static extern int vkResetFences(IntPtr d, uint n, ulong[] f);
    [DllImport("vulkan-1.dll")] static extern int vkResetCommandBuffer(IntPtr cb, uint f);
    [DllImport("vulkan-1.dll")] static extern int vkBeginCommandBuffer(IntPtr cb, ref VkCBBI bi);
    [DllImport("vulkan-1.dll")] static extern int vkEndCommandBuffer(IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBeginRenderPass(IntPtr cb, ref VkRPBI rp, uint c);
    [DllImport("vulkan-1.dll")] static extern void vkCmdEndRenderPass(IntPtr cb);
    [DllImport("vulkan-1.dll")] static extern void vkCmdBindPipeline(IntPtr cb, uint bp, ulong p);
    [DllImport("vulkan-1.dll")] static extern void vkCmdDraw(IntPtr cb, uint vc, uint ic, uint fv, uint fi);
    [DllImport("vulkan-1.dll")] static extern unsafe void vkCmdCopyImageToBuffer(IntPtr cb, ulong img, uint layout, ulong buf, uint n, VkBufImgCopy* r);
    [DllImport("vulkan-1.dll")] static extern int vkQueueSubmit(IntPtr q, uint n, ref VkSubmitInfo si, ulong f);
    [DllImport("vulkan-1.dll")] static extern int vkMapMemory(IntPtr d, ulong m, ulong o, ulong sz, uint f, out IntPtr p);
    [DllImport("vulkan-1.dll")] static extern void vkUnmapMemory(IntPtr d, ulong m);
    [DllImport("vulkan-1.dll")] static extern int vkDeviceWaitIdle(IntPtr d);

    static readonly Guid IID_F2 = new Guid("50c83a1c-e072-4c48-87b0-3630fa36a6d0");
    static readonly Guid IID_DXGIDev = new Guid("54ec77fa-1377-44e6-8c32-88fd5f44c84c");
    static readonly Guid IID_Tex2D = new Guid("6f15aaf2-d208-4e89-9ab4-489535d34f9c");
    static readonly Guid IID_DCDev = new Guid("C37EA93A-E7AA-450D-B16F-9746CB0407F3");

    static IntPtr VT(IntPtr p, int i) { return Marshal.ReadIntPtr(Marshal.ReadIntPtr(p), i * IntPtr.Size); }
    static int QI(IntPtr o, Guid g, out IntPtr r) { var f = Marshal.GetDelegateForFunctionPointer<QIDelegate>(VT(o, 0)); return f(o, ref g, out r); }
    static void Rel(IntPtr o) { if (o != IntPtr.Zero) Marshal.Release(o); }
    static T GetGL<T>(string n) where T : class { IntPtr p = wglGetProcAddress(n); if (p == IntPtr.Zero) throw new Exception("GL: " + n); return Marshal.GetDelegateForFunctionPointer(p, typeof(T)) as T; }

    static bool _quit; static WndProcDelegate _wpr;
    static IntPtr _hw, _d3d, _ctx, _fac, _dc, _dct, _dcr;

    static IntPtr WP(IntPtr h, uint m, IntPtr w, IntPtr l) {
        if (m == WM_CLOSE || m == WM_DEST) { _quit = true; PostQuitMessage(0); return IntPtr.Zero; }
        if (m == WM_KEY && (int)w == VK_ESC) { _quit = true; PostQuitMessage(0); return IntPtr.Zero; }
        return DefWindowProc(h, m, w, l);
    }
    static void MakeWin() {
        var hi = GetModuleHandle(null); _wpr = WP;
        var wc = new WNDCLASSEX { cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)), style = CS_OWN, lpfnWndProc = _wpr, hInstance = hi, hCursor = LoadCursor(IntPtr.Zero, 32512), lpszClassName = "DCMulti" };
        RegisterClassEx(ref wc);
        var rc = new RECT { Right = PW * 3, Bottom = PH }; AdjustWindowRect(ref rc, WS_OVR, false);
        _hw = CreateWindowEx(0, "DCMulti", "Hello, DirectComposition(C#) World!", WS_OVR | WS_VIS, 100, 100, rc.Right - rc.Left, rc.Bottom - rc.Top, IntPtr.Zero, IntPtr.Zero, hi, IntPtr.Zero);
    }
    static void MakeD3D() {
        uint[] lv = { D3D_FL11 }; uint fl;
        int hr = D3D11CreateDevice(IntPtr.Zero, 1, IntPtr.Zero, D3D_BGRA, lv, 1, D3D_SDK, out _d3d, out fl, out _ctx);
        if (hr < 0) throw new Exception("D3D11: 0x" + hr.ToString("X8"));
    }
    static void MakeFac() {
        Guid g = new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
        CreateDXGIFactory1(ref g, out IntPtr f1); QI(f1, IID_F2, out _fac); Rel(f1);
    }
    static void MakeDC() {
        Guid dg = IID_DXGIDev; QI(_d3d, dg, out IntPtr dxgi);
        Guid dcg = IID_DCDev; DCompositionCreateDevice(dxgi, ref dcg, out _dc); Rel(dxgi);
        Marshal.GetDelegateForFunctionPointer<DCCreateTargetDelegate>(VT(_dc, 6))(_dc, _hw, 1, out _dct);
        Marshal.GetDelegateForFunctionPointer<DCCreateVisDelegate>(VT(_dc, 7))(_dc, out _dcr);
        Marshal.GetDelegateForFunctionPointer<DCSetRootDelegate>(VT(_dct, 3))(_dct, _dcr);
    }
    static IntPtr DCVis() { Marshal.GetDelegateForFunctionPointer<DCCreateVisDelegate>(VT(_dc, 7))(_dc, out IntPtr v); return v; }
    static void DCSetup(IntPtr v, IntPtr sc, float x) {
        Marshal.GetDelegateForFunctionPointer<DCSetContentDelegate>(VT(v, 15))(v, sc);
        Marshal.GetDelegateForFunctionPointer<DCSetOffXDelegate>(VT(v, 4))(v, x);
        Marshal.GetDelegateForFunctionPointer<DCSetOffYDelegate>(VT(v, 6))(v, 0f);
        Marshal.GetDelegateForFunctionPointer<DCAddVisDelegate>(VT(_dcr, 16))(_dcr, v, 1, IntPtr.Zero);
    }
    static void DCCommit() { Marshal.GetDelegateForFunctionPointer<DCCommitDelegate>(VT(_dc, 3))(_dc); }

    static IntPtr MakeSC(int w, int h) {
        var d = new DXGI_SWAP_CHAIN_DESC1 { Width=(uint)w, Height=(uint)h, Format=DXGI_B8, SampleDesc=new DXGI_SAMPLE_DESC{Count=1}, BufferUsage=DXGI_USAGE_RTO, BufferCount=2, SwapEffect=DXGI_FLIP_SEQ, AlphaMode=DXGI_ALPHA_PRE };
        Marshal.GetDelegateForFunctionPointer<CreateSCCompDelegate>(VT(_fac, 24))(_fac, _d3d, ref d, IntPtr.Zero, out IntPtr sc); return sc;
    }
    static IntPtr SCBuf(IntPtr sc) { Guid g = IID_Tex2D; Marshal.GetDelegateForFunctionPointer<GetBufDelegate>(VT(sc, 9))(sc, 0, ref g, out IntPtr t); return t; }
    static void SCPres(IntPtr sc) { Marshal.GetDelegateForFunctionPointer<PresentDelegate>(VT(sc, 8))(sc, 1, 0); }
    static IntPtr MakeRTV(IntPtr t) { Marshal.GetDelegateForFunctionPointer<CreateRTVDelegate>(VT(_d3d, 9))(_d3d, t, IntPtr.Zero, out IntPtr r); return r; }
    static IntPtr MakeStagTex(int w, int h) {
        var d = new D3D11_TEXTURE2D_DESC { Width=(uint)w, Height=(uint)h, MipLevels=1, ArraySize=1, Format=DXGI_B8, SampleDesc=new DXGI_SAMPLE_DESC{Count=1}, Usage=D3D_STAGING, CPUAccessFlags=D3D_CPU_W };
        Marshal.GetDelegateForFunctionPointer<CreateTex2DDelegate>(VT(_d3d, 5))(_d3d, ref d, IntPtr.Zero, out IntPtr t); return t;
    }
    static void ClearRTV(IntPtr r, float cr, float cg, float cb, float ca) { Marshal.GetDelegateForFunctionPointer<ClearRTVDelegate>(VT(_ctx, 50))(_ctx, r, new float[]{cr,cg,cb,ca}); }
    static void CopyRes(IntPtr d, IntPtr s) { Marshal.GetDelegateForFunctionPointer<CopyResDelegate>(VT(_ctx, 47))(_ctx, d, s); }
    static D3D11_MAPPED_SUBRESOURCE MapW(IntPtr r) { Marshal.GetDelegateForFunctionPointer<MapDelegate>(VT(_ctx, 14))(_ctx, r, 0, D3D_MAP_W, 0, out var m); return m; }
    static void Unmap(IntPtr r) { Marshal.GetDelegateForFunctionPointer<UnmapDelegate>(VT(_ctx, 15))(_ctx, r, 0); }

    // D3D11 panel
    static IntPtr _dxSC, _dxBB, _dxRTV, _dxVB, _dxVS, _dxPS, _dxIL;
    static string HLSL = "struct VSI{float3 p:POSITION;float4 c:COLOR;};\nstruct PSI{float4 p:SV_POSITION;float4 c:COLOR;};\nPSI VS(VSI i){PSI o;o.p=float4(i.p,1);o.c=i.c;return o;}\nfloat4 PS(PSI i):SV_Target{return i.c;}\n";
    static void InitDX() {
        _dxSC = MakeSC(PW, PH); _dxBB = SCBuf(_dxSC); _dxRTV = MakeRTV(_dxBB);
        D3DCompile(HLSL, (IntPtr)HLSL.Length, "dx", IntPtr.Zero, IntPtr.Zero, "VS", "vs_4_0", 0, 0, out IntPtr vb, out _);
        D3DCompile(HLSL, (IntPtr)HLSL.Length, "dx", IntPtr.Zero, IntPtr.Zero, "PS", "ps_4_0", 0, 0, out IntPtr pb, out _);
        IntPtr vP = Marshal.GetDelegateForFunctionPointer<BlobPtrDelegate>(VT(vb,3))(vb), vS = Marshal.GetDelegateForFunctionPointer<BlobSzDelegate>(VT(vb,4))(vb);
        IntPtr pP = Marshal.GetDelegateForFunctionPointer<BlobPtrDelegate>(VT(pb,3))(pb), pS = Marshal.GetDelegateForFunctionPointer<BlobSzDelegate>(VT(pb,4))(pb);
        Marshal.GetDelegateForFunctionPointer<CreateVSDelegate>(VT(_d3d,12))(_d3d, vP, vS, IntPtr.Zero, out _dxVS);
        Marshal.GetDelegateForFunctionPointer<CreatePSDelegate>(VT(_d3d,15))(_d3d, pP, pS, IntPtr.Zero, out _dxPS);
        var el = new[] { new D3D11_INPUT_ELEMENT_DESC{SemanticName="POSITION",Format=DXGI_R32G32B32,AlignedByteOffset=0}, new D3D11_INPUT_ELEMENT_DESC{SemanticName="COLOR",Format=DXGI_R32G32B32A32,AlignedByteOffset=12} };
        Marshal.GetDelegateForFunctionPointer<CreateILDelegate>(VT(_d3d,11))(_d3d, el, 2, vP, vS, out _dxIL); Rel(vb); Rel(pb);
        var vs = new DxVertex[]{new DxVertex{X=0,Y=0.5f,Z=0,R=1,G=0,B=0,A=1},new DxVertex{X=0.5f,Y=-0.5f,Z=0,R=0,G=1,B=0,A=1},new DxVertex{X=-0.5f,Y=-0.5f,Z=0,R=0,G=0,B=1,A=1}};
        GCHandle hV = GCHandle.Alloc(vs, GCHandleType.Pinned);
        var bd = new D3D11_BUFFER_DESC{ByteWidth=(uint)(Marshal.SizeOf(typeof(DxVertex))*3),BindFlags=D3D_BIND_VB};
        var sd = new D3D11_SUBRESOURCE_DATA{pSysMem=hV.AddrOfPinnedObject()};
        Marshal.GetDelegateForFunctionPointer<CreateBufferDelegate>(VT(_d3d,3))(_d3d, ref bd, ref sd, out _dxVB); hV.Free();
        DCSetup(DCVis(), _dxSC, PW); Console.WriteLine("[D3D11] OK");
    }
    static void RenderDX() {
        ClearRTV(_dxRTV, 0.05f, 0.15f, 0.05f, 1f);
        Marshal.GetDelegateForFunctionPointer<OMSetRTDelegate>(VT(_ctx,33))(_ctx, 1, new[]{_dxRTV}, IntPtr.Zero);
        var vp = new D3D11_VIEWPORT{Width=PW,Height=PH,MaxDepth=1};
        Marshal.GetDelegateForFunctionPointer<RSSetVPDelegate>(VT(_ctx,44))(_ctx, 1, ref vp);
        Marshal.GetDelegateForFunctionPointer<IASetILDelegate>(VT(_ctx,17))(_ctx, _dxIL);
        Marshal.GetDelegateForFunctionPointer<IASetVBDelegate>(VT(_ctx,18))(_ctx, 0, 1, new[]{_dxVB}, new uint[]{(uint)Marshal.SizeOf(typeof(DxVertex))}, new uint[]{0});
        Marshal.GetDelegateForFunctionPointer<IASetTopoDelegate>(VT(_ctx,24))(_ctx, D3D_TOPO_TRI);
        Marshal.GetDelegateForFunctionPointer<VSSetDelegate>(VT(_ctx,11))(_ctx, _dxVS, null, 0);
        Marshal.GetDelegateForFunctionPointer<PSSetDelegate>(VT(_ctx,9))(_ctx, _dxPS, null, 0);
        Marshal.GetDelegateForFunctionPointer<DrawDelegate>(VT(_ctx,13))(_ctx, 3, 0);
        SCPres(_dxSC);
    }

    // GL panel
    static IntPtr _glSC, _glBB, _glHDC, _glHRC, _glID, _glIO;
    static uint _glFBO, _glRBO, _glProg, _glPA, _glCA; static uint[] _glVBO = new uint[2];
    static glGenBuffersD gGB; static glBindBufferD gBB; static glBufferDataD gBD;
    static glCreateShaderD gCS; static glShaderSourceD gSS; static glCompileShaderD gCoS;
    static glCreateProgramD gCP; static glAttachShaderD gAS; static glLinkProgramD gLP; static glUseProgramD gUP;
    static glGetAttribLocationD gGA; static glEnableVAD gEV; static glVertexAttribPointerD gVAP;
    static glGenFBD gGF; static glBindFBD gBF; static glFBRBD gFR; static glGenRBD gGR;
    static glGenVAOD gGV; static glBindVAOD gBV;
    static wglDXLockD gDL; static wglDXUnlockD gDU;

    static void InitGL() {
        _glHDC = GetDC(_hw);
        var pfd = new PIXELFORMATDESCRIPTOR{nSize=(ushort)Marshal.SizeOf(typeof(PIXELFORMATDESCRIPTOR)),nVersion=1,dwFlags=0x25,cColorBits=32};
        int fmt = ChoosePixelFormat(_glHDC, ref pfd); SetPixelFormat(_glHDC, fmt, ref pfd);
        IntPtr tmp = wglCreateContext(_glHDC); wglMakeCurrent(_glHDC, tmp);
        _glHRC = GetGL<wglCreateCtxARBD>("wglCreateContextAttribsARB")(_glHDC, IntPtr.Zero, null);
        wglMakeCurrent(_glHDC, _glHRC); wglDeleteContext(tmp);
        gGB=GetGL<glGenBuffersD>("glGenBuffers"); gBB=GetGL<glBindBufferD>("glBindBuffer"); gBD=GetGL<glBufferDataD>("glBufferData");
        gCS=GetGL<glCreateShaderD>("glCreateShader"); gSS=GetGL<glShaderSourceD>("glShaderSource"); gCoS=GetGL<glCompileShaderD>("glCompileShader");
        gCP=GetGL<glCreateProgramD>("glCreateProgram"); gAS=GetGL<glAttachShaderD>("glAttachShader"); gLP=GetGL<glLinkProgramD>("glLinkProgram"); gUP=GetGL<glUseProgramD>("glUseProgram");
        gGA=GetGL<glGetAttribLocationD>("glGetAttribLocation"); gEV=GetGL<glEnableVAD>("glEnableVertexAttribArray"); gVAP=GetGL<glVertexAttribPointerD>("glVertexAttribPointer");
        gGF=GetGL<glGenFBD>("glGenFramebuffers"); gBF=GetGL<glBindFBD>("glBindFramebuffer"); gFR=GetGL<glFBRBD>("glFramebufferRenderbuffer"); gGR=GetGL<glGenRBD>("glGenRenderbuffers");
        gGV=GetGL<glGenVAOD>("glGenVertexArrays"); gBV=GetGL<glBindVAOD>("glBindVertexArray");
        var dxO=GetGL<wglDXOpenD>("wglDXOpenDeviceNV"); var dxR=GetGL<wglDXRegD>("wglDXRegisterObjectNV");
        gDL=GetGL<wglDXLockD>("wglDXLockObjectsNV"); gDU=GetGL<wglDXUnlockD>("wglDXUnlockObjectsNV");
        _glSC = MakeSC(PW, PH); _glBB = SCBuf(_glSC);
        _glID = dxO(_d3d); if (_glID == IntPtr.Zero) throw new Exception("wglDXOpenDeviceNV");
        var rb = new uint[1]; gGR(1, rb); _glRBO = rb[0];
        _glIO = dxR(_glID, _glBB, _glRBO, GL_RB, WGL_RW); if (_glIO == IntPtr.Zero) throw new Exception("wglDXRegisterObjectNV");
        var fb = new uint[1]; gGF(1, fb); _glFBO = fb[0]; gBF(GL_FB, _glFBO); gFR(GL_FB, GL_CA0, GL_RB, _glRBO); gBF(GL_FB, 0);
        var va = new uint[1]; gGV(1, va); gBV(va[0]); gGB(2, _glVBO);
        float[] vt={0,0.5f,0,0.5f,-0.5f,0,-0.5f,-0.5f,0}; float[] cl={1,0,0,0,1,0,0,0,1};
        gBB(GL_ABuf, _glVBO[0]); gBD(GL_ABuf, vt.Length*4, vt, GL_STATIC);
        gBB(GL_ABuf, _glVBO[1]); gBD(GL_ABuf, cl.Length*4, cl, GL_STATIC);
        string vs="#version 460 core\nlayout(location=0) in vec3 pos;layout(location=1) in vec3 col;\nout vec4 vC;\nvoid main(){vC=vec4(col,1);gl_Position=vec4(pos.x,-pos.y,pos.z,1);}\n";
        string fs="#version 460 core\nin vec4 vC;out vec4 oC;\nvoid main(){oC=vC;}\n";
        uint v=gCS(GL_VS); gSS(v,1,new[]{vs},null); gCoS(v);
        uint f=gCS(GL_FS); gSS(f,1,new[]{fs},null); gCoS(f);
        _glProg=gCP(); gAS(_glProg,v); gAS(_glProg,f); gLP(_glProg); gUP(_glProg);
        _glPA=gGA(_glProg,"pos"); _glCA=gGA(_glProg,"col"); gEV(_glPA); gEV(_glCA);
        DCSetup(DCVis(), _glSC, 0); Console.WriteLine("[GL] OK");
    }
    static void RenderGL() {
        wglMakeCurrent(_glHDC, _glHRC);
        var o = new IntPtr[]{_glIO}; gDL(_glID, 1, o);
        gBF(GL_FB, _glFBO); glViewport(0,0,PW,PH); glClearColor(0.05f,0.05f,0.15f,1f); glClear(GL_COLBIT);
        gUP(_glProg); gBB(GL_ABuf,_glVBO[0]); gVAP(_glPA,3,GL_FLT,false,0,IntPtr.Zero);
        gBB(GL_ABuf,_glVBO[1]); gVAP(_glCA,3,GL_FLT,false,0,IntPtr.Zero);
        glDrawArrays(GL_TRI,0,3); gBF(GL_FB,0); glFlush(); gDU(_glID,1,o); SCPres(_glSC);
    }

    // VK panel
    static IntPtr _vSC, _vBB, _vST, _vI, _vPD, _vD, _vQ, _vCP, _vCB;
    static ulong _vOI, _vOV, _vOM, _vSB, _vSM2, _vRP, _vFB2, _vPL, _vPP, _vFN;
    static int _vQF;
    static unsafe uint FindMT(ref VkPhysMemProps p, uint bits, uint req) {
        for (uint i=0;i<p.typeCnt;i++) { if ((bits&(1u<<(int)i))!=0) { uint f; fixed(byte*b=p.types){f=((VkMemType*)b)[i].propFlags;} if((f&req)==req) return i; } }
        throw new Exception("No VK mem type");
    }
    static unsafe void InitVK() {
        var an = Marshal.StringToHGlobalAnsi("vk");
        var ai = new VkAppInfo{sType=0,pAppName=an,apiVer=(1u<<22)}; GCHandle hAI=GCHandle.Alloc(ai,GCHandleType.Pinned);
        var ici = new VkInstCI{sType=1,pAppInfo=hAI.AddrOfPinnedObject()}; vkCreateInstance(ref ici,IntPtr.Zero,out _vI); hAI.Free(); Marshal.FreeHGlobal(an);
        uint cnt=0; vkEnumeratePhysicalDevices(_vI,ref cnt,null); var ds=new IntPtr[cnt]; vkEnumeratePhysicalDevices(_vI,ref cnt,ds); _vPD=ds[0]; _vQF=-1;
        uint qc=0; vkGetPhysicalDeviceQueueFamilyProperties(_vPD,ref qc,null); var qp=new VkQFP[qc]; vkGetPhysicalDeviceQueueFamilyProperties(_vPD,ref qc,qp);
        for(int i=0;i<qc;i++) if((qp[i].qFlags&1)!=0){_vQF=i;break;}
        GCHandle hP=GCHandle.Alloc(new float[]{1f},GCHandleType.Pinned);
        var qci=new VkDevQCI{sType=2,qfi=(uint)_vQF,qCnt=1,pPrio=hP.AddrOfPinnedObject()}; GCHandle hQ=GCHandle.Alloc(qci,GCHandleType.Pinned);
        var dci=new VkDevCI{sType=3,qciCnt=1,pQCI=hQ.AddrOfPinnedObject()}; vkCreateDevice(_vPD,ref dci,IntPtr.Zero,out _vD); hQ.Free(); hP.Free();
        vkGetDeviceQueue(_vD,(uint)_vQF,0,out _vQ); vkGetPhysicalDeviceMemoryProperties(_vPD,out var mp);
        var ic=new VkImgCI{sType=14,imgType=1,fmt=44,eW=PW,eH=PH,eD=1,mip=1,arr=1,samples=1,usage=0x11}; vkCreateImage(_vD,ref ic,IntPtr.Zero,out _vOI);
        vkGetImageMemoryRequirements(_vD,_vOI,out var ir); var ia2=new VkMemAI{sType=5,size=ir.size,memIdx=FindMT(ref mp,ir.memBits,1)}; vkAllocateMemory(_vD,ref ia2,IntPtr.Zero,out _vOM); vkBindImageMemory(_vD,_vOI,_vOM,0);
        var ivc=new VkImgViewCI{sType=15,img=_vOI,viewType=1,fmt=44,aspect=1,lvlCnt=1,layerCnt=1}; vkCreateImageView(_vD,ref ivc,IntPtr.Zero,out _vOV);
        ulong bsz=(ulong)(PW*PH*4); var bc=new VkBufCI{sType=12,size=bsz,usage=2}; vkCreateBuffer(_vD,ref bc,IntPtr.Zero,out _vSB);
        vkGetBufferMemoryRequirements(_vD,_vSB,out var br); var ba=new VkMemAI{sType=5,size=br.size,memIdx=FindMT(ref mp,br.memBits,6)}; vkAllocateMemory(_vD,ref ba,IntPtr.Zero,out _vSM2); vkBindBufferMemory(_vD,_vSB,_vSM2,0);
        var att=new VkAttDesc{fmt=44,samples=1,loadOp=1,storeOp=0,stLoadOp=2,stStoreOp=1,finalLayout=6}; var ar=new VkAttRef{att=0,layout=2};
        GCHandle hA=GCHandle.Alloc(att,GCHandleType.Pinned),hR=GCHandle.Alloc(ar,GCHandleType.Pinned);
        var sd=new VkSubDesc{caCnt=1,pCA=hR.AddrOfPinnedObject()}; GCHandle hS=GCHandle.Alloc(sd,GCHandleType.Pinned);
        var rpc=new VkRPCI{sType=38,attCnt=1,pAtts=hA.AddrOfPinnedObject(),subCnt=1,pSubs=hS.AddrOfPinnedObject()}; vkCreateRenderPass(_vD,ref rpc,IntPtr.Zero,out _vRP); hA.Free();hR.Free();hS.Free();
        GCHandle hV=GCHandle.Alloc(new ulong[]{_vOV},GCHandleType.Pinned);
        var fbc=new VkFBCI{sType=37,rp=_vRP,attCnt=1,pAtts=hV.AddrOfPinnedObject(),w=PW,h=PH,layers=1}; vkCreateFramebuffer(_vD,ref fbc,IntPtr.Zero,out _vFB2); hV.Free();
        byte[] vSpv=SC.Compile(File.ReadAllText("hello.vert"),0,"hello.vert"), fSpv=SC.Compile(File.ReadAllText("hello.frag"),1,"hello.frag");
        ulong vsm,fsm;
        {GCHandle h=GCHandle.Alloc(vSpv,GCHandleType.Pinned);var c=new VkSMCI{sType=16,codeSz=(UIntPtr)vSpv.Length,pCode=h.AddrOfPinnedObject()};vkCreateShaderModule(_vD,ref c,IntPtr.Zero,out vsm);h.Free();}
        {GCHandle h=GCHandle.Alloc(fSpv,GCHandleType.Pinned);var c=new VkSMCI{sType=16,codeSz=(UIntPtr)fSpv.Length,pCode=h.AddrOfPinnedObject()};vkCreateShaderModule(_vD,ref c,IntPtr.Zero,out fsm);h.Free();}
        IntPtr ms=Marshal.StringToHGlobalAnsi("main");
        var stg=new VkPSSCI[]{new VkPSSCI{sType=18,stage=1,module=vsm,pName=ms},new VkPSSCI{sType=18,stage=0x10,module=fsm,pName=ms}};
        GCHandle hStg=GCHandle.Alloc(stg,GCHandleType.Pinned);
        var vi=new VkPVICI{sType=19}; var ias=new VkPIACI{sType=20,topo=3};
        var vp=new VkViewport{w=PW,h=PH,maxD=1}; var sc2=new VkRect2D{ext=new VkExt2D{w=PW,h=PH}};
        GCHandle hVP=GCHandle.Alloc(vp,GCHandleType.Pinned),hSC=GCHandle.Alloc(sc2,GCHandleType.Pinned);
        var vps=new VkPVPCI{sType=22,vpCnt=1,pVP=hVP.AddrOfPinnedObject(),scCnt=1,pSC=hSC.AddrOfPinnedObject()};
        var rs=new VkPRCI{sType=23,lineW=1f}; var mss=new VkPMSCI{sType=24,rSamples=1};
        var cba=new VkPCBAS{wMask=0xF}; GCHandle hCBA=GCHandle.Alloc(cba,GCHandleType.Pinned);
        var cbs=new VkPCBCI{sType=26,attCnt=1,pAtts=hCBA.AddrOfPinnedObject()};
        GCHandle hVI=GCHandle.Alloc(vi,GCHandleType.Pinned),hIA=GCHandle.Alloc(ias,GCHandleType.Pinned),hVPS=GCHandle.Alloc(vps,GCHandleType.Pinned),hRS=GCHandle.Alloc(rs,GCHandleType.Pinned),hMS=GCHandle.Alloc(mss,GCHandleType.Pinned),hCB=GCHandle.Alloc(cbs,GCHandleType.Pinned);
        var plc=new VkPLCI{sType=30}; vkCreatePipelineLayout(_vD,ref plc,IntPtr.Zero,out _vPL);
        var gpc=new VkGPCI{sType=28,stageCnt=2,pStages=hStg.AddrOfPinnedObject(),pVIS=hVI.AddrOfPinnedObject(),pIAS=hIA.AddrOfPinnedObject(),pVPS=hVPS.AddrOfPinnedObject(),pRast=hRS.AddrOfPinnedObject(),pMS=hMS.AddrOfPinnedObject(),pCBS=hCB.AddrOfPinnedObject(),layout=_vPL,rp=_vRP};
        vkCreateGraphicsPipelines(_vD,0,1,ref gpc,IntPtr.Zero,out _vPP);
        hStg.Free();hVI.Free();hIA.Free();hVPS.Free();hRS.Free();hMS.Free();hCB.Free();hCBA.Free();hVP.Free();hSC.Free();
        Marshal.FreeHGlobal(ms); vkDestroyShaderModule(_vD,vsm,IntPtr.Zero); vkDestroyShaderModule(_vD,fsm,IntPtr.Zero);
        var cpc=new VkCPCI{sType=39,flags=2,qfi=(uint)_vQF}; vkCreateCommandPool(_vD,ref cpc,IntPtr.Zero,out _vCP);
        var cbi=new VkCBAI{sType=40,pool=_vCP,cnt=1}; vkAllocateCommandBuffers(_vD,ref cbi,out _vCB);
        var fc=new VkFenceCI{sType=8,flags=1}; vkCreateFence(_vD,ref fc,IntPtr.Zero,out _vFN);
        _vSC=MakeSC(PW,PH); _vBB=SCBuf(_vSC); _vST=MakeStagTex(PW,PH);
        DCSetup(DCVis(), _vSC, PW*2); Console.WriteLine("[VK] OK");
    }
    static unsafe void RenderVK() {
        var fn=new ulong[]{_vFN}; vkWaitForFences(_vD,1,fn,1,ulong.MaxValue); vkResetFences(_vD,1,fn); vkResetCommandBuffer(_vCB,0);
        var bi=new VkCBBI{sType=42}; vkBeginCommandBuffer(_vCB,ref bi);
        var cv=new VkClearVal{color=new VkClearCol{r=0.15f,g=0.05f,b=0.05f,a=1f}}; GCHandle hCV=GCHandle.Alloc(cv,GCHandleType.Pinned);
        var rpbi=new VkRPBI{sType=43,rp=_vRP,fb=_vFB2,area=new VkRect2D{ext=new VkExt2D{w=PW,h=PH}},cvCnt=1,pCV=hCV.AddrOfPinnedObject()};
        vkCmdBeginRenderPass(_vCB,ref rpbi,0); vkCmdBindPipeline(_vCB,0,_vPP); vkCmdDraw(_vCB,3,1,0,0); vkCmdEndRenderPass(_vCB); hCV.Free();
        var rg=new VkBufImgCopy{bRL=PW,bIH=PH,aspect=1,lCnt=1,eW=PW,eH=PH,eD=1}; vkCmdCopyImageToBuffer(_vCB,_vOI,6,_vSB,1,&rg); vkEndCommandBuffer(_vCB);
        GCHandle hC=GCHandle.Alloc(new IntPtr[]{_vCB},GCHandleType.Pinned);
        var si=new VkSubmitInfo{sType=4,cbCnt=1,pCB=hC.AddrOfPinnedObject()}; vkQueueSubmit(_vQ,1,ref si,_vFN); hC.Free();
        vkWaitForFences(_vD,1,fn,1,ulong.MaxValue);
        vkMapMemory(_vD,_vSM2,0,(ulong)(PW*PH*4),0,out IntPtr vd);
        var m=MapW(_vST); int p=PW*4;
        for(int y=0;y<PH;y++) Buffer.MemoryCopy((void*)(vd+y*p),(void*)(m.pData+y*(int)m.RowPitch),p,p);
        Unmap(_vST); vkUnmapMemory(_vD,_vSM2); CopyRes(_vBB,_vST); SCPres(_vSC);
    }

    [STAThread] static unsafe void Main() {
        Console.WriteLine("=== GL + D3D11 + VK via DirectComposition (C#) ===");
        MakeWin(); MakeD3D(); MakeFac(); MakeDC();
        Console.WriteLine("--- GL ---"); InitGL();
        Console.WriteLine("--- D3D11 ---"); InitDX();
        Console.WriteLine("--- VK ---"); InitVK();
        DCCommit();
        Console.WriteLine("Main loop...");
        bool first=true; MSG msg;
        while(!_quit) {
            while(PeekMessage(out msg,IntPtr.Zero,0,0,PM_REM)){if(msg.message==WM_QUIT){_quit=true;break;}TranslateMessage(ref msg);DispatchMessage(ref msg);}
            if(_quit) break; RenderGL(); RenderDX(); RenderVK();
            if(first){Console.WriteLine("First frame OK");first=false;} System.Threading.Thread.Sleep(1);
        }
        vkDeviceWaitIdle(_vD); Console.WriteLine("=== END ===");
    }
}
