# Hello.ps1
# OpenGL 4.6 + D3D11 + Vulkan 1.4 Triangles via Windows.UI.Composition (Win32 Desktop Interop)
# ALL COM/WinRT calls via vtable index. No external libraries. No WinRT projections.
# Logging: OutputDebugStringW (use DebugView to monitor)
#
# Requires: PowerShell 5.1, shaderc_shared.dll, hello.vert, hello.frag
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Hello.ps1

# ==============================================================================
# C# interop layer: structs, P/Invoke, delegates, and helper methods
# All unsafe/pointer operations must live in compiled C# code
# ==============================================================================

$NativeSource = @'
using System;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;

// ============================================================
// shaderc SPIR-V compiler wrapper
// ============================================================
public static class SC
{
    const string L = "shaderc_shared.dll";
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compiler_initialize();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compiler_release(IntPtr c);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_options_initialize();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compile_options_release(IntPtr o);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_compile_options_set_optimization_level(IntPtr o, int l);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_compile_into_spv(IntPtr c, [MarshalAs(UnmanagedType.LPStr)] string s, UIntPtr sz, int k, [MarshalAs(UnmanagedType.LPStr)] string fn, [MarshalAs(UnmanagedType.LPStr)] string ep, IntPtr o);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern int shaderc_result_get_compilation_status(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern UIntPtr shaderc_result_get_length(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_bytes(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr shaderc_result_get_error_message(IntPtr r);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] public static extern void shaderc_result_release(IntPtr r);

    public static byte[] Compile(string src, int kind, string file)
    {
        IntPtr comp = shaderc_compiler_initialize();
        IntPtr opt = shaderc_compile_options_initialize();
        shaderc_compile_options_set_optimization_level(opt, 2);
        try
        {
            IntPtr res = shaderc_compile_into_spv(comp, src, (UIntPtr)Encoding.UTF8.GetByteCount(src), kind, file, "main", opt);
            try
            {
                if (shaderc_result_get_compilation_status(res) != 0)
                {
                    string e = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(res));
                    throw new Exception("Shader: " + e);
                }
                int len = (int)(ulong)shaderc_result_get_length(res);
                byte[] data = new byte[len];
                Marshal.Copy(shaderc_result_get_bytes(res), data, 0, len);
                return data;
            }
            finally { shaderc_result_release(res); }
        }
        finally
        {
            shaderc_compile_options_release(opt);
            shaderc_compiler_release(comp);
        }
    }
}

// ============================================================
// Win32 / DXGI / D3D11 / Vulkan / WinRT Structures
// ============================================================
[StructLayout(LayoutKind.Sequential)]
public struct POINT { public int X, Y; }

[StructLayout(LayoutKind.Sequential)]
public struct MSG
{
    public IntPtr hwnd;
    public uint message;
    public IntPtr wParam;
    public IntPtr lParam;
    public uint time;
    public POINT pt;
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT { public int Left, Top, Right, Bottom; }

[StructLayout(LayoutKind.Sequential)]
public struct PAINTSTRUCT
{
    public IntPtr hdc;
    public int fErase;
    public RECT rcPaint;
    public int fRestore;
    public int fIncUpdate;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
    public byte[] rgbReserved;
}

[StructLayout(LayoutKind.Sequential)]
public struct Float2 { public float X, Y; }
[StructLayout(LayoutKind.Sequential)]
public struct Float3 { public float X, Y, Z; }

[StructLayout(LayoutKind.Sequential)]
public struct PIXELFORMATDESCRIPTOR
{
    public ushort nSize, nVersion;
    public uint dwFlags;
    public byte iPixelType, cColorBits, cRedBits, cRedShift, cGreenBits, cGreenShift, cBlueBits, cBlueShift;
    public byte cAlphaBits, cAlphaShift, cAccumBits, cAccumRedBits, cAccumGreenBits, cAccumBlueBits, cAccumAlphaBits;
    public byte cDepthBits, cStencilBits, cAuxBuffers, iLayerType, bReserved;
    public uint dwLayerMask, dwVisibleMask, dwDamageMask;
}

[StructLayout(LayoutKind.Sequential)]
public struct DXGI_SAMPLE_DESC { public uint Count, Quality; }

[StructLayout(LayoutKind.Sequential)]
public struct DXGI_SWAP_CHAIN_DESC1
{
    public uint Width, Height, Format;
    public int  Stereo;
    public DXGI_SAMPLE_DESC SampleDesc;
    public uint BufferUsage, BufferCount, Scaling, SwapEffect, AlphaMode, Flags;
}

[StructLayout(LayoutKind.Sequential)]
public struct Vertex { public float X, Y, Z, R, G, B, A; }

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct D3D11_BUFFER_DESC { public uint ByteWidth, Usage, BindFlags, CPUAccessFlags, MiscFlags, StructureByteStride; }

[StructLayout(LayoutKind.Sequential)]
public struct D3D11_SUBRESOURCE_DATA { public IntPtr pSysMem; public uint SysMemPitch, SysMemSlicePitch; }

[StructLayout(LayoutKind.Sequential)]
public struct D3D11_INPUT_ELEMENT_DESC
{
    [MarshalAs(UnmanagedType.LPStr)] public string SemanticName;
    public uint SemanticIndex, Format, InputSlot, AlignedByteOffset, InputSlotClass, InstanceDataStepRate;
}

[StructLayout(LayoutKind.Sequential)]
public struct D3D11_VIEWPORT { public float TopLeftX, TopLeftY, Width, Height, MinDepth, MaxDepth; }

[StructLayout(LayoutKind.Sequential)]
public struct D3D11_TEXTURE2D_DESC
{
    public uint Width, Height, MipLevels, ArraySize, Format;
    public DXGI_SAMPLE_DESC SampleDesc;
    public uint Usage, BindFlags, CPUAccessFlags, MiscFlags;
}

[StructLayout(LayoutKind.Sequential)]
public struct D3D11_MAPPED_SUBRESOURCE { public IntPtr pData; public uint RowPitch, DepthPitch; }

// Vulkan structs
[StructLayout(LayoutKind.Sequential)] public struct VkAppInfo { public uint sType; public IntPtr pNext, pAppName; public uint appVer; public IntPtr pEngName; public uint engVer, apiVer; }
[StructLayout(LayoutKind.Sequential)] public struct VkInstCI { public uint sType; public IntPtr pNext; public uint flags; public IntPtr pAppInfo; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; }
[StructLayout(LayoutKind.Sequential)] public struct VkDevQCI { public uint sType; public IntPtr pNext; public uint flags, qfi, qCnt; public IntPtr pPrio; }
[StructLayout(LayoutKind.Sequential)] public struct VkDevCI { public uint sType; public IntPtr pNext; public uint flags, qciCnt; public IntPtr pQCI; public uint lCnt; public IntPtr ppL; public uint eCnt; public IntPtr ppE; public IntPtr pFeat; }
[StructLayout(LayoutKind.Sequential)] public struct VkQFP { public uint qFlags, qCnt, tsVB, gW, gH, gD; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemReq { public ulong size, align; public uint memBits; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemAI { public uint sType; public IntPtr pNext; public ulong size; public uint memIdx; }
[StructLayout(LayoutKind.Sequential)] public struct VkMemType { public uint propFlags, heapIdx; }
[StructLayout(LayoutKind.Sequential, Pack = 4)] public struct VkPhysMemProps { public uint typeCnt; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public byte[] types; public uint heapCnt; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public byte[] heaps; }
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
[StructLayout(LayoutKind.Explicit)]   public struct VkClearVal { [FieldOffset(0)] public VkClearCol color; }
[StructLayout(LayoutKind.Sequential)] public struct VkRPBI { public uint sType; public IntPtr pNext; public ulong rp, fb; public VkRect2D area; public uint cvCnt; public IntPtr pCV; }
[StructLayout(LayoutKind.Sequential)] public struct VkFenceCI { public uint sType; public IntPtr pNext; public uint flags; }
[StructLayout(LayoutKind.Sequential)] public struct VkSubmitInfo { public uint sType; public IntPtr pNext; public uint wsCnt; public IntPtr pWS, pWSM; public uint cbCnt; public IntPtr pCB; public uint ssCnt; public IntPtr pSS; }
[StructLayout(LayoutKind.Sequential)] public struct VkBufImgCopy { public ulong bufOff; public uint bRL, bIH, aspect, mip, baseL, lCnt; public int oX, oY, oZ; public uint eW, eH, eD; }
[StructLayout(LayoutKind.Sequential)] public struct DispatcherQueueOptions { public int dwSize, threadType, apartmentType; }

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
public struct WNDCLASSEX
{
    public uint cbSize, style;
    public WndProcDelegate lpfnWndProc;
    public int cbClsExtra, cbWndExtra;
    public IntPtr hInstance, hIcon, hCursor, hbrBackground;
    public string lpszMenuName, lpszClassName;
    public IntPtr hIconSm;
}
public delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);

// ============================================================
// COM vtable delegate types
// ============================================================
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int QIDelegate(IntPtr thisPtr, ref Guid riid, out IntPtr ppv);

// D3D11 Device
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateBufferDelegate(IntPtr device, ref D3D11_BUFFER_DESC pDesc, ref D3D11_SUBRESOURCE_DATA pInit, out IntPtr ppBuffer);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateRTVDelegate(IntPtr device, IntPtr pResource, IntPtr pDesc, out IntPtr ppRTView);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateInputLayoutDelegate(IntPtr device, [In] D3D11_INPUT_ELEMENT_DESC[] pDescs, uint num, IntPtr pBytecode, IntPtr len, out IntPtr ppLayout);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateVSDelegate(IntPtr device, IntPtr pBytecode, IntPtr len, IntPtr pLinkage, out IntPtr ppVS);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreatePSDelegate(IntPtr device, IntPtr pBytecode, IntPtr len, IntPtr pLinkage, out IntPtr ppPS);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateTexture2DDelegate(IntPtr device, ref D3D11_TEXTURE2D_DESC pDesc, IntPtr pInitData, out IntPtr ppTexture2D);

// D3D11 DeviceContext
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void PSSetShaderDelegate(IntPtr ctx, IntPtr ps, IntPtr[] ci, uint num);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void VSSetShaderDelegate(IntPtr ctx, IntPtr vs, IntPtr[] ci, uint num);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DrawDelegate(IntPtr ctx, uint vertexCount, uint startVertex);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetInputLayoutDelegate(IntPtr ctx, IntPtr layout);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetVertexBuffersDelegate(IntPtr ctx, uint slot, uint num, [In] IntPtr[] vbs, [In] uint[] strides, [In] uint[] offsets);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void IASetPrimitiveTopologyDelegate(IntPtr ctx, uint topology);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void OMSetRenderTargetsDelegate(IntPtr ctx, uint num, [In] IntPtr[] rtvs, IntPtr dsv);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void RSSetViewportsDelegate(IntPtr ctx, uint num, ref D3D11_VIEWPORT vp);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void ClearRTVDelegate(IntPtr ctx, IntPtr rtv, [MarshalAs(UnmanagedType.LPArray, SizeConst = 4)] float[] color);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int MapDelegate(IntPtr ctx, IntPtr res, uint subresource, uint mapType, uint mapFlags, out D3D11_MAPPED_SUBRESOURCE mapped);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void UnmapDelegate(IntPtr ctx, IntPtr res, uint subresource);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void CopyResourceDelegate(IntPtr ctx, IntPtr dst, IntPtr src);

// DXGI
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int GetAdapterDelegate(IntPtr dxgiDevice, out IntPtr ppAdapter);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int GetParentDelegate(IntPtr obj, ref Guid riid, out IntPtr ppParent);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateSCForCompDelegate(IntPtr factory, IntPtr pDevice, ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pRestrict, out IntPtr ppSC);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int GetSCBufferDelegate(IntPtr sc, uint buf, ref Guid riid, out IntPtr ppSurface);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PresentDelegate(IntPtr sc, uint sync, uint flags);

// ID3DBlob
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr BlobGetPtrDelegate(IntPtr blob);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr BlobGetSizeDelegate(IntPtr blob);

// Composition Interop (IUnknown-based)
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateDesktopWindowTargetDelegate(IntPtr interop, IntPtr hwnd, int isTopmost, out IntPtr ppTarget);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateCompSurfaceForSCDelegate(IntPtr interop, IntPtr swapChain, out IntPtr ppSurface);

// WinRT Composition (IInspectable-based)
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateContainerVisualDelegate(IntPtr compositor, out IntPtr ppVisual);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateSpriteVisualDelegate(IntPtr compositor, out IntPtr ppVisual);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int CreateSurfaceBrushWithSurfaceDelegate(IntPtr compositor, IntPtr surface, out IntPtr ppBrush);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PutRootDelegate(IntPtr target, IntPtr visual);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int GetChildrenDelegate(IntPtr container, out IntPtr ppChildren);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int InsertAtTopDelegate(IntPtr collection, IntPtr visual);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PutBrushDelegate(IntPtr sprite, IntPtr brush);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PutSizeDelegate(IntPtr visual, Float2 size);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int PutOffsetDelegate(IntPtr visual, Float3 offset);

// OpenGL extension delegates
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr wglCreateContextAttribsARBDelegate(IntPtr hdc, IntPtr shareContext, int[] attribList);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr wglDXOpenDeviceNVDelegate(IntPtr dxDevice);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate bool wglDXCloseDeviceNVDelegate(IntPtr hDevice);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr wglDXRegisterObjectNVDelegate(IntPtr hDevice, IntPtr dxObject, uint name, uint type, uint access);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate bool wglDXUnregisterObjectNVDelegate(IntPtr hDevice, IntPtr hObject);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate bool wglDXLockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate bool wglDXUnlockObjectsNVDelegate(IntPtr hDevice, int count, IntPtr[] hObjects);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glGenBuffersDelegate(int n, uint[] buffers);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glBindBufferDelegate(uint target, uint buffer);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glBufferDataFloatDelegate(uint target, int size, float[] data, uint usage);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate uint glCreateShaderDelegate(uint shaderType);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glShaderSourceDelegate(uint shader, int count, string[] source, int[] length);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glCompileShaderDelegate(uint shader);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate uint glCreateProgramDelegate();
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glAttachShaderDelegate(uint program, uint shader);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glLinkProgramDelegate(uint program);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glUseProgramDelegate(uint program);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int glGetAttribLocationDelegate(uint program, string name);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glEnableVertexAttribArrayDelegate(uint index);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glVertexAttribPointerDelegate(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glGenVertexArraysDelegate(int n, uint[] arrays);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glBindVertexArrayDelegate(uint array);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glGenFramebuffersDelegate(int n, uint[] framebuffers);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glBindFramebufferDelegate(uint target, uint framebuffer);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glFramebufferRenderbufferDelegate(uint target, uint attachment, uint renderbuffertarget, uint renderbuffer);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glGenRenderbuffersDelegate(int n, uint[] renderbuffers);
[UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void glClipControlDelegate(uint origin, uint depth);

// ============================================================
// Native P/Invoke declarations
// ============================================================
public static class N
{
    // Win32
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern void OutputDebugStringW(string s);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern bool UpdateWindow(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern IntPtr LoadCursor(IntPtr hInst, int lpCursorName);
    [DllImport("user32.dll", EntryPoint = "RegisterClassEx", CharSet = CharSet.Auto, SetLastError = true)] public static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle, int x, int y, int w, int h, IntPtr hParent, IntPtr hMenu, IntPtr hInst, IntPtr lpParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint min, uint max, uint rm);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern bool TranslateMessage([In] ref MSG lpMsg);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr DispatchMessage([In] ref MSG lpMsg);
    [DllImport("user32.dll")] public static extern void PostQuitMessage(int nExitCode);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern IntPtr EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);
    [DllImport("user32.dll")] public static extern bool AdjustWindowRect(ref RECT lpRect, uint dwStyle, bool bMenu);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)] public static extern IntPtr GetModuleHandle(string lpModuleName);

    // WndProc must be in C# to avoid PowerShell runspace issues on native callbacks
    static WndProcDelegate _wndProcDelegate;

    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam)
    {
        if (uMsg == 0x000F) // WM_PAINT
        {
            PAINTSTRUCT ps;
            BeginPaint(hWnd, out ps);
            EndPaint(hWnd, ref ps);
            return IntPtr.Zero;
        }
        if (uMsg == 0x0002) // WM_DESTROY
        {
            OutputDebugStringW("[WndProc] WM_DESTROY received\n");
            PostQuitMessage(0);
            return IntPtr.Zero;
        }
        return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    // Create the application window entirely from C# to keep WndProc alive
    public static IntPtr CreateAppWindow(uint panelWidth, uint panelHeight, int panelCount, string title)
    {
        IntPtr hInstance = GetModuleHandle(null);
        _wndProcDelegate = new WndProcDelegate(WndProc);

        var wc = new WNDCLASSEX
        {
            cbSize        = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)),
            style         = 0x0020, // CS_OWNDC
            lpfnWndProc   = _wndProcDelegate,
            hInstance     = hInstance,
            hCursor       = LoadCursor(IntPtr.Zero, 32512), // IDC_ARROW
            hbrBackground = (IntPtr)(5 + 1), // COLOR_WINDOW + 1
            lpszClassName = "Win32CompTrianglePS",
        };

        ushort atom = RegisterClassEx(ref wc);
        if (atom == 0) return IntPtr.Zero;

        RECT rc = new RECT { Right = (int)(panelWidth * panelCount), Bottom = (int)panelHeight };
        AdjustWindowRect(ref rc, 0x00CF0000, false); // WS_OVERLAPPEDWINDOW

        IntPtr hwnd = CreateWindowEx(0, "Win32CompTrianglePS", title,
            0x00CF0000 | 0x10000000, // WS_OVERLAPPEDWINDOW | WS_VISIBLE
            100, 100, rc.Right - rc.Left, rc.Bottom - rc.Top,
            IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);

        if (hwnd != IntPtr.Zero)
        {
            ShowWindow(hwnd, 1);
            UpdateWindow(hwnd);
        }
        return hwnd;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)] public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr ReleaseDC(IntPtr hWnd, IntPtr hDc);

    // GDI / OpenGL base
    [DllImport("gdi32.dll")] public static extern int ChoosePixelFormat(IntPtr hdc, [In] ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("gdi32.dll")] public static extern bool SetPixelFormat(IntPtr hdc, int format, [In] ref PIXELFORMATDESCRIPTOR pfd);
    [DllImport("opengl32.dll")] public static extern IntPtr wglCreateContext(IntPtr hdc);
    [DllImport("opengl32.dll")] public static extern int wglMakeCurrent(IntPtr hdc, IntPtr hglrc);
    [DllImport("opengl32.dll")] public static extern int wglDeleteContext(IntPtr hglrc);
    [DllImport("opengl32.dll")] public static extern IntPtr wglGetProcAddress(string procName);
    [DllImport("opengl32.dll")] public static extern void glClearColor(float r, float g, float b, float a);
    [DllImport("opengl32.dll")] public static extern void glClear(uint mask);
    [DllImport("opengl32.dll")] public static extern void glViewport(int x, int y, int width, int height);
    [DllImport("opengl32.dll")] public static extern void glDrawArrays(uint mode, int first, int count);
    [DllImport("opengl32.dll")] public static extern void glFlush();

    // D3D11
    [DllImport("d3d11.dll")] public static extern int D3D11CreateDevice(IntPtr pAdapter, int DriverType, IntPtr Software, uint Flags, [In, MarshalAs(UnmanagedType.LPArray)] uint[] pFL, uint numFL, uint SDKVer, out IntPtr ppDev, out IntPtr pFL2, out IntPtr ppCtx);
    [DllImport("d3dcompiler_47.dll", CallingConvention = CallingConvention.StdCall)] public static extern int D3DCompile([MarshalAs(UnmanagedType.LPStr)] string src, IntPtr srcSz, [MarshalAs(UnmanagedType.LPStr)] string name, IntPtr defines, IntPtr include, [MarshalAs(UnmanagedType.LPStr)] string entry, [MarshalAs(UnmanagedType.LPStr)] string target, uint flags1, uint flags2, out IntPtr code, out IntPtr errors);

    // WinRT / CoreMessaging
    [DllImport("CoreMessaging.dll")] public static extern int CreateDispatcherQueueController(ref DispatcherQueueOptions options, out IntPtr controller);
    [DllImport("combase.dll", PreserveSig = true)] public static extern int RoInitialize(int initType);
    [DllImport("combase.dll", PreserveSig = true)] public static extern int RoActivateInstance(IntPtr activatableClassId, out IntPtr instance);
    [DllImport("combase.dll", PreserveSig = true)] public static extern int WindowsCreateString([MarshalAs(UnmanagedType.LPWStr)] string src, uint len, out IntPtr hstring);
    [DllImport("combase.dll", PreserveSig = true)] public static extern int WindowsDeleteString(IntPtr hstring);

    // Vulkan
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
    [DllImport("vulkan-1.dll")] public static extern void vkCmdCopyImageToBuffer(IntPtr cb, ulong img, uint layout, ulong buf, uint n, ref VkBufImgCopy r);
    [DllImport("vulkan-1.dll")] public static extern int vkQueueSubmit(IntPtr q, uint n, ref VkSubmitInfo si, ulong f);
    [DllImport("vulkan-1.dll")] public static extern int vkMapMemory(IntPtr d, ulong m, ulong o, ulong sz, uint f, out IntPtr p);
    [DllImport("vulkan-1.dll")] public static extern void vkUnmapMemory(IntPtr d, ulong m);
    [DllImport("vulkan-1.dll")] public static extern int vkDeviceWaitIdle(IntPtr d);
}

// ============================================================
// Helper class: COM vtable calls, unsafe memory copy, etc.
// ============================================================
public static class H
{
    // Read vtable entry and create delegate
    public static Delegate VT(IntPtr pCom, int index, Type delegateType)
    {
        IntPtr vt = Marshal.ReadIntPtr(pCom);
        IntPtr mp = Marshal.ReadIntPtr(vt, index * IntPtr.Size);
        return Marshal.GetDelegateForFunctionPointer(mp, delegateType);
    }

    // QueryInterface
    public static int QI(IntPtr pUnk, ref Guid iid, out IntPtr ppv)
    {
        IntPtr vt = Marshal.ReadIntPtr(pUnk);
        IntPtr mp = Marshal.ReadIntPtr(vt, 0 * IntPtr.Size);
        var fn = Marshal.GetDelegateForFunctionPointer(mp, typeof(QIDelegate)) as QIDelegate;
        return fn(pUnk, ref iid, out ppv);
    }

    // ID3DBlob::GetBufferPointer (vtable #3)
    public static IntPtr BlobPtr(IntPtr blob)
    {
        IntPtr vt = Marshal.ReadIntPtr(blob);
        IntPtr mp = Marshal.ReadIntPtr(vt, 3 * IntPtr.Size);
        var fn = Marshal.GetDelegateForFunctionPointer(mp, typeof(BlobGetPtrDelegate)) as BlobGetPtrDelegate;
        return fn(blob);
    }

    // ID3DBlob::GetBufferSize (vtable #4)
    public static int BlobSize(IntPtr blob)
    {
        IntPtr vt = Marshal.ReadIntPtr(blob);
        IntPtr mp = Marshal.ReadIntPtr(vt, 4 * IntPtr.Size);
        var fn = Marshal.GetDelegateForFunctionPointer(mp, typeof(BlobGetSizeDelegate)) as BlobGetSizeDelegate;
        return (int)fn(blob);
    }

    // Load OpenGL extension function (non-generic for PowerShell 5.1 compatibility)
    public static Delegate LoadGLDelegate(string name, Type delegateType)
    {
        IntPtr p = N.wglGetProcAddress(name);
        if (p == IntPtr.Zero) throw new Exception("GL symbol not found: " + name);
        return Marshal.GetDelegateForFunctionPointer(p, delegateType);
    }

    // Find Vulkan memory type matching requirements
    public static uint FindMemoryType(VkPhysMemProps p, uint bits, uint req)
    {
        int mtSize = Marshal.SizeOf(typeof(VkMemType));
        for (uint i = 0; i < p.typeCnt; i++)
        {
            if ((bits & (1u << (int)i)) == 0) continue;
            // Read VkMemType from the byte array
            uint propFlags = BitConverter.ToUInt32(p.types, (int)(i * mtSize));
            if ((propFlags & req) == req) return i;
        }
        throw new Exception("No VK memory type");
    }

    // Row-by-row memory copy for Vulkan readback (replaces unsafe Buffer.MemoryCopy)
    public static void CopyRows(IntPtr src, IntPtr dst, int srcPitch, int dstPitch, int width, int height)
    {
        byte[] row = new byte[width];
        for (int y = 0; y < height; y++)
        {
            Marshal.Copy(src + y * srcPitch, row, 0, width);
            Marshal.Copy(row, 0, dst + y * dstPitch, width);
        }
    }
}
'@

Add-Type -TypeDefinition $NativeSource -IgnoreWarnings

# ==============================================================================
# Constants
# ==============================================================================
$WIDTH  = [uint32]320
$HEIGHT = [uint32]480
$PANEL_COUNT = 3

# Win32 constants
$WS_OVERLAPPEDWINDOW = [uint32]0x00CF0000
$WS_VISIBLE          = [uint32]0x10000000
$WM_DESTROY = [uint32]0x0002
$WM_PAINT   = [uint32]0x000F
$WM_QUIT    = [uint32]0x0012
$PM_REMOVE  = [uint32]0x0001
$CS_OWNDC   = [uint32]0x0020
$IDC_ARROW  = 32512
$COLOR_WINDOW = 5

# DXGI / D3D11 constants
$DXGI_FORMAT_R32G32B32_FLOAT    = [uint32]6
$DXGI_FORMAT_R32G32B32A32_FLOAT = [uint32]2
$DXGI_FORMAT_B8G8R8A8_UNORM     = [uint32]87
$DXGI_USAGE_RENDER_TARGET_OUTPUT = [uint32]0x20
$DXGI_SCALING_STRETCH            = [uint32]0
$DXGI_SWAP_EFFECT_FLIP_DISCARD  = [uint32]4
$DXGI_ALPHA_MODE_IGNORE         = [uint32]0

$D3D_DRIVER_TYPE_HARDWARE       = 1
$D3D_FEATURE_LEVEL_11_0         = [uint32]0xb000
$D3D11_SDK_VERSION              = [uint32]7
$D3D11_CREATE_DEVICE_BGRA_SUPPORT = [uint32]0x20
$D3D11_BIND_VERTEX_BUFFER       = [uint32]0x1
$D3D11_USAGE_DEFAULT            = [uint32]0
$D3D11_USAGE_STAGING            = [uint32]3
$D3D11_CPU_ACCESS_WRITE         = [uint32]0x10000
$D3D11_MAP_WRITE                = [uint32]2
$D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = [uint32]4
$D3DCOMPILE_ENABLE_STRICTNESS   = [uint32](1 -shl 11)

# OpenGL constants
$GL_TRIANGLES          = [uint32]0x0004
$GL_FLOAT              = [uint32]0x1406
$GL_COLOR_BUFFER_BIT   = [uint32]0x00004000
$GL_ARRAY_BUFFER       = [uint32]0x8892
$GL_STATIC_DRAW        = [uint32]0x88E4
$GL_FRAGMENT_SHADER    = [uint32]0x8B30
$GL_VERTEX_SHADER      = [uint32]0x8B31
$GL_FRAMEBUFFER        = [uint32]0x8D40
$GL_RENDERBUFFER       = [uint32]0x8D41
$GL_COLOR_ATTACHMENT0  = [uint32]0x8CE0
$GL_LOWER_LEFT         = [uint32]0x8CA1
$GL_NEGATIVE_ONE_TO_ONE= [uint32]0x935E
$WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
$WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
$WGL_CONTEXT_PROFILE_MASK_ARB  = 0x9126
$WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
$WGL_ACCESS_READ_WRITE_NV      = [uint32]0x0001

$PFD_TYPE_RGBA       = 0
$PFD_DOUBLEBUFFER    = 1
$PFD_DRAW_TO_WINDOW  = 4
$PFD_SUPPORT_OPENGL  = 32

# GUIDs
$IID_IDXGIDevice     = [Guid]"54ec77fa-1377-44e6-8c32-88fd5f44c84c"
$IID_IDXGIFactory2   = [Guid]"50c83a1c-e072-4c48-87b0-3630fa36a6d0"
$IID_ID3D11Texture2D = [Guid]"6f15aaf2-d208-4e89-9ab4-489535d34f9c"
$IID_ICompositorDesktopInterop = [Guid]"29E691FA-4567-4DCA-B319-D0F207EB6807"
$IID_ICompositorInterop        = [Guid]"25297D5C-3AD4-4C9C-B5CF-E36A38512330"
$IID_ICompositor         = [Guid]"B403CA50-7F8C-4E83-985F-CC45060036D8"
$IID_ICompositionTarget  = [Guid]"A1BEA8BA-D726-4663-8129-6B5E7927FFA6"
$IID_IContainerVisual    = [Guid]"02F6BC74-ED20-4773-AFE6-D49B4A93DB32"
$IID_IVisualCollection   = [Guid]"8B745505-FD3E-4A98-84A8-E949468C6BCB"
$IID_ISpriteVisual       = [Guid]"08E05581-1AD1-4F97-9757-402D76E4233B"
$IID_IVisual             = [Guid]"117E202D-A859-4C89-873B-C2AA566788E3"
$IID_ICompositionBrush   = [Guid]"AB0D7608-30C0-40E9-B568-B60A6BD1FB46"

# HLSL shaders (embedded)
$VS_HLSL = @"
struct VSInput  { float3 pos : POSITION; float4 col : COLOR; };
struct VSOutput { float4 pos : SV_POSITION; float4 col : COLOR; };
VSOutput main(VSInput i) {
    VSOutput o;
    o.pos = float4(i.pos, 1);
    o.col = i.col;
    return o;
}
"@

$PS_HLSL = @"
struct PSInput { float4 pos : SV_POSITION; float4 col : COLOR; };
float4 main(PSInput i) : SV_TARGET { return i.col; }
"@

# GLSL shaders (embedded)
$VS_GLSL = @"
#version 460 core
in vec3 position;
in vec3 color;
out vec4 vColor;
void main() {
    gl_Position = vec4(position.x, -position.y, position.z, 1.0);
    vColor = vec4(color, 1.0);
}
"@

$FS_GLSL = @"
#version 460 core
in vec4 vColor;
out vec4 outColor;
void main() {
    outColor = vColor;
}
"@

# ==============================================================================
# Global state (equivalent to C# static fields)
# ==============================================================================
$script:g_hwnd             = [IntPtr]::Zero
$script:g_compositor       = [IntPtr]::Zero
$script:g_compositorUnk    = [IntPtr]::Zero
$script:g_desktopTarget    = [IntPtr]::Zero
$script:g_compTarget       = [IntPtr]::Zero
$script:g_rootContainer    = [IntPtr]::Zero
$script:g_rootVisual       = [IntPtr]::Zero
$script:g_children         = [IntPtr]::Zero
$script:g_dqController     = [IntPtr]::Zero
$script:g_spriteRaw        = @([IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$script:g_spriteVisual     = @([IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
$script:g_brush            = @([IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)

# OpenGL interop state
$script:g_hDC              = [IntPtr]::Zero
$script:g_hGLRC            = [IntPtr]::Zero
$script:g_dxInteropDevice  = [IntPtr]::Zero
$script:g_dxInteropObject  = [IntPtr]::Zero
$script:g_fbo              = [uint32]0
$script:g_rbo              = [uint32]0
$script:g_vbo              = [uint32[]]@(0, 0)
$script:g_program          = [uint32]0
$script:g_posAttrib        = 0
$script:g_colAttrib        = 0

# GL extension function delegates
$script:glGenBuffers       = $null
$script:glBindBuffer       = $null
$script:glBufferData       = $null
$script:glCreateShader     = $null
$script:glShaderSource     = $null
$script:glCompileShader    = $null
$script:glCreateProgram    = $null
$script:glAttachShader     = $null
$script:glLinkProgram      = $null
$script:glUseProgram       = $null
$script:glGetAttribLocation= $null
$script:glEnableVertexAttribArray = $null
$script:glVertexAttribPointer = $null
$script:glGenVertexArrays  = $null
$script:glBindVertexArray  = $null
$script:glGenFramebuffers  = $null
$script:glBindFramebuffer  = $null
$script:glFramebufferRenderbuffer = $null
$script:glGenRenderbuffers = $null
$script:glClipControl      = $null
$script:wglDXOpenDeviceNV  = $null
$script:wglDXCloseDeviceNV = $null
$script:wglDXRegisterObjectNV   = $null
$script:wglDXUnregisterObjectNV = $null
$script:wglDXLockObjectsNV      = $null
$script:wglDXUnlockObjectsNV    = $null

# Vulkan state
$script:g_vkPhysicalDevice = [IntPtr]::Zero
$script:g_vkDevice         = [IntPtr]::Zero
$script:g_vkQueue          = [IntPtr]::Zero
$script:g_vkCommandPool    = [IntPtr]::Zero
$script:g_vkCommandBuffer  = [IntPtr]::Zero
$script:g_vkImage          = [uint64]0
$script:g_vkImageView      = [uint64]0
$script:g_vkImageMemory    = [uint64]0
$script:g_vkReadbackBuffer = [uint64]0
$script:g_vkReadbackMemory = [uint64]0
$script:g_vkRenderPass     = [uint64]0
$script:g_vkFramebuffer    = [uint64]0
$script:g_vkPipelineLayout = [uint64]0
$script:g_vkPipeline       = [uint64]0
$script:g_vkFence          = [uint64]0
$script:g_vkQueueFamily    = -1
$script:g_stagingTexture   = [IntPtr]::Zero
$script:g_swapChainBackBuffer = [IntPtr]::Zero
$script:g_firstRender      = $true

# ==============================================================================
# Debug logging
# ==============================================================================
function dbg([string]$fn, [string]$msg) {
    [N]::OutputDebugStringW("[$fn] $msg`n")
}

function dbgHR([string]$fn, [string]$api, [int]$hr) {
    [N]::OutputDebugStringW("[$fn] $api failed hr=0x$($hr.ToString('X8'))`n")
}

# WndProc is implemented in C# (class N) to avoid PowerShell runspace issues on native callbacks

# ==============================================================================
# CreateAppWindow (delegated to C# to keep WndProc GC-rooted)
# ==============================================================================
function CreateAppWindow {
    dbg "CreateAppWindow" "begin (via C#)"
    $hwnd = [N]::CreateAppWindow($WIDTH, $HEIGHT, $PANEL_COUNT,
        "OpenGL + D3D11 + Vulkan via Windows.UI.Composition (PowerShell)")
    if ($hwnd -eq [IntPtr]::Zero) {
        dbg "CreateAppWindow" "FAILED"
    } else {
        dbg "CreateAppWindow" "ok"
    }
    return $hwnd
}

# ==============================================================================
# InitD3D11 - Create device, swap chain, shaders, vertex buffer
# ==============================================================================
function InitD3D11 {
    $FN = "InitD3D11"
    dbg $FN "begin"
    $result = @{
        device = [IntPtr]::Zero; context = [IntPtr]::Zero; swapChain = [IntPtr]::Zero
        rtv = [IntPtr]::Zero; vs = [IntPtr]::Zero; ps = [IntPtr]::Zero
        inputLayout = [IntPtr]::Zero; vertexBuffer = [IntPtr]::Zero; hr = 0
    }

    # 1) D3D11CreateDevice
    $dev = [IntPtr]::Zero; $ctx = [IntPtr]::Zero; $flOut = [IntPtr]::Zero
    $fls = [uint32[]]@($D3D_FEATURE_LEVEL_11_0)
    $hr = [N]::D3D11CreateDevice([IntPtr]::Zero, $D3D_DRIVER_TYPE_HARDWARE, [IntPtr]::Zero,
        $D3D11_CREATE_DEVICE_BGRA_SUPPORT, $fls, [uint32]1, $D3D11_SDK_VERSION,
        [ref]$dev, [ref]$flOut, [ref]$ctx)
    if ($hr -lt 0) { dbgHR $FN "D3D11CreateDevice" $hr; $result.hr = $hr; return $result }
    $result.device = $dev; $result.context = $ctx

    # 2) QI -> IDXGIDevice
    $dxgiDev = [IntPtr]::Zero
    $hr = [H]::QI($dev, [ref]$IID_IDXGIDevice, [ref]$dxgiDev)
    if ($hr -lt 0) { dbgHR $FN "QI(IDXGIDevice)" $hr; $result.hr = $hr; return $result }

    # 3) GetAdapter (vt#7)
    $adapter = [IntPtr]::Zero
    $fn3 = [H]::VT($dxgiDev, 7, [GetAdapterDelegate])
    $hr = $fn3.Invoke($dxgiDev, [ref]$adapter)
    if ($hr -lt 0) { dbgHR $FN "GetAdapter" $hr; $result.hr = $hr; return $result }

    # 4) GetParent -> IDXGIFactory2 (vt#6)
    $factory = [IntPtr]::Zero
    $fn4 = [H]::VT($adapter, 6, [GetParentDelegate])
    $hr = $fn4.Invoke($adapter, [ref]$IID_IDXGIFactory2, [ref]$factory)
    [System.Runtime.InteropServices.Marshal]::Release($adapter) | Out-Null
    if ($hr -lt 0) { dbgHR $FN "GetParent" $hr; $result.hr = $hr; return $result }

    # 5) CreateSwapChainForComposition (vt#24)
    $scDesc = New-Object DXGI_SWAP_CHAIN_DESC1
    $scDesc.Width = $WIDTH; $scDesc.Height = $HEIGHT
    $scDesc.Format = $DXGI_FORMAT_B8G8R8A8_UNORM
    # NOTE: Must create nested struct separately then assign (PowerShell value-type copy semantics)
    $sd = New-Object DXGI_SAMPLE_DESC; $sd.Count = 1; $sd.Quality = 0
    $scDesc.SampleDesc = $sd
    $scDesc.BufferUsage = $DXGI_USAGE_RENDER_TARGET_OUTPUT
    $scDesc.BufferCount = 2
    $scDesc.Scaling = $DXGI_SCALING_STRETCH
    $scDesc.SwapEffect = $DXGI_SWAP_EFFECT_FLIP_DISCARD
    $scDesc.AlphaMode = $DXGI_ALPHA_MODE_IGNORE

    $sc = [IntPtr]::Zero
    $fn5 = [H]::VT($factory, 24, [CreateSCForCompDelegate])
    $hr = $fn5.Invoke($factory, $dev, [ref]$scDesc, [IntPtr]::Zero, [ref]$sc)
    [System.Runtime.InteropServices.Marshal]::Release($factory) | Out-Null
    [System.Runtime.InteropServices.Marshal]::Release($dxgiDev) | Out-Null
    if ($hr -lt 0) { dbgHR $FN "CreateSwapChainForComposition" $hr; $result.hr = $hr; return $result }
    $result.swapChain = $sc

    # 6) GetBuffer(0) (vt#9 on SwapChain)
    $backBuf = [IntPtr]::Zero
    $fn6 = [H]::VT($sc, 9, [GetSCBufferDelegate])
    $hr = $fn6.Invoke($sc, [uint32]0, [ref]$IID_ID3D11Texture2D, [ref]$backBuf)
    if ($hr -lt 0) { dbgHR $FN "GetBuffer" $hr; $result.hr = $hr; return $result }

    # 7) CreateRenderTargetView (vt#9 on Device)
    $rtvOut = [IntPtr]::Zero
    $fn7 = [H]::VT($dev, 9, [CreateRTVDelegate])
    $hr = $fn7.Invoke($dev, $backBuf, [IntPtr]::Zero, [ref]$rtvOut)
    [System.Runtime.InteropServices.Marshal]::Release($backBuf) | Out-Null
    if ($hr -lt 0) { dbgHR $FN "CreateRTV" $hr; $result.hr = $hr; return $result }
    $result.rtv = $rtvOut

    # 8) Compile HLSL shaders
    $vsBlob = [IntPtr]::Zero; $psBlob = [IntPtr]::Zero; $errBlob = [IntPtr]::Zero
    $hr = [N]::D3DCompile($VS_HLSL, [IntPtr]$VS_HLSL.Length, $null, [IntPtr]::Zero, [IntPtr]::Zero,
        "main", "vs_4_0", $D3DCOMPILE_ENABLE_STRICTNESS, 0, [ref]$vsBlob, [ref]$errBlob)
    if ($errBlob -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($errBlob) | Out-Null }
    if ($hr -lt 0) { dbgHR $FN "D3DCompile(VS)" $hr; $result.hr = $hr; return $result }

    $errBlob = [IntPtr]::Zero
    $hr = [N]::D3DCompile($PS_HLSL, [IntPtr]$PS_HLSL.Length, $null, [IntPtr]::Zero, [IntPtr]::Zero,
        "main", "ps_4_0", $D3DCOMPILE_ENABLE_STRICTNESS, 0, [ref]$psBlob, [ref]$errBlob)
    if ($errBlob -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($errBlob) | Out-Null }
    if ($hr -lt 0) { dbgHR $FN "D3DCompile(PS)" $hr; $result.hr = $hr; return $result }

    # 9) CreateVertexShader (vt#12)
    $vsOut = [IntPtr]::Zero
    $fn9 = [H]::VT($dev, 12, [CreateVSDelegate])
    $hr = $fn9.Invoke($dev, [H]::BlobPtr($vsBlob), [IntPtr][H]::BlobSize($vsBlob), [IntPtr]::Zero, [ref]$vsOut)
    if ($hr -lt 0) { dbgHR $FN "CreateVertexShader" $hr; $result.hr = $hr; return $result }
    $result.vs = $vsOut

    # 10) CreatePixelShader (vt#15)
    $psOut = [IntPtr]::Zero
    $fn10 = [H]::VT($dev, 15, [CreatePSDelegate])
    $hr = $fn10.Invoke($dev, [H]::BlobPtr($psBlob), [IntPtr][H]::BlobSize($psBlob), [IntPtr]::Zero, [ref]$psOut)
    if ($hr -lt 0) { dbgHR $FN "CreatePixelShader" $hr; $result.hr = $hr; return $result }
    $result.ps = $psOut

    # 11) CreateInputLayout (vt#11)
    $elems = @(
        (New-Object D3D11_INPUT_ELEMENT_DESC -Property @{ SemanticName="POSITION"; Format=$DXGI_FORMAT_R32G32B32_FLOAT;    AlignedByteOffset=0  }),
        (New-Object D3D11_INPUT_ELEMENT_DESC -Property @{ SemanticName="COLOR";    Format=$DXGI_FORMAT_R32G32B32A32_FLOAT; AlignedByteOffset=12 })
    )
    $ilOut = [IntPtr]::Zero
    $fn11 = [H]::VT($dev, 11, [CreateInputLayoutDelegate])
    $hr = $fn11.Invoke($dev, $elems, [uint32]$elems.Length, [H]::BlobPtr($vsBlob), [IntPtr][H]::BlobSize($vsBlob), [ref]$ilOut)
    [System.Runtime.InteropServices.Marshal]::Release($vsBlob) | Out-Null
    [System.Runtime.InteropServices.Marshal]::Release($psBlob) | Out-Null
    if ($hr -lt 0) { dbgHR $FN "CreateInputLayout" $hr; $result.hr = $hr; return $result }
    $result.inputLayout = $ilOut

    # 12) CreateBuffer (vt#3) - vertex buffer
    $verts = [Vertex[]]@(
        (New-Object Vertex -Property @{ X= 0.0; Y= 0.5; Z=0.5; R=1;G=0;B=0;A=1 }),
        (New-Object Vertex -Property @{ X= 0.5; Y=-0.5; Z=0.5; R=0;G=1;B=0;A=1 }),
        (New-Object Vertex -Property @{ X=-0.5; Y=-0.5; Z=0.5; R=0;G=0;B=1;A=1 })
    )
    $vertSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][Vertex])
    $bd = New-Object D3D11_BUFFER_DESC
    $bd.ByteWidth = [uint32]($vertSize * $verts.Length)
    $bd.Usage = $D3D11_USAGE_DEFAULT
    $bd.BindFlags = $D3D11_BIND_VERTEX_BUFFER

    $pin = [System.Runtime.InteropServices.GCHandle]::Alloc($verts, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    try {
        $sd = New-Object D3D11_SUBRESOURCE_DATA
        $sd.pSysMem = $pin.AddrOfPinnedObject()
        $vbOut = [IntPtr]::Zero
        $fn12 = [H]::VT($dev, 3, [CreateBufferDelegate])
        $hr = $fn12.Invoke($dev, [ref]$bd, [ref]$sd, [ref]$vbOut)
    } finally { $pin.Free() }
    if ($hr -lt 0) { dbgHR $FN "CreateBuffer" $hr; $result.hr = $hr; return $result }
    $result.vertexBuffer = $vbOut

    dbg $FN "ok (all 12 steps completed)"
    return $result
}

# ==============================================================================
# CreateSwapChainForComposition (additional swap chains for GL / VK panels)
# ==============================================================================
function CreateSwapChainForComposition([IntPtr]$device) {
    $dxgiDev = [IntPtr]::Zero
    $hr = [H]::QI($device, [ref]$IID_IDXGIDevice, [ref]$dxgiDev)
    if ($hr -lt 0) { return @{ hr=$hr; swapChain=[IntPtr]::Zero } }

    $adapter = [IntPtr]::Zero
    $fn = [H]::VT($dxgiDev, 7, [GetAdapterDelegate])
    $hr = $fn.Invoke($dxgiDev, [ref]$adapter)
    if ($hr -lt 0) { [System.Runtime.InteropServices.Marshal]::Release($dxgiDev) | Out-Null; return @{ hr=$hr; swapChain=[IntPtr]::Zero } }

    $factory = [IntPtr]::Zero
    $fn2 = [H]::VT($adapter, 6, [GetParentDelegate])
    $hr = $fn2.Invoke($adapter, [ref]$IID_IDXGIFactory2, [ref]$factory)
    [System.Runtime.InteropServices.Marshal]::Release($adapter) | Out-Null
    if ($hr -lt 0) { [System.Runtime.InteropServices.Marshal]::Release($dxgiDev) | Out-Null; return @{ hr=$hr; swapChain=[IntPtr]::Zero } }

    $scDesc = New-Object DXGI_SWAP_CHAIN_DESC1
    $scDesc.Width = $WIDTH; $scDesc.Height = $HEIGHT
    $scDesc.Format = $DXGI_FORMAT_B8G8R8A8_UNORM
    $sd2 = New-Object DXGI_SAMPLE_DESC; $sd2.Count = 1; $sd2.Quality = 0
    $scDesc.SampleDesc = $sd2
    $scDesc.BufferUsage = $DXGI_USAGE_RENDER_TARGET_OUTPUT
    $scDesc.BufferCount = 2
    $scDesc.Scaling = $DXGI_SCALING_STRETCH
    $scDesc.SwapEffect = $DXGI_SWAP_EFFECT_FLIP_DISCARD
    $scDesc.AlphaMode = $DXGI_ALPHA_MODE_IGNORE

    $sc = [IntPtr]::Zero
    $fn3 = [H]::VT($factory, 24, [CreateSCForCompDelegate])
    $hr = $fn3.Invoke($factory, $device, [ref]$scDesc, [IntPtr]::Zero, [ref]$sc)
    [System.Runtime.InteropServices.Marshal]::Release($factory) | Out-Null
    [System.Runtime.InteropServices.Marshal]::Release($dxgiDev) | Out-Null
    return @{ hr=$hr; swapChain=$sc }
}

# ==============================================================================
# InitComposition - set up Windows.UI.Composition visual tree
# ==============================================================================
function AddCompositionPanel([IntPtr]$swapChain, [float]$offsetX, [int]$index) {
    $LogTag = "AddPanel[$index]"
    $compInterop = [IntPtr]::Zero
    dbg $LogTag "begin swapChain=0x$($swapChain.ToString('X')) offsetX=$offsetX"
    $hr = [H]::QI($script:g_compositorUnk, [ref]$IID_ICompositorInterop, [ref]$compInterop)
    dbg $LogTag "QI(ICompositorInterop) hr=0x$($hr.ToString('X8')) interop=0x$($compInterop.ToString('X'))"
    if ($hr -lt 0) { return $hr }

    $surface = [IntPtr]::Zero
    dbg $LogTag "before VT(compInterop,4)=CreateCompSurfaceForSCDelegate"
    $vtCreateCompSurface = [H]::VT($compInterop, 4, [CreateCompSurfaceForSCDelegate])
    dbg $LogTag "before CreateCompSurfaceForSwapChain invoke"
    $hr = $vtCreateCompSurface.Invoke($compInterop, $swapChain, [ref]$surface)
    [System.Runtime.InteropServices.Marshal]::Release($compInterop) | Out-Null
    dbg $LogTag "CreateCompSurface hr=0x$($hr.ToString('X8')) surface=0x$($surface.ToString('X'))"
    if ($hr -lt 0) { return $hr }

    $surfBrush = [IntPtr]::Zero
    dbg $LogTag "before VT(compositor,24)=CreateSurfaceBrushWithSurfaceDelegate"
    $vtCreateSurfaceBrush = [H]::VT($script:g_compositor, 24, [CreateSurfaceBrushWithSurfaceDelegate])
    dbg $LogTag "before CreateSurfaceBrushWithSurface invoke"
    $hr = $vtCreateSurfaceBrush.Invoke($script:g_compositor, $surface, [ref]$surfBrush)
    [System.Runtime.InteropServices.Marshal]::Release($surface) | Out-Null
    dbg $LogTag "CreateSurfaceBrush hr=0x$($hr.ToString('X8')) surfBrush=0x$($surfBrush.ToString('X'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "before QI(ICompositionBrush)"
    $tmpBrush = [IntPtr]::Zero
    $hr = [H]::QI($surfBrush, [ref]$IID_ICompositionBrush, [ref]$tmpBrush)
    [System.Runtime.InteropServices.Marshal]::Release($surfBrush) | Out-Null
    if ($hr -ge 0) { $script:g_brush[$index] = $tmpBrush }
    dbg $LogTag "QI(ICompositionBrush) hr=0x$($hr.ToString('X8')) brush=0x$($script:g_brush[$index].ToString('X'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "before VT(compositor,22)=CreateSpriteVisualDelegate"
    $vtCreateSprite = [H]::VT($script:g_compositor, 22, [CreateSpriteVisualDelegate])
    dbg $LogTag "before CreateSpriteVisual invoke"
    $tmpSpriteRaw = [IntPtr]::Zero
    $hr = $vtCreateSprite.Invoke($script:g_compositor, [ref]$tmpSpriteRaw)
    if ($hr -ge 0) { $script:g_spriteRaw[$index] = $tmpSpriteRaw }
    dbg $LogTag "CreateSpriteVisual hr=0x$($hr.ToString('X8')) spriteRaw=0x$($script:g_spriteRaw[$index].ToString('X'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "before VT(spriteRaw,7)=PutBrushDelegate"
    $vtPutBrush = [H]::VT($script:g_spriteRaw[$index], 7, [PutBrushDelegate])
    dbg $LogTag "before PutBrush invoke"
    $hr = $vtPutBrush.Invoke($script:g_spriteRaw[$index], $script:g_brush[$index])
    dbg $LogTag "PutBrush hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "before QI(IVisual from sprite)"
    $tmpSpriteVisual = [IntPtr]::Zero
    $hr = [H]::QI($script:g_spriteRaw[$index], [ref]$IID_IVisual, [ref]$tmpSpriteVisual)
    if ($hr -ge 0) { $script:g_spriteVisual[$index] = $tmpSpriteVisual }
    dbg $LogTag "QI(IVisual) hr=0x$($hr.ToString('X8')) spriteVisual=0x$($script:g_spriteVisual[$index].ToString('X'))"
    if ($hr -lt 0) { return $hr }

    $size = New-Object Float2; $size.X = $WIDTH; $size.Y = $HEIGHT
    dbg $LogTag "before VT(spriteVisual,36)=PutSizeDelegate size=($($size.X),$($size.Y))"
    $vtPutSize = [H]::VT($script:g_spriteVisual[$index], 36, [PutSizeDelegate])
    dbg $LogTag "before PutSize invoke"
    $hr = $vtPutSize.Invoke($script:g_spriteVisual[$index], $size)
    dbg $LogTag "PutSize hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $offset = New-Object Float3; $offset.X = $offsetX; $offset.Y = 0.0; $offset.Z = 0.0
    dbg $LogTag "before VT(spriteVisual,21)=PutOffsetDelegate offset=($($offset.X),$($offset.Y),$($offset.Z))"
    $vtPutOffset = [H]::VT($script:g_spriteVisual[$index], 21, [PutOffsetDelegate])
    dbg $LogTag "before PutOffset invoke"
    $hr = $vtPutOffset.Invoke($script:g_spriteVisual[$index], $offset)
    dbg $LogTag "PutOffset hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "before VT(children,9)=InsertAtTopDelegate"
    $vtInsertAtTop = [H]::VT($script:g_children, 9, [InsertAtTopDelegate])
    dbg $LogTag "before InsertAtTop invoke"
    $hr = $vtInsertAtTop.Invoke($script:g_children, $script:g_spriteVisual[$index])
    dbg $LogTag "InsertAtTop hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    dbg $LogTag "ok"
    return 0
}

function InitComposition([IntPtr]$hwnd, [IntPtr]$glSwapChain, [IntPtr]$d3dSwapChain, [IntPtr]$vkSwapChain) {
    $FN = "InitComposition"
    dbg $FN "begin"

    $hr = [N]::RoInitialize(0)
    dbg $FN "RoInitialize hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0 -and $hr -ne 1) { return $hr }

    $dqOpt = New-Object DispatcherQueueOptions
    $dqOpt.dwSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type][DispatcherQueueOptions])
    $dqOpt.threadType = 2
    $dqOpt.apartmentType = 0
    $hr = [N]::CreateDispatcherQueueController([ref]$dqOpt, [ref]$script:g_dqController)
    dbg $FN "CreateDispatcherQueueController hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    # RoActivateInstance("Windows.UI.Composition.Compositor")
    $className = "Windows.UI.Composition.Compositor"
    $hstr = [IntPtr]::Zero
    $hr = [N]::WindowsCreateString($className, [uint32]$className.Length, [ref]$hstr)
    dbg $FN "WindowsCreateString hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }
    $hr = [N]::RoActivateInstance($hstr, [ref]$script:g_compositorUnk)
    [N]::WindowsDeleteString($hstr) | Out-Null
    dbg $FN "RoActivateInstance hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $hr = [H]::QI($script:g_compositorUnk, [ref]$IID_ICompositor, [ref]$script:g_compositor)
    dbg $FN "QI(ICompositor) hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    # ICompositorDesktopInterop::CreateDesktopWindowTarget
    $deskInterop = [IntPtr]::Zero
    $hr = [H]::QI($script:g_compositorUnk, [ref]$IID_ICompositorDesktopInterop, [ref]$deskInterop)
    dbg $FN "QI(ICompositorDesktopInterop) hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }
    $fn = [H]::VT($deskInterop, 3, [CreateDesktopWindowTargetDelegate])
    $hr = $fn.Invoke($deskInterop, $hwnd, 0, [ref]$script:g_desktopTarget)
    [System.Runtime.InteropServices.Marshal]::Release($deskInterop) | Out-Null
    dbg $FN "CreateDesktopWindowTarget hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $hr = [H]::QI($script:g_desktopTarget, [ref]$IID_ICompositionTarget, [ref]$script:g_compTarget)
    dbg $FN "QI(ICompositionTarget) hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    # Create container visual and set as root
    $fn2 = [H]::VT($script:g_compositor, 9, [CreateContainerVisualDelegate])
    $hr = $fn2.Invoke($script:g_compositor, [ref]$script:g_rootContainer)
    dbg $FN "CreateContainerVisual hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $hr = [H]::QI($script:g_rootContainer, [ref]$IID_IVisual, [ref]$script:g_rootVisual)
    dbg $FN "QI(IVisual for root) hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $fn3 = [H]::VT($script:g_compTarget, 7, [PutRootDelegate])
    $hr = $fn3.Invoke($script:g_compTarget, $script:g_rootVisual)
    dbg $FN "PutRoot hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    $fn4 = [H]::VT($script:g_rootContainer, 6, [GetChildrenDelegate])
    $hr = $fn4.Invoke($script:g_rootContainer, [ref]$script:g_children)
    dbg $FN "GetChildren hr=0x$($hr.ToString('X8'))"
    if ($hr -lt 0) { return $hr }

    # Add three panels: OpenGL, D3D11, Vulkan
    $hr = AddCompositionPanel $glSwapChain 0.0 0
    dbg $FN "AddCompositionPanel(GL) hr=$hr"
    if ($hr -lt 0) { return $hr }
    $hr = AddCompositionPanel $d3dSwapChain ([float]$WIDTH) 1
    dbg $FN "AddCompositionPanel(D3D) hr=$hr"
    if ($hr -lt 0) { return $hr }
    $hr = AddCompositionPanel $vkSwapChain ([float]($WIDTH * 2)) 2
    dbg $FN "AddCompositionPanel(VK) hr=$hr"
    if ($hr -lt 0) { return $hr }

    dbg $FN "ok"
    return 0
}

# ==============================================================================
# CreateStagingTexture - for Vulkan readback to D3D11
# ==============================================================================
function CreateStagingTexture([IntPtr]$device) {
    $desc = New-Object D3D11_TEXTURE2D_DESC
    $desc.Width = $WIDTH; $desc.Height = $HEIGHT
    $desc.MipLevels = 1; $desc.ArraySize = 1
    $desc.Format = $DXGI_FORMAT_B8G8R8A8_UNORM
    $sd3 = New-Object DXGI_SAMPLE_DESC; $sd3.Count = 1; $sd3.Quality = 0
    $desc.SampleDesc = $sd3
    $desc.Usage = $D3D11_USAGE_STAGING
    $desc.CPUAccessFlags = $D3D11_CPU_ACCESS_WRITE

    $tex = [IntPtr]::Zero
    $fn = [H]::VT($device, 5, [CreateTexture2DDelegate])
    $hr = $fn.Invoke($device, [ref]$desc, [IntPtr]::Zero, [ref]$tex)
    if ($hr -lt 0) { throw "CreateTexture2D failed hr=0x$($hr.ToString('X8'))" }
    return $tex
}

# ==============================================================================
# InitOpenGLInterop - set up WGL context and DX-GL interop
# ==============================================================================
function InitOpenGLInterop([IntPtr]$hwnd, [IntPtr]$device, [IntPtr]$swapChain) {
    $FN = "InitOpenGLInterop"
    dbg $FN "begin"

    $script:g_hDC = [N]::GetDC($hwnd)
    if ($script:g_hDC -eq [IntPtr]::Zero) { return -1 }

    $pfd = New-Object PIXELFORMATDESCRIPTOR
    $pfd.nSize = [uint16][System.Runtime.InteropServices.Marshal]::SizeOf([type][PIXELFORMATDESCRIPTOR])
    $pfd.nVersion = 1
    $pfd.dwFlags = $PFD_SUPPORT_OPENGL -bor $PFD_DRAW_TO_WINDOW -bor $PFD_DOUBLEBUFFER
    $pfd.iPixelType = [byte]$PFD_TYPE_RGBA
    $pfd.cColorBits = 32; $pfd.cAlphaBits = 8; $pfd.cDepthBits = 24

    $format = [N]::ChoosePixelFormat($script:g_hDC, [ref]$pfd)
    if ($format -eq 0) { return -1 }
    if (-not [N]::SetPixelFormat($script:g_hDC, $format, [ref]$pfd)) { return -1 }

    # Create legacy GL context, then upgrade to 4.6 core
    $tmp = [N]::wglCreateContext($script:g_hDC)
    if ($tmp -eq [IntPtr]::Zero) { return -1 }
    [N]::wglMakeCurrent($script:g_hDC, $tmp) | Out-Null

    $createCtx = [H]::LoadGLDelegate("wglCreateContextAttribsARB", [wglCreateContextAttribsARBDelegate])
    $attrs = [int[]]@(
        $WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        $WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        $WGL_CONTEXT_PROFILE_MASK_ARB, $WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0
    )
    $script:g_hGLRC = $createCtx.Invoke($script:g_hDC, [IntPtr]::Zero, $attrs)
    if ($script:g_hGLRC -eq [IntPtr]::Zero) { return -1 }

    [N]::wglMakeCurrent($script:g_hDC, $script:g_hGLRC) | Out-Null
    [N]::wglDeleteContext($tmp) | Out-Null

    # Load all required GL extension functions
    $script:glGenBuffers       = [H]::LoadGLDelegate("glGenBuffers", [glGenBuffersDelegate])
    $script:glBindBuffer       = [H]::LoadGLDelegate("glBindBuffer", [glBindBufferDelegate])
    $script:glBufferData       = [H]::LoadGLDelegate("glBufferData", [glBufferDataFloatDelegate])
    $script:glCreateShader     = [H]::LoadGLDelegate("glCreateShader", [glCreateShaderDelegate])
    $script:glShaderSource     = [H]::LoadGLDelegate("glShaderSource", [glShaderSourceDelegate])
    $script:glCompileShader    = [H]::LoadGLDelegate("glCompileShader", [glCompileShaderDelegate])
    $script:glCreateProgram    = [H]::LoadGLDelegate("glCreateProgram", [glCreateProgramDelegate])
    $script:glAttachShader     = [H]::LoadGLDelegate("glAttachShader", [glAttachShaderDelegate])
    $script:glLinkProgram      = [H]::LoadGLDelegate("glLinkProgram", [glLinkProgramDelegate])
    $script:glUseProgram       = [H]::LoadGLDelegate("glUseProgram", [glUseProgramDelegate])
    $script:glGetAttribLocation= [H]::LoadGLDelegate("glGetAttribLocation", [glGetAttribLocationDelegate])
    $script:glEnableVertexAttribArray = [H]::LoadGLDelegate("glEnableVertexAttribArray", [glEnableVertexAttribArrayDelegate])
    $script:glVertexAttribPointer = [H]::LoadGLDelegate("glVertexAttribPointer", [glVertexAttribPointerDelegate])
    $script:glGenVertexArrays  = [H]::LoadGLDelegate("glGenVertexArrays", [glGenVertexArraysDelegate])
    $script:glBindVertexArray  = [H]::LoadGLDelegate("glBindVertexArray", [glBindVertexArrayDelegate])
    $script:glGenFramebuffers  = [H]::LoadGLDelegate("glGenFramebuffers", [glGenFramebuffersDelegate])
    $script:glBindFramebuffer  = [H]::LoadGLDelegate("glBindFramebuffer", [glBindFramebufferDelegate])
    $script:glFramebufferRenderbuffer = [H]::LoadGLDelegate("glFramebufferRenderbuffer", [glFramebufferRenderbufferDelegate])
    $script:glGenRenderbuffers = [H]::LoadGLDelegate("glGenRenderbuffers", [glGenRenderbuffersDelegate])
    $script:glClipControl      = [H]::LoadGLDelegate("glClipControl", [glClipControlDelegate])

    $script:wglDXOpenDeviceNV  = [H]::LoadGLDelegate("wglDXOpenDeviceNV", [wglDXOpenDeviceNVDelegate])
    $script:wglDXCloseDeviceNV = [H]::LoadGLDelegate("wglDXCloseDeviceNV", [wglDXCloseDeviceNVDelegate])
    $script:wglDXRegisterObjectNV   = [H]::LoadGLDelegate("wglDXRegisterObjectNV", [wglDXRegisterObjectNVDelegate])
    $script:wglDXUnregisterObjectNV = [H]::LoadGLDelegate("wglDXUnregisterObjectNV", [wglDXUnregisterObjectNVDelegate])
    $script:wglDXLockObjectsNV      = [H]::LoadGLDelegate("wglDXLockObjectsNV", [wglDXLockObjectsNVDelegate])
    $script:wglDXUnlockObjectsNV    = [H]::LoadGLDelegate("wglDXUnlockObjectsNV", [wglDXUnlockObjectsNVDelegate])

    $script:glClipControl.Invoke($GL_LOWER_LEFT, $GL_NEGATIVE_ONE_TO_ONE)

    # Set up DX-GL interop via NV_DX_interop
    $script:g_dxInteropDevice = $script:wglDXOpenDeviceNV.Invoke($device)
    if ($script:g_dxInteropDevice -eq [IntPtr]::Zero) { return -1 }

    $backBuffer = [IntPtr]::Zero
    $fnBuf = [H]::VT($swapChain, 9, [GetSCBufferDelegate])
    $hr = $fnBuf.Invoke($swapChain, [uint32]0, [ref]$IID_ID3D11Texture2D, [ref]$backBuffer)
    if ($hr -lt 0) { return $hr }

    $rbo = [uint32[]]@(0)
    $script:glGenRenderbuffers.Invoke(1, $rbo)
    $script:g_rbo = $rbo[0]
    $script:g_dxInteropObject = $script:wglDXRegisterObjectNV.Invoke(
        $script:g_dxInteropDevice, $backBuffer, $script:g_rbo, $GL_RENDERBUFFER, $WGL_ACCESS_READ_WRITE_NV)
    [System.Runtime.InteropServices.Marshal]::Release($backBuffer) | Out-Null
    if ($script:g_dxInteropObject -eq [IntPtr]::Zero) { return -1 }

    $fbo = [uint32[]]@(0)
    $script:glGenFramebuffers.Invoke(1, $fbo)
    $script:g_fbo = $fbo[0]
    $script:glBindFramebuffer.Invoke($GL_FRAMEBUFFER, $script:g_fbo)
    $script:glFramebufferRenderbuffer.Invoke($GL_FRAMEBUFFER, $GL_COLOR_ATTACHMENT0, $GL_RENDERBUFFER, $script:g_rbo)
    $script:glBindFramebuffer.Invoke($GL_FRAMEBUFFER, [uint32]0)

    # Create VAO, VBOs, compile shaders
    $vao = [uint32[]]@(0)
    $script:glGenVertexArrays.Invoke(1, $vao)
    $script:glBindVertexArray.Invoke($vao[0])

    $script:glGenBuffers.Invoke(2, $script:g_vbo)
    $vertices = [float[]]@(-0.5, -0.5, 0.0,  0.5, -0.5, 0.0,  0.0, 0.5, 0.0)
    $colors   = [float[]]@( 0.0,  0.0, 1.0,  0.0,  1.0, 0.0,  1.0, 0.0, 0.0)

    $script:glBindBuffer.Invoke($GL_ARRAY_BUFFER, $script:g_vbo[0])
    $script:glBufferData.Invoke($GL_ARRAY_BUFFER, $vertices.Length * 4, $vertices, $GL_STATIC_DRAW)
    $script:glBindBuffer.Invoke($GL_ARRAY_BUFFER, $script:g_vbo[1])
    $script:glBufferData.Invoke($GL_ARRAY_BUFFER, $colors.Length * 4, $colors, $GL_STATIC_DRAW)

    $glvs = $script:glCreateShader.Invoke($GL_VERTEX_SHADER)
    $script:glShaderSource.Invoke($glvs, 1, [string[]]@($VS_GLSL), $null)
    $script:glCompileShader.Invoke($glvs)
    $glfs = $script:glCreateShader.Invoke($GL_FRAGMENT_SHADER)
    $script:glShaderSource.Invoke($glfs, 1, [string[]]@($FS_GLSL), $null)
    $script:glCompileShader.Invoke($glfs)

    $script:g_program = $script:glCreateProgram.Invoke()
    $script:glAttachShader.Invoke($script:g_program, $glvs)
    $script:glAttachShader.Invoke($script:g_program, $glfs)
    $script:glLinkProgram.Invoke($script:g_program)
    $script:glUseProgram.Invoke($script:g_program)

    $script:g_posAttrib = $script:glGetAttribLocation.Invoke($script:g_program, "position")
    $script:g_colAttrib = $script:glGetAttribLocation.Invoke($script:g_program, "color")
    $script:glEnableVertexAttribArray.Invoke([uint32]$script:g_posAttrib)
    $script:glEnableVertexAttribArray.Invoke([uint32]$script:g_colAttrib)

    dbg $FN "ok"
    return 0
}

# ==============================================================================
# InitVulkan - create Vulkan device, pipeline, framebuffer, command pool
# ==============================================================================
function InitVulkan([IntPtr]$device, [IntPtr]$swapChain) {
    $FN = "InitVulkan"
    dbg $FN "begin"

    # Create Vulkan instance
    $appName = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi("vk14")
    $ai = New-Object VkAppInfo; $ai.sType = 0; $ai.pAppName = $appName; $ai.apiVer = (1 -shl 22) -bor (4 -shl 12)
    $hAI = [System.Runtime.InteropServices.GCHandle]::Alloc($ai, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $ici = New-Object VkInstCI; $ici.sType = 1; $ici.pAppInfo = $hAI.AddrOfPinnedObject()
    $vkInstance = [IntPtr]::Zero
    if ([N]::vkCreateInstance([ref]$ici, [IntPtr]::Zero, [ref]$vkInstance) -ne 0) { throw "vkCreateInstance failed" }
    $hAI.Free()
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($appName)

    # Enumerate physical devices
    [uint32]$count = 0
    [N]::vkEnumeratePhysicalDevices($vkInstance, [ref]$count, $null) | Out-Null
    $devs = New-Object IntPtr[] $count
    [N]::vkEnumeratePhysicalDevices($vkInstance, [ref]$count, $devs) | Out-Null
    $script:g_vkPhysicalDevice = $devs[0]

    # Find graphics queue family
    [uint32]$qc = 0
    [N]::vkGetPhysicalDeviceQueueFamilyProperties($script:g_vkPhysicalDevice, [ref]$qc, $null)
    $qps = New-Object VkQFP[] $qc
    [N]::vkGetPhysicalDeviceQueueFamilyProperties($script:g_vkPhysicalDevice, [ref]$qc, $qps)
    for ($i = 0; $i -lt $qc; $i++) {
        if (($qps[$i].qFlags -band 1) -ne 0) { $script:g_vkQueueFamily = $i; break }
    }
    if ($script:g_vkQueueFamily -lt 0) { throw "No graphics queue" }

    # Create logical device
    $hP = [System.Runtime.InteropServices.GCHandle]::Alloc([float[]]@(1.0), [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $qci = New-Object VkDevQCI; $qci.sType = 2; $qci.qfi = [uint32]$script:g_vkQueueFamily; $qci.qCnt = 1; $qci.pPrio = $hP.AddrOfPinnedObject()
    $hQ = [System.Runtime.InteropServices.GCHandle]::Alloc($qci, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $dci = New-Object VkDevCI; $dci.sType = 3; $dci.qciCnt = 1; $dci.pQCI = $hQ.AddrOfPinnedObject()
    if ([N]::vkCreateDevice($script:g_vkPhysicalDevice, [ref]$dci, [IntPtr]::Zero, [ref]$script:g_vkDevice) -ne 0) { throw "vkCreateDevice failed" }
    $hQ.Free(); $hP.Free()
    [N]::vkGetDeviceQueue($script:g_vkDevice, [uint32]$script:g_vkQueueFamily, 0, [ref]$script:g_vkQueue)

    $memProps = New-Object VkPhysMemProps
    [N]::vkGetPhysicalDeviceMemoryProperties($script:g_vkPhysicalDevice, [ref]$memProps)

    # Create Vulkan image (R8G8B8A8 format = 44)
    $ic = New-Object VkImgCI; $ic.sType = 14; $ic.imgType = 1; $ic.fmt = 44
    $ic.eW = $WIDTH; $ic.eH = $HEIGHT; $ic.eD = 1; $ic.mip = 1; $ic.arr = 1; $ic.samples = 1; $ic.usage = 0x11
    if ([N]::vkCreateImage($script:g_vkDevice, [ref]$ic, [IntPtr]::Zero, [ref]$script:g_vkImage) -ne 0) { throw "vkCreateImage failed" }
    $ir = New-Object VkMemReq
    [N]::vkGetImageMemoryRequirements($script:g_vkDevice, $script:g_vkImage, [ref]$ir)
    $ia = New-Object VkMemAI; $ia.sType = 5; $ia.size = $ir.size; $ia.memIdx = [H]::FindMemoryType($memProps, $ir.memBits, 1)
    if ([N]::vkAllocateMemory($script:g_vkDevice, [ref]$ia, [IntPtr]::Zero, [ref]$script:g_vkImageMemory) -ne 0) { throw "vkAllocateMemory(image) failed" }
    [N]::vkBindImageMemory($script:g_vkDevice, $script:g_vkImage, $script:g_vkImageMemory, [uint64]0) | Out-Null

    $ivc = New-Object VkImgViewCI; $ivc.sType = 15; $ivc.img = $script:g_vkImage; $ivc.viewType = 1; $ivc.fmt = 44
    $ivc.aspect = 1; $ivc.lvlCnt = 1; $ivc.layerCnt = 1
    if ([N]::vkCreateImageView($script:g_vkDevice, [ref]$ivc, [IntPtr]::Zero, [ref]$script:g_vkImageView) -ne 0) { throw "vkCreateImageView failed" }

    # Create readback buffer
    [uint64]$readSize = [uint64]($WIDTH * $HEIGHT * 4)
    $bc = New-Object VkBufCI; $bc.sType = 12; $bc.size = $readSize; $bc.usage = 2
    if ([N]::vkCreateBuffer($script:g_vkDevice, [ref]$bc, [IntPtr]::Zero, [ref]$script:g_vkReadbackBuffer) -ne 0) { throw "vkCreateBuffer failed" }
    $br = New-Object VkMemReq
    [N]::vkGetBufferMemoryRequirements($script:g_vkDevice, $script:g_vkReadbackBuffer, [ref]$br)
    $ba = New-Object VkMemAI; $ba.sType = 5; $ba.size = $br.size; $ba.memIdx = [H]::FindMemoryType($memProps, $br.memBits, 6)
    if ([N]::vkAllocateMemory($script:g_vkDevice, [ref]$ba, [IntPtr]::Zero, [ref]$script:g_vkReadbackMemory) -ne 0) { throw "vkAllocateMemory(buffer) failed" }
    [N]::vkBindBufferMemory($script:g_vkDevice, $script:g_vkReadbackBuffer, $script:g_vkReadbackMemory, [uint64]0) | Out-Null

    # Create render pass
    $att = New-Object VkAttDesc; $att.fmt = 44; $att.samples = 1; $att.loadOp = 1; $att.storeOp = 0; $att.stLoadOp = 2; $att.stStoreOp = 1; $att.finalLayout = 6
    $ar = New-Object VkAttRef; $ar.att = 0; $ar.layout = 2
    $hA = [System.Runtime.InteropServices.GCHandle]::Alloc($att, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hR = [System.Runtime.InteropServices.GCHandle]::Alloc($ar, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $sub = New-Object VkSubDesc; $sub.caCnt = 1; $sub.pCA = $hR.AddrOfPinnedObject()
    $hS = [System.Runtime.InteropServices.GCHandle]::Alloc($sub, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $rpc = New-Object VkRPCI; $rpc.sType = 38; $rpc.attCnt = 1; $rpc.pAtts = $hA.AddrOfPinnedObject(); $rpc.subCnt = 1; $rpc.pSubs = $hS.AddrOfPinnedObject()
    if ([N]::vkCreateRenderPass($script:g_vkDevice, [ref]$rpc, [IntPtr]::Zero, [ref]$script:g_vkRenderPass) -ne 0) { throw "vkCreateRenderPass failed" }
    $hA.Free(); $hR.Free(); $hS.Free()

    # Create framebuffer
    $hV = [System.Runtime.InteropServices.GCHandle]::Alloc([uint64[]]@($script:g_vkImageView), [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $fbc = New-Object VkFBCI; $fbc.sType = 37; $fbc.rp = $script:g_vkRenderPass; $fbc.attCnt = 1; $fbc.pAtts = $hV.AddrOfPinnedObject()
    $fbc.w = $WIDTH; $fbc.h = $HEIGHT; $fbc.layers = 1
    if ([N]::vkCreateFramebuffer($script:g_vkDevice, [ref]$fbc, [IntPtr]::Zero, [ref]$script:g_vkFramebuffer) -ne 0) { throw "vkCreateFramebuffer failed" }
    $hV.Free()

    # Compile SPIR-V shaders via shaderc
    $vsSpv = [SC]::Compile([IO.File]::ReadAllText("hello.vert"), 0, "hello.vert")
    $fsSpv = [SC]::Compile([IO.File]::ReadAllText("hello.frag"), 1, "hello.frag")

    # Create shader modules
    [uint64]$vsm = 0; [uint64]$fsm = 0
    $hVS = [System.Runtime.InteropServices.GCHandle]::Alloc($vsSpv, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $smv = New-Object VkSMCI; $smv.sType = 16; $smv.codeSz = (New-Object UIntPtr([uint64]$vsSpv.Length)); $smv.pCode = $hVS.AddrOfPinnedObject()
    if ([N]::vkCreateShaderModule($script:g_vkDevice, [ref]$smv, [IntPtr]::Zero, [ref]$vsm) -ne 0) { throw "vkCreateShaderModule(vs) failed" }
    $hVS.Free()

    $hFS = [System.Runtime.InteropServices.GCHandle]::Alloc($fsSpv, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $smf = New-Object VkSMCI; $smf.sType = 16; $smf.codeSz = (New-Object UIntPtr([uint64]$fsSpv.Length)); $smf.pCode = $hFS.AddrOfPinnedObject()
    if ([N]::vkCreateShaderModule($script:g_vkDevice, [ref]$smf, [IntPtr]::Zero, [ref]$fsm) -ne 0) { throw "vkCreateShaderModule(fs) failed" }
    $hFS.Free()

    # Create graphics pipeline
    $mainName = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi("main")
    $stg = [VkPSSCI[]]@(
        (New-Object VkPSSCI -Property @{ sType=18; stage=1;    module=$vsm; pName=$mainName }),
        (New-Object VkPSSCI -Property @{ sType=18; stage=0x10; module=$fsm; pName=$mainName })
    )
    $hStg = [System.Runtime.InteropServices.GCHandle]::Alloc($stg, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $vi = New-Object VkPVICI; $vi.sType = 19
    $ia2 = New-Object VkPIACI; $ia2.sType = 20; $ia2.topo = 3
    $vp = New-Object VkViewport; $vp.w = $WIDTH; $vp.h = $HEIGHT; $vp.maxD = 1
    $scExt = New-Object VkExt2D; $scExt.w = $WIDTH; $scExt.h = $HEIGHT
    $scRect = New-Object VkRect2D; $scRect.ext = $scExt
    $hVP = [System.Runtime.InteropServices.GCHandle]::Alloc($vp, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hSC = [System.Runtime.InteropServices.GCHandle]::Alloc($scRect, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $vps = New-Object VkPVPCI; $vps.sType = 22; $vps.vpCnt = 1; $vps.pVP = $hVP.AddrOfPinnedObject(); $vps.scCnt = 1; $vps.pSC = $hSC.AddrOfPinnedObject()
    $rs = New-Object VkPRCI; $rs.sType = 23; $rs.lineW = 1.0
    $ms = New-Object VkPMSCI; $ms.sType = 24; $ms.rSamples = 1
    $cba = New-Object VkPCBAS; $cba.wMask = 0xF
    $hCBA = [System.Runtime.InteropServices.GCHandle]::Alloc($cba, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $cbs = New-Object VkPCBCI; $cbs.sType = 26; $cbs.attCnt = 1; $cbs.pAtts = $hCBA.AddrOfPinnedObject()
    $hVI = [System.Runtime.InteropServices.GCHandle]::Alloc($vi, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hIA = [System.Runtime.InteropServices.GCHandle]::Alloc($ia2, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hVPS = [System.Runtime.InteropServices.GCHandle]::Alloc($vps, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hRS = [System.Runtime.InteropServices.GCHandle]::Alloc($rs, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hMS = [System.Runtime.InteropServices.GCHandle]::Alloc($ms, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $hCB = [System.Runtime.InteropServices.GCHandle]::Alloc($cbs, [System.Runtime.InteropServices.GCHandleType]::Pinned)

    $plc = New-Object VkPLCI; $plc.sType = 30
    [N]::vkCreatePipelineLayout($script:g_vkDevice, [ref]$plc, [IntPtr]::Zero, [ref]$script:g_vkPipelineLayout) | Out-Null

    $gpc = New-Object VkGPCI
    $gpc.sType = 28; $gpc.stageCnt = 2
    $gpc.pStages = $hStg.AddrOfPinnedObject()
    $gpc.pVIS = $hVI.AddrOfPinnedObject()
    $gpc.pIAS = $hIA.AddrOfPinnedObject()
    $gpc.pVPS = $hVPS.AddrOfPinnedObject()
    $gpc.pRast = $hRS.AddrOfPinnedObject()
    $gpc.pMS = $hMS.AddrOfPinnedObject()
    $gpc.pCBS = $hCB.AddrOfPinnedObject()
    $gpc.layout = $script:g_vkPipelineLayout
    $gpc.rp = $script:g_vkRenderPass
    if ([N]::vkCreateGraphicsPipelines($script:g_vkDevice, [uint64]0, 1, [ref]$gpc, [IntPtr]::Zero, [ref]$script:g_vkPipeline) -ne 0) {
        throw "vkCreateGraphicsPipelines failed"
    }

    $hStg.Free(); $hVI.Free(); $hIA.Free(); $hVPS.Free(); $hRS.Free(); $hMS.Free(); $hCB.Free(); $hCBA.Free(); $hVP.Free(); $hSC.Free()
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($mainName)
    [N]::vkDestroyShaderModule($script:g_vkDevice, $vsm, [IntPtr]::Zero)
    [N]::vkDestroyShaderModule($script:g_vkDevice, $fsm, [IntPtr]::Zero)

    # Create command pool, command buffer, fence
    $cpc = New-Object VkCPCI; $cpc.sType = 39; $cpc.flags = 2; $cpc.qfi = [uint32]$script:g_vkQueueFamily
    if ([N]::vkCreateCommandPool($script:g_vkDevice, [ref]$cpc, [IntPtr]::Zero, [ref]$script:g_vkCommandPool) -ne 0) { throw "vkCreateCommandPool failed" }
    $cbi = New-Object VkCBAI; $cbi.sType = 40; $cbi.pool = $script:g_vkCommandPool; $cbi.cnt = 1
    if ([N]::vkAllocateCommandBuffers($script:g_vkDevice, [ref]$cbi, [ref]$script:g_vkCommandBuffer) -ne 0) { throw "vkAllocateCommandBuffers failed" }
    $fc = New-Object VkFenceCI; $fc.sType = 8; $fc.flags = 1
    if ([N]::vkCreateFence($script:g_vkDevice, [ref]$fc, [IntPtr]::Zero, [ref]$script:g_vkFence) -ne 0) { throw "vkCreateFence failed" }

    # Create staging texture and get swap chain back buffer for VK->D3D copy
    $script:g_stagingTexture = CreateStagingTexture $device
    $fnBuf = [H]::VT($swapChain, 9, [GetSCBufferDelegate])
    $hr = $fnBuf.Invoke($swapChain, [uint32]0, [ref]$IID_ID3D11Texture2D, [ref]$script:g_swapChainBackBuffer)
    if ($hr -lt 0) { throw "GetBuffer failed hr=0x$($hr.ToString('X8'))" }

    dbg $FN "ok"
}

# ==============================================================================
# RenderOpenGL - render GL triangle via DX-GL interop
# ==============================================================================
function RenderOpenGL([IntPtr]$swapChain) {
    [N]::wglMakeCurrent($script:g_hDC, $script:g_hGLRC) | Out-Null
    $objs = [IntPtr[]]@($script:g_dxInteropObject)
    if (-not $script:wglDXLockObjectsNV.Invoke($script:g_dxInteropDevice, 1, $objs)) { return }
    try {
        $script:glBindFramebuffer.Invoke($GL_FRAMEBUFFER, $script:g_fbo)
        [N]::glViewport(0, 0, [int]$WIDTH, [int]$HEIGHT)
        [N]::glClearColor(0.05, 0.05, 0.15, 1.0)
        [N]::glClear($GL_COLOR_BUFFER_BIT)
        $script:glUseProgram.Invoke($script:g_program)
        $script:glBindBuffer.Invoke($GL_ARRAY_BUFFER, $script:g_vbo[0])
        $script:glVertexAttribPointer.Invoke([uint32]$script:g_posAttrib, 3, $GL_FLOAT, $false, 0, [IntPtr]::Zero)
        $script:glBindBuffer.Invoke($GL_ARRAY_BUFFER, $script:g_vbo[1])
        $script:glVertexAttribPointer.Invoke([uint32]$script:g_colAttrib, 3, $GL_FLOAT, $false, 0, [IntPtr]::Zero)
        [N]::glDrawArrays($GL_TRIANGLES, 0, 3)
        [N]::glFlush()
        $script:glBindFramebuffer.Invoke($GL_FRAMEBUFFER, [uint32]0)
    } finally {
        $script:wglDXUnlockObjectsNV.Invoke($script:g_dxInteropDevice, 1, $objs) | Out-Null
    }
    $fnPresent = [H]::VT($swapChain, 8, [PresentDelegate])
    $fnPresent.Invoke($swapChain, [uint32]1, [uint32]0) | Out-Null
}

# ==============================================================================
# RenderD3D11 - render D3D11 triangle
# ==============================================================================
function RenderD3D11([IntPtr]$ctx, [IntPtr]$rtv, [IntPtr]$vs, [IntPtr]$ps, [IntPtr]$layout, [IntPtr]$vb, [IntPtr]$sc) {
    try {
        $vp = New-Object D3D11_VIEWPORT
        $vp.Width = $WIDTH; $vp.Height = $HEIGHT; $vp.MaxDepth = 1
        ([RSSetViewportsDelegate]([H]::VT($ctx, 44, [RSSetViewportsDelegate]))).Invoke($ctx, [uint32]1, [ref]$vp)
        ([OMSetRenderTargetsDelegate]([H]::VT($ctx, 33, [OMSetRenderTargetsDelegate]))).Invoke($ctx, [uint32]1, [IntPtr[]]@($rtv), [IntPtr]::Zero)
        ([ClearRTVDelegate]([H]::VT($ctx, 50, [ClearRTVDelegate]))).Invoke($ctx, $rtv, [float[]]@(0.05, 0.15, 0.05, 1.0))
        ([IASetInputLayoutDelegate]([H]::VT($ctx, 17, [IASetInputLayoutDelegate]))).Invoke($ctx, $layout)

        $stride = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][Vertex])
        ([IASetVertexBuffersDelegate]([H]::VT($ctx, 18, [IASetVertexBuffersDelegate]))).Invoke($ctx, [uint32]0, [uint32]1, [IntPtr[]]@($vb), [uint32[]]@($stride), [uint32[]]@(0))
        ([IASetPrimitiveTopologyDelegate]([H]::VT($ctx, 24, [IASetPrimitiveTopologyDelegate]))).Invoke($ctx, $D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
        ([VSSetShaderDelegate]([H]::VT($ctx, 11, [VSSetShaderDelegate]))).Invoke($ctx, $vs, $null, [uint32]0)
        ([PSSetShaderDelegate]([H]::VT($ctx, 9, [PSSetShaderDelegate]))).Invoke($ctx, $ps, $null, [uint32]0)
        ([DrawDelegate]([H]::VT($ctx, 13, [DrawDelegate]))).Invoke($ctx, [uint32]3, [uint32]0)

        $hr = ([PresentDelegate]([H]::VT($sc, 8, [PresentDelegate]))).Invoke($sc, [uint32]1, [uint32]0)

        if ($script:g_firstRender) {
            dbg "Render" "first frame Present hr=0x$($hr.ToString('X8'))"
            $script:g_firstRender = $false
        }
    } catch {
        dbg "Render" "EXCEPTION: $_"
    }
}

# ==============================================================================
# RenderVulkan - render VK triangle, readback to staging texture, copy to SC
# ==============================================================================
function RenderVulkan([IntPtr]$context, [IntPtr]$swapChain) {
    $f = [uint64[]]@($script:g_vkFence)
    [N]::vkWaitForFences($script:g_vkDevice, 1, $f, 1, [uint64]::MaxValue) | Out-Null
    [N]::vkResetFences($script:g_vkDevice, 1, $f) | Out-Null
    [N]::vkResetCommandBuffer($script:g_vkCommandBuffer, 0) | Out-Null

    $bi = New-Object VkCBBI; $bi.sType = 42
    [N]::vkBeginCommandBuffer($script:g_vkCommandBuffer, [ref]$bi) | Out-Null

    $cc = New-Object VkClearCol; $cc.r = 0.15; $cc.g = 0.05; $cc.b = 0.05; $cc.a = 1.0
    $cv = New-Object VkClearVal; $cv.color = $cc
    $hCV = [System.Runtime.InteropServices.GCHandle]::Alloc($cv, [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $rpbi = New-Object VkRPBI
    $rpbi.sType = 43; $rpbi.rp = $script:g_vkRenderPass; $rpbi.fb = $script:g_vkFramebuffer
    $aExt = New-Object VkExt2D; $aExt.w = $WIDTH; $aExt.h = $HEIGHT
    $aRect = New-Object VkRect2D; $aRect.ext = $aExt
    $rpbi.area = $aRect
    $rpbi.cvCnt = 1; $rpbi.pCV = $hCV.AddrOfPinnedObject()
    [N]::vkCmdBeginRenderPass($script:g_vkCommandBuffer, [ref]$rpbi, 0)
    [N]::vkCmdBindPipeline($script:g_vkCommandBuffer, 0, $script:g_vkPipeline)
    [N]::vkCmdDraw($script:g_vkCommandBuffer, 3, 1, 0, 0)
    [N]::vkCmdEndRenderPass($script:g_vkCommandBuffer)
    $hCV.Free()

    # Copy image to readback buffer
    $rg = New-Object VkBufImgCopy; $rg.bRL = $WIDTH; $rg.bIH = $HEIGHT; $rg.aspect = 1; $rg.lCnt = 1
    $rg.eW = $WIDTH; $rg.eH = $HEIGHT; $rg.eD = 1
    [N]::vkCmdCopyImageToBuffer($script:g_vkCommandBuffer, $script:g_vkImage, [uint32]6, $script:g_vkReadbackBuffer, 1, [ref]$rg)
    [N]::vkEndCommandBuffer($script:g_vkCommandBuffer) | Out-Null

    $hC = [System.Runtime.InteropServices.GCHandle]::Alloc([IntPtr[]]@($script:g_vkCommandBuffer), [System.Runtime.InteropServices.GCHandleType]::Pinned)
    $si = New-Object VkSubmitInfo; $si.sType = 4; $si.cbCnt = 1; $si.pCB = $hC.AddrOfPinnedObject()
    [N]::vkQueueSubmit($script:g_vkQueue, 1, [ref]$si, $script:g_vkFence) | Out-Null
    $hC.Free()

    # Wait for GPU, map Vulkan buffer, copy to D3D11 staging texture
    [N]::vkWaitForFences($script:g_vkDevice, 1, $f, 1, [uint64]::MaxValue) | Out-Null
    $src = [IntPtr]::Zero
    [N]::vkMapMemory($script:g_vkDevice, $script:g_vkReadbackMemory, [uint64]0, [uint64]($WIDTH * $HEIGHT * 4), 0, [ref]$src) | Out-Null

    # Map D3D11 staging texture for writing
    $map = New-Object D3D11_MAPPED_SUBRESOURCE
    $fnMap = [H]::VT($context, 14, [MapDelegate])
    $hr = $fnMap.Invoke($context, $script:g_stagingTexture, [uint32]0, $D3D11_MAP_WRITE, [uint32]0, [ref]$map)
    if ($hr -ge 0) {
        $pitch = [int]($WIDTH * 4)
        [H]::CopyRows($src, $map.pData, $pitch, [int]$map.RowPitch, $pitch, [int]$HEIGHT)

        $fnUnmap = [H]::VT($context, 15, [UnmapDelegate])
        $fnUnmap.Invoke($context, $script:g_stagingTexture, [uint32]0)
    }
    [N]::vkUnmapMemory($script:g_vkDevice, $script:g_vkReadbackMemory)

    # Copy staging texture to swap chain back buffer
    $fnCopy = [H]::VT($context, 47, [CopyResourceDelegate])
    $fnCopy.Invoke($context, $script:g_swapChainBackBuffer, $script:g_stagingTexture)

    $fnPresent = [H]::VT($swapChain, 8, [PresentDelegate])
    $fnPresent.Invoke($swapChain, [uint32]1, [uint32]0) | Out-Null
}

# ==============================================================================
# Cleanup - release all COM objects and resources
# ==============================================================================
function Cleanup($device, $context, $d3dSwapChain, $glSwapChain, $vkSwapChain, $rtv, $vs, $ps, $inputLayout, $vertexBuffer) {
    $FN = "Cleanup"
    dbg $FN "begin"

    if ($script:g_dxInteropObject -ne [IntPtr]::Zero -and $script:g_dxInteropDevice -ne [IntPtr]::Zero) {
        $script:wglDXUnregisterObjectNV.Invoke($script:g_dxInteropDevice, $script:g_dxInteropObject) | Out-Null
    }
    if ($script:g_dxInteropDevice -ne [IntPtr]::Zero) {
        $script:wglDXCloseDeviceNV.Invoke($script:g_dxInteropDevice) | Out-Null
    }
    [N]::wglMakeCurrent([IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    if ($script:g_hGLRC -ne [IntPtr]::Zero) { [N]::wglDeleteContext($script:g_hGLRC) | Out-Null }
    if ($script:g_hDC -ne [IntPtr]::Zero) { [N]::ReleaseDC($script:g_hwnd, $script:g_hDC) | Out-Null }

    # Release Composition objects
    $toRelease = @($script:g_children)
    for ($i = 0; $i -lt $PANEL_COUNT; $i++) {
        $toRelease += $script:g_spriteVisual[$i]
        $toRelease += $script:g_spriteRaw[$i]
        $toRelease += $script:g_brush[$i]
    }
    $toRelease += @($script:g_rootVisual, $script:g_rootContainer, $script:g_compTarget,
                     $script:g_desktopTarget, $script:g_compositor, $script:g_compositorUnk, $script:g_dqController)

    foreach ($ptr in $toRelease) {
        if ($ptr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($ptr) | Out-Null }
    }

    # Release D3D11 / DXGI objects
    $d3dObjs = @($vertexBuffer, $inputLayout, $ps, $vs, $rtv, $d3dSwapChain, $glSwapChain, $vkSwapChain, $context)
    if ($script:g_swapChainBackBuffer -ne [IntPtr]::Zero) { $d3dObjs += $script:g_swapChainBackBuffer }
    if ($script:g_stagingTexture -ne [IntPtr]::Zero) { $d3dObjs += $script:g_stagingTexture }
    foreach ($ptr in $d3dObjs) {
        if ($ptr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($ptr) | Out-Null }
    }

    if ($script:g_vkDevice -ne [IntPtr]::Zero) { [N]::vkDeviceWaitIdle($script:g_vkDevice) | Out-Null }
    if ($device -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::Release($device) | Out-Null }

    dbg $FN "ok"
}

# ==============================================================================
# Main Entry Point
# ==============================================================================
dbg "Main" "========================================"
dbg "Main" "OpenGL 4.6 + D3D11 + Vulkan 1.4 via Composition (PowerShell vtable)"
dbg "Main" "========================================"

# Create application window
$script:g_hwnd = CreateAppWindow
if ($script:g_hwnd -eq [IntPtr]::Zero) {
    dbg "Main" "FATAL: CreateAppWindow failed"
    exit 1
}

# Initialize D3D11
$d3d = InitD3D11
if ($d3d.hr -lt 0) {
    dbg "Main" "FATAL: InitD3D11 failed"
    Cleanup $d3d.device $d3d.context $d3d.swapChain ([IntPtr]::Zero) ([IntPtr]::Zero) $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer
    exit 1
}

# Create additional swap chains for OpenGL and Vulkan panels
$glSC = CreateSwapChainForComposition $d3d.device
if ($glSC.hr -lt 0) {
    dbg "Main" "FATAL: CreateSwapChainForComposition(gl) failed"
    exit 1
}
$vkSC = CreateSwapChainForComposition $d3d.device
if ($vkSC.hr -lt 0) {
    dbg "Main" "FATAL: CreateSwapChainForComposition(vk) failed"
    exit 1
}

# Initialize OpenGL interop
$hr = InitOpenGLInterop $script:g_hwnd $d3d.device $glSC.swapChain
if ($hr -lt 0) {
    dbg "Main" "FATAL: InitOpenGLInterop failed"
    Cleanup $d3d.device $d3d.context $d3d.swapChain $glSC.swapChain $vkSC.swapChain $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer
    exit 1
}

# Initialize Vulkan
try {
    InitVulkan $d3d.device $vkSC.swapChain
} catch {
    dbg "Main" "FATAL: InitVulkan failed: $_"
    Cleanup $d3d.device $d3d.context $d3d.swapChain $glSC.swapChain $vkSC.swapChain $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer
    exit 1
}

# Initialize Windows.UI.Composition visual tree
$hr = InitComposition $script:g_hwnd $glSC.swapChain $d3d.swapChain $vkSC.swapChain
if ($hr -lt 0) {
    dbg "Main" "FATAL: InitComposition failed"
    Cleanup $d3d.device $d3d.context $d3d.swapChain $glSC.swapChain $vkSC.swapChain $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer
    exit 1
}

# Message loop
dbg "Main" "entering message loop"
$msg = New-Object MSG
$loopCount = 0
while ($msg.message -ne $WM_QUIT) {
    if ([N]::PeekMessage([ref]$msg, [IntPtr]::Zero, 0, 0, $PM_REMOVE)) {
        [N]::TranslateMessage([ref]$msg) | Out-Null
        [N]::DispatchMessage([ref]$msg) | Out-Null
    } else {
        try {
            RenderOpenGL $glSC.swapChain
        } catch {
            if ($loopCount -eq 0) { dbg "Main" "RenderOpenGL EXCEPTION: $_" }
        }
        try {
            RenderD3D11 $d3d.context $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer $d3d.swapChain
        } catch {
            if ($loopCount -eq 0) { dbg "Main" "RenderD3D11 EXCEPTION: $_" }
        }
        try {
            RenderVulkan $d3d.context $vkSC.swapChain
        } catch {
            if ($loopCount -eq 0) { dbg "Main" "RenderVulkan EXCEPTION: $_" }
        }
        if ($loopCount -eq 0) { dbg "Main" "first render loop iteration completed" }
        $loopCount++
    }
}

# Cleanup
dbg "Main" "message loop ended"
Cleanup $d3d.device $d3d.context $d3d.swapChain $glSC.swapChain $vkSC.swapChain $d3d.rtv $d3d.vs $d3d.ps $d3d.inputLayout $d3d.vertexBuffer
dbg "Main" "exit"
