# Hello.ps1
# OpenGL 4.6 + DirectX 11 + Vulkan 1.4 triangles composited via DirectComposition
# Run: powershell -ExecutionPolicy Bypass -File Hello.ps1
#
# Requirements:
#   Windows 8+ (DirectComposition), GPU with WGL_NV_DX_interop2
#   Vulkan SDK (shaderc_shared.dll + vulkan-1.dll), hello.vert/hello.frag in same folder

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

// Win32
[StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
[StructLayout(LayoutKind.Sequential)] public struct RECT  { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public POINT pt; }
public delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct WNDCLASSEX { public uint cbSize, style; public WndProcDelegate lpfnWndProc; public int cbClsExtra, cbWndExtra; public IntPtr hInstance, hIcon, hCursor, hbrBackground; public string lpszMenuName, lpszClassName; public IntPtr hIconSm; }
[StructLayout(LayoutKind.Sequential)] public struct PAINTSTRUCT { public IntPtr hdc; public int fErase; public RECT rcPaint; public int fRestore, fIncUpdate; [MarshalAs(UnmanagedType.ByValArray, SizeConst=32)] public byte[] rgbReserved; }
[StructLayout(LayoutKind.Sequential)]
public struct PIXELFORMATDESCRIPTOR { public ushort nSize, nVersion; public uint dwFlags; public byte iPixelType, cColorBits, cRedBits, cRedShift, cGreenBits, cGreenShift, cBlueBits, cBlueShift, cAlphaBits, cAlphaShift, cAccumBits, cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits, cDepthBits, cStencilBits, cAuxBuffers, iLayerType, bReserved; public uint dwLayerMask, dwVisibleMask, dwDamageMask; }

// D3D11/DXGI
[StructLayout(LayoutKind.Sequential)] public struct DXGI_SAMPLE_DESC { public uint Count, Quality; }
[StructLayout(LayoutKind.Sequential)] public struct DXGI_SWAP_CHAIN_DESC1 { public uint Width, Height, Format; [MarshalAs(UnmanagedType.Bool)] public bool Stereo; public DXGI_SAMPLE_DESC SampleDesc; public uint BufferUsage, BufferCount, Scaling, SwapEffect, AlphaMode, Flags; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_TEXTURE2D_DESC { public uint Width, Height, MipLevels, ArraySize, Format; public DXGI_SAMPLE_DESC SampleDesc; public uint Usage, BindFlags, CPUAccessFlags, MiscFlags; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_MAPPED_SUBRESOURCE { public IntPtr pData; public uint RowPitch, DepthPitch; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_BUFFER_DESC { public uint ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_SUBRESOURCE_DATA { public IntPtr pSysMem; public uint SysMemPitch, SysMemSlicePitch; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_INPUT_ELEMENT_DESC { [MarshalAs(UnmanagedType.LPStr)] public string SemanticName; public uint SemanticIndex, Format, InputSlot, AlignedByteOffset, InputSlotClass, InstanceDataStepRate; }
[StructLayout(LayoutKind.Sequential)] public struct D3D11_VIEWPORT { public float TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth; }
[StructLayout(LayoutKind.Sequential)] public struct DxVertex { public float X, Y, Z, R, G, B, A; }

// COM delegates
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int QIDelegate(IntPtr self, ref Guid riid, out IntPtr ppv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateRTVDelegate(IntPtr d, IntPtr r, IntPtr desc, out IntPtr rtv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateBufferDelegate(IntPtr d, ref D3D11_BUFFER_DESC desc, ref D3D11_SUBRESOURCE_DATA data, out IntPtr buf);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateTex2DDelegate(IntPtr d, ref D3D11_TEXTURE2D_DESC desc, IntPtr init, out IntPtr tex);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateVSDelegate(IntPtr d, IntPtr bc, IntPtr sz, IntPtr lnk, out IntPtr vs);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreatePSDelegate(IntPtr d, IntPtr bc, IntPtr sz, IntPtr lnk, out IntPtr ps);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateILDelegate(IntPtr d, [In] D3D11_INPUT_ELEMENT_DESC[] e, uint n, IntPtr bc, IntPtr sz, out IntPtr il);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void PSSetDelegate(IntPtr c, IntPtr ps, IntPtr[] ci, uint n);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void VSSetDelegate(IntPtr c, IntPtr vs, IntPtr[] ci, uint n);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DrawDelegate(IntPtr c, uint cnt, uint start);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int MapDelegate(IntPtr c, IntPtr r, uint sub, uint type, uint flags, out D3D11_MAPPED_SUBRESOURCE m);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void UnmapDelegate(IntPtr c, IntPtr r, uint sub);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetILDelegate(IntPtr c, IntPtr il);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetVBDelegate(IntPtr c, uint slot, uint n, IntPtr[] vbs, uint[] strides, uint[] offs);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetTopoDelegate(IntPtr c, uint topo);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void OMSetRTDelegate(IntPtr c, uint n, IntPtr[] rtvs, IntPtr dsv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void RSSetVPDelegate(IntPtr c, uint n, ref D3D11_VIEWPORT vp);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void CopyResDelegate(IntPtr c, IntPtr dst, IntPtr src);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void ClearRTVDelegate(IntPtr c, IntPtr rtv, [MarshalAs(UnmanagedType.LPArray, SizeConst=4)] float[] col);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PresentDelegate(IntPtr sc, uint sync, uint flags);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int GetBufDelegate(IntPtr sc, uint buf, ref Guid iid, out IntPtr srf);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateSCCompDelegate(IntPtr fac, IntPtr dev, ref DXGI_SWAP_CHAIN_DESC1 desc, IntPtr restrict, out IntPtr sc);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr BlobPtrDelegate(IntPtr b);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr BlobSzDelegate(IntPtr b);

// DComp delegates
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCCommitDelegate(IntPtr d);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCCreateTargetDelegate(IntPtr d, IntPtr hw, int top, out IntPtr t);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCCreateVisDelegate(IntPtr d, out IntPtr v);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCSetRootDelegate(IntPtr t, IntPtr v);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCSetOffXDelegate(IntPtr v, float x);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCSetOffYDelegate(IntPtr v, float y);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCSetContentDelegate(IntPtr v, IntPtr c);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCAddVisDelegate(IntPtr v, IntPtr ch, int above, IntPtr rf);

// GL delegates
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glGenBuffersDelegate(int n, uint[] b);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glBindBufferDelegate(uint t, uint b);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glBufferDataFloatDelegate(uint t, int sz, float[] d, uint u);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate uint glCreateShaderDelegate(uint t);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glShaderSourceDelegate(uint s, int c, string[] src, int[] len);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glCompileShaderDelegate(uint s);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate uint glCreateProgramDelegate();
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glAttachShaderDelegate(uint p, uint s);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glLinkProgramDelegate(uint p);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glUseProgramDelegate(uint p);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate uint glGetAttribLocationDelegate(uint p, string n);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glEnableVertexAttribArrayDelegate(uint i);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glVertexAttribPointerDelegate(uint i, int sz, uint t, bool norm, int stride, IntPtr ptr);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glGenFramebuffersDelegate(int n, uint[] f);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glBindFramebufferDelegate(uint t, uint f);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glFramebufferRenderbufferDelegate(uint t, uint a, uint rt, uint rb);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glGenRenderbuffersDelegate(int n, uint[] r);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glGenVertexArraysDelegate(int n, uint[] v);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void glBindVertexArrayDelegate(uint v);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hdc, IntPtr sh, int[] a);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate IntPtr wglDXOpenDeviceNVDelegate(IntPtr dx);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate IntPtr wglDXRegisterObjectNVDelegate(IntPtr h, IntPtr dx, uint gl, uint t, uint a);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int wglDXLockObjectsNVDelegate(IntPtr h, int c, IntPtr[] o);
[UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int wglDXUnlockObjectsNVDelegate(IntPtr h, int c, IntPtr[] o);

// Vulkan structs
[StructLayout(LayoutKind.Sequential)] public struct VkAppInfo { public uint sType; public IntPtr pNext, pAppName; public uint appVer; public IntPtr pEngName; public uint engVer, apiVer; }
[StructLayout(LayoutKind.Sequential)] public struct VkInstCI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pAppInfo; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; }
[StructLayout(LayoutKind.Sequential)] public struct VkDevQCI { public uint sType; public IntPtr pNext; public uint flags, qfi, qCnt; public IntPtr pPrio; }
[StructLayout(LayoutKind.Sequential)] public struct VkDevCI { public uint sType; public IntPtr pNext; public uint flags, qciCnt; public IntPtr pQCI; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; public IntPtr pFeat; }
[StructLayout(LayoutKind.Sequential)] public struct VkQFP { public uint qFlags, qCnt, tsVB, gW, gH, gD; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemReq { public ulong size, align; public uint memBits; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemAI { public uint sType; public IntPtr pNext; public ulong size; public uint memIdx; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemType { public uint propFlags, heapIdx; }
[StructLayout(LayoutKind.Sequential)] public struct VkPhysMemProps { public uint typeCnt; [MarshalAs(UnmanagedType.ByValArray, SizeConst=256)] public byte[] types; public uint heapCnt; [MarshalAs(UnmanagedType.ByValArray, SizeConst=256)] public byte[] heaps; }
[StructLayout(LayoutKind.Sequential)] public struct VkImgCI { public uint sType; public IntPtr pNext; public uint flags, imgType, fmt, eW, eH, eD, mip, arr, samples, tiling, usage, sharing, qfCnt; public IntPtr pQF; public uint initLayout; }
[StructLayout(LayoutKind.Sequential)] public struct VkImgViewCI { public uint sType; public IntPtr pNext; public uint flags; public ulong img; public uint viewType, fmt, cR, cG, cB, cA, aspect, baseMip, lvlCnt, baseLayer, layerCnt; }
[StructLayout(LayoutKind.Sequential)] public struct VkBufCI { public uint sType; public IntPtr pNext; public uint flags; public ulong size; public uint usage, sharing, qfCnt; public IntPtr pQF; }
[StructLayout(LayoutKind.Sequential)] public struct VkAttDesc { public uint flags, fmt, samples, loadOp, storeOp, stLoadOp, stStoreOp, initLayout, finalLayout; }
[StructLayout(LayoutKind.Sequential)] public struct VkAttRef { public uint att, layout; }
[StructLayout(LayoutKind.Sequential)] public struct VkSubDesc { public uint flags, bp, iaCnt; public IntPtr pIA; public uint caCnt; public IntPtr pCA, pRA, pDA; public uint paCnt; public IntPtr pPA; }
[StructLayout(LayoutKind.Sequential)] public struct VkRPCI { public uint sType; public IntPtr pNext; public uint flags, attCnt; public IntPtr pAtts; public uint subCnt; public IntPtr pSubs; public uint depCnt; public IntPtr pDeps; }
[StructLayout(LayoutKind.Sequential)] public struct VkFBCI { public uint sType; public IntPtr pNext; public uint flags; public ulong rp; public uint attCnt; public IntPtr pAtts; public uint w, h, layers; }
[StructLayout(LayoutKind.Sequential)] public struct VkSMCI { public uint sType; public IntPtr pNext; public uint flags; public UIntPtr codeSz; public IntPtr pCode; }
[StructLayout(LayoutKind.Sequential)] public struct VkPSSCI { public uint sType; public IntPtr pNext; public uint flags, stage; public ulong module; public IntPtr pName, pSpec; }
[StructLayout(LayoutKind.Sequential)] public struct VkPVICI { public uint sType; public IntPtr pNext; public uint flags, vbdCnt; public IntPtr pVBD; public uint vadCnt; public IntPtr pVAD; }
[StructLayout(LayoutKind.Sequential)] public struct VkPIACI { public uint sType; public IntPtr pNext; public uint flags, topo, primRestart; }
[StructLayout(LayoutKind.Sequential)] public struct VkViewport { public float x, y, w, h, minD, maxD; }
[StructLayout(LayoutKind.Sequential)] public struct VkOff2D { public int x, y; }
[StructLayout(LayoutKind.Sequential)] public struct VkExt2D { public uint w, h; }
[StructLayout(LayoutKind.Sequential)] public struct VkRect2D { public VkOff2D off; public VkExt2D ext; }
[StructLayout(LayoutKind.Sequential)] public struct VkPVPCI { public uint sType; public IntPtr pNext; public uint flags, vpCnt; public IntPtr pVP; public uint scCnt; public IntPtr pSC; }
[StructLayout(LayoutKind.Sequential)] public struct VkPRCI { public uint sType; public IntPtr pNext; public uint flags, depthClamp, rastDiscard, polyMode, cullMode, frontFace, depthBias; public float dbConst, dbClamp, dbSlope, lineW; }
[StructLayout(LayoutKind.Sequential)] public struct VkPMSCI { public uint sType; public IntPtr pNext; public uint flags, rSamples, sShading; public float minSS; public IntPtr pSM; public uint a2c, a2o; }
[StructLayout(LayoutKind.Sequential)] public struct VkPCBAS { public uint blendEn, sCBF, dCBF, cbOp, sABF, dABF, abOp, wMask; }
[StructLayout(LayoutKind.Sequential)] public struct VkPCBCI { public uint sType; public IntPtr pNext; public uint flags, logicOpEn, logicOp, attCnt; public IntPtr pAtts; public float bc0, bc1, bc2, bc3; }
[StructLayout(LayoutKind.Sequential)] public struct VkPLCI { public uint sType; public IntPtr pNext; public uint flags, slCnt; public IntPtr pSL; public uint pcCnt; public IntPtr pPC; }
[StructLayout(LayoutKind.Sequential)] public struct VkGPCI { public uint sType; public IntPtr pNext; public uint flags, stageCnt; public IntPtr pStages, pVIS, pIAS, pTess, pVPS, pRast, pMS, pDS, pCBS, pDyn; public ulong layout, rp; public uint subpass; public ulong basePipe; public int basePipeIdx; }
[StructLayout(LayoutKind.Sequential)] public struct VkCPCI { public uint sType; public IntPtr pNext; public uint flags, qfi; }
[StructLayout(LayoutKind.Sequential)] public struct VkCBAI { public uint sType; public IntPtr pNext; public IntPtr pool; public uint level, cnt; }
[StructLayout(LayoutKind.Sequential)] public struct VkCBBI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pInh; }
[StructLayout(LayoutKind.Sequential)] public struct VkClearCol { public float r, g, b, a; }
[StructLayout(LayoutKind.Explicit)]  public struct VkClearVal { [FieldOffset(0)] public VkClearCol color; }
[StructLayout(LayoutKind.Sequential)] public struct VkRPBI { public uint sType; public IntPtr pNext; public ulong rp, fb; public VkRect2D area; public uint cvCnt; public IntPtr pCV; }
[StructLayout(LayoutKind.Sequential)] public struct VkFenceCI { public uint sType; public IntPtr pNext; public uint flags; }
[StructLayout(LayoutKind.Sequential)] public struct VkSubmitInfo { public uint sType; public IntPtr pNext; public uint wsCnt; public IntPtr pWS, pWSM; public uint cbCnt; public IntPtr pCB; public uint ssCnt; public IntPtr pSS; }
[StructLayout(LayoutKind.Sequential)] public struct VkBufImgCopy { public ulong bufOff; public uint bRL, bIH, aspect, mip, baseL, lCnt; public int oX, oY, oZ; public uint eW, eH, eD; }

// Shaderc
public static class SC {
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
        try {
            IntPtr r = shaderc_compile_into_spv(c, src, (UIntPtr)src.Length, kind, fname, "main", o);
            if (shaderc_result_get_compilation_status(r) != 0) { string e = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(r)); shaderc_result_release(r); throw new Exception("Shader: " + e); }
            int len = (int)(ulong)shaderc_result_get_length(r); byte[] d = new byte[len]; Marshal.Copy(shaderc_result_get_bytes(r), d, 0, len); shaderc_result_release(r); return d;
        } finally { shaderc_compile_options_release(o); shaderc_compiler_release(c); }
    }
}

// P/Invoke + WndProc (C# to avoid PS runspace issues)
public static class N {
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool ShowWindow(IntPtr h, int c);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool UpdateWindow(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern IntPtr LoadCursor(IntPtr h, int c);
    [DllImport("user32.dll", EntryPoint="RegisterClassEx", CharSet=CharSet.Auto, SetLastError=true)] public static extern ushort RegisterClassEx([In] ref WNDCLASSEX w);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr CreateWindowEx(uint ex, string cls, string ttl, uint st, int x, int y, int w, int h, IntPtr p, IntPtr m, IntPtr hi, IntPtr lp);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool PeekMessage(out MSG m, IntPtr h, uint mn, uint mx, uint rm);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern bool TranslateMessage([In] ref MSG m);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr DispatchMessage([In] ref MSG m);
    [DllImport("user32.dll")] public static extern void PostQuitMessage(int c);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr DefWindowProc(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr BeginPaint(IntPtr h, out PAINTSTRUCT p);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr EndPaint(IntPtr h, ref PAINTSTRUCT p);
    [DllImport("user32.dll")] public static extern bool AdjustWindowRect(ref RECT r, uint s, bool m);
    [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern IntPtr GetModuleHandle(string n);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr ReleaseDC(IntPtr h, IntPtr d);
    [DllImport("gdi32.dll")] public static extern int ChoosePixelFormat(IntPtr h, ref PIXELFORMATDESCRIPTOR p);
    [DllImport("gdi32.dll")] public static extern bool SetPixelFormat(IntPtr h, int f, ref PIXELFORMATDESCRIPTOR p);
    [DllImport("opengl32.dll")] public static extern IntPtr wglCreateContext(IntPtr h);
    [DllImport("opengl32.dll")] public static extern int wglMakeCurrent(IntPtr h, IntPtr g);
    [DllImport("opengl32.dll")] public static extern int wglDeleteContext(IntPtr g);
    [DllImport("opengl32.dll")] public static extern IntPtr wglGetProcAddress(string n);
    [DllImport("opengl32.dll")] public static extern void glClearColor(float r, float g, float b, float a);
    [DllImport("opengl32.dll")] public static extern void glClear(uint m);
    [DllImport("opengl32.dll")] public static extern void glViewport(int x, int y, int w, int h);
    [DllImport("opengl32.dll")] public static extern void glDrawArrays(uint m, int f, int c);
    [DllImport("opengl32.dll")] public static extern void glFlush();
    [DllImport("d3d11.dll")] public static extern int D3D11CreateDevice(IntPtr a, int dt, IntPtr sw, uint fl, uint[] lv, uint n, uint sdk, out IntPtr dev, out uint flOut, out IntPtr ctx);
    [DllImport("dxgi.dll")] public static extern int CreateDXGIFactory1(ref Guid iid, out IntPtr fac);
    [DllImport("d3dcompiler_47.dll")] public static extern int D3DCompile([MarshalAs(UnmanagedType.LPStr)] string src, IntPtr sz, [MarshalAs(UnmanagedType.LPStr)] string nm, IntPtr def, IntPtr inc, [MarshalAs(UnmanagedType.LPStr)] string ep, [MarshalAs(UnmanagedType.LPStr)] string tgt, uint f1, uint f2, out IntPtr code, out IntPtr err);
    [DllImport("dcomp.dll")] public static extern int DCompositionCreateDevice(IntPtr dxgi, ref Guid iid, out IntPtr dcomp);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateInstance(ref VkInstCI ci, IntPtr a, out IntPtr i);
    [DllImport("vulkan-1.dll")] public static extern int vkEnumeratePhysicalDevices(IntPtr i, ref uint c, IntPtr[] d);
    [DllImport("vulkan-1.dll")] public static extern void vkGetPhysicalDeviceQueueFamilyProperties(IntPtr p, ref uint c, [Out] VkQFP[] q);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateDevice(IntPtr p, ref VkDevCI ci, IntPtr a, out IntPtr d);
    [DllImport("vulkan-1.dll")] public static extern void vkGetDeviceQueue(IntPtr d, uint qf, uint qi, out IntPtr q);
    [DllImport("vulkan-1.dll")] public static extern void vkGetPhysicalDeviceMemoryProperties(IntPtr p, out VkPhysMemProps m);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateImage(IntPtr d, ref VkImgCI ci, IntPtr a, out ulong img);
    [DllImport("vulkan-1.dll")] public static extern void vkGetImageMemoryRequirements(IntPtr d, ulong img, out VkMemReq r);
    [DllImport("vulkan-1.dll")] public static extern int vkAllocateMemory(IntPtr d, ref VkMemAI ai, IntPtr a, out ulong m);
    [DllImport("vulkan-1.dll")] public static extern int vkBindImageMemory(IntPtr d, ulong img, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateImageView(IntPtr d, ref VkImgViewCI ci, IntPtr a, out ulong v);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateBuffer(IntPtr d, ref VkBufCI ci, IntPtr a, out ulong b);
    [DllImport("vulkan-1.dll")] public static extern void vkGetBufferMemoryRequirements(IntPtr d, ulong b, out VkMemReq r);
    [DllImport("vulkan-1.dll")] public static extern int vkBindBufferMemory(IntPtr d, ulong b, ulong m, ulong o);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateRenderPass(IntPtr d, ref VkRPCI ci, IntPtr a, out ulong rp);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateFramebuffer(IntPtr d, ref VkFBCI ci, IntPtr a, out ulong fb);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateShaderModule(IntPtr d, ref VkSMCI ci, IntPtr a, out ulong sm);
    [DllImport("vulkan-1.dll")] public static extern void vkDestroyShaderModule(IntPtr d, ulong sm, IntPtr a);
    [DllImport("vulkan-1.dll")] public static extern int vkCreatePipelineLayout(IntPtr d, ref VkPLCI ci, IntPtr a, out ulong pl);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateGraphicsPipelines(IntPtr d, ulong cache, uint n, ref VkGPCI ci, IntPtr a, out ulong p);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateCommandPool(IntPtr d, ref VkCPCI ci, IntPtr a, out IntPtr p);
    [DllImport("vulkan-1.dll")] public static extern int vkAllocateCommandBuffers(IntPtr d, ref VkCBAI ai, out IntPtr cb);
    [DllImport("vulkan-1.dll")] public static extern int vkCreateFence(IntPtr d, ref VkFenceCI ci, IntPtr a, out ulong f);
    [DllImport("vulkan-1.dll")] public static extern int vkWaitForFences(IntPtr d, uint n, ulong[] f, uint all, ulong t);
    [DllImport("vulkan-1.dll")] public static extern int vkResetFences(IntPtr d, uint n, ulong[] f);
    [DllImport("vulkan-1.dll")] public static extern int vkResetCommandBuffer(IntPtr cb, uint f);
    [DllImport("vulkan-1.dll")] public static extern int vkBeginCommandBuffer(IntPtr cb, ref VkCBBI bi);
    [DllImport("vulkan-1.dll")] public static extern int vkEndCommandBuffer(IntPtr cb);
    [DllImport("vulkan-1.dll")] public static extern void vkCmdBeginRenderPass(IntPtr cb, ref VkRPBI rp, uint c);
    [DllImport("vulkan-1.dll")] public static extern void vkCmdEndRenderPass(IntPtr cb);
    [DllImport("vulkan-1.dll")] public static extern void vkCmdBindPipeline(IntPtr cb, uint bp, ulong p);
    [DllImport("vulkan-1.dll")] public static extern void vkCmdDraw(IntPtr cb, uint vc, uint ic, uint fv, uint fi);
    [DllImport("vulkan-1.dll")] public static extern void vkCmdCopyImageToBuffer(IntPtr cb, ulong img, uint layout, ulong buf, uint n, IntPtr r);
    [DllImport("vulkan-1.dll")] public static extern int vkQueueSubmit(IntPtr q, uint n, ref VkSubmitInfo si, ulong f);
    [DllImport("vulkan-1.dll")] public static extern int vkMapMemory(IntPtr d, ulong m, ulong o, ulong sz, uint f, out IntPtr p);
    [DllImport("vulkan-1.dll")] public static extern void vkUnmapMemory(IntPtr d, ulong m);
    [DllImport("vulkan-1.dll")] public static extern int vkDeviceWaitIdle(IntPtr d);

    static WndProcDelegate _wndProcDelegate;
    public static bool Quit = false;
    static IntPtr WndProc(IntPtr h, uint m, IntPtr w, IntPtr l) {
        if (m == 0x0010 || m == 0x0002) { Quit = true; PostQuitMessage(0); return IntPtr.Zero; }
        if (m == 0x0100 && (int)w == 0x1B) { Quit = true; PostQuitMessage(0); return IntPtr.Zero; }
        if (m == 0x000F) { PAINTSTRUCT ps; BeginPaint(h, out ps); EndPaint(h, ref ps); return IntPtr.Zero; }
        return DefWindowProc(h, m, w, l);
    }
    public static IntPtr CreateAppWindow(int pw, int ph, int cnt, string title) {
        IntPtr hi = GetModuleHandle(null);
        _wndProcDelegate = new WndProcDelegate(WndProc);
        var wc = new WNDCLASSEX { cbSize=(uint)Marshal.SizeOf(typeof(WNDCLASSEX)), style=0x20, lpfnWndProc=_wndProcDelegate, hInstance=hi, hCursor=LoadCursor(IntPtr.Zero,32512), lpszClassName="DCMultiPS" };
        RegisterClassEx(ref wc);
        var rc = new RECT { Right=pw*cnt, Bottom=ph }; AdjustWindowRect(ref rc, 0xCF0000, false);
        IntPtr hw = CreateWindowEx(0,"DCMultiPS",title,0xCF0000|0x10000000,100,100,rc.Right-rc.Left,rc.Bottom-rc.Top,IntPtr.Zero,IntPtr.Zero,hi,IntPtr.Zero);
        if(hw!=IntPtr.Zero){ShowWindow(hw,1);UpdateWindow(hw);} return hw;
    }
}

// Helpers
public static class H {
    public static Delegate VT(IntPtr o, int i, Type t) { return Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(o), i*IntPtr.Size), t); }
    public static int QI(IntPtr o, ref Guid g, ref IntPtr r) { var f=(QIDelegate)VT(o,0,typeof(QIDelegate)); return f(o,ref g,out r); }
    public static void Rel(IntPtr o) { if(o!=IntPtr.Zero) Marshal.Release(o); }
    public static Delegate LoadGLDelegate(string name, Type t) { IntPtr p=N.wglGetProcAddress(name); if(p==IntPtr.Zero) throw new Exception("GL: "+name); return Marshal.GetDelegateForFunctionPointer(p,t); }
    public static void CopyRows(IntPtr src, IntPtr dst, int dstPitch, int srcPitch, int h) {
        byte[] row=new byte[srcPitch]; for(int y=0;y<h;y++){Marshal.Copy(src+y*srcPitch,row,0,srcPitch);Marshal.Copy(row,0,dst+y*dstPitch,srcPitch);}
    }
    public static uint FindMemType(VkPhysMemProps mp, uint bits, uint req) {
        for(uint i=0;i<mp.typeCnt;i++){if((bits&(1u<<(int)i))!=0){uint f=BitConverter.ToUInt32(mp.types,(int)(i*8));if((f&req)==req)return i;}} throw new Exception("No VK mem type");
    }
}
'@ -ReferencedAssemblies @()

# ---- Constants ----
$PW=320; $PH=480
$WM_QUIT=0x12; $PM_REM=1
$DXGI_B8=87; $DXGI_R32G32B32=6; $DXGI_R32G32B32A32=2; $DXGI_USAGE_RTO=0x20
$DXGI_FLIP_SEQ=3; $DXGI_ALPHA_PRE=1
$D3D_FL11=0xB000; $D3D_SDK=7; $D3D_BGRA=0x20; $D3D_STAGING=3
$D3D_BIND_VB=1; $D3D_MAP_W=2; $D3D_CPU_W=0x10000; $D3D_TOPO_TRI=4
$GL_TRI=4; $GL_FLT=0x1406; $GL_COLBIT=0x4000; $GL_ABuf=0x8892; $GL_STATIC=0x88E4
$GL_VS2=0x8B31; $GL_FS2=0x8B30; $GL_FB=0x8D40; $GL_RB=0x8D41; $GL_CA0=0x8CE0; $WGL_RW=1

$IID_F2   = [Guid]::new("50c83a1c-e072-4c48-87b0-3630fa36a6d0")
$IID_DXGIDev = [Guid]::new("54ec77fa-1377-44e6-8c32-88fd5f44c84c")
$IID_Tex2D = [Guid]::new("6f15aaf2-d208-4e89-9ab4-489535d34f9c")
$IID_DCDev = [Guid]::new("C37EA93A-E7AA-450D-B16F-9746CB0407F3")

$HLSL = "struct VSI{float3 p:POSITION;float4 c:COLOR;};`nstruct PSI{float4 p:SV_POSITION;float4 c:COLOR;};`nPSI VS(VSI i){PSI o;o.p=float4(i.p,1);o.c=i.c;return o;}`nfloat4 PS(PSI i):SV_Target{return i.c;}`n"

# ---- Global state ----
$script:_hw=$script:_d3d=$script:_ctx=$script:_fac=$script:_dc=$script:_dct=$script:_dcr=[IntPtr]::Zero

# GL
$script:_glSC=$script:_glBB=$script:_glHDC=$script:_glHRC=$script:_glID=$script:_glIO=[IntPtr]::Zero
$script:_glFBO=$script:_glRBO=$script:_glProg=$script:_glPA=$script:_glCA=[uint32]0
$script:_glVBO=[uint32[]]@(0,0)
$script:gGB=$script:gBB2=$script:gBD=$script:gCS=$script:gSS=$script:gCoS=$null
$script:gCP=$script:gAS=$script:gLP=$script:gUP=$script:gGA=$script:gEV=$script:gVAP=$null
$script:gGF=$script:gBF=$script:gFR=$script:gGR=$script:gGV=$script:gBV=$null
$script:gDL=$script:gDU=$null

# DX
$script:_dxSC=$script:_dxBB=$script:_dxRTV=$script:_dxVB=$script:_dxVS=$script:_dxPS=$script:_dxIL=[IntPtr]::Zero

# VK
$script:_vI=$script:_vPD=$script:_vD=$script:_vQ=$script:_vCP=$script:_vCB=[IntPtr]::Zero
$script:_vQF=-1
$script:_vOI=$script:_vOM=$script:_vOV=$script:_vSB=$script:_vSM2=[uint64]0
$script:_vRP=$script:_vFB2=$script:_vPL=$script:_vPP=$script:_vFN=[uint64]0
$script:_vSC=$script:_vBB=$script:_vST=[IntPtr]::Zero

# ---- Shared D3D11 helpers ----
function MakeSC([int]$w,[int]$h) {
    $d=New-Object DXGI_SWAP_CHAIN_DESC1; $d.Width=[uint32]$w; $d.Height=[uint32]$h; $d.Format=$DXGI_B8
    $sd=New-Object DXGI_SAMPLE_DESC; $sd.Count=1; $d.SampleDesc=$sd
    $d.BufferUsage=$DXGI_USAGE_RTO; $d.BufferCount=2; $d.SwapEffect=$DXGI_FLIP_SEQ; $d.AlphaMode=$DXGI_ALPHA_PRE
    $sc=[IntPtr]::Zero; ([CreateSCCompDelegate][H]::VT($script:_fac,24,[CreateSCCompDelegate])).Invoke($script:_fac,$script:_d3d,[ref]$d,[IntPtr]::Zero,[ref]$sc)|Out-Null; $sc
}
function SCBuf([IntPtr]$sc) { $g=$IID_Tex2D; $t=[IntPtr]::Zero; ([GetBufDelegate][H]::VT($sc,9,[GetBufDelegate])).Invoke($sc,0,[ref]$g,[ref]$t)|Out-Null; $t }
function SCPres([IntPtr]$sc) { ([PresentDelegate][H]::VT($sc,8,[PresentDelegate])).Invoke($sc,1,0)|Out-Null }
function MakeRTV([IntPtr]$t) { $r=[IntPtr]::Zero; ([CreateRTVDelegate][H]::VT($script:_d3d,9,[CreateRTVDelegate])).Invoke($script:_d3d,$t,[IntPtr]::Zero,[ref]$r)|Out-Null; $r }
function MakeStagTex([int]$w,[int]$h) {
    $d=New-Object D3D11_TEXTURE2D_DESC; $d.Width=[uint32]$w; $d.Height=[uint32]$h; $d.MipLevels=1; $d.ArraySize=1; $d.Format=$DXGI_B8
    $sd=New-Object DXGI_SAMPLE_DESC; $sd.Count=1; $d.SampleDesc=$sd; $d.Usage=$D3D_STAGING; $d.CPUAccessFlags=$D3D_CPU_W
    $t=[IntPtr]::Zero; ([CreateTex2DDelegate][H]::VT($script:_d3d,5,[CreateTex2DDelegate])).Invoke($script:_d3d,[ref]$d,[IntPtr]::Zero,[ref]$t)|Out-Null; $t
}
function ClearR([IntPtr]$rtv,[float]$r,[float]$g,[float]$b,[float]$a) { ([ClearRTVDelegate][H]::VT($script:_ctx,50,[ClearRTVDelegate])).Invoke($script:_ctx,$rtv,[float[]]@($r,$g,$b,$a)) }
function CopyR([IntPtr]$d,[IntPtr]$s) { ([CopyResDelegate][H]::VT($script:_ctx,47,[CopyResDelegate])).Invoke($script:_ctx,$d,$s) }
function MapW2([IntPtr]$r) { $m=New-Object D3D11_MAPPED_SUBRESOURCE; ([MapDelegate][H]::VT($script:_ctx,14,[MapDelegate])).Invoke($script:_ctx,$r,0,$D3D_MAP_W,0,[ref]$m)|Out-Null; $m }
function Unmap2([IntPtr]$r) { ([UnmapDelegate][H]::VT($script:_ctx,15,[UnmapDelegate])).Invoke($script:_ctx,$r,0) }

# ---- DComp helpers ----
function DCVis { $v=[IntPtr]::Zero; ([DCCreateVisDelegate][H]::VT($script:_dc,7,[DCCreateVisDelegate])).Invoke($script:_dc,[ref]$v)|Out-Null; $v }
function DCSetup([IntPtr]$v,[IntPtr]$sc,[float]$x) {
    ([DCSetContentDelegate][H]::VT($v,15,[DCSetContentDelegate])).Invoke($v,$sc)|Out-Null
    ([DCSetOffXDelegate][H]::VT($v,4,[DCSetOffXDelegate])).Invoke($v,$x)|Out-Null
    ([DCSetOffYDelegate][H]::VT($v,6,[DCSetOffYDelegate])).Invoke($v,0.0)|Out-Null
    ([DCAddVisDelegate][H]::VT($script:_dcr,16,[DCAddVisDelegate])).Invoke($script:_dcr,$v,1,[IntPtr]::Zero)|Out-Null
}
function DCCommit { ([DCCommitDelegate][H]::VT($script:_dc,3,[DCCommitDelegate])).Invoke($script:_dc)|Out-Null }

# ---- Init functions ----
function MakeD3D {
    $dev=[IntPtr]::Zero; $ctx=[IntPtr]::Zero; $fl=[uint32]0
    $hr=[N]::D3D11CreateDevice([IntPtr]::Zero,1,[IntPtr]::Zero,$D3D_BGRA,[uint32[]]@($D3D_FL11),1,$D3D_SDK,[ref]$dev,[ref]$fl,[ref]$ctx)
    if($hr -lt 0){throw "D3D11: 0x$($hr.ToString('X8'))"}; $script:_d3d=$dev; $script:_ctx=$ctx
}

function MakeFac {
    $g=[Guid]::new("770aae78-f26f-4dba-a829-253c83d1b387"); $f1=[IntPtr]::Zero
    [N]::CreateDXGIFactory1([ref]$g,[ref]$f1)|Out-Null; $f2=[IntPtr]::Zero; $g2=$IID_F2
    [H]::QI($f1,[ref]$g2,[ref]$f2)|Out-Null; [H]::Rel($f1); $script:_fac=$f2
}

function MakeDC {
    $dxgi=[IntPtr]::Zero; $g1=$IID_DXGIDev; [H]::QI($script:_d3d,[ref]$g1,[ref]$dxgi)|Out-Null
    $g2=$IID_DCDev; [N]::DCompositionCreateDevice($dxgi,[ref]$g2,[ref]$script:_dc)|Out-Null; [H]::Rel($dxgi)
    ([DCCreateTargetDelegate][H]::VT($script:_dc,6,[DCCreateTargetDelegate])).Invoke($script:_dc,$script:_hw,1,[ref]$script:_dct)|Out-Null
    ([DCCreateVisDelegate][H]::VT($script:_dc,7,[DCCreateVisDelegate])).Invoke($script:_dc,[ref]$script:_dcr)|Out-Null
    ([DCSetRootDelegate][H]::VT($script:_dct,3,[DCSetRootDelegate])).Invoke($script:_dct,$script:_dcr)|Out-Null
}

function InitGL {
    $script:_glSC=MakeSC $PW $PH; $script:_glBB=SCBuf $script:_glSC
    $script:_glHDC=[N]::GetDC($script:_hw)
    $pfd=New-Object PIXELFORMATDESCRIPTOR
    $pfd.nSize=[uint16][Runtime.InteropServices.Marshal]::SizeOf([type][PIXELFORMATDESCRIPTOR]); $pfd.nVersion=1; $pfd.dwFlags=0x25; $pfd.cColorBits=32
    $pf=[N]::ChoosePixelFormat($script:_glHDC,[ref]$pfd); [N]::SetPixelFormat($script:_glHDC,$pf,[ref]$pfd)|Out-Null
    $tmp=[N]::wglCreateContext($script:_glHDC); [N]::wglMakeCurrent($script:_glHDC,$tmp)|Out-Null
    $createCtx=[H]::LoadGLDelegate("wglCreateContextAttribsARB",[wglCreateContextAttribsARBDelegate])
    $script:_glHRC=$createCtx.Invoke($script:_glHDC,[IntPtr]::Zero,[int[]]@(0x2091,4,0x2092,6,0x9126,1,0))
    [N]::wglMakeCurrent([IntPtr]::Zero,[IntPtr]::Zero)|Out-Null; [N]::wglDeleteContext($tmp)|Out-Null
    [N]::wglMakeCurrent($script:_glHDC,$script:_glHRC)|Out-Null

    $script:gGB=[H]::LoadGLDelegate("glGenBuffers",[glGenBuffersDelegate])
    $script:gBB2=[H]::LoadGLDelegate("glBindBuffer",[glBindBufferDelegate])
    $script:gBD=[H]::LoadGLDelegate("glBufferData",[glBufferDataFloatDelegate])
    $script:gCS=[H]::LoadGLDelegate("glCreateShader",[glCreateShaderDelegate])
    $script:gSS=[H]::LoadGLDelegate("glShaderSource",[glShaderSourceDelegate])
    $script:gCoS=[H]::LoadGLDelegate("glCompileShader",[glCompileShaderDelegate])
    $script:gCP=[H]::LoadGLDelegate("glCreateProgram",[glCreateProgramDelegate])
    $script:gAS=[H]::LoadGLDelegate("glAttachShader",[glAttachShaderDelegate])
    $script:gLP=[H]::LoadGLDelegate("glLinkProgram",[glLinkProgramDelegate])
    $script:gUP=[H]::LoadGLDelegate("glUseProgram",[glUseProgramDelegate])
    $script:gGA=[H]::LoadGLDelegate("glGetAttribLocation",[glGetAttribLocationDelegate])
    $script:gEV=[H]::LoadGLDelegate("glEnableVertexAttribArray",[glEnableVertexAttribArrayDelegate])
    $script:gVAP=[H]::LoadGLDelegate("glVertexAttribPointer",[glVertexAttribPointerDelegate])
    $script:gGF=[H]::LoadGLDelegate("glGenFramebuffers",[glGenFramebuffersDelegate])
    $script:gBF=[H]::LoadGLDelegate("glBindFramebuffer",[glBindFramebufferDelegate])
    $script:gFR=[H]::LoadGLDelegate("glFramebufferRenderbuffer",[glFramebufferRenderbufferDelegate])
    $script:gGR=[H]::LoadGLDelegate("glGenRenderbuffers",[glGenRenderbuffersDelegate])
    $script:gGV=[H]::LoadGLDelegate("glGenVertexArrays",[glGenVertexArraysDelegate])
    $script:gBV=[H]::LoadGLDelegate("glBindVertexArray",[glBindVertexArrayDelegate])

    $dxOpen=[H]::LoadGLDelegate("wglDXOpenDeviceNV",[wglDXOpenDeviceNVDelegate])
    $script:_glID=$dxOpen.Invoke($script:_d3d)
    $dxReg=[H]::LoadGLDelegate("wglDXRegisterObjectNV",[wglDXRegisterObjectNVDelegate])
    $script:gDL=[H]::LoadGLDelegate("wglDXLockObjectsNV",[wglDXLockObjectsNVDelegate])
    $script:gDU=[H]::LoadGLDelegate("wglDXUnlockObjectsNV",[wglDXUnlockObjectsNVDelegate])

    $rbo=[uint32[]]@(0); $script:gGR.Invoke(1,$rbo); $script:_glRBO=$rbo[0]
    $script:_glIO=$dxReg.Invoke($script:_glID,$script:_glBB,$script:_glRBO,$GL_RB,$WGL_RW)
    $fbo=[uint32[]]@(0); $script:gGF.Invoke(1,$fbo); $script:_glFBO=$fbo[0]
    $script:gBF.Invoke($GL_FB,$script:_glFBO); $script:gFR.Invoke($GL_FB,$GL_CA0,$GL_RB,$script:_glRBO)

    $glVS="$('#')version 460`nlayout(location=0)in vec3 aP;layout(location=1)in vec4 aC;out vec4 vC;void main(){gl_Position=vec4(aP.x,-aP.y,aP.z,1);vC=aC;}"
    $glFS="$('#')version 460`nin vec4 vC;out vec4 fC;void main(){fC=vC;}"
    $vs=$script:gCS.Invoke($GL_VS2); $script:gSS.Invoke($vs,1,[string[]]@($glVS),$null); $script:gCoS.Invoke($vs)
    $fs=$script:gCS.Invoke($GL_FS2); $script:gSS.Invoke($fs,1,[string[]]@($glFS),$null); $script:gCoS.Invoke($fs)
    $script:_glProg=$script:gCP.Invoke(); $script:gAS.Invoke($script:_glProg,$vs); $script:gAS.Invoke($script:_glProg,$fs)
    $script:gLP.Invoke($script:_glProg); $script:gUP.Invoke($script:_glProg)
    $script:_glPA=$script:gGA.Invoke($script:_glProg,"aP"); $script:_glCA=$script:gGA.Invoke($script:_glProg,"aC")

    [float[]]$pos=@(0,0.5,0, 0.5,-0.5,0, -0.5,-0.5,0); [float[]]$col=@(1,0,0,1, 0,1,0,1, 0,0,1,1)
    $script:_glVBO=[uint32[]]@(0,0); $script:gGB.Invoke(2,$script:_glVBO)
    $script:gBB2.Invoke($GL_ABuf,$script:_glVBO[0]); $script:gBD.Invoke($GL_ABuf,$pos.Length*4,$pos,$GL_STATIC)
    $script:gBB2.Invoke($GL_ABuf,$script:_glVBO[1]); $script:gBD.Invoke($GL_ABuf,$col.Length*4,$col,$GL_STATIC)

    $vao=[uint32[]]@(0); $script:gGV.Invoke(1,$vao); $script:gBV.Invoke($vao[0])
    $script:gBB2.Invoke($GL_ABuf,$script:_glVBO[0]); $script:gEV.Invoke($script:_glPA); $script:gVAP.Invoke($script:_glPA,3,$GL_FLT,$false,0,[IntPtr]::Zero)
    $script:gBB2.Invoke($GL_ABuf,$script:_glVBO[1]); $script:gEV.Invoke($script:_glCA); $script:gVAP.Invoke($script:_glCA,4,$GL_FLT,$false,0,[IntPtr]::Zero)

    DCSetup (DCVis) $script:_glSC 0.0
    Write-Host "[GL] OK"
}

function InitDX {
    $script:_dxSC=MakeSC $PW $PH; $script:_dxBB=SCBuf $script:_dxSC; $script:_dxRTV=MakeRTV $script:_dxBB
    $vb=[IntPtr]::Zero;$ve=[IntPtr]::Zero;$pb=[IntPtr]::Zero;$pe=[IntPtr]::Zero
    [N]::D3DCompile($HLSL,[IntPtr]$HLSL.Length,"dx",[IntPtr]::Zero,[IntPtr]::Zero,"VS","vs_4_0",0,0,[ref]$vb,[ref]$ve)|Out-Null
    [N]::D3DCompile($HLSL,[IntPtr]$HLSL.Length,"dx",[IntPtr]::Zero,[IntPtr]::Zero,"PS","ps_4_0",0,0,[ref]$pb,[ref]$pe)|Out-Null
    $vP=([BlobPtrDelegate][H]::VT($vb,3,[BlobPtrDelegate])).Invoke($vb); $vS=([BlobSzDelegate][H]::VT($vb,4,[BlobSzDelegate])).Invoke($vb)
    $pP=([BlobPtrDelegate][H]::VT($pb,3,[BlobPtrDelegate])).Invoke($pb); $pS=([BlobSzDelegate][H]::VT($pb,4,[BlobSzDelegate])).Invoke($pb)
    ([CreateVSDelegate][H]::VT($script:_d3d,12,[CreateVSDelegate])).Invoke($script:_d3d,$vP,$vS,[IntPtr]::Zero,[ref]$script:_dxVS)|Out-Null
    ([CreatePSDelegate][H]::VT($script:_d3d,15,[CreatePSDelegate])).Invoke($script:_d3d,$pP,$pS,[IntPtr]::Zero,[ref]$script:_dxPS)|Out-Null
    $el=@((New-Object D3D11_INPUT_ELEMENT_DESC -Property @{SemanticName="POSITION";Format=$DXGI_R32G32B32;AlignedByteOffset=0}),(New-Object D3D11_INPUT_ELEMENT_DESC -Property @{SemanticName="COLOR";Format=$DXGI_R32G32B32A32;AlignedByteOffset=12}))
    ([CreateILDelegate][H]::VT($script:_d3d,11,[CreateILDelegate])).Invoke($script:_d3d,$el,2,$vP,$vS,[ref]$script:_dxIL)|Out-Null; [H]::Rel($vb); [H]::Rel($pb)
    $vs=[DxVertex[]]@((New-Object DxVertex -Property @{X=0;Y=0.5;Z=0;R=1;G=0;B=0;A=1}),(New-Object DxVertex -Property @{X=0.5;Y=-0.5;Z=0;R=0;G=1;B=0;A=1}),(New-Object DxVertex -Property @{X=-0.5;Y=-0.5;Z=0;R=0;G=0;B=1;A=1}))
    $hV=[Runtime.InteropServices.GCHandle]::Alloc($vs,[Runtime.InteropServices.GCHandleType]::Pinned)
    $bd=New-Object D3D11_BUFFER_DESC; $bd.ByteWidth=[uint32]([Runtime.InteropServices.Marshal]::SizeOf([type][DxVertex])*3); $bd.BindFlags=$D3D_BIND_VB
    $sd=New-Object D3D11_SUBRESOURCE_DATA; $sd.pSysMem=$hV.AddrOfPinnedObject()
    ([CreateBufferDelegate][H]::VT($script:_d3d,3,[CreateBufferDelegate])).Invoke($script:_d3d,[ref]$bd,[ref]$sd,[ref]$script:_dxVB)|Out-Null; $hV.Free()
    DCSetup (DCVis) $script:_dxSC ([float]$PW)
    Write-Host "[D3D11] OK"
}

function InitVK {
    $an=[Runtime.InteropServices.Marshal]::StringToHGlobalAnsi("vk")
    $ai=New-Object VkAppInfo; $ai.sType=0; $ai.pAppName=$an; $ai.apiVer=(1-shl 22)
    $hAI=[Runtime.InteropServices.GCHandle]::Alloc($ai,[Runtime.InteropServices.GCHandleType]::Pinned)
    $ici=New-Object VkInstCI; $ici.sType=1; $ici.pAppInfo=$hAI.AddrOfPinnedObject()
    [N]::vkCreateInstance([ref]$ici,[IntPtr]::Zero,[ref]$script:_vI)|Out-Null; $hAI.Free(); [Runtime.InteropServices.Marshal]::FreeHGlobal($an)
    [uint32]$cnt=0; [N]::vkEnumeratePhysicalDevices($script:_vI,[ref]$cnt,$null)|Out-Null
    $ds=[IntPtr[]]::new($cnt); [N]::vkEnumeratePhysicalDevices($script:_vI,[ref]$cnt,$ds)|Out-Null; $script:_vPD=$ds[0]
    [uint32]$qc=0; [N]::vkGetPhysicalDeviceQueueFamilyProperties($script:_vPD,[ref]$qc,$null)
    $qp=[VkQFP[]]::new($qc); [N]::vkGetPhysicalDeviceQueueFamilyProperties($script:_vPD,[ref]$qc,$qp)
    $script:_vQF=-1; for($i=0;$i -lt $qc;$i++){if(($qp[$i].qFlags -band 1) -ne 0){$script:_vQF=$i;break}}
    $hP=[Runtime.InteropServices.GCHandle]::Alloc([float[]]@(1.0),[Runtime.InteropServices.GCHandleType]::Pinned)
    $qci=New-Object VkDevQCI; $qci.sType=2; $qci.qfi=[uint32]$script:_vQF; $qci.qCnt=1; $qci.pPrio=$hP.AddrOfPinnedObject()
    $hQ=[Runtime.InteropServices.GCHandle]::Alloc($qci,[Runtime.InteropServices.GCHandleType]::Pinned)
    $dci=New-Object VkDevCI; $dci.sType=3; $dci.qciCnt=1; $dci.pQCI=$hQ.AddrOfPinnedObject()
    [N]::vkCreateDevice($script:_vPD,[ref]$dci,[IntPtr]::Zero,[ref]$script:_vD)|Out-Null; $hQ.Free(); $hP.Free()
    [N]::vkGetDeviceQueue($script:_vD,[uint32]$script:_vQF,0,[ref]$script:_vQ)
    $mp=New-Object VkPhysMemProps; [N]::vkGetPhysicalDeviceMemoryProperties($script:_vPD,[ref]$mp)
    $ic=New-Object VkImgCI; $ic.sType=14; $ic.imgType=1; $ic.fmt=44; $ic.eW=[uint32]$PW; $ic.eH=[uint32]$PH; $ic.eD=1; $ic.mip=1; $ic.arr=1; $ic.samples=1; $ic.usage=0x11
    [N]::vkCreateImage($script:_vD,[ref]$ic,[IntPtr]::Zero,[ref]$script:_vOI)|Out-Null
    $ir=New-Object VkMemReq; [N]::vkGetImageMemoryRequirements($script:_vD,$script:_vOI,[ref]$ir)
    $ia=New-Object VkMemAI; $ia.sType=5; $ia.size=$ir.size; $ia.memIdx=[H]::FindMemType($mp,$ir.memBits,1)
    [N]::vkAllocateMemory($script:_vD,[ref]$ia,[IntPtr]::Zero,[ref]$script:_vOM)|Out-Null; [N]::vkBindImageMemory($script:_vD,$script:_vOI,$script:_vOM,0)|Out-Null
    $ivc=New-Object VkImgViewCI; $ivc.sType=15; $ivc.img=$script:_vOI; $ivc.viewType=1; $ivc.fmt=44; $ivc.aspect=1; $ivc.lvlCnt=1; $ivc.layerCnt=1
    [N]::vkCreateImageView($script:_vD,[ref]$ivc,[IntPtr]::Zero,[ref]$script:_vOV)|Out-Null
    [uint64]$bsz=$PW*$PH*4; $bc=New-Object VkBufCI; $bc.sType=12; $bc.size=$bsz; $bc.usage=2
    [N]::vkCreateBuffer($script:_vD,[ref]$bc,[IntPtr]::Zero,[ref]$script:_vSB)|Out-Null
    $br=New-Object VkMemReq; [N]::vkGetBufferMemoryRequirements($script:_vD,$script:_vSB,[ref]$br)
    $ba=New-Object VkMemAI; $ba.sType=5; $ba.size=$br.size; $ba.memIdx=[H]::FindMemType($mp,$br.memBits,6)
    [N]::vkAllocateMemory($script:_vD,[ref]$ba,[IntPtr]::Zero,[ref]$script:_vSM2)|Out-Null; [N]::vkBindBufferMemory($script:_vD,$script:_vSB,$script:_vSM2,0)|Out-Null
    $att=New-Object VkAttDesc; $att.fmt=44; $att.samples=1; $att.loadOp=1; $att.storeOp=0; $att.stLoadOp=2; $att.stStoreOp=1; $att.finalLayout=6
    $ar=New-Object VkAttRef; $ar.att=0; $ar.layout=2
    $hA=[Runtime.InteropServices.GCHandle]::Alloc($att,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hR=[Runtime.InteropServices.GCHandle]::Alloc($ar,[Runtime.InteropServices.GCHandleType]::Pinned)
    $sd2=New-Object VkSubDesc; $sd2.caCnt=1; $sd2.pCA=$hR.AddrOfPinnedObject()
    $hS=[Runtime.InteropServices.GCHandle]::Alloc($sd2,[Runtime.InteropServices.GCHandleType]::Pinned)
    $rpc=New-Object VkRPCI; $rpc.sType=38; $rpc.attCnt=1; $rpc.pAtts=$hA.AddrOfPinnedObject(); $rpc.subCnt=1; $rpc.pSubs=$hS.AddrOfPinnedObject()
    [N]::vkCreateRenderPass($script:_vD,[ref]$rpc,[IntPtr]::Zero,[ref]$script:_vRP)|Out-Null; $hA.Free();$hR.Free();$hS.Free()
    $hV2=[Runtime.InteropServices.GCHandle]::Alloc([uint64[]]@($script:_vOV),[Runtime.InteropServices.GCHandleType]::Pinned)
    $fbc=New-Object VkFBCI; $fbc.sType=37; $fbc.rp=$script:_vRP; $fbc.attCnt=1; $fbc.pAtts=$hV2.AddrOfPinnedObject(); $fbc.w=[uint32]$PW; $fbc.h=[uint32]$PH; $fbc.layers=1
    [N]::vkCreateFramebuffer($script:_vD,[ref]$fbc,[IntPtr]::Zero,[ref]$script:_vFB2)|Out-Null; $hV2.Free()
    $vsSpv=[SC]::Compile((Get-Content "hello.vert" -Raw),0,"hello.vert"); $fsSpv=[SC]::Compile((Get-Content "hello.frag" -Raw),1,"hello.frag")
    [uint64]$vsm=0; [uint64]$fsm=0
    $hVS=[Runtime.InteropServices.GCHandle]::Alloc($vsSpv,[Runtime.InteropServices.GCHandleType]::Pinned)
    $smv=New-Object VkSMCI; $smv.sType=16; $smv.codeSz=(New-Object UIntPtr([uint64]$vsSpv.Length)); $smv.pCode=$hVS.AddrOfPinnedObject()
    [N]::vkCreateShaderModule($script:_vD,[ref]$smv,[IntPtr]::Zero,[ref]$vsm)|Out-Null; $hVS.Free()
    $hFS=[Runtime.InteropServices.GCHandle]::Alloc($fsSpv,[Runtime.InteropServices.GCHandleType]::Pinned)
    $smf=New-Object VkSMCI; $smf.sType=16; $smf.codeSz=(New-Object UIntPtr([uint64]$fsSpv.Length)); $smf.pCode=$hFS.AddrOfPinnedObject()
    [N]::vkCreateShaderModule($script:_vD,[ref]$smf,[IntPtr]::Zero,[ref]$fsm)|Out-Null; $hFS.Free()
    $ms=[Runtime.InteropServices.Marshal]::StringToHGlobalAnsi("main")
    $stg=[VkPSSCI[]]@((New-Object VkPSSCI -Property @{sType=18;stage=1;module=$vsm;pName=$ms}),(New-Object VkPSSCI -Property @{sType=18;stage=0x10;module=$fsm;pName=$ms}))
    $hStg=[Runtime.InteropServices.GCHandle]::Alloc($stg,[Runtime.InteropServices.GCHandleType]::Pinned)
    $vi=New-Object VkPVICI; $vi.sType=19; $ias2=New-Object VkPIACI; $ias2.sType=20; $ias2.topo=3
    $vp=New-Object VkViewport; $vp.w=$PW; $vp.h=$PH; $vp.maxD=1
    $scExt=New-Object VkExt2D; $scExt.w=[uint32]$PW; $scExt.h=[uint32]$PH; $sc2=New-Object VkRect2D; $sc2.ext=$scExt
    $hVP=[Runtime.InteropServices.GCHandle]::Alloc($vp,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hSC=[Runtime.InteropServices.GCHandle]::Alloc($sc2,[Runtime.InteropServices.GCHandleType]::Pinned)
    $vps=New-Object VkPVPCI; $vps.sType=22; $vps.vpCnt=1; $vps.pVP=$hVP.AddrOfPinnedObject(); $vps.scCnt=1; $vps.pSC=$hSC.AddrOfPinnedObject()
    $rs=New-Object VkPRCI; $rs.sType=23; $rs.lineW=1.0; $mss=New-Object VkPMSCI; $mss.sType=24; $mss.rSamples=1
    $cba=New-Object VkPCBAS; $cba.wMask=0xF; $hCBA=[Runtime.InteropServices.GCHandle]::Alloc($cba,[Runtime.InteropServices.GCHandleType]::Pinned)
    $cbs=New-Object VkPCBCI; $cbs.sType=26; $cbs.attCnt=1; $cbs.pAtts=$hCBA.AddrOfPinnedObject()
    $hVI=[Runtime.InteropServices.GCHandle]::Alloc($vi,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hIA=[Runtime.InteropServices.GCHandle]::Alloc($ias2,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hVPS=[Runtime.InteropServices.GCHandle]::Alloc($vps,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hRS=[Runtime.InteropServices.GCHandle]::Alloc($rs,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hMS=[Runtime.InteropServices.GCHandle]::Alloc($mss,[Runtime.InteropServices.GCHandleType]::Pinned)
    $hCB=[Runtime.InteropServices.GCHandle]::Alloc($cbs,[Runtime.InteropServices.GCHandleType]::Pinned)
    $plc=New-Object VkPLCI; $plc.sType=30; [N]::vkCreatePipelineLayout($script:_vD,[ref]$plc,[IntPtr]::Zero,[ref]$script:_vPL)|Out-Null
    $gpc=New-Object VkGPCI; $gpc.sType=28; $gpc.stageCnt=2; $gpc.pStages=$hStg.AddrOfPinnedObject()
    $gpc.pVIS=$hVI.AddrOfPinnedObject(); $gpc.pIAS=$hIA.AddrOfPinnedObject(); $gpc.pVPS=$hVPS.AddrOfPinnedObject()
    $gpc.pRast=$hRS.AddrOfPinnedObject(); $gpc.pMS=$hMS.AddrOfPinnedObject(); $gpc.pCBS=$hCB.AddrOfPinnedObject()
    $gpc.layout=$script:_vPL; $gpc.rp=$script:_vRP
    [N]::vkCreateGraphicsPipelines($script:_vD,0,1,[ref]$gpc,[IntPtr]::Zero,[ref]$script:_vPP)|Out-Null
    $hStg.Free();$hVI.Free();$hIA.Free();$hVPS.Free();$hRS.Free();$hMS.Free();$hCB.Free();$hCBA.Free();$hVP.Free();$hSC.Free()
    [Runtime.InteropServices.Marshal]::FreeHGlobal($ms)
    [N]::vkDestroyShaderModule($script:_vD,$vsm,[IntPtr]::Zero); [N]::vkDestroyShaderModule($script:_vD,$fsm,[IntPtr]::Zero)
    $cpc=New-Object VkCPCI; $cpc.sType=39; $cpc.flags=2; $cpc.qfi=[uint32]$script:_vQF
    [N]::vkCreateCommandPool($script:_vD,[ref]$cpc,[IntPtr]::Zero,[ref]$script:_vCP)|Out-Null
    $cbi=New-Object VkCBAI; $cbi.sType=40; $cbi.pool=$script:_vCP; $cbi.cnt=1
    [N]::vkAllocateCommandBuffers($script:_vD,[ref]$cbi,[ref]$script:_vCB)|Out-Null
    $fc=New-Object VkFenceCI; $fc.sType=8; $fc.flags=1; [N]::vkCreateFence($script:_vD,[ref]$fc,[IntPtr]::Zero,[ref]$script:_vFN)|Out-Null
    $script:_vSC=MakeSC $PW $PH; $script:_vBB=SCBuf $script:_vSC; $script:_vST=MakeStagTex $PW $PH
    DCSetup (DCVis) $script:_vSC ([float]($PW*2))
    Write-Host "[VK] OK"
}

# ---- Render functions ----
function RenderGL {
    $script:gDL.Invoke($script:_glID,1,[IntPtr[]]@($script:_glIO))|Out-Null
    $script:gBF.Invoke($GL_FB,$script:_glFBO); [N]::glViewport(0,0,$PW,$PH)
    [N]::glClearColor(0.05,0.05,0.15,1.0); [N]::glClear($GL_COLBIT)
    [N]::glDrawArrays($GL_TRI,0,3); [N]::glFlush()
    $script:gDU.Invoke($script:_glID,1,[IntPtr[]]@($script:_glIO))|Out-Null
    SCPres $script:_glSC
}

function RenderDX {
    ClearR $script:_dxRTV 0.05 0.15 0.05 1.0
    ([OMSetRTDelegate][H]::VT($script:_ctx,33,[OMSetRTDelegate])).Invoke($script:_ctx,1,[IntPtr[]]@($script:_dxRTV),[IntPtr]::Zero)
    $vp=New-Object D3D11_VIEWPORT; $vp.Width=$PW; $vp.Height=$PH; $vp.MaxDepth=1
    ([RSSetVPDelegate][H]::VT($script:_ctx,44,[RSSetVPDelegate])).Invoke($script:_ctx,1,[ref]$vp)
    ([IASetILDelegate][H]::VT($script:_ctx,17,[IASetILDelegate])).Invoke($script:_ctx,$script:_dxIL)
    $stride=[uint32][Runtime.InteropServices.Marshal]::SizeOf([type][DxVertex])
    ([IASetVBDelegate][H]::VT($script:_ctx,18,[IASetVBDelegate])).Invoke($script:_ctx,0,1,[IntPtr[]]@($script:_dxVB),[uint32[]]@($stride),[uint32[]]@(0))
    ([IASetTopoDelegate][H]::VT($script:_ctx,24,[IASetTopoDelegate])).Invoke($script:_ctx,$D3D_TOPO_TRI)
    ([VSSetDelegate][H]::VT($script:_ctx,11,[VSSetDelegate])).Invoke($script:_ctx,$script:_dxVS,$null,0)
    ([PSSetDelegate][H]::VT($script:_ctx,9,[PSSetDelegate])).Invoke($script:_ctx,$script:_dxPS,$null,0)
    ([DrawDelegate][H]::VT($script:_ctx,13,[DrawDelegate])).Invoke($script:_ctx,3,0)
    SCPres $script:_dxSC
}

function RenderVK {
    $fn2=[uint64[]]@($script:_vFN)
    [N]::vkWaitForFences($script:_vD,1,$fn2,1,[uint64]::MaxValue)|Out-Null
    [N]::vkResetFences($script:_vD,1,$fn2)|Out-Null; [N]::vkResetCommandBuffer($script:_vCB,0)|Out-Null
    $bi=New-Object VkCBBI; $bi.sType=42; [N]::vkBeginCommandBuffer($script:_vCB,[ref]$bi)|Out-Null
    $cc=New-Object VkClearCol; $cc.r=0.15; $cc.g=0.05; $cc.b=0.05; $cc.a=1.0
    $cv=New-Object VkClearVal; $cv.color=$cc
    $hCV=[Runtime.InteropServices.GCHandle]::Alloc($cv,[Runtime.InteropServices.GCHandleType]::Pinned)
    $aExt=New-Object VkExt2D; $aExt.w=[uint32]$PW; $aExt.h=[uint32]$PH
    $aRect=New-Object VkRect2D; $aRect.ext=$aExt
    $rpbi=New-Object VkRPBI; $rpbi.sType=43; $rpbi.rp=$script:_vRP; $rpbi.fb=$script:_vFB2
    $rpbi.area=$aRect; $rpbi.cvCnt=1; $rpbi.pCV=$hCV.AddrOfPinnedObject()
    [N]::vkCmdBeginRenderPass($script:_vCB,[ref]$rpbi,0)
    [N]::vkCmdBindPipeline($script:_vCB,0,$script:_vPP); [N]::vkCmdDraw($script:_vCB,3,1,0,0)
    [N]::vkCmdEndRenderPass($script:_vCB); $hCV.Free()
    $rg=New-Object VkBufImgCopy; $rg.bRL=[uint32]$PW; $rg.bIH=[uint32]$PH; $rg.aspect=1; $rg.lCnt=1; $rg.eW=[uint32]$PW; $rg.eH=[uint32]$PH; $rg.eD=1
    $hRG=[Runtime.InteropServices.GCHandle]::Alloc($rg,[Runtime.InteropServices.GCHandleType]::Pinned)
    [N]::vkCmdCopyImageToBuffer($script:_vCB,$script:_vOI,6,$script:_vSB,1,$hRG.AddrOfPinnedObject()); $hRG.Free()
    [N]::vkEndCommandBuffer($script:_vCB)|Out-Null
    $hC=[Runtime.InteropServices.GCHandle]::Alloc([IntPtr[]]@($script:_vCB),[Runtime.InteropServices.GCHandleType]::Pinned)
    $si=New-Object VkSubmitInfo; $si.sType=4; $si.cbCnt=1; $si.pCB=$hC.AddrOfPinnedObject()
    [N]::vkQueueSubmit($script:_vQ,1,[ref]$si,$script:_vFN)|Out-Null; $hC.Free()
    [N]::vkWaitForFences($script:_vD,1,$fn2,1,[uint64]::MaxValue)|Out-Null
    $vd=[IntPtr]::Zero; [N]::vkMapMemory($script:_vD,$script:_vSM2,0,[uint64]($PW*$PH*4),0,[ref]$vd)|Out-Null
    $m=MapW2 $script:_vST; [H]::CopyRows($vd,$m.pData,[int]$m.RowPitch,($PW*4),$PH)
    Unmap2 $script:_vST; [N]::vkUnmapMemory($script:_vD,$script:_vSM2)
    CopyR $script:_vBB $script:_vST; SCPres $script:_vSC
}

# ---- Main ----
Write-Host "=== GL + D3D11 + VK via DirectComposition (PowerShell) ==="
$script:_hw = [N]::CreateAppWindow($PW, $PH, 3, "Hello, DirectComposition(PowerShell) World!")
if ($script:_hw -eq [IntPtr]::Zero) { throw "CreateAppWindow failed" }
MakeD3D; MakeFac; MakeDC
Write-Host "--- GL ---"; InitGL
Write-Host "--- D3D11 ---"; InitDX
Write-Host "--- VK ---"; InitVK
DCCommit
Write-Host "Main loop..."
$msg = New-Object MSG; $first = $true
while (-not [N]::Quit) {
    while ([N]::PeekMessage([ref]$msg, [IntPtr]::Zero, 0, 0, $PM_REM)) {
        if ($msg.message -eq $WM_QUIT) { [N]::Quit = $true; break }
        [N]::TranslateMessage([ref]$msg) | Out-Null; [N]::DispatchMessage([ref]$msg) | Out-Null
    }
    if ([N]::Quit) { break }
    RenderGL; RenderDX; RenderVK
    if ($first) { Write-Host "First frame OK"; $first = $false }
    Start-Sleep -Milliseconds 1
}
if ($script:_vD -ne [IntPtr]::Zero) { [N]::vkDeviceWaitIdle($script:_vD) | Out-Null }
Write-Host "=== END ==="

