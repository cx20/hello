// RayMarch.js - JScript.NET Vulkan 1.4 Ray Marching Demo
// Build: jsc /platform:x64 /nologo RayMarch.js && RayMarch.exe
// Requirements:
//   - Vulkan runtime (vulkan-1.dll)
//   - shaderc_shared.dll (from Vulkan SDK, or in current directory)
//   - hello.vert / hello.frag in the same directory (inline GLSL fallback exists)
//
// Debug output goes to both Console AND Windows DebugView (Sysinternals).
// Run DebugView.exe as Administrator and enable "Capture Win32" to see output.

import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;
import System.Text;
import System.CodeDom.Compiler;
import System.IO;

// ===== Debug output: Console + DebugView (OutputDebugStringA) =====

// Cache the OutputDebugStringA P/Invoke type to avoid rebuilding each call
var g_dbgType = (function() {
  try {
    var dom = AppDomain.CurrentDomain;
    var asm = dom.DefineDynamicAssembly(new AssemblyName("DbgStr"), AssemblyBuilderAccess.Run);
    var mod = asm.DefineDynamicModule("M");
    var typ = mod.DefineType("T", TypeAttributes.Public);
    var meth = typ.DefineMethod("OutputDebugStringA", 6|128|16|8192,
      Type.GetType("System.Void"), [Type.GetType("System.String")]);
    meth.SetCustomAttribute(new CustomAttributeBuilder(
      DllImportAttribute.GetConstructor([Type.GetType("System.String")]), ["kernel32.dll"]));
    return typ.CreateType();
  } catch(_e) { return null; }
})();

function DebugLog(message:String): void {
  var line:String = "[RAYMARCH] " + message;
  Console.WriteLine(line);
  // Also send to DebugView (visible when running under a debugger or Sysinternals DebugView)
  try {
    if(g_dbgType != null) {
      g_dbgType.InvokeMember("OutputDebugStringA",
        BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,
        null, null, [line + "\r\n"]);
    }
  } catch(_e2) {}
}

// Translate common VkResult integer codes to a readable name
function VkResultStr(r:int):String {
  switch(r) {
    case  0: return "VK_SUCCESS";
    case  1: return "VK_NOT_READY";
    case  2: return "VK_TIMEOUT";
    case  3: return "VK_EVENT_SET";
    case  4: return "VK_EVENT_RESET";
    case  5: return "VK_INCOMPLETE";
    case -1: return "VK_ERROR_OUT_OF_HOST_MEMORY";
    case -2: return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
    case -3: return "VK_ERROR_INITIALIZATION_FAILED";
    case -4: return "VK_ERROR_DEVICE_LOST";
    case -5: return "VK_ERROR_MEMORY_MAP_FAILED";
    case -6: return "VK_ERROR_LAYER_NOT_PRESENT";
    case -7: return "VK_ERROR_EXTENSION_NOT_PRESENT";
    case -8: return "VK_ERROR_FEATURE_NOT_PRESENT";
    case -9: return "VK_ERROR_INCOMPATIBLE_DRIVER";
    case -10: return "VK_ERROR_TOO_MANY_OBJECTS";
    case -11: return "VK_ERROR_FORMAT_NOT_SUPPORTED";
    case -12: return "VK_ERROR_FRAGMENTED_POOL";
    case -1000069000: return "VK_ERROR_OUT_OF_POOL_MEMORY";
    case  1000001003: return "VK_SUBOPTIMAL_KHR";
    case -1000001004: return "VK_ERROR_SURFACE_LOST_KHR";
    case -1000001003: return "VK_ERROR_NATIVE_WINDOW_IN_USE_KHR";
    default: return "UNKNOWN_VkResult(" + r + ")";
  }
}

// Log a Vulkan call result; returns true on VK_SUCCESS
function VkCheck(r:int, func:String, step:String):Boolean {
  if(r == 0) {
    DebugLog("    OK   [" + func + "] " + step);
    return true;
  }
  DebugLog("  **FAIL [" + func + "] " + step + " => " + VkResultStr(r));
  return false;
}

function Step(func:String, step:String):void {
  DebugLog("  STEP [" + func + "] " + step);
}

function PtrHex(p:IntPtr):String{
  if(p==IntPtr.Zero) return "0x0";
  if(IntPtr.Size==8){
    var v:long = p.ToInt64();
    if(v<0) v = v + 9223372036854775807 + 9223372036854775809;
    return "0x"+v.toString(16);
  } else {
    var v32:int = p.ToInt32();
    if(v32<0) v32 = v32 + 0x100000000;
    return "0x"+v32.toString(16);
  }
}

function ArgStr(a:Object):String{
  if(a==null) return "null";
  if(a.GetType().FullName=="System.IntPtr") return PtrHex(IntPtr(a));
  var t = a.GetType().FullName;
  if(t=="System.UInt64") return "0x"+System.UInt64(a).ToString("X");
  if(t=="System.UInt32") return "0x"+System.UInt32(a).ToString("X");
  if(t=="System.Int32")  return String(a);
  if(t=="System.Single") return String(a);
  return a.ToString();
}

function ArgsStr(args:Object[]):String{
  if(args==null) return "";
  var s="";
  for(var i=0; i<args.length; i++){
    if(i>0) s+=", ";
    s+=ArgStr(args[i]);
  }
  return s;
}

// ===== VulkanInvoker: C# helper compiled at runtime =====
// Provides strongly-typed delegate wrappers for each Vulkan calling pattern.

var createVulkanInvoker = (function() {
  DebugLog("VulkanInvoker: compiling C# helper with CodeDom...");

  var source =
  "using System; using System.Runtime.InteropServices;\n" +
  "public static class VulkanInvoker {\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr DGetProcAddr(IntPtr inst, IntPtr name);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate2(IntPtr p1, IntPtr p2);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate3(IntPtr p1, IntPtr p2, IntPtr p3);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate4(IntPtr p1, IntPtr p2, IntPtr p3, IntPtr p4);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DRet1(IntPtr p1);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid1(IntPtr p1);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid2(IntPtr p1, IntPtr p2);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid3(IntPtr p1, IntPtr p2, IntPtr p3);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid4(IntPtr p1, uint p2, uint p3, IntPtr p4);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DBindPipeline(IntPtr cmd, uint bind, ulong pipe);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DSetViewport(IntPtr cmd, uint first, uint cnt, IntPtr vp);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDraw(IntPtr cmd, uint vc, uint ic, uint fv, uint fi);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DBeginRP(IntPtr cmd, IntPtr info, uint cont);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DSubmit(IntPtr q, uint cnt, IntPtr sub, ulong fence);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DPresent(IntPtr q, IntPtr info);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DAcquire(IntPtr dev, ulong sc, ulong to, ulong sem, ulong fence, IntPtr idx);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DWaitFence(IntPtr dev, uint cnt, IntPtr f, uint all, ulong to);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DResetFence(IntPtr dev, uint cnt, IntPtr f);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DResetCmd(IntPtr cmd, uint flags);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DMap(IntPtr dev, ulong mem, ulong off, ulong sz, uint fl, IntPtr pp);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DUnmap(IntPtr dev, ulong mem);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DBind(IntPtr dev, ulong buf, ulong mem, ulong off);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDestroy2(IntPtr dev, ulong h);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDestroy3(IntPtr dev, ulong h, IntPtr alloc);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DGetImages(IntPtr dev, ulong sc, IntPtr cnt, IntPtr img);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreatePipe(IntPtr dev, ulong cache, uint cnt, IntPtr info, IntPtr alloc, IntPtr pipe);\n" +
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DPushConst(IntPtr cmd, ulong layout, uint sf, uint offset, uint size, IntPtr pValues);\n" +
  "  public static IntPtr GetProc(IntPtr f, IntPtr i, IntPtr n) { return ((DGetProcAddr)Marshal.GetDelegateForFunctionPointer(f,typeof(DGetProcAddr)))(i,n); }\n" +
  "  public static int Create2(IntPtr f, IntPtr a, IntPtr b) { return ((DCreate2)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate2)))(a,b); }\n" +
  "  public static int Create3(IntPtr f, IntPtr a, IntPtr b, IntPtr c) { return ((DCreate3)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate3)))(a,b,c); }\n" +
  "  public static int Create4(IntPtr f, IntPtr a, IntPtr b, IntPtr c, IntPtr d) { return ((DCreate4)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate4)))(a,b,c,d); }\n" +
  "  public static int Ret1(IntPtr f, IntPtr a) { return ((DRet1)Marshal.GetDelegateForFunctionPointer(f,typeof(DRet1)))(a); }\n" +
  "  public static void Void1(IntPtr f, IntPtr a) { ((DVoid1)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid1)))(a); }\n" +
  "  public static void Void2(IntPtr f, IntPtr a, IntPtr b) { ((DVoid2)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid2)))(a,b); }\n" +
  "  public static void Void3(IntPtr f, IntPtr a, IntPtr b, IntPtr c) { ((DVoid3)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid3)))(a,b,c); }\n" +
  "  public static void Void4(IntPtr f, IntPtr a, uint b, uint c, IntPtr d) { ((DVoid4)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid4)))(a,b,c,d); }\n" +
  "  public static void BindPipe(IntPtr f, IntPtr c, uint b, ulong p) { ((DBindPipeline)Marshal.GetDelegateForFunctionPointer(f,typeof(DBindPipeline)))(c,b,p); }\n" +
  "  public static void SetVP(IntPtr f, IntPtr c, uint a, uint b, IntPtr v) { ((DSetViewport)Marshal.GetDelegateForFunctionPointer(f,typeof(DSetViewport)))(c,a,b,v); }\n" +
  "  public static void Draw(IntPtr f, IntPtr c, uint vc, uint ic, uint fv, uint fi) { ((DDraw)Marshal.GetDelegateForFunctionPointer(f,typeof(DDraw)))(c,vc,ic,fv,fi); }\n" +
  "  public static void BeginRP(IntPtr f, IntPtr c, IntPtr i, uint co) { ((DBeginRP)Marshal.GetDelegateForFunctionPointer(f,typeof(DBeginRP)))(c,i,co); }\n" +
  "  public static int Submit(IntPtr f, IntPtr q, uint c, IntPtr s, ulong fe) { return ((DSubmit)Marshal.GetDelegateForFunctionPointer(f,typeof(DSubmit)))(q,c,s,fe); }\n" +
  "  public static int Present(IntPtr f, IntPtr q, IntPtr i) { return ((DPresent)Marshal.GetDelegateForFunctionPointer(f,typeof(DPresent)))(q,i); }\n" +
  "  public static int Acquire(IntPtr f, IntPtr d, ulong sc, ulong to, ulong sem, ulong fe, IntPtr i) { return ((DAcquire)Marshal.GetDelegateForFunctionPointer(f,typeof(DAcquire)))(d,sc,to,sem,fe,i); }\n" +
  "  public static int WaitFence(IntPtr f, IntPtr d, uint c, IntPtr fe, uint a, ulong t) { return ((DWaitFence)Marshal.GetDelegateForFunctionPointer(f,typeof(DWaitFence)))(d,c,fe,a,t); }\n" +
  "  public static int ResetFence(IntPtr f, IntPtr d, uint c, IntPtr fe) { return ((DResetFence)Marshal.GetDelegateForFunctionPointer(f,typeof(DResetFence)))(d,c,fe); }\n" +
  "  public static int ResetCmd(IntPtr f, IntPtr c, uint fl) { return ((DResetCmd)Marshal.GetDelegateForFunctionPointer(f,typeof(DResetCmd)))(c,fl); }\n" +
  "  public static int Map(IntPtr f, IntPtr d, ulong m, ulong o, ulong s, uint fl, IntPtr p) { return ((DMap)Marshal.GetDelegateForFunctionPointer(f,typeof(DMap)))(d,m,o,s,fl,p); }\n" +
  "  public static void Unmap(IntPtr f, IntPtr d, ulong m) { ((DUnmap)Marshal.GetDelegateForFunctionPointer(f,typeof(DUnmap)))(d,m); }\n" +
  "  public static int Bind(IntPtr f, IntPtr d, ulong b, ulong m, ulong o) { return ((DBind)Marshal.GetDelegateForFunctionPointer(f,typeof(DBind)))(d,b,m,o); }\n" +
  "  public static void Destroy2(IntPtr f, IntPtr d, ulong h) { ((DDestroy2)Marshal.GetDelegateForFunctionPointer(f,typeof(DDestroy2)))(d,h); }\n" +
  "  public static void Destroy3(IntPtr f, IntPtr d, ulong h, IntPtr a) { ((DDestroy3)Marshal.GetDelegateForFunctionPointer(f,typeof(DDestroy3)))(d,h,a); }\n" +
  "  public static int GetImages(IntPtr f, IntPtr d, ulong sc, IntPtr c, IntPtr i) { return ((DGetImages)Marshal.GetDelegateForFunctionPointer(f,typeof(DGetImages)))(d,sc,c,i); }\n" +
  "  public static int CreatePipe(IntPtr f, IntPtr d, ulong ca, uint c, IntPtr i, IntPtr a, IntPtr p) { return ((DCreatePipe)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreatePipe)))(d,ca,c,i,a,p); }\n" +
  "  public static void PushConst(IntPtr f, IntPtr c, ulong l, uint sf, uint o, uint sz, IntPtr v) { ((DPushConst)Marshal.GetDelegateForFunctionPointer(f,typeof(DPushConst)))(c,l,sf,o,sz,v); }\n" +
  "}";

  var cp = CodeDomProvider.CreateProvider("CSharp");
  var cps = new CompilerParameters();
  cps.GenerateInMemory = true;
  var cr = cp.CompileAssemblyFromSource(cps, source);
  if (cr.Errors.HasErrors) {
    for (var i = 0; i < cr.Errors.Count; i++) DebugLog("VulkanInvoker compile error: " + cr.Errors[i].ToString());
    return null;
  }
  DebugLog("VulkanInvoker: compiled OK");
  return cr.CompiledAssembly.GetType("VulkanInvoker");
})();

// ===== Dynamic P/Invoke (StdCall) =====

function InvokeWin32(dll:String, ret:Type, name:String, types:Type[], args:Object[]): Object {
  var dom = AppDomain.CurrentDomain;
  var asm = dom.DefineDynamicAssembly(new AssemblyName("P" + name), AssemblyBuilderAccess.Run);
  var mod = asm.DefineDynamicModule("M");
  var typ = mod.DefineType("T", TypeAttributes.Public);
  var meth = typ.DefineMethod(name, 6|128|16|8192, ret, types);
  meth.SetCustomAttribute(new CustomAttributeBuilder(
    DllImportAttribute.GetConstructor([Type.GetType("System.String")]), [dll]));
  return typ.CreateType().InvokeMember(name,
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod, null, null, args);
}

// ===== Dynamic P/Invoke (Cdecl) =====

function InvokeCdecl(dll:String, ret:Type, name:String, types:Type[], args:Object[]): Object {
  var dom = AppDomain.CurrentDomain;
  var asm = dom.DefineDynamicAssembly(new AssemblyName("P" + name + "C"), AssemblyBuilderAccess.Run);
  var mod = asm.DefineDynamicModule("M");
  var typ = mod.DefineType("T", TypeAttributes.Public);
  var meth = typ.DefineMethod(name, 6|128|16|8192, ret, types);
  var ctor = DllImportAttribute.GetConstructor([Type.GetType("System.String")]);
  var prop = DllImportAttribute.GetProperty("CallingConvention", BindingFlags.Public|BindingFlags.Instance);
  var ctorArgs:Object[]=new Object[1];
  ctorArgs[0]=dll;
  if(prop!=null){
    var props:PropertyInfo[]=new PropertyInfo[1];
    props[0]=prop;
    var propVals:Object[]=new Object[1];
    propVals[0]=CallingConvention.Cdecl;
    meth.SetCustomAttribute(new CustomAttributeBuilder(ctor, ctorArgs, props, propVals));
  } else {
    meth.SetCustomAttribute(new CustomAttributeBuilder(ctor, ctorArgs));
  }
  return typ.CreateType().InvokeMember(name,
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod, null, null, args);
}

// ===== Constants =====

// Win32
const WS_OVERLAPPEDWINDOW=0x00CF0000, WS_VISIBLE=0x10000000, CW_USEDEFAULT=-2147483648;
const SW_SHOW=5, WM_QUIT=0x0012, PM_REMOVE=1, CS_OWNDC=0x0020, WHITE_BRUSH=0;

// Vulkan sType
const VK_STRUCTURE_TYPE_APPLICATION_INFO=0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO=1;
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO=2, VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO=3;
const VK_STRUCTURE_TYPE_SUBMIT_INFO=4;
const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO=8, VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO=9;
const VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO=15;
const VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO=16;
const VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO=18;
const VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO=19;
const VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO=20;
const VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO=22;
const VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO=23;
const VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO=24;
const VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO=26;
const VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO=27;
const VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO=28;
const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO=30;
const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO=37;
const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO=38;
const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO=39;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO=40;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO=42;
const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO=43;
const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR=1000009000;
const VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR=1000001000;
const VK_STRUCTURE_TYPE_PRESENT_INFO_KHR=1000001001;

// Vulkan misc
const VK_SUCCESS=0;
const VK_QUEUE_GRAPHICS_BIT=1;
const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT=2;
const VK_COMMAND_BUFFER_LEVEL_PRIMARY=0;
const VK_FENCE_CREATE_SIGNALED_BIT=1;
const VK_PIPELINE_BIND_POINT_GRAPHICS=0;
const VK_SUBPASS_CONTENTS_INLINE=0;
const VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST=3;
const VK_POLYGON_MODE_FILL=0;
const VK_CULL_MODE_NONE=0;
const VK_FRONT_FACE_COUNTER_CLOCKWISE=0;
const VK_SAMPLE_COUNT_1_BIT=1;
const VK_DYNAMIC_STATE_VIEWPORT=0, VK_DYNAMIC_STATE_SCISSOR=1;
const VK_SHADER_STAGE_VERTEX_BIT=1, VK_SHADER_STAGE_FRAGMENT_BIT=16;
const VK_FORMAT_B8G8R8A8_SRGB=44; // UNORM: manual gamma in shader; was SRGB(50) which caused double-correction
const VK_COLOR_SPACE_SRGB_NONLINEAR_KHR=0, VK_PRESENT_MODE_FIFO_KHR=2;
const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT=16, VK_SHARING_MODE_EXCLUSIVE=0;
const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR=1, VK_IMAGE_VIEW_TYPE_2D=1;
const VK_IMAGE_ASPECT_COLOR_BIT=1;
const VK_ATTACHMENT_LOAD_OP_CLEAR=1, VK_ATTACHMENT_STORE_OP_STORE=0;
const VK_ATTACHMENT_LOAD_OP_DONT_CARE=2, VK_ATTACHMENT_STORE_OP_DONT_CARE=1;
const VK_IMAGE_LAYOUT_UNDEFINED=0, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR=1000001002;
const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL=2;
const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT=0x400;
const VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT=0x100;
const VK_COLOR_COMPONENT_RGBA=15;
const VK_API_VERSION_1_4=((1<<22)|(4<<12));

// shaderc
const SHADERC_SHADER_KIND_VERTEX=0;
const SHADERC_SHADER_KIND_FRAGMENT=1;
const SHADERC_STATUS_SUCCESS=0;

// Push constant layout: float iTime + float padding + vec2 iResolution = 16 bytes
const PUSH_CONSTANT_SIZE=16;

// ===== Globals =====

var vkInstance:IntPtr=IntPtr.Zero, vkPhysicalDevice:IntPtr=IntPtr.Zero, vkDevice:IntPtr=IntPtr.Zero;
var vkSurface:ulong=0, vkSwapchain:ulong=0, vkRenderPass:ulong=0, vkPipelineLayout:ulong=0;
var vkGraphicsPipeline:ulong=0, vkCommandPool:ulong=0, vkCommandBuffer:IntPtr=IntPtr.Zero;
var vkGraphicsQueue:IntPtr=IntPtr.Zero;
var vkImageAvailableSemaphore:ulong=0, vkRenderFinishedSemaphore:ulong=0, vkInFlightFence:ulong=0;
var vkSwapchainImages:ulong[]=null, vkSwapchainImageViews:ulong[]=null, vkFramebuffers:ulong[]=null;
var vkSwapchainImageCount:uint=0, vkGraphicsQueueFamilyIndex:uint=0;
var windowWidth:uint=800, windowHeight:uint=600;
var g_startTimeMs:long=0;

// Function pointers
var vkGetInstanceProcAddr_ptr:IntPtr=IntPtr.Zero, vkCreateInstance_ptr:IntPtr=IntPtr.Zero;
var vkGetDeviceProcAddr_ptr:IntPtr=IntPtr.Zero;
var vkEnumeratePhysicalDevices_ptr:IntPtr=IntPtr.Zero;
var vkGetPhysicalDeviceQueueFamilyProperties_ptr:IntPtr=IntPtr.Zero;
var vkCreateDevice_ptr:IntPtr=IntPtr.Zero, vkGetDeviceQueue_ptr:IntPtr=IntPtr.Zero;
var vkCreateWin32SurfaceKHR_ptr:IntPtr=IntPtr.Zero, vkCreateSwapchainKHR_ptr:IntPtr=IntPtr.Zero;
var vkGetSwapchainImagesKHR_ptr:IntPtr=IntPtr.Zero, vkCreateImageView_ptr:IntPtr=IntPtr.Zero;
var vkCreateShaderModule_ptr:IntPtr=IntPtr.Zero, vkDestroyShaderModule_ptr:IntPtr=IntPtr.Zero;
var vkCreatePipelineLayout_ptr:IntPtr=IntPtr.Zero, vkCreateRenderPass_ptr:IntPtr=IntPtr.Zero;
var vkCreateGraphicsPipelines_ptr:IntPtr=IntPtr.Zero, vkCreateFramebuffer_ptr:IntPtr=IntPtr.Zero;
var vkCreateCommandPool_ptr:IntPtr=IntPtr.Zero, vkAllocateCommandBuffers_ptr:IntPtr=IntPtr.Zero;
var vkBeginCommandBuffer_ptr:IntPtr=IntPtr.Zero, vkEndCommandBuffer_ptr:IntPtr=IntPtr.Zero;
var vkCmdBeginRenderPass_ptr:IntPtr=IntPtr.Zero, vkCmdEndRenderPass_ptr:IntPtr=IntPtr.Zero;
var vkCmdBindPipeline_ptr:IntPtr=IntPtr.Zero, vkCmdSetViewport_ptr:IntPtr=IntPtr.Zero;
var vkCmdSetScissor_ptr:IntPtr=IntPtr.Zero, vkCmdDraw_ptr:IntPtr=IntPtr.Zero;
var vkCmdPushConstants_ptr:IntPtr=IntPtr.Zero;
var vkCreateSemaphore_ptr:IntPtr=IntPtr.Zero, vkCreateFence_ptr:IntPtr=IntPtr.Zero;
var vkWaitForFences_ptr:IntPtr=IntPtr.Zero, vkResetFences_ptr:IntPtr=IntPtr.Zero;
var vkAcquireNextImageKHR_ptr:IntPtr=IntPtr.Zero, vkQueueSubmit_ptr:IntPtr=IntPtr.Zero;
var vkQueuePresentKHR_ptr:IntPtr=IntPtr.Zero, vkDeviceWaitIdle_ptr:IntPtr=IntPtr.Zero;
var vkResetCommandBuffer_ptr:IntPtr=IntPtr.Zero;
var vkGetPhysicalDeviceMemoryProperties_ptr:IntPtr=IntPtr.Zero;

// ===== Memory helpers =====

function WriteU64(p:IntPtr,o:int,v:ulong):void{
  Marshal.WriteInt32(p,o,int(v&0xFFFFFFFF));
  Marshal.WriteInt32(p,o+4,int((v>>32)&0xFFFFFFFF));
}
function ReadU64(p:IntPtr,o:int):ulong{
  return ulong(uint(Marshal.ReadInt32(p,o)))|(ulong(uint(Marshal.ReadInt32(p,o+4)))<<32);
}
function ClearMem(p:IntPtr,sz:int):void{
  for(var i=0;i<sz;i++) Marshal.WriteByte(p,i,0);
}

// ===== Win32 wrappers =====

function GetModuleHandle(n:String):IntPtr{
  return InvokeWin32("kernel32.dll",Type.GetType("System.IntPtr"),"GetModuleHandleA",[Type.GetType("System.String")],[n]);
}
function GetProcAddress(h:IntPtr,n:String):IntPtr{
  return InvokeWin32("kernel32.dll",Type.GetType("System.IntPtr"),"GetProcAddress",[Type.GetType("System.IntPtr"),Type.GetType("System.String")],[h,n]);
}
function LoadLibrary(n:String):IntPtr{
  return InvokeWin32("kernel32.dll",Type.GetType("System.IntPtr"),"LoadLibraryA",[Type.GetType("System.String")],[n]);
}
function CreateWindowEx(ex:int,cls:String,ttl:String,st:int,x:int,y:int,w:int,h:int,par:IntPtr,mn:IntPtr,inst:IntPtr,pm:IntPtr):IntPtr{
  return InvokeWin32("user32.dll",Type.GetType("System.IntPtr"),"CreateWindowExA",
    [Type.GetType("System.Int32"),Type.GetType("System.String"),Type.GetType("System.String"),Type.GetType("System.Int32"),
     Type.GetType("System.Int32"),Type.GetType("System.Int32"),Type.GetType("System.Int32"),Type.GetType("System.Int32"),
     Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr")],
    [ex,cls,ttl,st,x,y,w,h,par,mn,inst,pm]);
}
function ShowWindow(h:IntPtr,c:int):Boolean{ return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"ShowWindow",[Type.GetType("System.IntPtr"),Type.GetType("System.Int32")],[h,c]); }
function UpdateWindow(h:IntPtr):Boolean{ return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"UpdateWindow",[Type.GetType("System.IntPtr")],[h]); }
function DestroyWindow(h:IntPtr):Boolean{ return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"DestroyWindow",[Type.GetType("System.IntPtr")],[h]); }
function PostQuitMessage(c:int):void{ InvokeWin32("user32.dll",Type.GetType("System.Void"),"PostQuitMessage",[Type.GetType("System.Int32")],[c]); }
function PeekMessage(m:IntPtr,h:IntPtr,mn:uint,mx:uint,rm:uint):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"PeekMessageA",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32")],
    [m,h,mn,mx,rm]);
}
function TranslateMessage(m:IntPtr):Boolean{ return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"TranslateMessage",[Type.GetType("System.IntPtr")],[m]); }
function DispatchMessage(m:IntPtr):IntPtr{ return InvokeWin32("user32.dll",Type.GetType("System.IntPtr"),"DispatchMessageA",[Type.GetType("System.IntPtr")],[m]); }
function Sleep(ms:uint):void{ InvokeWin32("kernel32.dll",Type.GetType("System.Void"),"Sleep",[Type.GetType("System.UInt32")],[ms]); }
function GetStockObject(i:int):IntPtr{ return InvokeWin32("gdi32.dll",Type.GetType("System.IntPtr"),"GetStockObject",[Type.GetType("System.Int32")],[i]); }
function IsWindow(h:IntPtr):Boolean{ return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"IsWindow",[Type.GetType("System.IntPtr")],[h]); }

// ===== shaderc: runtime GLSL -> SPIR-V =====

var g_shadercDll:String=null;

function ResolveShadercDll():String{
  if(g_shadercDll!=null) return g_shadercDll;
  try{
    var sdk=Environment.GetEnvironmentVariable("VULKAN_SDK");
    if(sdk!=null && sdk!=""){
      var p1=Path.Combine(sdk,"Bin","shaderc_shared.dll");
      if(File.Exists(p1)){ g_shadercDll=p1; return g_shadercDll; }
      var p2=Path.Combine(sdk,"Bin64","shaderc_shared.dll");
      if(File.Exists(p2)){ g_shadercDll=p2; return g_shadercDll; }
    }
    var local=Path.Combine(Environment.CurrentDirectory,"shaderc_shared.dll");
    if(File.Exists(local)){ g_shadercDll=local; return g_shadercDll; }
  }catch(_e){}
  g_shadercDll="shaderc_shared.dll";  // last resort: rely on PATH
  return g_shadercDll;
}

function ShadercCompile(source:String, kind:int, filename:String, entry:String):byte[]{
  var FN="ShadercCompile("+filename+")";
  var dll=ResolveShadercDll();
  DebugLog("  "+FN+": using DLL=" + dll);

  Step(FN,"shaderc_compiler_initialize");
  var compiler:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compiler_initialize",new Array(),new Array());
  if(compiler==IntPtr.Zero) throw new Exception(FN+": shaderc_compiler_initialize returned NULL");
  DebugLog("  "+FN+": compiler handle=" + PtrHex(compiler));

  Step(FN,"shaderc_compile_options_initialize");
  var options:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compile_options_initialize",new Array(),new Array());
  if(options==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception(FN+": shaderc_compile_options_initialize returned NULL");
  }

  // Optimization level 2 (performance)
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_set_optimization_level",
    [Type.GetType("System.IntPtr"),Type.GetType("System.Int32")],[options,2]);

  var srcBytes:byte[]=Encoding.UTF8.GetBytes(source);
  var srcPtr=Marshal.AllocHGlobal(int(srcBytes.length));
  Marshal.Copy(srcBytes,0,srcPtr,int(srcBytes.length));
  var filePtr=Marshal.StringToHGlobalAnsi(filename);
  var entryPtr=Marshal.StringToHGlobalAnsi(entry);

  Step(FN,"shaderc_compile_into_spv (srcLen="+srcBytes.length+", kind="+kind+")");
  var result:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compile_into_spv",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.UIntPtr"),
     Type.GetType("System.Int32"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr")],
    [compiler,srcPtr,new UIntPtr(uint(srcBytes.length)),kind,filePtr,entryPtr,options]);

  Marshal.FreeHGlobal(entryPtr); Marshal.FreeHGlobal(filePtr); Marshal.FreeHGlobal(srcPtr);

  if(result==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception(FN+": shaderc_compile_into_spv returned NULL");
  }

  var status:int=int(InvokeCdecl(dll,Type.GetType("System.Int32"),"shaderc_result_get_compilation_status",
    [Type.GetType("System.IntPtr")],[result]));
  DebugLog("  "+FN+": compilation status=" + status);

  if(status!=SHADERC_STATUS_SUCCESS){
    var errPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_error_message",
      [Type.GetType("System.IntPtr")],[result]);
    var errMsg:String=(errPtr==IntPtr.Zero)?"(no message)":Marshal.PtrToStringAnsi(errPtr);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception(FN+": compile FAILED (status="+status+"): "+errMsg);
  }

  var len:ulong=ulong(InvokeCdecl(dll,Type.GetType("System.UInt64"),"shaderc_result_get_length",
    [Type.GetType("System.IntPtr")],[result]));
  var bytesPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_bytes",
    [Type.GetType("System.IntPtr")],[result]);
  DebugLog("  "+FN+": SPIR-V bytes=" + len + " ptr=" + PtrHex(bytesPtr));

  if(bytesPtr==IntPtr.Zero || len==0){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception(FN+": empty SPIR-V result");
  }

  var outBytes:byte[]=new byte[int(len)];
  Marshal.Copy(bytesPtr,outBytes,0,int(len));

  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);

  DebugLog("  "+FN+": OK, SPIR-V size=" + outBytes.length);
  return outBytes;
}

// ===== Inline GLSL fallback =====

const VERT_GLSL =
"#version 450\n"+
"#extension GL_ARB_separate_shader_objects : enable\n"+
"layout(location = 0) out vec2 fragCoord;\n"+
"vec2 positions[3] = vec2[](\n"+
"    vec2(-1.0, -1.0),\n"+
"    vec2( 3.0, -1.0),\n"+
"    vec2(-1.0,  3.0)\n"+
");\n"+
"void main() {\n"+
"    vec2 pos = positions[gl_VertexIndex];\n"+
"    gl_Position = vec4(pos, 0.0, 1.0);\n"+
"    fragCoord = vec2(pos.x * 0.5 + 0.5, 1.0 - (pos.y * 0.5 + 0.5));\n"+
"}\n";

const FRAG_GLSL =
"#version 450\n"+
"#extension GL_ARB_separate_shader_objects : enable\n"+
"layout(location = 0) in vec2 fragCoord;\n"+
"layout(location = 0) out vec4 outColor;\n"+
"layout(push_constant) uniform PushConstants {\n"+
"    float iTime;\n"+
"    float padding;\n"+
"    vec2 iResolution;\n"+
"} pc;\n"+
"const int MAX_STEPS = 100;\n"+
"const float MAX_DIST = 100.0;\n"+
"const float SURF_DIST = 0.001;\n"+
"float sdSphere(vec3 p, float r) { return length(p) - r; }\n"+
"float sdTorus(vec3 p, vec2 t) {\n"+
"    vec2 q = vec2(length(p.xz) - t.x, p.y);\n"+
"    return length(q) - t.y;\n"+
"}\n"+
"float smin(float a, float b, float k) {\n"+
"    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);\n"+
"    return mix(b, a, h) - k * h * (1.0 - h);\n"+
"}\n"+
"float GetDist(vec3 p) {\n"+
"    float sphere = sdSphere(p - vec3(sin(pc.iTime) * 1.5, 0.5 + sin(pc.iTime * 2.0) * 0.3, 0.0), 0.5);\n"+
"    float angle = pc.iTime * 0.5;\n"+
"    vec3 tp = p - vec3(0.0, 0.5, 0.0);\n"+
"    float cosA = cos(angle), sinA = sin(angle);\n"+
"    vec2 rXZ = vec2(cosA*tp.x - sinA*tp.z, sinA*tp.x + cosA*tp.z);\n"+
"    tp.x = rXZ.x; tp.z = rXZ.y;\n"+
"    float a2 = angle * 0.7, cosA2 = cos(a2), sinA2 = sin(a2);\n"+
"    vec2 rXY = vec2(cosA2*tp.x - sinA2*tp.y, sinA2*tp.x + cosA2*tp.y);\n"+
"    tp.x = rXY.x; tp.y = rXY.y;\n"+
"    float torus = sdTorus(tp, vec2(0.8, 0.2));\n"+
"    float plane = p.y + 0.5;\n"+
"    return min(smin(sphere, torus, 0.3), plane);\n"+
"}\n"+
"float RayMarch(vec3 ro, vec3 rd) {\n"+
"    float d = 0.0;\n"+
"    for (int i = 0; i < MAX_STEPS; i++) {\n"+
"        float ds = GetDist(ro + rd * d);\n"+
"        d += ds;\n"+
"        if (d > MAX_DIST || ds < SURF_DIST) break;\n"+
"    }\n"+
"    return d;\n"+
"}\n"+
"vec3 GetNormal(vec3 p) {\n"+
"    float d = GetDist(p);\n"+
"    vec2 e = vec2(0.001, 0.0);\n"+
"    return normalize(d - vec3(GetDist(p-e.xyy), GetDist(p-e.yxy), GetDist(p-e.yyx)));\n"+
"}\n"+
"float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {\n"+
"    float res = 1.0; float t = mint;\n"+
"    for (int i = 0; i < 64; i++) {\n"+
"        if (t >= maxt) break;\n"+
"        float h = GetDist(ro + rd * t);\n"+
"        if (h < 0.001) return 0.0;\n"+
"        res = min(res, k * h / t); t += h;\n"+
"    }\n"+
"    return res;\n"+
"}\n"+
"float GetAO(vec3 p, vec3 n) {\n"+
"    float occ = 0.0, sca = 1.0;\n"+
"    for (int i = 0; i < 5; i++) {\n"+
"        float h = 0.01 + 0.12 * float(i) / 4.0;\n"+
"        occ += (h - GetDist(p + h * n)) * sca; sca *= 0.95;\n"+
"    }\n"+
"    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);\n"+
"}\n"+
"void main() {\n"+
"    vec2 uv = fragCoord - 0.5;\n"+
"    uv.x *= pc.iResolution.x / pc.iResolution.y;\n"+
"    vec3 ro = vec3(0.0, 1.5, -4.0);\n"+
"    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));\n"+
"    vec3 lightPos = vec3(3.0, 5.0, -2.0);\n"+
"    float d = RayMarch(ro, rd);\n"+
"    vec3 col = vec3(0.0);\n"+
"    if (d < MAX_DIST) {\n"+
"        vec3 p = ro + rd * d;\n"+
"        vec3 n = GetNormal(p);\n"+
"        vec3 l = normalize(lightPos - p);\n"+
"        vec3 r = reflect(-l, n);\n"+
"        vec3 matCol = (p.y < -0.49)\n"+
"            ? mix(vec3(0.2), vec3(0.8), mod(floor(p.x)+floor(p.z), 2.0))\n"+
"            : vec3(0.4, 0.6, 0.9);\n"+
"        float diff = max(dot(n,l),0.0);\n"+
"        float spec = pow(max(dot(r,normalize(ro-p)),0.0),32.0);\n"+
"        float ao = GetAO(p,n);\n"+
"        float shadow = GetShadow(p+n*0.01, l, 0.01, length(lightPos-p), 16.0);\n"+
"        col = matCol*(vec3(0.1,0.12,0.15)*ao + diff*shadow) + spec*shadow*0.5;\n"+
"        col = mix(col, vec3(0.05,0.05,0.1), 1.0-exp(-0.02*d*d));\n"+
"    } else {\n"+
"        col = mix(vec3(0.1,0.1,0.15), vec3(0.02,0.02,0.05), fragCoord.y);\n"+
"    }\n"+
"    outColor = vec4(pow(col, vec3(0.4545)), 1.0);\n"+
"}\n";

function ReadShaderText(fileName:String, fallback:String):String{
  try{
    var path=Path.Combine(Environment.CurrentDirectory, fileName);
    if(File.Exists(path)){
      DebugLog("  ReadShaderText: loaded from disk: " + path);
      return File.ReadAllText(path);
    }
    DebugLog("  ReadShaderText: not found on disk: " + path);
  }catch(ex){ DebugLog("  ReadShaderText: exception reading " + fileName + ": " + ex.Message); }
  DebugLog("  ReadShaderText: using inline GLSL fallback for " + fileName);
  return fallback;
}

// ===== Vulkan proc resolution =====

function VkGetProc(inst:IntPtr, name:String):IntPtr{
  var np=Marshal.StringToHGlobalAnsi(name);
  var r=IntPtr(createVulkanInvoker.InvokeMember("GetProc",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkGetInstanceProcAddr_ptr,inst,np]));
  Marshal.FreeHGlobal(np);
  return r;
}

function VkGetDevProc(dev:IntPtr, name:String):IntPtr{
  if(vkGetDeviceProcAddr_ptr==IntPtr.Zero){
    vkGetDeviceProcAddr_ptr=VkGetProc(vkInstance,"vkGetDeviceProcAddr");
    DebugLog("  vkGetDeviceProcAddr resolved: " + PtrHex(vkGetDeviceProcAddr_ptr));
  }
  var np=Marshal.StringToHGlobalAnsi(name);
  var r=IntPtr(createVulkanInvoker.InvokeMember("GetProc",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkGetDeviceProcAddr_ptr,dev,np]));
  Marshal.FreeHGlobal(np);
  return r;
}

function VK_Invoke(method:String, args:Object[]):Object{
  try{
    return createVulkanInvoker.InvokeMember(
      method,BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,args);
  }catch(e){
    DebugLog("VK_Invoke("+method+"): exception: "+e.ToString());
    throw e;
  }
}

// ===== Vulkan initialization functions =====

function LoadVulkan():Boolean{
  DebugLog(">>> LoadVulkan: start");

  Step("LoadVulkan","LoadLibrary(vulkan-1.dll)");
  var lib=LoadLibrary("vulkan-1.dll");
  if(lib==IntPtr.Zero){
    DebugLog("  **FAIL LoadVulkan: vulkan-1.dll not found. Is Vulkan runtime installed?");
    return false;
  }
  DebugLog("  LoadVulkan: vulkan-1.dll handle=" + PtrHex(lib));

  Step("LoadVulkan","GetProcAddress(vkGetInstanceProcAddr)");
  vkGetInstanceProcAddr_ptr=GetProcAddress(lib,"vkGetInstanceProcAddr");
  if(vkGetInstanceProcAddr_ptr==IntPtr.Zero){
    DebugLog("  **FAIL LoadVulkan: vkGetInstanceProcAddr not found");
    return false;
  }
  DebugLog("  LoadVulkan: vkGetInstanceProcAddr=" + PtrHex(vkGetInstanceProcAddr_ptr));

  Step("LoadVulkan","VkGetProc(null, vkCreateInstance)");
  vkCreateInstance_ptr=VkGetProc(IntPtr.Zero,"vkCreateInstance");
  if(vkCreateInstance_ptr==IntPtr.Zero){
    DebugLog("  **FAIL LoadVulkan: vkCreateInstance could not be resolved");
    return false;
  }
  DebugLog("  LoadVulkan: vkCreateInstance=" + PtrHex(vkCreateInstance_ptr));

  DebugLog(">>> LoadVulkan: OK");
  return true;
}

function LoadInstanceFunctions():void{
  DebugLog(">>> LoadInstanceFunctions: start");
  vkEnumeratePhysicalDevices_ptr=VkGetProc(vkInstance,"vkEnumeratePhysicalDevices");
  DebugLog("  vkEnumeratePhysicalDevices=" + PtrHex(vkEnumeratePhysicalDevices_ptr));
  vkGetPhysicalDeviceQueueFamilyProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceQueueFamilyProperties");
  DebugLog("  vkGetPhysicalDeviceQueueFamilyProperties=" + PtrHex(vkGetPhysicalDeviceQueueFamilyProperties_ptr));
  vkCreateDevice_ptr=VkGetProc(vkInstance,"vkCreateDevice");
  DebugLog("  vkCreateDevice=" + PtrHex(vkCreateDevice_ptr));
  vkCreateWin32SurfaceKHR_ptr=VkGetProc(vkInstance,"vkCreateWin32SurfaceKHR");
  DebugLog("  vkCreateWin32SurfaceKHR=" + PtrHex(vkCreateWin32SurfaceKHR_ptr));
  vkGetPhysicalDeviceMemoryProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceMemoryProperties");
  DebugLog("  vkGetPhysicalDeviceMemoryProperties=" + PtrHex(vkGetPhysicalDeviceMemoryProperties_ptr));
  DebugLog(">>> LoadInstanceFunctions: OK");
}

function LoadDeviceFunctions():void{
  DebugLog(">>> LoadDeviceFunctions: start");
  vkGetDeviceQueue_ptr=VkGetDevProc(vkDevice,"vkGetDeviceQueue");                   DebugLog("  vkGetDeviceQueue=" + PtrHex(vkGetDeviceQueue_ptr));
  vkCreateSwapchainKHR_ptr=VkGetDevProc(vkDevice,"vkCreateSwapchainKHR");           DebugLog("  vkCreateSwapchainKHR=" + PtrHex(vkCreateSwapchainKHR_ptr));
  vkGetSwapchainImagesKHR_ptr=VkGetDevProc(vkDevice,"vkGetSwapchainImagesKHR");     DebugLog("  vkGetSwapchainImagesKHR=" + PtrHex(vkGetSwapchainImagesKHR_ptr));
  vkCreateImageView_ptr=VkGetDevProc(vkDevice,"vkCreateImageView");                 DebugLog("  vkCreateImageView=" + PtrHex(vkCreateImageView_ptr));
  vkCreateShaderModule_ptr=VkGetDevProc(vkDevice,"vkCreateShaderModule");           DebugLog("  vkCreateShaderModule=" + PtrHex(vkCreateShaderModule_ptr));
  vkDestroyShaderModule_ptr=VkGetDevProc(vkDevice,"vkDestroyShaderModule");         DebugLog("  vkDestroyShaderModule=" + PtrHex(vkDestroyShaderModule_ptr));
  vkCreatePipelineLayout_ptr=VkGetDevProc(vkDevice,"vkCreatePipelineLayout");       DebugLog("  vkCreatePipelineLayout=" + PtrHex(vkCreatePipelineLayout_ptr));
  vkCreateRenderPass_ptr=VkGetDevProc(vkDevice,"vkCreateRenderPass");               DebugLog("  vkCreateRenderPass=" + PtrHex(vkCreateRenderPass_ptr));
  vkCreateGraphicsPipelines_ptr=VkGetDevProc(vkDevice,"vkCreateGraphicsPipelines"); DebugLog("  vkCreateGraphicsPipelines=" + PtrHex(vkCreateGraphicsPipelines_ptr));
  vkCreateFramebuffer_ptr=VkGetDevProc(vkDevice,"vkCreateFramebuffer");             DebugLog("  vkCreateFramebuffer=" + PtrHex(vkCreateFramebuffer_ptr));
  vkCreateCommandPool_ptr=VkGetDevProc(vkDevice,"vkCreateCommandPool");             DebugLog("  vkCreateCommandPool=" + PtrHex(vkCreateCommandPool_ptr));
  vkAllocateCommandBuffers_ptr=VkGetDevProc(vkDevice,"vkAllocateCommandBuffers");   DebugLog("  vkAllocateCommandBuffers=" + PtrHex(vkAllocateCommandBuffers_ptr));
  vkBeginCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkBeginCommandBuffer");           DebugLog("  vkBeginCommandBuffer=" + PtrHex(vkBeginCommandBuffer_ptr));
  vkEndCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkEndCommandBuffer");               DebugLog("  vkEndCommandBuffer=" + PtrHex(vkEndCommandBuffer_ptr));
  vkCmdBeginRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdBeginRenderPass");           DebugLog("  vkCmdBeginRenderPass=" + PtrHex(vkCmdBeginRenderPass_ptr));
  vkCmdEndRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdEndRenderPass");               DebugLog("  vkCmdEndRenderPass=" + PtrHex(vkCmdEndRenderPass_ptr));
  vkCmdBindPipeline_ptr=VkGetDevProc(vkDevice,"vkCmdBindPipeline");                 DebugLog("  vkCmdBindPipeline=" + PtrHex(vkCmdBindPipeline_ptr));
  vkCmdSetViewport_ptr=VkGetDevProc(vkDevice,"vkCmdSetViewport");                   DebugLog("  vkCmdSetViewport=" + PtrHex(vkCmdSetViewport_ptr));
  vkCmdSetScissor_ptr=VkGetDevProc(vkDevice,"vkCmdSetScissor");                     DebugLog("  vkCmdSetScissor=" + PtrHex(vkCmdSetScissor_ptr));
  vkCmdDraw_ptr=VkGetDevProc(vkDevice,"vkCmdDraw");                                 DebugLog("  vkCmdDraw=" + PtrHex(vkCmdDraw_ptr));
  vkCmdPushConstants_ptr=VkGetDevProc(vkDevice,"vkCmdPushConstants");               DebugLog("  vkCmdPushConstants=" + PtrHex(vkCmdPushConstants_ptr));
  vkCreateSemaphore_ptr=VkGetDevProc(vkDevice,"vkCreateSemaphore");                 DebugLog("  vkCreateSemaphore=" + PtrHex(vkCreateSemaphore_ptr));
  vkCreateFence_ptr=VkGetDevProc(vkDevice,"vkCreateFence");                         DebugLog("  vkCreateFence=" + PtrHex(vkCreateFence_ptr));
  vkWaitForFences_ptr=VkGetDevProc(vkDevice,"vkWaitForFences");                     DebugLog("  vkWaitForFences=" + PtrHex(vkWaitForFences_ptr));
  vkResetFences_ptr=VkGetDevProc(vkDevice,"vkResetFences");                         DebugLog("  vkResetFences=" + PtrHex(vkResetFences_ptr));
  vkAcquireNextImageKHR_ptr=VkGetDevProc(vkDevice,"vkAcquireNextImageKHR");         DebugLog("  vkAcquireNextImageKHR=" + PtrHex(vkAcquireNextImageKHR_ptr));
  vkQueueSubmit_ptr=VkGetDevProc(vkDevice,"vkQueueSubmit");                         DebugLog("  vkQueueSubmit=" + PtrHex(vkQueueSubmit_ptr));
  vkQueuePresentKHR_ptr=VkGetDevProc(vkDevice,"vkQueuePresentKHR");                 DebugLog("  vkQueuePresentKHR=" + PtrHex(vkQueuePresentKHR_ptr));
  vkDeviceWaitIdle_ptr=VkGetDevProc(vkDevice,"vkDeviceWaitIdle");                   DebugLog("  vkDeviceWaitIdle=" + PtrHex(vkDeviceWaitIdle_ptr));
  vkResetCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkResetCommandBuffer");           DebugLog("  vkResetCommandBuffer=" + PtrHex(vkResetCommandBuffer_ptr));
  DebugLog(">>> LoadDeviceFunctions: OK");
}

function CreateVulkanInstance():Boolean{
  DebugLog(">>> CreateVulkanInstance: start");

  var appName=Marshal.StringToHGlobalAnsi("Ray March Demo");
  var engName=Marshal.StringToHGlobalAnsi("No Engine");
  var ext1=Marshal.StringToHGlobalAnsi("VK_KHR_surface");
  var ext2=Marshal.StringToHGlobalAnsi("VK_KHR_win32_surface");

  var appInfo=Marshal.AllocHGlobal(48);
  ClearMem(appInfo,48);
  Marshal.WriteInt32(appInfo,0,VK_STRUCTURE_TYPE_APPLICATION_INFO);
  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?16:8,appName);
  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?32:16,engName);
  Marshal.WriteInt32(appInfo,(IntPtr.Size==8)?44:24,VK_API_VERSION_1_4);
  DebugLog("  CreateVulkanInstance: apiVersion=VK_API_VERSION_1_4 (0x" + VK_API_VERSION_1_4.toString(16) + ")");

  var extArr=Marshal.AllocHGlobal(int(IntPtr.Size*2));
  Marshal.WriteIntPtr(extArr,0,ext1);
  Marshal.WriteIntPtr(extArr,IntPtr.Size,ext2);

  var createInfo=Marshal.AllocHGlobal(64);
  ClearMem(createInfo,64);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(createInfo,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(createInfo,24,appInfo);
    Marshal.WriteInt32(createInfo,48,2); // extensionCount
    Marshal.WriteIntPtr(createInfo,56,extArr);
  } else {
    Marshal.WriteInt32(createInfo,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(createInfo,12,appInfo);
    Marshal.WriteInt32(createInfo,24,2);
    Marshal.WriteIntPtr(createInfo,28,extArr);
  }

  Step("CreateVulkanInstance","vkCreateInstance");
  var instPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  var result=int(VK_Invoke("Create3",[vkCreateInstance_ptr,createInfo,IntPtr.Zero,instPtr]));

  if(VkCheck(result,"CreateVulkanInstance","vkCreateInstance"))
    vkInstance=Marshal.ReadIntPtr(instPtr);
  DebugLog("  CreateVulkanInstance: vkInstance=" + PtrHex(vkInstance));

  Marshal.FreeHGlobal(instPtr); Marshal.FreeHGlobal(createInfo); Marshal.FreeHGlobal(appInfo);
  Marshal.FreeHGlobal(extArr); Marshal.FreeHGlobal(ext1); Marshal.FreeHGlobal(ext2);
  Marshal.FreeHGlobal(appName); Marshal.FreeHGlobal(engName);

  DebugLog(">>> CreateVulkanInstance: " + (result==VK_SUCCESS ? "OK" : "FAILED"));
  return result==VK_SUCCESS;
}

function SelectPhysicalDevice():Boolean{
  DebugLog(">>> SelectPhysicalDevice: start");
  var cntPtr=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(cntPtr,0,0);
  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,IntPtr.Zero]);
  var cnt=Marshal.ReadInt32(cntPtr);
  DebugLog("  SelectPhysicalDevice: device count=" + cnt);
  if(cnt==0){
    DebugLog("  **FAIL SelectPhysicalDevice: no Vulkan-capable physical devices found");
    Marshal.FreeHGlobal(cntPtr); return false;
  }
  var devs=Marshal.AllocHGlobal(int(IntPtr.Size*cnt));
  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,devs]);
  vkPhysicalDevice=Marshal.ReadIntPtr(devs);
  DebugLog("  SelectPhysicalDevice: using first device handle=" + PtrHex(vkPhysicalDevice));
  Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(devs);
  DebugLog(">>> SelectPhysicalDevice: OK");
  return true;
}

function FindGraphicsQueueFamily():Boolean{
  DebugLog(">>> FindGraphicsQueueFamily: start");
  var cntPtr=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(cntPtr,0,0);
  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,IntPtr.Zero]);
  var cnt=Marshal.ReadInt32(cntPtr);
  DebugLog("  FindGraphicsQueueFamily: queue family count=" + cnt);
  var props=Marshal.AllocHGlobal(int(24*cnt));
  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,props]);
  for(var i=0; i<cnt; i++){
    var flags=Marshal.ReadInt32(props,i*24);
    DebugLog("  FindGraphicsQueueFamily: family[" + i + "] flags=0x" + flags.toString(16));
    if((flags&VK_QUEUE_GRAPHICS_BIT)!=0){
      vkGraphicsQueueFamilyIndex=uint(i);
      DebugLog("  FindGraphicsQueueFamily: selected family index=" + i);
      Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(props);
      DebugLog(">>> FindGraphicsQueueFamily: OK");
      return true;
    }
  }
  DebugLog("  **FAIL FindGraphicsQueueFamily: no graphics queue family found");
  Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(props);
  return false;
}

function CreateLogicalDevice():Boolean{
  DebugLog(">>> CreateLogicalDevice: start (queueFamily=" + vkGraphicsQueueFamilyIndex + ")");

  var priority=Marshal.AllocHGlobal(4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,priority,4);

  var queueInfo=Marshal.AllocHGlobal(40);
  ClearMem(queueInfo,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(queueInfo,0,VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    Marshal.WriteInt32(queueInfo,20,int(vkGraphicsQueueFamilyIndex));
    Marshal.WriteInt32(queueInfo,24,1);
    Marshal.WriteIntPtr(queueInfo,32,priority);
  } else {
    Marshal.WriteInt32(queueInfo,0,VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    Marshal.WriteInt32(queueInfo,12,int(vkGraphicsQueueFamilyIndex));
    Marshal.WriteInt32(queueInfo,16,1);
    Marshal.WriteIntPtr(queueInfo,20,priority);
  }

  var swapExt=Marshal.StringToHGlobalAnsi("VK_KHR_swapchain");
  var extArr=Marshal.AllocHGlobal(int(IntPtr.Size));
  Marshal.WriteIntPtr(extArr,0,swapExt);

  var devInfo=Marshal.AllocHGlobal(72);
  ClearMem(devInfo,72);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(devInfo,0,VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    Marshal.WriteInt32(devInfo,20,1); Marshal.WriteIntPtr(devInfo,24,queueInfo);
    Marshal.WriteInt32(devInfo,48,1); Marshal.WriteIntPtr(devInfo,56,extArr);
  } else {
    Marshal.WriteInt32(devInfo,0,VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    Marshal.WriteInt32(devInfo,12,1); Marshal.WriteIntPtr(devInfo,16,queueInfo);
    Marshal.WriteInt32(devInfo,28,1); Marshal.WriteIntPtr(devInfo,32,extArr);
  }

  Step("CreateLogicalDevice","vkCreateDevice");
  var devPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  var result=int(VK_Invoke("Create4",[vkCreateDevice_ptr,vkPhysicalDevice,devInfo,IntPtr.Zero,devPtr]));

  if(VkCheck(result,"CreateLogicalDevice","vkCreateDevice"))
    vkDevice=Marshal.ReadIntPtr(devPtr);
  DebugLog("  CreateLogicalDevice: vkDevice=" + PtrHex(vkDevice));

  Marshal.FreeHGlobal(devPtr); Marshal.FreeHGlobal(devInfo); Marshal.FreeHGlobal(queueInfo);
  Marshal.FreeHGlobal(priority); Marshal.FreeHGlobal(extArr); Marshal.FreeHGlobal(swapExt);

  DebugLog(">>> CreateLogicalDevice: " + (result==VK_SUCCESS ? "OK" : "FAILED"));
  return result==VK_SUCCESS;
}

function GetGraphicsQueue():void{
  DebugLog(">>> GetGraphicsQueue: start");
  var qPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  VK_Invoke("Void4",[vkGetDeviceQueue_ptr,vkDevice,uint(vkGraphicsQueueFamilyIndex),uint(0),qPtr]);
  vkGraphicsQueue=Marshal.ReadIntPtr(qPtr);
  Marshal.FreeHGlobal(qPtr);
  DebugLog("  GetGraphicsQueue: vkGraphicsQueue=" + PtrHex(vkGraphicsQueue));
  DebugLog(">>> GetGraphicsQueue: OK");
}

function CreateWin32Surface(hInst:IntPtr, hWnd:IntPtr):Boolean{
  DebugLog(">>> CreateWin32Surface: start (hInst=" + PtrHex(hInst) + " hWnd=" + PtrHex(hWnd) + ")");
  var ci=Marshal.AllocHGlobal(40);
  ClearMem(ci,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,24,hInst); Marshal.WriteIntPtr(ci,32,hWnd);
  } else {
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,12,hInst); Marshal.WriteIntPtr(ci,16,hWnd);
  }
  var sPtr=Marshal.AllocHGlobal(8);
  Step("CreateWin32Surface","vkCreateWin32SurfaceKHR");
  var r=int(VK_Invoke("Create4",[vkCreateWin32SurfaceKHR_ptr,vkInstance,ci,IntPtr.Zero,sPtr]));
  if(VkCheck(r,"CreateWin32Surface","vkCreateWin32SurfaceKHR"))
    vkSurface=ReadU64(sPtr,0);
  DebugLog("  CreateWin32Surface: vkSurface=0x" + vkSurface.toString(16));
  Marshal.FreeHGlobal(sPtr); Marshal.FreeHGlobal(ci);
  DebugLog(">>> CreateWin32Surface: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

function CreateSwapchain():Boolean{
  DebugLog(">>> CreateSwapchain: start (w=" + windowWidth + " h=" + windowHeight + ")");
  var ci=Marshal.AllocHGlobal(104);
  ClearMem(ci,104);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,24,vkSurface);
    Marshal.WriteInt32(ci,32,2);
    Marshal.WriteInt32(ci,36,VK_FORMAT_B8G8R8A8_SRGB);
    Marshal.WriteInt32(ci,40,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
    Marshal.WriteInt32(ci,44,int(windowWidth)); Marshal.WriteInt32(ci,48,int(windowHeight));
    Marshal.WriteInt32(ci,52,1);
    Marshal.WriteInt32(ci,56,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);
    Marshal.WriteInt32(ci,60,VK_SHARING_MODE_EXCLUSIVE);
    Marshal.WriteInt32(ci,80,1);
    Marshal.WriteInt32(ci,84,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR);
    Marshal.WriteInt32(ci,88,VK_PRESENT_MODE_FIFO_KHR);
    Marshal.WriteInt32(ci,92,1);
  } else {
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,12,vkSurface);
    Marshal.WriteInt32(ci,20,2); Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB);
    Marshal.WriteInt32(ci,28,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
    Marshal.WriteInt32(ci,32,int(windowWidth)); Marshal.WriteInt32(ci,36,int(windowHeight));
    Marshal.WriteInt32(ci,40,1); Marshal.WriteInt32(ci,44,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);
    Marshal.WriteInt32(ci,48,VK_SHARING_MODE_EXCLUSIVE); Marshal.WriteInt32(ci,60,1);
    Marshal.WriteInt32(ci,64,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR);
    Marshal.WriteInt32(ci,68,VK_PRESENT_MODE_FIFO_KHR); Marshal.WriteInt32(ci,72,1);
  }
  var scPtr=Marshal.AllocHGlobal(8);
  Step("CreateSwapchain","vkCreateSwapchainKHR");
  var r=int(VK_Invoke("Create4",[vkCreateSwapchainKHR_ptr,vkDevice,ci,IntPtr.Zero,scPtr]));
  if(VkCheck(r,"CreateSwapchain","vkCreateSwapchainKHR"))
    vkSwapchain=ReadU64(scPtr,0);
  DebugLog("  CreateSwapchain: vkSwapchain=0x" + vkSwapchain.toString(16));
  Marshal.FreeHGlobal(scPtr); Marshal.FreeHGlobal(ci);
  DebugLog(">>> CreateSwapchain: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

function GetSwapchainImages():Boolean{
  DebugLog(">>> GetSwapchainImages: start");
  var cntPtr=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(cntPtr,0,0);
  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,IntPtr.Zero]);
  vkSwapchainImageCount=uint(Marshal.ReadInt32(cntPtr));
  DebugLog("  GetSwapchainImages: image count=" + vkSwapchainImageCount);
  var imgBuf=Marshal.AllocHGlobal(int(8*vkSwapchainImageCount));
  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,imgBuf]);
  vkSwapchainImages=new ulong[vkSwapchainImageCount];
  for(var i:uint=0; i<vkSwapchainImageCount; i++){
    vkSwapchainImages[i]=ReadU64(imgBuf,int(i*8));
    DebugLog("  GetSwapchainImages: image[" + i + "]=0x" + vkSwapchainImages[i].toString(16));
  }
  Marshal.FreeHGlobal(imgBuf); Marshal.FreeHGlobal(cntPtr);
  DebugLog(">>> GetSwapchainImages: OK");
  return true;
}

function CreateImageViews():Boolean{
  DebugLog(">>> CreateImageViews: start (count=" + vkSwapchainImageCount + ")");
  vkSwapchainImageViews=new ulong[vkSwapchainImageCount];

  // VkImageViewCreateInfo x64 layout:
  //   0:  sType (int32)
  //   4:  pad
  //   8:  pNext (ptr 8b)
  //  16:  flags (int32)
  //  20:  pad
  //  24:  image (uint64)
  //  32:  viewType (int32)
  //  36:  format (int32)
  //  40:  components.r/g/b/a (4 x int32 = 16b, all 0 = IDENTITY)
  //  56:  subresourceRange.aspectMask (int32)
  //  60:  subresourceRange.baseMipLevel (int32)
  //  64:  subresourceRange.levelCount (int32)
  //  68:  subresourceRange.baseArrayLayer (int32)
  //  72:  subresourceRange.layerCount (int32)
  // total: 76 bytes -> allocate 80
  //
  // VkImageViewCreateInfo x86 layout:
  //   0:  sType
  //   4:  pNext (ptr 4b)
  //   8:  flags
  //  12:  image (uint64)
  //  20:  viewType
  //  24:  format
  //  28:  components (16b)
  //  44:  aspectMask
  //  48:  baseMipLevel
  //  52:  levelCount
  //  56:  baseArrayLayer
  //  60:  layerCount
  // total: 64 bytes -> allocate 80 is fine

  var ci=Marshal.AllocHGlobal(80);
  for(var i:uint=0; i<vkSwapchainImageCount; i++){
    ClearMem(ci,80);
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
    if(IntPtr.Size==8){
      WriteU64(ci,24,vkSwapchainImages[i]);          // image
      Marshal.WriteInt32(ci,32,VK_IMAGE_VIEW_TYPE_2D); // viewType
      Marshal.WriteInt32(ci,36,VK_FORMAT_B8G8R8A8_SRGB); // format
      // components all 0 (IDENTITY) - already zeroed by ClearMem
      Marshal.WriteInt32(ci,56,VK_IMAGE_ASPECT_COLOR_BIT); // aspectMask
      Marshal.WriteInt32(ci,60,0);  // baseMipLevel
      Marshal.WriteInt32(ci,64,1);  // levelCount
      Marshal.WriteInt32(ci,68,0);  // baseArrayLayer
      Marshal.WriteInt32(ci,72,1);  // layerCount
    } else {
      WriteU64(ci,12,vkSwapchainImages[i]);          // image (uint64 at offset 12)
      Marshal.WriteInt32(ci,20,VK_IMAGE_VIEW_TYPE_2D); // viewType
      Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB); // format
      // components: 28..43 = 0 (IDENTITY)
      Marshal.WriteInt32(ci,44,VK_IMAGE_ASPECT_COLOR_BIT); // aspectMask
      Marshal.WriteInt32(ci,48,0);  // baseMipLevel
      Marshal.WriteInt32(ci,52,1);  // levelCount
      Marshal.WriteInt32(ci,56,0);  // baseArrayLayer
      Marshal.WriteInt32(ci,60,1);  // layerCount
    }
    DebugLog("  CreateImageViews[" + i + "]: image=0x" + vkSwapchainImages[i].toString(16)
      + " fmt=" + VK_FORMAT_B8G8R8A8_SRGB + " aspect=" + VK_IMAGE_ASPECT_COLOR_BIT);
    var ivPtr=Marshal.AllocHGlobal(8);
    var r=int(VK_Invoke("Create4",[vkCreateImageView_ptr,vkDevice,ci,IntPtr.Zero,ivPtr]));
    if(!VkCheck(r,"CreateImageViews","vkCreateImageView[" + i + "]")){
      Marshal.FreeHGlobal(ivPtr); Marshal.FreeHGlobal(ci); return false;
    }
    vkSwapchainImageViews[i]=ReadU64(ivPtr,0);
    DebugLog("  CreateImageViews: view[" + i + "]=0x" + vkSwapchainImageViews[i].toString(16));
    Marshal.FreeHGlobal(ivPtr);
  }
  Marshal.FreeHGlobal(ci);
  DebugLog(">>> CreateImageViews: OK");
  return true;
}

function CreateShaderModule(spirv:byte[], label:String):ulong{
  DebugLog("  CreateShaderModule("+label+"): spirv bytes=" + spirv.length);
  if(spirv==null || (spirv.length%4)!=0){
    DebugLog("  **FAIL CreateShaderModule("+label+"): invalid SPIR-V (null or not 4-byte aligned, len=" + (spirv==null?-1:spirv.length) + ")");
    return 0;
  }
  var handle=GCHandle.Alloc(spirv, GCHandleType.Pinned);
  var codePtr=handle.AddrOfPinnedObject();
  // Verify SPIR-V magic number (0x07230203)
  var magic=uint(Marshal.ReadInt32(codePtr,0));
  DebugLog("  CreateShaderModule("+label+"): SPIR-V magic=0x" + magic.toString(16) + (magic==0x07230203?" (OK)":" *** WRONG MAGIC! ***"));

  var ci=Marshal.AllocHGlobal(40);
  ClearMem(ci,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    WriteU64(ci,24,ulong(spirv.length));
    Marshal.WriteIntPtr(ci,32,codePtr);
  } else {
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    Marshal.WriteInt32(ci,12,spirv.length);
    Marshal.WriteIntPtr(ci,16,codePtr);
  }
  var modPtr=Marshal.AllocHGlobal(8);
  // Call directly from vulkan-1.dll to bypass function pointer wrapping issues
  var r:int=int(InvokeWin32("vulkan-1.dll",Type.GetType("System.Int32"),"vkCreateShaderModule",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),
     Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr")],
    [vkDevice,ci,IntPtr.Zero,modPtr]));
  var mod:ulong=(r==VK_SUCCESS)?ReadU64(modPtr,0):0;
  VkCheck(r,"CreateShaderModule("+label+")","vkCreateShaderModule");
  DebugLog("  CreateShaderModule("+label+"): handle=0x" + mod.toString(16));
  Marshal.FreeHGlobal(modPtr); Marshal.FreeHGlobal(ci); handle.Free();
  return mod;
}

function CreateRenderPass():Boolean{
  DebugLog(">>> CreateRenderPass: start");

  var attach=Marshal.AllocHGlobal(36);
  ClearMem(attach,36);
  Marshal.WriteInt32(attach,4,VK_FORMAT_B8G8R8A8_SRGB);
  Marshal.WriteInt32(attach,8,VK_SAMPLE_COUNT_1_BIT);
  Marshal.WriteInt32(attach,12,VK_ATTACHMENT_LOAD_OP_CLEAR);
  Marshal.WriteInt32(attach,16,VK_ATTACHMENT_STORE_OP_STORE);
  Marshal.WriteInt32(attach,20,VK_ATTACHMENT_LOAD_OP_DONT_CARE);
  Marshal.WriteInt32(attach,24,VK_ATTACHMENT_STORE_OP_DONT_CARE);
  Marshal.WriteInt32(attach,28,VK_IMAGE_LAYOUT_UNDEFINED);
  Marshal.WriteInt32(attach,32,VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);

  var colorRef=Marshal.AllocHGlobal(8);
  Marshal.WriteInt32(colorRef,0,0);
  Marshal.WriteInt32(colorRef,4,VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

  var subpass=Marshal.AllocHGlobal(72);
  ClearMem(subpass,72);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(subpass,4,VK_PIPELINE_BIND_POINT_GRAPHICS);
    Marshal.WriteInt32(subpass,24,1); Marshal.WriteIntPtr(subpass,32,colorRef);
  } else {
    Marshal.WriteInt32(subpass,4,VK_PIPELINE_BIND_POINT_GRAPHICS);
    Marshal.WriteInt32(subpass,16,1); Marshal.WriteIntPtr(subpass,20,colorRef);
  }

  var dep=Marshal.AllocHGlobal(28);
  Marshal.WriteInt32(dep,0,-1); Marshal.WriteInt32(dep,4,0);
  Marshal.WriteInt32(dep,8,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  Marshal.WriteInt32(dep,12,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  Marshal.WriteInt32(dep,16,0); Marshal.WriteInt32(dep,20,VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);

  var ci=Marshal.AllocHGlobal(64);
  ClearMem(ci,64);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,attach);
    Marshal.WriteInt32(ci,32,1); Marshal.WriteIntPtr(ci,40,subpass);
    Marshal.WriteInt32(ci,48,1); Marshal.WriteIntPtr(ci,56,dep);
  } else {
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,12,1); Marshal.WriteIntPtr(ci,16,attach);
    Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,subpass);
    Marshal.WriteInt32(ci,28,1); Marshal.WriteIntPtr(ci,32,dep);
  }

  var rpPtr=Marshal.AllocHGlobal(8);
  Step("CreateRenderPass","vkCreateRenderPass");
  var r=int(VK_Invoke("Create4",[vkCreateRenderPass_ptr,vkDevice,ci,IntPtr.Zero,rpPtr]));
  if(VkCheck(r,"CreateRenderPass","vkCreateRenderPass"))
    vkRenderPass=ReadU64(rpPtr,0);
  DebugLog("  CreateRenderPass: handle=0x" + vkRenderPass.toString(16));

  Marshal.FreeHGlobal(rpPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(dep);
  Marshal.FreeHGlobal(subpass); Marshal.FreeHGlobal(colorRef); Marshal.FreeHGlobal(attach);
  DebugLog(">>> CreateRenderPass: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

// Create pipeline layout with a 16-byte push constant range for the fragment shader
function CreatePipelineLayout():Boolean{
  DebugLog(">>> CreatePipelineLayout: start (pushConstantSize=" + PUSH_CONSTANT_SIZE + " bytes)");

  // VkPushConstantRange { stageFlags, offset, size }
  var pcRange=Marshal.AllocHGlobal(12);
  Marshal.WriteInt32(pcRange,0,VK_SHADER_STAGE_FRAGMENT_BIT);
  Marshal.WriteInt32(pcRange,4,0);
  Marshal.WriteInt32(pcRange,8,PUSH_CONSTANT_SIZE);
  DebugLog("  CreatePipelineLayout: VkPushConstantRange stageFlags=" + VK_SHADER_STAGE_FRAGMENT_BIT + " offset=0 size=" + PUSH_CONSTANT_SIZE);

  var ci=Marshal.AllocHGlobal(48);
  ClearMem(ci,48);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,32,1); Marshal.WriteIntPtr(ci,40,pcRange);
  } else {
    Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,pcRange);
  }

  var plPtr=Marshal.AllocHGlobal(8);
  Step("CreatePipelineLayout","vkCreatePipelineLayout");
  var r=int(VK_Invoke("Create4",[vkCreatePipelineLayout_ptr,vkDevice,ci,IntPtr.Zero,plPtr]));
  if(VkCheck(r,"CreatePipelineLayout","vkCreatePipelineLayout"))
    vkPipelineLayout=ReadU64(plPtr,0);
  DebugLog("  CreatePipelineLayout: handle=0x" + vkPipelineLayout.toString(16));

  Marshal.FreeHGlobal(plPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(pcRange);
  DebugLog(">>> CreatePipelineLayout: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

// Compile shaders at runtime and create the graphics pipeline
function CreateGraphicsPipeline():Boolean{
  DebugLog(">>> CreateGraphicsPipeline: start");

  // -- Shader compilation --
  DebugLog("  CreateGraphicsPipeline: reading shader sources");
  var vertSrc=ReadShaderText("hello.vert", VERT_GLSL);
  var fragSrc=ReadShaderText("hello.frag", FRAG_GLSL);

  DebugLog("  CreateGraphicsPipeline: compiling vertex shader (len=" + vertSrc.length + ")");
  var vertSpv:byte[]=null;
  try{ vertSpv=ShadercCompile(vertSrc,SHADERC_SHADER_KIND_VERTEX,"hello.vert","main"); }
  catch(ex){ DebugLog("  **FAIL CreateGraphicsPipeline: vert compile: " + ex.ToString()); return false; }

  DebugLog("  CreateGraphicsPipeline: compiling fragment shader (len=" + fragSrc.length + ")");
  var fragSpv:byte[]=null;
  try{ fragSpv=ShadercCompile(fragSrc,SHADERC_SHADER_KIND_FRAGMENT,"hello.frag","main"); }
  catch(ex){ DebugLog("  **FAIL CreateGraphicsPipeline: frag compile: " + ex.ToString()); return false; }

  DebugLog("  CreateGraphicsPipeline: SPIR-V sizes vert=" + vertSpv.length + " frag=" + fragSpv.length);

  // -- Shader modules --
  Step("CreateGraphicsPipeline","CreateShaderModule(vert)");
  var vertMod=CreateShaderModule(vertSpv,"vert");
  Step("CreateGraphicsPipeline","CreateShaderModule(frag)");
  var fragMod=CreateShaderModule(fragSpv,"frag");

  if(vertMod==0 || fragMod==0){
    DebugLog("  **FAIL CreateGraphicsPipeline: shader module creation failed (vert=0x" + vertMod.toString(16) + " frag=0x" + fragMod.toString(16) + ")");
    return false;
  }

  var mainName=Marshal.StringToHGlobalAnsi("main");
  var stageSize=(IntPtr.Size==8)?48:32;
  var stages=Marshal.AllocHGlobal(int(stageSize*2));
  ClearMem(stages,stageSize*2);

  // Vertex stage
  Marshal.WriteInt32(stages,0,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
  Marshal.WriteInt32(stages,(IntPtr.Size==8)?20:12,VK_SHADER_STAGE_VERTEX_BIT);
  WriteU64(stages,(IntPtr.Size==8)?24:16,vertMod);
  Marshal.WriteIntPtr(stages,(IntPtr.Size==8)?32:24,mainName);

  // Fragment stage
  Marshal.WriteInt32(stages,stageSize,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
  Marshal.WriteInt32(stages,stageSize+((IntPtr.Size==8)?20:12),VK_SHADER_STAGE_FRAGMENT_BIT);
  WriteU64(stages,stageSize+((IntPtr.Size==8)?24:16),fragMod);
  Marshal.WriteIntPtr(stages,stageSize+((IntPtr.Size==8)?32:24),mainName);
  DebugLog("  CreateGraphicsPipeline: shader stages configured");

  // Vertex input: empty (gl_VertexIndex used in shader)
  var vertexInput=Marshal.AllocHGlobal(48);
  ClearMem(vertexInput,48);
  Marshal.WriteInt32(vertexInput,0,VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);
  DebugLog("  CreateGraphicsPipeline: vertex input = empty (fullscreen triangle)");

  // Input assembly
  var inputAsm=Marshal.AllocHGlobal(32);
  ClearMem(inputAsm,32);
  Marshal.WriteInt32(inputAsm,0,VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);
  Marshal.WriteInt32(inputAsm,(IntPtr.Size==8)?20:12,VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);

  // Viewport state (dynamic)
  var viewportState=Marshal.AllocHGlobal(48);
  ClearMem(viewportState,48);
  Marshal.WriteInt32(viewportState,0,VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);
  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?20:12,1);
  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?32:20,1);

  // Rasterization: no culling (full-screen triangle)
  var raster=Marshal.AllocHGlobal(64);
  ClearMem(raster,64);
  Marshal.WriteInt32(raster,0,VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?28:20,VK_POLYGON_MODE_FILL);
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?32:24,VK_CULL_MODE_NONE);
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?36:28,VK_FRONT_FACE_COUNTER_CLOCKWISE);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,IntPtr.Add(raster,int((IntPtr.Size==8)?56:48)),4);
  DebugLog("  CreateGraphicsPipeline: rasterizer cullMode=NONE");

  // Multisample
  var multisample=Marshal.AllocHGlobal(48);
  ClearMem(multisample,48);
  Marshal.WriteInt32(multisample,0,VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);
  Marshal.WriteInt32(multisample,(IntPtr.Size==8)?20:12,VK_SAMPLE_COUNT_1_BIT);

  // Color blend (passthrough)
  var blendAttach=Marshal.AllocHGlobal(32);
  ClearMem(blendAttach,32);
  Marshal.WriteInt32(blendAttach,28,VK_COLOR_COMPONENT_RGBA);
  var colorBlend=Marshal.AllocHGlobal(56);
  ClearMem(colorBlend,56);
  Marshal.WriteInt32(colorBlend,0,VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(colorBlend,28,1); Marshal.WriteIntPtr(colorBlend,32,blendAttach); }
  else              { Marshal.WriteInt32(colorBlend,20,1); Marshal.WriteIntPtr(colorBlend,24,blendAttach); }

  // Dynamic state
  var dynStates=Marshal.AllocHGlobal(8);
  Marshal.WriteInt32(dynStates,0,VK_DYNAMIC_STATE_VIEWPORT);
  Marshal.WriteInt32(dynStates,4,VK_DYNAMIC_STATE_SCISSOR);
  var dynState=Marshal.AllocHGlobal(32);
  ClearMem(dynState,32);
  Marshal.WriteInt32(dynState,0,VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(dynState,20,2); Marshal.WriteIntPtr(dynState,24,dynStates); }
  else              { Marshal.WriteInt32(dynState,12,2); Marshal.WriteIntPtr(dynState,16,dynStates); }

  // Pipeline create info
  var pipeInfo=Marshal.AllocHGlobal(144);
  ClearMem(pipeInfo,144);
  Marshal.WriteInt32(pipeInfo,0,VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(pipeInfo,20,2);  Marshal.WriteIntPtr(pipeInfo,24,stages);
    Marshal.WriteIntPtr(pipeInfo,32,vertexInput); Marshal.WriteIntPtr(pipeInfo,40,inputAsm);
    Marshal.WriteIntPtr(pipeInfo,56,viewportState); Marshal.WriteIntPtr(pipeInfo,64,raster);
    Marshal.WriteIntPtr(pipeInfo,72,multisample); Marshal.WriteIntPtr(pipeInfo,88,colorBlend);
    Marshal.WriteIntPtr(pipeInfo,96,dynState);
    WriteU64(pipeInfo,104,vkPipelineLayout); WriteU64(pipeInfo,112,vkRenderPass);
    Marshal.WriteInt32(pipeInfo,136,-1);
  } else {
    Marshal.WriteInt32(pipeInfo,12,2); Marshal.WriteIntPtr(pipeInfo,16,stages);
    Marshal.WriteIntPtr(pipeInfo,20,vertexInput); Marshal.WriteIntPtr(pipeInfo,24,inputAsm);
    Marshal.WriteIntPtr(pipeInfo,32,viewportState); Marshal.WriteIntPtr(pipeInfo,36,raster);
    Marshal.WriteIntPtr(pipeInfo,40,multisample); Marshal.WriteIntPtr(pipeInfo,48,colorBlend);
    Marshal.WriteIntPtr(pipeInfo,52,dynState);
    WriteU64(pipeInfo,56,vkPipelineLayout); WriteU64(pipeInfo,64,vkRenderPass);
    Marshal.WriteInt32(pipeInfo,84,-1);
  }
  DebugLog("  CreateGraphicsPipeline: pipelineLayout=0x" + vkPipelineLayout.toString(16) + " renderPass=0x" + vkRenderPass.toString(16));

  var pipePtr=Marshal.AllocHGlobal(8);
  Step("CreateGraphicsPipeline","vkCreateGraphicsPipelines");
  var r=int(createVulkanInvoker.InvokeMember("CreatePipe",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateGraphicsPipelines_ptr,vkDevice,ulong(0),uint(1),pipeInfo,IntPtr.Zero,pipePtr]));
  if(VkCheck(r,"CreateGraphicsPipeline","vkCreateGraphicsPipelines"))
    vkGraphicsPipeline=ReadU64(pipePtr,0);
  DebugLog("  CreateGraphicsPipeline: pipeline=0x" + vkGraphicsPipeline.toString(16));

  // Shader modules no longer needed after pipeline creation
  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkDestroyShaderModule_ptr,vkDevice,vertMod,IntPtr.Zero]);
  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkDestroyShaderModule_ptr,vkDevice,fragMod,IntPtr.Zero]);
  DebugLog("  CreateGraphicsPipeline: shader modules destroyed");

  Marshal.FreeHGlobal(pipePtr); Marshal.FreeHGlobal(pipeInfo);
  Marshal.FreeHGlobal(dynState); Marshal.FreeHGlobal(dynStates);
  Marshal.FreeHGlobal(colorBlend); Marshal.FreeHGlobal(blendAttach);
  Marshal.FreeHGlobal(multisample); Marshal.FreeHGlobal(raster);
  Marshal.FreeHGlobal(viewportState); Marshal.FreeHGlobal(inputAsm);
  Marshal.FreeHGlobal(vertexInput); Marshal.FreeHGlobal(stages); Marshal.FreeHGlobal(mainName);

  DebugLog(">>> CreateGraphicsPipeline: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

function CreateFramebuffers():Boolean{
  DebugLog(">>> CreateFramebuffers: start (count=" + vkSwapchainImageCount + ")");
  vkFramebuffers=new ulong[vkSwapchainImageCount];
  var ci=Marshal.AllocHGlobal(64);
  var attachPtr=Marshal.AllocHGlobal(8);
  for(var i:uint=0; i<vkSwapchainImageCount; i++){
    ClearMem(ci,64);
    WriteU64(attachPtr,0,vkSwapchainImageViews[i]);
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
    if(IntPtr.Size==8){
      WriteU64(ci,24,vkRenderPass);
      Marshal.WriteInt32(ci,32,1); Marshal.WriteIntPtr(ci,40,attachPtr);
      Marshal.WriteInt32(ci,48,int(windowWidth)); Marshal.WriteInt32(ci,52,int(windowHeight));
      Marshal.WriteInt32(ci,56,1);
    } else {
      WriteU64(ci,12,vkRenderPass);
      Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,attachPtr);
      Marshal.WriteInt32(ci,28,int(windowWidth)); Marshal.WriteInt32(ci,32,int(windowHeight));
      Marshal.WriteInt32(ci,36,1);
    }
    var fbPtr=Marshal.AllocHGlobal(8);
    var r=int(VK_Invoke("Create4",[vkCreateFramebuffer_ptr,vkDevice,ci,IntPtr.Zero,fbPtr]));
    if(!VkCheck(r,"CreateFramebuffers","vkCreateFramebuffer[" + i + "]")){
      Marshal.FreeHGlobal(fbPtr); Marshal.FreeHGlobal(attachPtr); Marshal.FreeHGlobal(ci);
      return false;
    }
    vkFramebuffers[i]=ReadU64(fbPtr,0);
    DebugLog("  CreateFramebuffers: fb[" + i + "]=0x" + vkFramebuffers[i].toString(16));
    Marshal.FreeHGlobal(fbPtr);
  }
  Marshal.FreeHGlobal(attachPtr); Marshal.FreeHGlobal(ci);
  DebugLog(">>> CreateFramebuffers: OK");
  return true;
}

function CreateCommandPool():Boolean{
  DebugLog(">>> CreateCommandPool: start");
  var ci=Marshal.AllocHGlobal(24);
  ClearMem(ci,24);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);
  Marshal.WriteInt32(ci,(IntPtr.Size==8)?16:8,VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
  Marshal.WriteInt32(ci,(IntPtr.Size==8)?20:12,int(vkGraphicsQueueFamilyIndex));
  var poolPtr=Marshal.AllocHGlobal(8);
  Step("CreateCommandPool","vkCreateCommandPool");
  var r=int(VK_Invoke("Create4",[vkCreateCommandPool_ptr,vkDevice,ci,IntPtr.Zero,poolPtr]));
  if(VkCheck(r,"CreateCommandPool","vkCreateCommandPool"))
    vkCommandPool=ReadU64(poolPtr,0);
  DebugLog("  CreateCommandPool: handle=0x" + vkCommandPool.toString(16));
  Marshal.FreeHGlobal(poolPtr); Marshal.FreeHGlobal(ci);
  DebugLog(">>> CreateCommandPool: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

function AllocateCommandBuffers():Boolean{
  DebugLog(">>> AllocateCommandBuffers: start");
  var ai=Marshal.AllocHGlobal(32);
  ClearMem(ai,32);
  Marshal.WriteInt32(ai,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
  if(IntPtr.Size==8){
    WriteU64(ai,16,vkCommandPool);
    Marshal.WriteInt32(ai,24,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    Marshal.WriteInt32(ai,28,1);
  } else {
    WriteU64(ai,8,vkCommandPool);
    Marshal.WriteInt32(ai,16,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    Marshal.WriteInt32(ai,20,1);
  }
  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  Step("AllocateCommandBuffers","vkAllocateCommandBuffers");
  var r=int(VK_Invoke("Create3",[vkAllocateCommandBuffers_ptr,vkDevice,ai,cbPtr]));
  if(VkCheck(r,"AllocateCommandBuffers","vkAllocateCommandBuffers"))
    vkCommandBuffer=Marshal.ReadIntPtr(cbPtr);
  DebugLog("  AllocateCommandBuffers: handle=" + PtrHex(vkCommandBuffer));
  Marshal.FreeHGlobal(cbPtr); Marshal.FreeHGlobal(ai);
  DebugLog(">>> AllocateCommandBuffers: " + (r==VK_SUCCESS ? "OK" : "FAILED"));
  return r==VK_SUCCESS;
}

function CreateSyncObjects():Boolean{
  DebugLog(">>> CreateSyncObjects: start");
  var semInfo=Marshal.AllocHGlobal(24);
  ClearMem(semInfo,24);
  Marshal.WriteInt32(semInfo,0,VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO);
  var fenceInfo=Marshal.AllocHGlobal(24);
  ClearMem(fenceInfo,24);
  Marshal.WriteInt32(fenceInfo,0,VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);
  Marshal.WriteInt32(fenceInfo,(IntPtr.Size==8)?16:8,VK_FENCE_CREATE_SIGNALED_BIT);

  var ptr=Marshal.AllocHGlobal(8);
  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);
  vkImageAvailableSemaphore=ReadU64(ptr,0);
  DebugLog("  CreateSyncObjects: imageAvailSemaphore=0x" + vkImageAvailableSemaphore.toString(16));

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);
  vkRenderFinishedSemaphore=ReadU64(ptr,0);
  DebugLog("  CreateSyncObjects: renderFinishedSemaphore=0x" + vkRenderFinishedSemaphore.toString(16));

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateFence_ptr,vkDevice,fenceInfo,IntPtr.Zero,ptr]);
  vkInFlightFence=ReadU64(ptr,0);
  DebugLog("  CreateSyncObjects: inFlightFence=0x" + vkInFlightFence.toString(16));

  Marshal.FreeHGlobal(ptr); Marshal.FreeHGlobal(semInfo); Marshal.FreeHGlobal(fenceInfo);
  DebugLog(">>> CreateSyncObjects: OK");
  return true;
}

// ===== Render loop =====

var g_frameCount:int=0;

function RecordCommandBuffer(imgIdx:uint):Boolean{
  // Only log detailed command buffer info on first frame to avoid console spam
  var verbose:Boolean=(g_frameCount==0);
  if(verbose) DebugLog(">>> RecordCommandBuffer: frame=" + g_frameCount + " imgIdx=" + imgIdx);

  createVulkanInvoker.InvokeMember("ResetCmd",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkResetCommandBuffer_ptr,vkCommandBuffer,uint(0)]);

  var beginInfo=Marshal.AllocHGlobal(32);
  ClearMem(beginInfo,32);
  Marshal.WriteInt32(beginInfo,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
  var r:int=int(VK_Invoke("Create2",[vkBeginCommandBuffer_ptr,vkCommandBuffer,beginInfo]));
  if(verbose && !VkCheck(r,"RecordCommandBuffer","vkBeginCommandBuffer")) { Marshal.FreeHGlobal(beginInfo); return false; }

  // Clear color: near-black dark blue to match the ray march sky
  var clearVal=Marshal.AllocHGlobal(16);
  Marshal.Copy(BitConverter.GetBytes(float(0.02)),0,clearVal,4);
  Marshal.Copy(BitConverter.GetBytes(float(0.02)),0,IntPtr.Add(clearVal,4),4);
  Marshal.Copy(BitConverter.GetBytes(float(0.05)),0,IntPtr.Add(clearVal,8),4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,IntPtr.Add(clearVal,12),4);

  var rpBegin=Marshal.AllocHGlobal(64);
  ClearMem(rpBegin,64);
  Marshal.WriteInt32(rpBegin,0,VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
  if(IntPtr.Size==8){
    WriteU64(rpBegin,16,vkRenderPass); WriteU64(rpBegin,24,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,40,int(windowWidth)); Marshal.WriteInt32(rpBegin,44,int(windowHeight));
    Marshal.WriteInt32(rpBegin,48,1); Marshal.WriteIntPtr(rpBegin,56,clearVal);
  } else {
    WriteU64(rpBegin,8,vkRenderPass); WriteU64(rpBegin,16,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,32,int(windowWidth)); Marshal.WriteInt32(rpBegin,36,int(windowHeight));
    Marshal.WriteInt32(rpBegin,40,1); Marshal.WriteIntPtr(rpBegin,44,clearVal);
  }
  if(verbose) DebugLog("  RecordCommandBuffer: vkCmdBeginRenderPass fb=0x" + vkFramebuffers[imgIdx].toString(16));
  createVulkanInvoker.InvokeMember("BeginRP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdBeginRenderPass_ptr,vkCommandBuffer,rpBegin,uint(VK_SUBPASS_CONTENTS_INLINE)]);

  createVulkanInvoker.InvokeMember("BindPipe",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdBindPipeline_ptr,vkCommandBuffer,uint(VK_PIPELINE_BIND_POINT_GRAPHICS),vkGraphicsPipeline]);

  // Dynamic viewport
  var viewport=Marshal.AllocHGlobal(24);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,viewport,4);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport,4),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowWidth)),0,IntPtr.Add(viewport,8),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowHeight)),0,IntPtr.Add(viewport,12),4);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport,16),4);
  Marshal.Copy(BitConverter.GetBytes(float(1)),0,IntPtr.Add(viewport,20),4);
  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdSetViewport_ptr,vkCommandBuffer,uint(0),uint(1),viewport]);

  // Dynamic scissor
  var scissor=Marshal.AllocHGlobal(16);
  Marshal.WriteInt32(scissor,0,0); Marshal.WriteInt32(scissor,4,0);
  Marshal.WriteInt32(scissor,8,int(windowWidth)); Marshal.WriteInt32(scissor,12,int(windowHeight));
  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdSetScissor_ptr,vkCommandBuffer,uint(0),uint(1),scissor]);

  // Push constants: iTime (elapsed seconds), padding, iResolution.xy
  var nowMs:long=long(new Date().getTime());
  var elapsed:float=float(nowMs - g_startTimeMs) / 1000.0;
  var pcData=Marshal.AllocHGlobal(PUSH_CONSTANT_SIZE);
  Marshal.Copy(BitConverter.GetBytes(elapsed),0,pcData,4);
  Marshal.Copy(BitConverter.GetBytes(float(0.0)),0,IntPtr.Add(pcData,4),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowWidth)),0,IntPtr.Add(pcData,8),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowHeight)),0,IntPtr.Add(pcData,12),4);
  if(verbose) DebugLog("  RecordCommandBuffer: vkCmdPushConstants iTime=" + elapsed + " res=" + windowWidth + "x" + windowHeight);
  createVulkanInvoker.InvokeMember("PushConst",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdPushConstants_ptr,vkCommandBuffer,vkPipelineLayout,uint(VK_SHADER_STAGE_FRAGMENT_BIT),uint(0),uint(PUSH_CONSTANT_SIZE),pcData]);
  Marshal.FreeHGlobal(pcData);

  // Draw full-screen triangle (3 vertices, no vertex buffer)
  if(verbose) DebugLog("  RecordCommandBuffer: vkCmdDraw 3 vertices (fullscreen triangle)");
  createVulkanInvoker.InvokeMember("Draw",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdDraw_ptr,vkCommandBuffer,uint(3),uint(1),uint(0),uint(0)]);

  VK_Invoke("Void1",[vkCmdEndRenderPass_ptr,vkCommandBuffer]);
  createVulkanInvoker.InvokeMember("Ret1",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkEndCommandBuffer_ptr,vkCommandBuffer]);

  Marshal.FreeHGlobal(scissor); Marshal.FreeHGlobal(viewport);
  Marshal.FreeHGlobal(rpBegin); Marshal.FreeHGlobal(clearVal); Marshal.FreeHGlobal(beginInfo);

  if(verbose) DebugLog(">>> RecordCommandBuffer: OK");
  return true;
}

function DrawFrame():void{
  var fencePtr=Marshal.AllocHGlobal(8);
  WriteU64(fencePtr,0,vkInFlightFence);
  createVulkanInvoker.InvokeMember("WaitFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkWaitForFences_ptr,vkDevice,uint(1),fencePtr,uint(1),ulong(0xFFFFFFFFFFFFFFFF)]);
  createVulkanInvoker.InvokeMember("ResetFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkResetFences_ptr,vkDevice,uint(1),fencePtr]);

  var imgIdxPtr=Marshal.AllocHGlobal(4);
  var acqR:int=int(createVulkanInvoker.InvokeMember("Acquire",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkAcquireNextImageKHR_ptr,vkDevice,vkSwapchain,ulong(0xFFFFFFFFFFFFFFFF),vkImageAvailableSemaphore,ulong(0),imgIdxPtr]));
  // VK_SUBOPTIMAL_KHR (1000001003) is a non-fatal success: swapchain still works
  if(acqR != 0 && acqR != 1000001003){
    VkCheck(acqR,"DrawFrame","vkAcquireNextImageKHR");
    Marshal.FreeHGlobal(imgIdxPtr); Marshal.FreeHGlobal(fencePtr); return;
  }
  if(g_frameCount==0 || acqR!=0) DebugLog("  DrawFrame: vkAcquireNextImageKHR => " + VkResultStr(acqR));
  var imgIdx=uint(Marshal.ReadInt32(imgIdxPtr));
  if(imgIdx >= vkSwapchainImageCount){
    DebugLog("  **FAIL DrawFrame: imgIdx=" + imgIdx + " >= imageCount=" + vkSwapchainImageCount + " - skipping frame");
    Marshal.FreeHGlobal(imgIdxPtr); Marshal.FreeHGlobal(fencePtr); return;
  }

  RecordCommandBuffer(imgIdx);

  var waitSem=Marshal.AllocHGlobal(8); WriteU64(waitSem,0,vkImageAvailableSemaphore);
  var sigSem=Marshal.AllocHGlobal(8);  WriteU64(sigSem,0,vkRenderFinishedSemaphore);
  var waitStage=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(waitStage,0,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  Marshal.WriteIntPtr(cbPtr,0,vkCommandBuffer);

  var submitInfo=Marshal.AllocHGlobal(72);
  ClearMem(submitInfo,72);
  Marshal.WriteInt32(submitInfo,0,VK_STRUCTURE_TYPE_SUBMIT_INFO);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(submitInfo,16,1); Marshal.WriteIntPtr(submitInfo,24,waitSem);
    Marshal.WriteIntPtr(submitInfo,32,waitStage);
    Marshal.WriteInt32(submitInfo,40,1); Marshal.WriteIntPtr(submitInfo,48,cbPtr);
    Marshal.WriteInt32(submitInfo,56,1); Marshal.WriteIntPtr(submitInfo,64,sigSem);
  } else {
    Marshal.WriteInt32(submitInfo,8,1); Marshal.WriteIntPtr(submitInfo,12,waitSem);
    Marshal.WriteIntPtr(submitInfo,16,waitStage);
    Marshal.WriteInt32(submitInfo,20,1); Marshal.WriteIntPtr(submitInfo,24,cbPtr);
    Marshal.WriteInt32(submitInfo,28,1); Marshal.WriteIntPtr(submitInfo,32,sigSem);
  }

  var subR:int=int(createVulkanInvoker.InvokeMember("Submit",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkQueueSubmit_ptr,vkGraphicsQueue,uint(1),submitInfo,vkInFlightFence]));
  if(g_frameCount==0) VkCheck(subR,"DrawFrame","vkQueueSubmit");

  var swPtr=Marshal.AllocHGlobal(8); WriteU64(swPtr,0,vkSwapchain);
  var presentInfo=Marshal.AllocHGlobal(64);
  ClearMem(presentInfo,64);
  Marshal.WriteInt32(presentInfo,0,VK_STRUCTURE_TYPE_PRESENT_INFO_KHR);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(presentInfo,16,1); Marshal.WriteIntPtr(presentInfo,24,sigSem);
    Marshal.WriteInt32(presentInfo,32,1); Marshal.WriteIntPtr(presentInfo,40,swPtr);
    Marshal.WriteIntPtr(presentInfo,48,imgIdxPtr);
  } else {
    Marshal.WriteInt32(presentInfo,8,1); Marshal.WriteIntPtr(presentInfo,12,sigSem);
    Marshal.WriteInt32(presentInfo,16,1); Marshal.WriteIntPtr(presentInfo,20,swPtr);
    Marshal.WriteIntPtr(presentInfo,24,imgIdxPtr);
  }

  var presR:int=int(createVulkanInvoker.InvokeMember("Present",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkQueuePresentKHR_ptr,vkGraphicsQueue,presentInfo]));
  // VK_SUBOPTIMAL_KHR is non-fatal for present as well
  if(presR != 0 && presR != 1000001003) VkCheck(presR,"DrawFrame","vkQueuePresentKHR");
  else if(g_frameCount==0 || presR!=0) DebugLog("  DrawFrame: vkQueuePresentKHR => " + VkResultStr(presR));

  g_frameCount++;
  if(g_frameCount==1) DebugLog("=== First frame submitted successfully ===");

  Marshal.FreeHGlobal(presentInfo); Marshal.FreeHGlobal(swPtr);
  Marshal.FreeHGlobal(submitInfo); Marshal.FreeHGlobal(cbPtr);
  Marshal.FreeHGlobal(waitStage); Marshal.FreeHGlobal(sigSem);
  Marshal.FreeHGlobal(waitSem); Marshal.FreeHGlobal(imgIdxPtr); Marshal.FreeHGlobal(fencePtr);
}

// ===== Window registration =====

function RegisterWindowClass(hInst:IntPtr):Boolean{
  DebugLog(">>> RegisterWindowClass: start");
  var defProc=GetProcAddress(GetModuleHandle("user32.dll"),"DefWindowProcA");
  DebugLog("  RegisterWindowClass: DefWindowProcA=" + PtrHex(defProc));
  var brush=GetStockObject(WHITE_BRUSH);
  var className=Marshal.StringToHGlobalAnsi("raymarch14");

  var cbWndClass:int=(IntPtr.Size==8)?80:48;
  var wndClass=Marshal.AllocHGlobal(int(cbWndClass));
  ClearMem(wndClass,cbWndClass);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(wndClass,0,cbWndClass); Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc); Marshal.WriteIntPtr(wndClass,24,hInst);
    Marshal.WriteIntPtr(wndClass,48,brush); Marshal.WriteIntPtr(wndClass,64,className);
  } else {
    Marshal.WriteInt32(wndClass,0,cbWndClass); Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc); Marshal.WriteIntPtr(wndClass,20,hInst);
    Marshal.WriteIntPtr(wndClass,32,brush); Marshal.WriteIntPtr(wndClass,40,className);
  }

  var atom=InvokeWin32("user32.dll",Type.GetType("System.UInt16"),"RegisterClassExA",
    [Type.GetType("System.IntPtr")],[wndClass]);
  DebugLog("  RegisterWindowClass: atom=" + atom + (atom!=0 ? " (OK)" : " **FAIL**"));

  Marshal.FreeHGlobal(className); Marshal.FreeHGlobal(wndClass);
  DebugLog(">>> RegisterWindowClass: " + (atom!=0 ? "OK" : "FAILED"));
  return atom!=0;
}

function AllocateMsgStruct():IntPtr{
  var sz:int=(IntPtr.Size==8)?48:28;
  var buf=Marshal.AllocHGlobal(int(sz));
  ClearMem(buf,sz);
  return buf;
}

function GetMessageID(msg:IntPtr):uint{
  return uint(Marshal.ReadInt32(msg,(IntPtr.Size==8)?8:4));
}

// ===== Main entry point =====

function Main():void{
  DebugLog("========================================");
  DebugLog("=== Vulkan 1.4 Ray Marching Demo ===");
  DebugLog("  Platform: " + (IntPtr.Size==8 ? "x64" : "x86") + "  IntPtr.Size=" + IntPtr.Size);
  DebugLog("  WorkingDir: " + Environment.CurrentDirectory);
  DebugLog("  VULKAN_SDK: " + (Environment.GetEnvironmentVariable("VULKAN_SDK") || "(not set)"));
  DebugLog("  shaderc DLL: " + ResolveShadercDll());
  DebugLog("========================================");

  if(createVulkanInvoker==null){
    DebugLog("FATAL: VulkanInvoker compilation failed at startup - aborting");
    return;
  }

  g_startTimeMs=long(new Date().getTime());

  var hInst=GetModuleHandle(null);
  DebugLog("Main: hInstance=" + PtrHex(hInst));

  try{

    DebugLog("--- [1/13] LoadVulkan ---");
    if(!LoadVulkan()){ DebugLog("FATAL: LoadVulkan failed"); return; }

    DebugLog("--- [2/13] CreateVulkanInstance ---");
    if(!CreateVulkanInstance()){ DebugLog("FATAL: CreateVulkanInstance failed"); return; }

    DebugLog("--- [3/13] LoadInstanceFunctions ---");
    LoadInstanceFunctions();

    DebugLog("--- [4/13] SelectPhysicalDevice ---");
    if(!SelectPhysicalDevice()){ DebugLog("FATAL: SelectPhysicalDevice failed"); return; }

    DebugLog("--- [5/13] FindGraphicsQueueFamily ---");
    if(!FindGraphicsQueueFamily()){ DebugLog("FATAL: FindGraphicsQueueFamily failed"); return; }

    DebugLog("--- [6/13] CreateLogicalDevice ---");
    if(!CreateLogicalDevice()){ DebugLog("FATAL: CreateLogicalDevice failed"); return; }

    DebugLog("--- [7/13] LoadDeviceFunctions + GetGraphicsQueue ---");
    LoadDeviceFunctions();
    GetGraphicsQueue();

    DebugLog("--- [8/13] RegisterWindowClass + CreateWindow ---");
    if(!RegisterWindowClass(hInst)){ DebugLog("FATAL: RegisterWindowClass failed"); return; }

    var hWnd=CreateWindowEx(0,"raymarch14","Vulkan 1.4 - Ray Marching",
      WS_OVERLAPPEDWINDOW|WS_VISIBLE,CW_USEDEFAULT,CW_USEDEFAULT,
      int(windowWidth),int(windowHeight),IntPtr.Zero,IntPtr.Zero,hInst,IntPtr.Zero);
    DebugLog("  CreateWindowEx: hWnd=" + PtrHex(hWnd));
    if(hWnd==IntPtr.Zero){ DebugLog("FATAL: CreateWindowEx failed"); return; }
    ShowWindow(hWnd,SW_SHOW);
    UpdateWindow(hWnd);

    DebugLog("--- [9/13] CreateWin32Surface ---");
    if(!CreateWin32Surface(hInst,hWnd)){ DebugLog("FATAL: CreateWin32Surface failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- [10/13] CreateSwapchain ---");
    if(!CreateSwapchain()){ DebugLog("FATAL: CreateSwapchain failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- GetSwapchainImages + CreateImageViews ---");
    if(!GetSwapchainImages()){ DebugLog("FATAL: GetSwapchainImages failed"); DestroyWindow(hWnd); return; }
    if(!CreateImageViews()){ DebugLog("FATAL: CreateImageViews failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- [11/13] CreateRenderPass ---");
    if(!CreateRenderPass()){ DebugLog("FATAL: CreateRenderPass failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- [12/13] CreatePipelineLayout ---");
    if(!CreatePipelineLayout()){ DebugLog("FATAL: CreatePipelineLayout failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- [13/13] CreateGraphicsPipeline ---");
    if(!CreateGraphicsPipeline()){ DebugLog("FATAL: CreateGraphicsPipeline failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- CreateFramebuffers ---");
    if(!CreateFramebuffers()){ DebugLog("FATAL: CreateFramebuffers failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- CreateCommandPool + AllocateCommandBuffers ---");
    if(!CreateCommandPool()){ DebugLog("FATAL: CreateCommandPool failed"); DestroyWindow(hWnd); return; }
    if(!AllocateCommandBuffers()){ DebugLog("FATAL: AllocateCommandBuffers failed"); DestroyWindow(hWnd); return; }

    DebugLog("--- CreateSyncObjects ---");
    if(!CreateSyncObjects()){ DebugLog("FATAL: CreateSyncObjects failed"); DestroyWindow(hWnd); return; }

    DebugLog("========================================");
    DebugLog("=== Initialization COMPLETE - entering render loop ===");
    DebugLog("========================================");

    var msg=AllocateMsgStruct();
    var quit=false;

    while(!quit){
      if(PeekMessage(msg,IntPtr.Zero,0,0,PM_REMOVE)){
        if(GetMessageID(msg)==WM_QUIT) quit=true;
        else{ TranslateMessage(msg); DispatchMessage(msg); }
      } else {
        if(!IsWindow(hWnd)) PostQuitMessage(0);
        else{ DrawFrame(); Sleep(0); }
      }
    }

    DebugLog("Main: render loop exited after " + g_frameCount + " frames");
    VK_Invoke("Void1",[vkDeviceWaitIdle_ptr,vkDevice]);
    Marshal.FreeHGlobal(msg);
    DebugLog("=== Demo completed ===");

  }catch(e){
    DebugLog("FATAL EXCEPTION: " + e.ToString());
    throw e;
  }
}

Main();
