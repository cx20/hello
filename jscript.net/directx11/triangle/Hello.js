import System;
import System.Collections.Generic;
import System.CodeDom.Compiler;
import Microsoft.CSharp;
import System.Reflection;

function Main() {
    Console.WriteLine("Compiling embedded C# DirectX11 code...");

    var provider = new CSharpCodeProvider();
    var parameters = new CompilerParameters();
    
    parameters.GenerateInMemory = true;
    parameters.GenerateExecutable = false;
    parameters.CompilerOptions = "/unsafe"; 
    
    parameters.ReferencedAssemblies.Add("System.dll");
    parameters.ReferencedAssemblies.Add("System.Drawing.dll");
    parameters.ReferencedAssemblies.Add("System.Windows.Forms.dll");

    var results = provider.CompileAssemblyFromSource(parameters, csharpSource);

    if (results.Errors.HasErrors) {
        Console.WriteLine("Compilation failed:");
        for(var i=0; i < results.Errors.Count; i++) {
            Console.WriteLine(results.Errors[i].ErrorText);
        }
        return;
    }

    Console.WriteLine("Compilation successful. Starting application...");

    try {
        var assembly = results.CompiledAssembly;
        var programType = assembly.GetType("Hello");
        var mainMethod = programType.GetMethod("Main");
        // Hello.Main() を実行
        mainMethod.Invoke(null, null);
    } catch (e) {
        Console.WriteLine("Runtime Error: " + e.ToString());
    }
}

var csharpSource = [
    "using System;",
    "using System.Text;",
    "using System.Runtime.InteropServices;",
    "using System.Reflection;",
    "using System.ComponentModel;",

    "public class Hello",
    "{",
    "    const string SHADER_SOURCE = @\"",
    "      struct VS_IN { float3 pos : POSITION; float4 col : COLOR; };",
    "      struct PS_IN { float4 pos : SV_POSITION; float4 col : COLOR; };",
    "      PS_IN VS(VS_IN input) {",
    "        PS_IN output;",
    "        output.pos = float4(input.pos, 1.0);",
    "        output.col = input.col;",
    "        return output;",
    "      }",
    "      float4 PS(PS_IN input) : SV_Target {",
    "        return input.col;",
    "      }",
    "    \";",

    "    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X; public int Y; }",
    "    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam; public IntPtr lParam; public uint time; public POINT pt; }",
    "    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] ",
    "    struct WNDCLASSEX { public uint cbSize; public uint style; public IntPtr lpfnWndProc; public int cbClsExtra; public int cbWndExtra; public IntPtr hInstance; public IntPtr hIcon; public IntPtr hCursor; public IntPtr hbrBackground; public string lpszMenuName; public string lpszClassName; public IntPtr hIconSm; }",
    
    "    [StructLayout(LayoutKind.Sequential)] struct DXGI_SWAP_CHAIN_DESC1 { public uint Width; public uint Height; public uint Format; public bool Stereo; public DXGI_SAMPLE_DESC SampleDesc; public uint BufferUsage; public uint BufferCount; public uint Scaling; public uint SwapEffect; public uint AlphaMode; public uint Flags; }",
    "    [StructLayout(LayoutKind.Sequential)] struct DXGI_SAMPLE_DESC { public uint Count; public uint Quality; }",
    "    [StructLayout(LayoutKind.Sequential)] struct D3D11_VIEWPORT { public float TopLeftX; public float TopLeftY; public float Width; public float Height; public float MinDepth; public float MaxDepth; }",
    "    [StructLayout(LayoutKind.Sequential)] struct D3D11_INPUT_ELEMENT_DESC { [MarshalAs(UnmanagedType.LPStr)] public string SemanticName; public uint SemanticIndex; public uint Format; public uint InputSlot; public uint AlignedByteOffset; public uint InputSlotClass; public uint InstanceDataStepRate; }",
    "    [StructLayout(LayoutKind.Sequential)] struct Vertex { public float X, Y, Z; public float R, G, B, A; }",
    "    [StructLayout(LayoutKind.Sequential)] struct D3D11_BUFFER_DESC { public uint ByteWidth; public uint Usage; public uint BindFlags; public uint CPUAccessFlags; public uint MiscFlags; public uint StructureByteStride; }",
    "    [StructLayout(LayoutKind.Sequential)] struct D3D11_SUBRESOURCE_DATA { public IntPtr pSysMem; public uint SysMemPitch; public uint SysMemSlicePitch; }",

    "    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left; public int Top; public int Right; public int Bottom; }",
    "    [StructLayout(LayoutKind.Sequential)] struct PAINTSTRUCT { public IntPtr hdc; public bool fErase; public RECT rcPaint; public bool fRestore; public bool fIncUpdate; [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)] public byte[] Reserved; };",

    "    const uint CS_HREDRAW = 0x0002;",
    "    const uint CS_VREDRAW = 0x0001;",

    "    const uint WS_OVERLAPPEDWINDOW = 0x00CF0000; const uint WS_VISIBLE = 0x10000000;",
    "    const uint PM_REMOVE = 0x0001; const uint WM_QUIT = 0x0012; const uint WM_DESTROY = 0x0002; const uint WM_PAINT = 0x000F; const uint WM_ERASEBKGND = 0x0014;",
    "    const uint D3D11_SDK_VERSION = 7; const int D3D_DRIVER_TYPE_HARDWARE = 1;",
    "    const uint D3D11_BIND_VERTEX_BUFFER = 0x1;",
    "    const uint D3DCOMPILE_ENABLE_STRICTNESS = (1 << 11);",
    "    const int DXGI_FORMAT_R8G8B8A8_UNORM = 28; const int DXGI_FORMAT_R32G32B32_FLOAT = 6; const int DXGI_FORMAT_R32G32B32A32_FLOAT = 2;",
    "    const int DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20; const int DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;",

    "    [DllImport(\"user32.dll\", EntryPoint = \"CreateWindowExW\", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr CreateWindowEx(uint dwExStyle, string lpClassName, string lpWindowName, uint dwStyle, int x, int y, int nWidth, int nHeight, IntPtr hWndParent, IntPtr hMenu, IntPtr hInstance, IntPtr lpParam);",
    "    [DllImport(\"user32.dll\", EntryPoint = \"RegisterClassExW\", SetLastError = true, CharSet = CharSet.Unicode)] static extern ushort RegisterClassEx([In] ref WNDCLASSEX lpwcx);",
    "    [DllImport(\"user32.dll\", EntryPoint = \"DefWindowProcW\", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr DefWindowProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);",
    "    [DllImport(\"user32.dll\", SetLastError = true)] static extern void PostQuitMessage(int nExitCode);",
    "    [DllImport(\"user32.dll\")] static extern bool PeekMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);",
    "    [DllImport(\"user32.dll\")] static extern bool TranslateMessage([In] ref MSG lpMsg);",
    "    [DllImport(\"user32.dll\")] static extern IntPtr DispatchMessage([In] ref MSG lpMsg);",
    "    [DllImport(\"user32.dll\")] static extern IntPtr LoadCursor(IntPtr hInstance, IntPtr lpCursorName);",
    "    [DllImport(\"kernel32.dll\", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string lpModuleName);",
    "    [DllImport(\"user32.dll\")] static extern IntPtr BeginPaint(IntPtr hWnd, out PAINTSTRUCT lpPaint);",
    "    [DllImport(\"user32.dll\")] static extern bool EndPaint(IntPtr hWnd, ref PAINTSTRUCT lpPaint);",
    "    [DllImport(\"user32.dll\", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);",

    "    [DllImport(\"d3d11.dll\", CallingConvention = CallingConvention.StdCall)] static extern int D3D11CreateDevice(IntPtr pAdapter, int DriverType, IntPtr Software, uint Flags, IntPtr pFeatureLevels, uint FeatureLevels, uint SDKVersion, out IntPtr ppDevice, out IntPtr pFeatureLevel, out IntPtr ppImmediateContext);",
    "    [DllImport(\"dxgi.dll\", CallingConvention = CallingConvention.StdCall)] static extern int CreateDXGIFactory1(ref Guid riid, out IntPtr ppFactory);",
    "    [DllImport(\"d3dcompiler_47.dll\", CallingConvention = CallingConvention.StdCall)] static extern int D3DCompile([MarshalAs(UnmanagedType.LPStr)] string srcData, IntPtr srcDataSize, string sourceName, IntPtr defines, IntPtr include, string entryPoint, string target, uint flags1, uint flags2, out IntPtr code, out IntPtr errorMsgs);",

    "    delegate IntPtr WndProcDelegate(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int QueryInterfaceDelegate(IntPtr thisPtr, ref Guid riid, out IntPtr ppvObject);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateSwapChainForHwndDelegate(IntPtr factory, IntPtr pDevice, IntPtr hWnd, [In] ref DXGI_SWAP_CHAIN_DESC1 pDesc, IntPtr pFullscreenDesc, IntPtr pRestrictToOutput, out IntPtr ppSwapChain);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetBufferDelegate(IntPtr swapChain, uint Buffer, ref Guid riid, out IntPtr ppSurface);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateRenderTargetViewDelegate(IntPtr device, IntPtr pResource, IntPtr pDesc, out IntPtr ppRTView);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void OMSetRenderTargetsDelegate(IntPtr context, uint NumViews, [In] IntPtr[] ppRenderTargetViews, IntPtr pDepthStencilView);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void RSSetViewportsDelegate(IntPtr context, uint numViewports, ref D3D11_VIEWPORT viewport);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void ClearRenderTargetViewDelegate(IntPtr context, IntPtr pRenderTargetView, [MarshalAs(UnmanagedType.LPArray, SizeConst = 4)] float[] ColorRGBA);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateBufferDelegate(IntPtr device, [In] ref D3D11_BUFFER_DESC pDesc, [In] ref D3D11_SUBRESOURCE_DATA pInitialData, out IntPtr ppBuffer);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateVertexShaderDelegate(IntPtr device, IntPtr pShaderBytecode, IntPtr BytecodeLength, IntPtr pClassLinkage, out IntPtr ppVertexShader);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreatePixelShaderDelegate(IntPtr device, IntPtr pShaderBytecode, IntPtr BytecodeLength, IntPtr pClassLinkage, out IntPtr ppPixelShader);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void VSSetShaderDelegate(IntPtr context, IntPtr pVertexShader, IntPtr[] ppClassInstances, uint NumClassInstances);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void PSSetShaderDelegate(IntPtr context, IntPtr pPixelShader, IntPtr[] ppClassInstances, uint NumClassInstances);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int CreateInputLayoutDelegate(IntPtr device, [In] D3D11_INPUT_ELEMENT_DESC[] pInputElementDescs, uint NumElements, IntPtr pShaderBytecodeWithInputSignature, IntPtr BytecodeLength, out IntPtr ppInputLayout);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetInputLayoutDelegate(IntPtr context, IntPtr inputLayout);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetVertexBuffersDelegate(IntPtr context, uint StartSlot, uint NumBuffers, [In] IntPtr[] ppVertexBuffers, [In] uint[] pStrides, [In] uint[] pOffsets);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void IASetPrimitiveTopologyDelegate(IntPtr context, uint Topology);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate void DrawDelegate(IntPtr context, uint VertexCount, uint StartVertexLocation);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int PresentDelegate(IntPtr pSwapChain, uint SyncInterval, uint Flags);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr GetBufferPointerDelegate(IntPtr pBlob);",
    "    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate IntPtr GetBufferSizeDelegate(IntPtr pBlob);",

    "    static T GetMethod<T>(IntPtr ptr, int index) {",
    "        IntPtr vTable = Marshal.ReadIntPtr(ptr);",
    "        IntPtr methodPtr = Marshal.ReadIntPtr(vTable, index * IntPtr.Size);",
    "        return Marshal.GetDelegateForFunctionPointer<T>(methodPtr);",
    "    }",

    "    static IntPtr WndProc(IntPtr hWnd, uint uMsg, IntPtr wParam, IntPtr lParam) {",
    "        if (uMsg == WM_DESTROY) {",
    "            PostQuitMessage(0);",
    "            return IntPtr.Zero;",
    "        }",
    "        if (uMsg == WM_ERASEBKGND) {",
    "            return (IntPtr)1;",
    "        }",
    "        if (uMsg == WM_PAINT) {",
    "            PAINTSTRUCT ps;",
    "            IntPtr hdc = BeginPaint(hWnd, out ps);",
    "            EndPaint(hWnd, ref ps);",
    "            return IntPtr.Zero;",
    "        }",
    "        return DefWindowProc(hWnd, uMsg, wParam, lParam);",
    "    }",

    "    public static void Main() {",
    "        try {",
    "            IntPtr hInstance = GetModuleHandle(null);",
    "            WndProcDelegate wndProc = WndProc;",
    "            var wndClass = new WNDCLASSEX { cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)), style = CS_HREDRAW | CS_VREDRAW | 0x0020, lpfnWndProc = Marshal.GetFunctionPointerForDelegate(wndProc), hInstance = hInstance, hCursor = LoadCursor(IntPtr.Zero, (IntPtr)32512), lpszClassName = \"DX11Class\" };",
    "            RegisterClassEx(ref wndClass);",
    "            IntPtr hWnd = CreateWindowEx(0, \"DX11Class\", \"JScript.NET DX11 Triangle\", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 100, 100, 800, 600, IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero);",
    "            StringBuilder sb = new StringBuilder(256);",
    "            GetWindowText(hWnd, sb, 256);",
    "            Console.WriteLine(\"Window Title: \" + sb.ToString());",
    "",
    "            IntPtr device, context, featureLevel;",
    "            D3D11CreateDevice(IntPtr.Zero, D3D_DRIVER_TYPE_HARDWARE, IntPtr.Zero, 0, IntPtr.Zero, 0, D3D11_SDK_VERSION, out device, out featureLevel, out context);",
    "",
    "            IntPtr factory, factory2, swapChain;",
    "            Guid IID_Factory1 = new Guid(\"770aae78-f26f-4dba-a829-253c83d1b387\");",
    "            Guid IID_Factory2 = new Guid(\"50c83a1c-e072-4c48-87b0-3630fa36a6d0\");",
    "            CreateDXGIFactory1(ref IID_Factory1, out factory);",
    "            GetMethod<QueryInterfaceDelegate>(factory, 0)(factory, ref IID_Factory2, out factory2);",
    "            var scDesc = new DXGI_SWAP_CHAIN_DESC1 { Width = 800, Height = 600, Format = (uint)DXGI_FORMAT_R8G8B8A8_UNORM, SampleDesc = new DXGI_SAMPLE_DESC { Count = 1 }, BufferUsage = (uint)DXGI_USAGE_RENDER_TARGET_OUTPUT, BufferCount = 2, SwapEffect = (uint)DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL };",
    "            GetMethod<CreateSwapChainForHwndDelegate>(factory2, 15)(factory2, device, hWnd, ref scDesc, IntPtr.Zero, IntPtr.Zero, out swapChain);",
    "",
    "            IntPtr backBuffer, rtv;",
    "            Guid IID_Tex2D = new Guid(\"6f15aaf2-d208-4e89-9ab4-489535d34f9c\");",
    "            GetMethod<GetBufferDelegate>(swapChain, 9)(swapChain, 0, ref IID_Tex2D, out backBuffer);",
    "            GetMethod<CreateRenderTargetViewDelegate>(device, 9)(device, backBuffer, IntPtr.Zero, out rtv);",
    "",
    "            var vp = new D3D11_VIEWPORT { Width = 800, Height = 600, MaxDepth = 1.0f };",
    "",
    "            IntPtr vsBlob, psBlob, err;",
    "            D3DCompile(SHADER_SOURCE, (IntPtr)SHADER_SOURCE.Length, null, IntPtr.Zero, IntPtr.Zero, \"VS\", \"vs_4_0\", D3DCOMPILE_ENABLE_STRICTNESS, 0, out vsBlob, out err);",
    "            D3DCompile(SHADER_SOURCE, (IntPtr)SHADER_SOURCE.Length, null, IntPtr.Zero, IntPtr.Zero, \"PS\", \"ps_4_0\", D3DCOMPILE_ENABLE_STRICTNESS, 0, out psBlob, out err);",
    "            ",
    "            IntPtr vs, ps;",
    "            IntPtr vsPtr = GetMethod<GetBufferPointerDelegate>(vsBlob, 3)(vsBlob);",
    "            IntPtr vsSize = GetMethod<GetBufferSizeDelegate>(vsBlob, 4)(vsBlob);",
    "            IntPtr psPtr = GetMethod<GetBufferPointerDelegate>(psBlob, 3)(psBlob);",
    "            IntPtr psSize = GetMethod<GetBufferSizeDelegate>(psBlob, 4)(psBlob);",
    "            GetMethod<CreateVertexShaderDelegate>(device, 12)(device, vsPtr, vsSize, IntPtr.Zero, out vs);",
    "            GetMethod<CreatePixelShaderDelegate>(device, 15)(device, psPtr, psSize, IntPtr.Zero, out ps);",
    "",
    "            IntPtr layout;",
    "            var elements = new D3D11_INPUT_ELEMENT_DESC[] {",
    "                new D3D11_INPUT_ELEMENT_DESC { SemanticName=\"POSITION\", Format=(uint)DXGI_FORMAT_R32G32B32_FLOAT, InputSlotClass=0 },",
    "                new D3D11_INPUT_ELEMENT_DESC { SemanticName=\"COLOR\", Format=(uint)DXGI_FORMAT_R32G32B32A32_FLOAT, AlignedByteOffset=12, InputSlotClass=0 }",
    "            };",
    "            GetMethod<CreateInputLayoutDelegate>(device, 11)(device, elements, 2, vsPtr, vsSize, out layout);",
    "",
    "            var vertices = new Vertex[] {",
    "                new Vertex { X=0.0f, Y=0.5f, Z=0.0f, R=1, G=0, B=0, A=1 },",
    "                new Vertex { X=0.5f, Y=-0.5f, Z=0.0f, R=0, G=1, B=0, A=1 },",
    "                new Vertex { X=-0.5f, Y=-0.5f, Z=0.0f, R=0, G=0, B=1, A=1 }",
    "            };",
    "            IntPtr vb;",
    "            var bd = new D3D11_BUFFER_DESC { ByteWidth = (uint)(28 * 3), Usage = 0, BindFlags = 1 };",
    "            GCHandle handle = GCHandle.Alloc(vertices, GCHandleType.Pinned);",
    "            var initData = new D3D11_SUBRESOURCE_DATA { pSysMem = handle.AddrOfPinnedObject() };",
    "            GetMethod<CreateBufferDelegate>(device, 3)(device, ref bd, ref initData, out vb);",
    "            handle.Free();",
    "",
    "            MSG msg;",
    "            float[] color = { 0.0f, 0.2f, 0.4f, 1.0f };",
    "            while (true) {",
    "                if (PeekMessage(out msg, IntPtr.Zero, 0, 0, PM_REMOVE)) {",
    "                    if (msg.message == WM_QUIT) break;",
    "                    TranslateMessage(ref msg);",
    "                    DispatchMessage(ref msg);",
    "                } else {",
    "                    GetMethod<OMSetRenderTargetsDelegate>(context, 33)(context, 1, new IntPtr[] { rtv }, IntPtr.Zero);",
    "                    GetMethod<RSSetViewportsDelegate>(context, 44)(context, 1, ref vp);",
    "                    GetMethod<VSSetShaderDelegate>(context, 11)(context, vs, null, 0);",
    "                    GetMethod<PSSetShaderDelegate>(context, 9)(context, ps, null, 0);",
    "                    GetMethod<IASetInputLayoutDelegate>(context, 17)(context, layout);",
    "                    GetMethod<IASetVertexBuffersDelegate>(context, 18)(context, 0, 1, new IntPtr[] { vb }, new uint[] { 28 }, new uint[] { 0 });",
    "                    GetMethod<IASetPrimitiveTopologyDelegate>(context, 24)(context, 4);",
    "                    GetMethod<ClearRenderTargetViewDelegate>(context, 50)(context, rtv, color);",
    "                    GetMethod<DrawDelegate>(context, 13)(context, 3, 0);",
    "                    GetMethod<PresentDelegate>(swapChain, 8)(swapChain, 1, 0);",
    "                }",
    "            }",
    "        } catch (Exception ex) {",
    "            Console.WriteLine(ex.ToString());",
    "        }",
    "    }",
    "}"
].join("\n");

Main();
