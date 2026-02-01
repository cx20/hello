// HelloVulkan.js - JScript.NET Vulkan 1.4 Triangle Demo
// Build: jsc /platform:x64 /nologo HelloVulkan.js && HelloVulkan.exe
// Requirements: Vulkan runtime (vulkan-1.dll) installed (e.g., Vulkan SDK).

import System;

import System.Reflection;

import System.Reflection.Emit;

import System.Runtime.InteropServices;

import System.Text;

import System.CodeDom.Compiler;

import System.IO;

function DebugLog(message:String): void {

  Console.WriteLine("[DEBUG] " + message);

}

// ===== Debug helpers for VK invocations =====
function PtrHex(p:IntPtr):String{

  if(p==IntPtr.Zero) return "0x0";

  if(IntPtr.Size==8){

    var v:long = p.ToInt64();

    if(v<0) v = v + 9223372036854775807 + 9223372036854775809;
    // +2^64
    return "0x"+v.toString(16);

  }
  else{

    var v32:int = p.ToInt32();

    if(v32<0) v32 = v32 + 0x100000000;

    return "0x"+v32.toString(16);

  }

}

function ArgStr(a:Object):String{

  if(a==null) return "null";

  if(a.GetType().FullName=="System.IntPtr") return PtrHex(IntPtr(a));

  // JScript.NET boxes uint as System.UInt32, ulong as System.UInt64
  var t = a.GetType().FullName;

  if(t=="System.UInt64") return "0x"+System.UInt64(a).ToString("X");

  if(t=="System.UInt32") return "0x"+System.UInt32(a).ToString("X");

  if(t=="System.Int32")  return String(a);

  if(t=="System.Single") return String(a);

  return a.ToString();

}

function ArgsToString(args:Object[]):String{
  if(args==null) return "";
  var parts=new Array();
  for(var i=0;i<args.length;i++){
    parts.push(ArgStr(args[i]));
  }
  return parts.join(", ");
}


function ArgsStr(args:Object[]):String{

  if(args==null) return "";

  var s="";

  for(var i=0;
  i<args.length;
  i++){

    if(i>0) s+=", ";

    s+=ArgStr(args[i]);

  }

  return s;

}

function VK_Invoke(method:String, args:Object[]):Object{

  DebugLog("VK." + method + "(" + ArgsStr(args) + ")");

  try{

    return createVulkanInvoker.InvokeMember(
    method,
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,
    null,
    null,
    args
    );

  }
  catch(e){

    DebugLog("VK." + method + " threw: " + e.ToString());

    throw e;

  }

}

// Helper to call Vulkan function pointers via reflection
var createVulkanInvoker = (function() {

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
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DBindVB(IntPtr cmd, uint first, uint cnt, IntPtr buf, IntPtr off);\n" +
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
  "  public static void BindVB(IntPtr f, IntPtr c, uint a, uint b, IntPtr buf, IntPtr off) { ((DBindVB)Marshal.GetDelegateForFunctionPointer(f,typeof(DBindVB)))(c,a,b,buf,off); }\n" +
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
  "}";

  var cp = CodeDomProvider.CreateProvider("CSharp");

  var cps = new CompilerParameters();

  cps.GenerateInMemory = true;

  var cr = cp.CompileAssemblyFromSource(cps, source);

  if (cr.Errors.HasErrors) {
    for (var i = 0;
    i < cr.Errors.Count;
    i++) DebugLog(cr.Errors[i].ToString());
    return null;
  }

  return cr.CompiledAssembly.GetType("VulkanInvoker");

})();

// Dynamic P/Invoke
function InvokeWin32(dll:String, ret:Type, name:String, types:Type[], args:Object[]): Object {

  var dom = AppDomain.CurrentDomain;

  var asm = dom.DefineDynamicAssembly(new AssemblyName("P" + name), AssemblyBuilderAccess.Run);

  var mod = asm.DefineDynamicModule("M");

  var typ = mod.DefineType("T", TypeAttributes.Public);

  var meth = typ.DefineMethod(name, 6|128|16|8192, ret, types);

  meth.SetCustomAttribute(new CustomAttributeBuilder(DllImportAttribute.GetConstructor([Type.GetType("System.String")]), [dll]));

  return typ.CreateType().InvokeMember(name, BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod, null, null, args);

}

// Dynamic P/Invoke (cdecl)
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
    var cab = new CustomAttributeBuilder(ctor, ctorArgs, props, propVals);
    meth.SetCustomAttribute(cab);
  }
  else{
    var cab2 = new CustomAttributeBuilder(ctor, ctorArgs);
    meth.SetCustomAttribute(cab2);
  }

  return typ.CreateType().InvokeMember(name, BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod, null, null, args);

}

// ===== Part 2: Constants and globals =====

// Win32 constants
const WS_OVERLAPPEDWINDOW=0x00CF0000, WS_VISIBLE=0x10000000, CW_USEDEFAULT=-2147483648;

const SW_SHOW=5, WM_QUIT=0x0012, PM_REMOVE=1, CS_OWNDC=0x0020, WHITE_BRUSH=0;

// Vulkan constants
const VK_SUCCESS=0;

const VK_STRUCTURE_TYPE_APPLICATION_INFO=0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO=1;

const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO=2, VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO=3;

const VK_STRUCTURE_TYPE_SUBMIT_INFO=4, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO=5;

const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO=8, VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO=9;

const VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO=12, VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO=15;

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

const VK_QUEUE_GRAPHICS_BIT=1, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT=2;

const VK_COMMAND_BUFFER_LEVEL_PRIMARY=0, VK_FENCE_CREATE_SIGNALED_BIT=1;

const VK_PIPELINE_BIND_POINT_GRAPHICS=0, VK_SUBPASS_CONTENTS_INLINE=0;

const VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST=3, VK_POLYGON_MODE_FILL=0;

const VK_CULL_MODE_BACK_BIT=2, VK_FRONT_FACE_CLOCKWISE=1, VK_SAMPLE_COUNT_1_BIT=1;

const VK_DYNAMIC_STATE_VIEWPORT=0, VK_DYNAMIC_STATE_SCISSOR=1;

const VK_SHADER_STAGE_VERTEX_BIT=1, VK_SHADER_STAGE_FRAGMENT_BIT=16;

const VK_FORMAT_B8G8R8A8_SRGB=50, VK_FORMAT_R32G32_SFLOAT=103, VK_FORMAT_R32G32B32_SFLOAT=106;

const VK_COLOR_SPACE_SRGB_NONLINEAR_KHR=0, VK_PRESENT_MODE_FIFO_KHR=2;

const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT=16, VK_SHARING_MODE_EXCLUSIVE=0;

const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR=1, VK_IMAGE_VIEW_TYPE_2D=1;

const VK_IMAGE_ASPECT_COLOR_BIT=1, VK_ATTACHMENT_LOAD_OP_CLEAR=1;

const VK_ATTACHMENT_STORE_OP_STORE=0, VK_ATTACHMENT_LOAD_OP_DONT_CARE=2;

const VK_ATTACHMENT_STORE_OP_DONT_CARE=1, VK_IMAGE_LAYOUT_UNDEFINED=0;

const VK_IMAGE_LAYOUT_PRESENT_SRC_KHR=1000001002, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL=2;

const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT=0x400;

const VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT=0x100;

const VK_BUFFER_USAGE_VERTEX_BUFFER_BIT=0x80;

const VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT=2, VK_MEMORY_PROPERTY_HOST_COHERENT_BIT=4;

const VK_VERTEX_INPUT_RATE_VERTEX=0, VK_COLOR_COMPONENT_RGBA=15;

const VK_API_VERSION_1_4=((1<<22)|(4<<12));

// shaderc constants
const SHADERC_SHADER_KIND_VERTEX=0;
const SHADERC_SHADER_KIND_FRAGMENT=1;
const SHADERC_STATUS_SUCCESS=0;

// Global variables
var vkInstance:IntPtr=IntPtr.Zero, vkPhysicalDevice:IntPtr=IntPtr.Zero, vkDevice:IntPtr=IntPtr.Zero;

var vkSurface:ulong=0, vkSwapchain:ulong=0, vkRenderPass:ulong=0, vkPipelineLayout:ulong=0;

var vkGraphicsPipeline:ulong=0, vkCommandPool:ulong=0, vkCommandBuffer:IntPtr=IntPtr.Zero;

var vkGraphicsQueue:IntPtr=IntPtr.Zero;

var vkImageAvailableSemaphore:ulong=0, vkRenderFinishedSemaphore:ulong=0, vkInFlightFence:ulong=0;

var vkVertexBuffer:ulong=0, vkVertexBufferMemory:ulong=0;

var vkSwapchainImages:ulong[]=null, vkSwapchainImageViews:ulong[]=null, vkFramebuffers:ulong[]=null;

var vkSwapchainImageCount:uint=0, vkGraphicsQueueFamilyIndex:uint=0;

var windowWidth:uint=640, windowHeight:uint=480;

// Function pointers
var vkGetInstanceProcAddr_ptr:IntPtr=IntPtr.Zero, vkCreateInstance_ptr:IntPtr=IntPtr.Zero;
var vkGetDeviceProcAddr_ptr:IntPtr = IntPtr.Zero; // cached pointer


var vkEnumeratePhysicalDevices_ptr:IntPtr=IntPtr.Zero, vkGetPhysicalDeviceQueueFamilyProperties_ptr:IntPtr=IntPtr.Zero;

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

var vkCmdBindVertexBuffers_ptr:IntPtr=IntPtr.Zero;

var vkCreateSemaphore_ptr:IntPtr=IntPtr.Zero, vkCreateFence_ptr:IntPtr=IntPtr.Zero;

var vkWaitForFences_ptr:IntPtr=IntPtr.Zero, vkResetFences_ptr:IntPtr=IntPtr.Zero;

var vkAcquireNextImageKHR_ptr:IntPtr=IntPtr.Zero, vkQueueSubmit_ptr:IntPtr=IntPtr.Zero;

var vkQueuePresentKHR_ptr:IntPtr=IntPtr.Zero, vkDeviceWaitIdle_ptr:IntPtr=IntPtr.Zero;

var vkResetCommandBuffer_ptr:IntPtr=IntPtr.Zero;

var vkCreateBuffer_ptr:IntPtr=IntPtr.Zero, vkGetBufferMemoryRequirements_ptr:IntPtr=IntPtr.Zero;

var vkAllocateMemory_ptr:IntPtr=IntPtr.Zero, vkBindBufferMemory_ptr:IntPtr=IntPtr.Zero;

var vkMapMemory_ptr:IntPtr=IntPtr.Zero, vkUnmapMemory_ptr:IntPtr=IntPtr.Zero;

var vkGetPhysicalDeviceMemoryProperties_ptr:IntPtr=IntPtr.Zero;

// ===== Part 3: Helpers and Vulkan initialization =====

// Read/write UInt64 from unmanaged memory
function WriteU64(p:IntPtr,o:int,v:ulong):void{
  Marshal.WriteInt32(p,o,int(v&0xFFFFFFFF));
  Marshal.WriteInt32(p,o+4,int((v>>32)&0xFFFFFFFF));
}


var g_invokerMethodsDumped:Boolean=false;

function DumpInvokerMethods():void{
  if(g_invokerMethodsDumped) return;
  g_invokerMethodsDumped=true;
  try{
    DebugLog("=== VulkanInvoker methods (for signature debugging) ===");
    var ms = createVulkanInvoker.GetMethods();
    for(var i=0;i<ms.Length;i++){
      var mi = ms[i];
      // Print name + parameter count; full signature is verbose in JScript.NET
      DebugLog("  " + mi.Name + " (params=" + mi.GetParameters().Length + ")");
    }
    DebugLog("=== end methods ===");
  }catch(ex){
    DebugLog("DumpInvokerMethods failed: " + ex.ToString());
  }
}


function VK_InvokeNamed(fname:String, method:String, args:Object[]):Object{
  DebugLog("VK." + method + " " + fname + "(" + ArgsToString(args) + ")");
  try {
    return createVulkanInvoker.InvokeMember(
      method,
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null,
      args
    );
  } catch(ex) {
    DebugLog("EXCEPTION in " + fname + ": " + ex.ToString());
    throw ex;
  }
}


function ReadU64(p:IntPtr,o:int):ulong{
  return ulong(uint(Marshal.ReadInt32(p,o)))|(ulong(uint(Marshal.ReadInt32(p,o+4)))<<32);
}


function ReadPtr(p:IntPtr, o:int):IntPtr{
  // Read pointer-sized value from unmanaged memory (works for both x86/x64)
  return Marshal.ReadIntPtr(p, o);
}


function ClearMem(p:IntPtr,sz:int):void{
  for(var i=0;
  i<sz;
  i++)Marshal.WriteByte(p,i,0);
}

function DumpHex(ptr:IntPtr, size:int):String{
  var n = (size>256) ? 256 : size;
  var sb="";
  for(var i=0;i<n;i++){
    var b = Marshal.ReadByte(ptr, i);
    var hx = b.toString(16).toUpperCase();
    if(hx.length<2) hx="0"+hx;
    sb += hx;
    if(i != n-1) sb += " ";
  }
  return sb;
}


// Win32 API
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

function ShowWindow(h:IntPtr,c:int):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"ShowWindow",[Type.GetType("System.IntPtr"),Type.GetType("System.Int32")],[h,c]);
}

function UpdateWindow(h:IntPtr):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"UpdateWindow",[Type.GetType("System.IntPtr")],[h]);
}

function DestroyWindow(h:IntPtr):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"DestroyWindow",[Type.GetType("System.IntPtr")],[h]);
}

function PostQuitMessage(c:int):void{
  InvokeWin32("user32.dll",Type.GetType("System.Void"),"PostQuitMessage",[Type.GetType("System.Int32")],[c]);
}

function PeekMessage(m:IntPtr,h:IntPtr,mn:uint,mx:uint,rm:uint):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"PeekMessageA",[Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32")],[m,h,mn,mx,rm]);
}

function TranslateMessage(m:IntPtr):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"TranslateMessage",[Type.GetType("System.IntPtr")],[m]);
}

function DispatchMessage(m:IntPtr):IntPtr{
  return InvokeWin32("user32.dll",Type.GetType("System.IntPtr"),"DispatchMessageA",[Type.GetType("System.IntPtr")],[m]);
}

function Sleep(ms:uint):void{
  InvokeWin32("kernel32.dll",Type.GetType("System.Void"),"Sleep",[Type.GetType("System.UInt32")],[ms]);
}

function GetStockObject(i:int):IntPtr{
  return InvokeWin32("gdi32.dll",Type.GetType("System.IntPtr"),"GetStockObject",[Type.GetType("System.Int32")],[i]);
}

function IsWindow(h:IntPtr):Boolean{
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"IsWindow",[Type.GetType("System.IntPtr")],[h]);
}

// ===== shaderc (runtime GLSL -> SPIR-V) =====
var g_shadercDll:String=null;

function ResolveShadercDll():String{
  if(g_shadercDll!=null) return g_shadercDll;
  var dll="shaderc_shared.dll";
  try{
    var sdk=Environment.GetEnvironmentVariable("VULKAN_SDK");
    if(sdk!=null && sdk!=""){
      var p1=Path.Combine(sdk,"Bin","shaderc_shared.dll");
      if(File.Exists(p1)) { g_shadercDll=p1; return g_shadercDll; }
      var p2=Path.Combine(sdk,"Bin64","shaderc_shared.dll");
      if(File.Exists(p2)) { g_shadercDll=p2; return g_shadercDll; }
    }
    var local=Path.Combine(Environment.CurrentDirectory,"shaderc_shared.dll");
    if(File.Exists(local)) { g_shadercDll=local; return g_shadercDll; }
  }catch(_e){}
  g_shadercDll=dll;
  return g_shadercDll;
}

function ShadercCompile(source:String, kind:int, filename:String, entry:String):byte[]{
  var dll=ResolveShadercDll();
  DebugLog("Loading shaderc: " + dll);

  var compiler:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compiler_initialize",new Array(),new Array());
  if(compiler==IntPtr.Zero) throw new Exception("shaderc_compiler_initialize failed");

  var options:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compile_options_initialize",new Array(),new Array());
  if(options==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("shaderc_compile_options_initialize failed");
  }

  // optimization level = 2
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_set_optimization_level",
    [Type.GetType("System.IntPtr"),Type.GetType("System.Int32")],[options,2]);

  var srcBytes:byte[]=Encoding.UTF8.GetBytes(source);
  var srcPtr=Marshal.AllocHGlobal(int(srcBytes.length));
  Marshal.Copy(srcBytes,0,srcPtr,int(srcBytes.length));

  var filePtr=Marshal.StringToHGlobalAnsi(filename);
  var entryPtr=Marshal.StringToHGlobalAnsi(entry);

  var result:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compile_into_spv",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.UIntPtr"),Type.GetType("System.Int32"),
     Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr")],
    [compiler,srcPtr,new UIntPtr(uint(srcBytes.length)),kind,filePtr,entryPtr,options]);

  Marshal.FreeHGlobal(entryPtr);
  Marshal.FreeHGlobal(filePtr);
  Marshal.FreeHGlobal(srcPtr);

  if(result==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("shaderc_compile_into_spv failed (NULL)");
  }

  var status:int=int(InvokeCdecl(dll,Type.GetType("System.Int32"),"shaderc_result_get_compilation_status",
    [Type.GetType("System.IntPtr")],[result]));

  if(status!=SHADERC_STATUS_SUCCESS){
    var errPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_error_message",
      [Type.GetType("System.IntPtr")],[result]);
    var errMsg:String=(errPtr==IntPtr.Zero)?"(no message)":Marshal.PtrToStringAnsi(errPtr);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("Shader compilation failed ("+status+"): "+errMsg);
  }

  var len:ulong=ulong(InvokeCdecl(dll,Type.GetType("System.UInt64"),"shaderc_result_get_length",
    [Type.GetType("System.IntPtr")],[result]));

  var bytesPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_bytes",
    [Type.GetType("System.IntPtr")],[result]);

  if(bytesPtr==IntPtr.Zero || len==0){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("shaderc_result_get_bytes/length failed");
  }

  var outBytes:byte[]=new byte[int(len)];
  Marshal.Copy(bytesPtr,outBytes,0,int(len));

  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);

  return outBytes;
}

const VERT_GLSL =
"#version 450\n"+
"layout(location=0) in vec2 inPos;\n"+
"layout(location=1) in vec3 inColor;\n"+
"layout(location=0) out vec3 fragColor;\n"+
"void main(){\n"+
"  gl_Position = vec4(inPos, 0.0, 1.0);\n"+
"  fragColor = inColor;\n"+
"}\n";

const FRAG_GLSL =
"#version 450\n"+
"layout(location=0) in vec3 fragColor;\n"+
"layout(location=0) out vec4 outColor;\n"+
"void main(){\n"+
"  outColor = vec4(fragColor, 1.0);\n"+
"}\n";

function ReadShaderText(fileName:String, fallback:String):String{
  try{
    var path=Path.Combine(Environment.CurrentDirectory, fileName);
    if(File.Exists(path)){
      return File.ReadAllText(path);
    }
  }catch(_e){}
  return fallback;
}

// Resolve Vulkan functions
function VkGetProc(inst:IntPtr,name:String):IntPtr{

  var np=Marshal.StringToHGlobalAnsi(name);

  var r=IntPtr(createVulkanInvoker.InvokeMember("GetProc",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetInstanceProcAddr_ptr,inst,np]));

  Marshal.FreeHGlobal(np);
  return r;

}

function VkGetDevProc(dev:IntPtr,name:String):IntPtr{

  // Cache vkGetDeviceProcAddr function pointer (instance-level function)
  if(vkGetDeviceProcAddr_ptr==IntPtr.Zero){
    vkGetDeviceProcAddr_ptr=VkGetProc(vkInstance,"vkGetDeviceProcAddr");
    DebugLog("vkGetDeviceProcAddr_ptr=" + PtrHex(vkGetDeviceProcAddr_ptr));
  }

  var np=Marshal.StringToHGlobalAnsi(name);

  var r=IntPtr(createVulkanInvoker.InvokeMember(
    "GetProc",
    BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
    null, null,
    new Array(vkGetDeviceProcAddr_ptr, dev, np)
  ));

  Marshal.FreeHGlobal(np);
  return r;

}

// Load Vulkan (LoadLibrary/GetProcAddress)
function LoadVulkan():Boolean{

  DebugLog("Loading Vulkan...");

  var lib=LoadLibrary("vulkan-1.dll");

  if(lib==IntPtr.Zero){
    DebugLog("Failed to load vulkan-1.dll");
    return false;
  }

  vkGetInstanceProcAddr_ptr=GetProcAddress(lib,"vkGetInstanceProcAddr");

  if(vkGetInstanceProcAddr_ptr==IntPtr.Zero){
    DebugLog("Failed to get vkGetInstanceProcAddr");
    return false;
  }

  vkCreateInstance_ptr=VkGetProc(IntPtr.Zero,"vkCreateInstance");

  DebugLog("Vulkan loaded");
  return true;

}

// Load instance-level Vulkan functions
function LoadInstanceFunctions():void{

  vkEnumeratePhysicalDevices_ptr=VkGetProc(vkInstance,"vkEnumeratePhysicalDevices");

  vkGetPhysicalDeviceQueueFamilyProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceQueueFamilyProperties");

  vkCreateDevice_ptr=VkGetProc(vkInstance,"vkCreateDevice");

  vkCreateWin32SurfaceKHR_ptr=VkGetProc(vkInstance,"vkCreateWin32SurfaceKHR");

  vkGetPhysicalDeviceMemoryProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceMemoryProperties");

  DebugLog("Instance functions loaded");

}

// Load device-level Vulkan functions
function LoadDeviceFunctions():void{

  vkGetDeviceQueue_ptr=VkGetDevProc(vkDevice,"vkGetDeviceQueue");
  DebugLog("vkGetDeviceQueue_ptr=" + PtrHex(vkGetDeviceQueue_ptr));

  vkCreateSwapchainKHR_ptr=VkGetDevProc(vkDevice,"vkCreateSwapchainKHR");
  DebugLog("vkCreateSwapchainKHR_ptr=" + PtrHex(vkCreateSwapchainKHR_ptr));

  vkGetSwapchainImagesKHR_ptr=VkGetDevProc(vkDevice,"vkGetSwapchainImagesKHR");
  DebugLog("vkGetSwapchainImagesKHR_ptr=" + PtrHex(vkGetSwapchainImagesKHR_ptr));

  vkCreateImageView_ptr=VkGetDevProc(vkDevice,"vkCreateImageView");
  DebugLog("vkCreateImageView_ptr=" + PtrHex(vkCreateImageView_ptr));

  vkCreateShaderModule_ptr=VkGetDevProc(vkDevice,"vkCreateShaderModule");
  DebugLog("vkCreateShaderModule_ptr=" + PtrHex(vkCreateShaderModule_ptr));

  vkDestroyShaderModule_ptr=VkGetDevProc(vkDevice,"vkDestroyShaderModule");
  DebugLog("vkDestroyShaderModule_ptr=" + PtrHex(vkDestroyShaderModule_ptr));

  vkCreatePipelineLayout_ptr=VkGetDevProc(vkDevice,"vkCreatePipelineLayout");
  DebugLog("vkCreatePipelineLayout_ptr=" + PtrHex(vkCreatePipelineLayout_ptr));

  vkCreateRenderPass_ptr=VkGetDevProc(vkDevice,"vkCreateRenderPass");
  DebugLog("vkCreateRenderPass_ptr=" + PtrHex(vkCreateRenderPass_ptr));

  vkCreateGraphicsPipelines_ptr=VkGetDevProc(vkDevice,"vkCreateGraphicsPipelines");
  DebugLog("vkCreateGraphicsPipelines_ptr=" + PtrHex(vkCreateGraphicsPipelines_ptr));

  vkCreateFramebuffer_ptr=VkGetDevProc(vkDevice,"vkCreateFramebuffer");
  DebugLog("vkCreateFramebuffer_ptr=" + PtrHex(vkCreateFramebuffer_ptr));

  vkCreateCommandPool_ptr=VkGetDevProc(vkDevice,"vkCreateCommandPool");
  DebugLog("vkCreateCommandPool_ptr=" + PtrHex(vkCreateCommandPool_ptr));

  vkAllocateCommandBuffers_ptr=VkGetDevProc(vkDevice,"vkAllocateCommandBuffers");
  DebugLog("vkAllocateCommandBuffers_ptr=" + PtrHex(vkAllocateCommandBuffers_ptr));

  vkBeginCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkBeginCommandBuffer");
  DebugLog("vkBeginCommandBuffer_ptr=" + PtrHex(vkBeginCommandBuffer_ptr));

  vkEndCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkEndCommandBuffer");
  DebugLog("vkEndCommandBuffer_ptr=" + PtrHex(vkEndCommandBuffer_ptr));

  vkCmdBeginRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdBeginRenderPass");
  DebugLog("vkCmdBeginRenderPass_ptr=" + PtrHex(vkCmdBeginRenderPass_ptr));

  vkCmdEndRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdEndRenderPass");
  DebugLog("vkCmdEndRenderPass_ptr=" + PtrHex(vkCmdEndRenderPass_ptr));

  vkCmdBindPipeline_ptr=VkGetDevProc(vkDevice,"vkCmdBindPipeline");
  DebugLog("vkCmdBindPipeline_ptr=" + PtrHex(vkCmdBindPipeline_ptr));

  vkCmdSetViewport_ptr=VkGetDevProc(vkDevice,"vkCmdSetViewport");

  vkCmdSetScissor_ptr=VkGetDevProc(vkDevice,"vkCmdSetScissor");

  vkCmdDraw_ptr=VkGetDevProc(vkDevice,"vkCmdDraw");
  DebugLog("vkCmdDraw_ptr=" + PtrHex(vkCmdDraw_ptr));

  vkCmdBindVertexBuffers_ptr=VkGetDevProc(vkDevice,"vkCmdBindVertexBuffers");
  DebugLog("vkCmdBindVertexBuffers_ptr=" + PtrHex(vkCmdBindVertexBuffers_ptr));

  vkCreateSemaphore_ptr=VkGetDevProc(vkDevice,"vkCreateSemaphore");
  DebugLog("vkCreateSemaphore_ptr=" + PtrHex(vkCreateSemaphore_ptr));

  vkCreateFence_ptr=VkGetDevProc(vkDevice,"vkCreateFence");
  DebugLog("vkCreateFence_ptr=" + PtrHex(vkCreateFence_ptr));

  vkWaitForFences_ptr=VkGetDevProc(vkDevice,"vkWaitForFences");
  DebugLog("vkWaitForFences_ptr=" + PtrHex(vkWaitForFences_ptr));

  vkResetFences_ptr=VkGetDevProc(vkDevice,"vkResetFences");
  DebugLog("vkResetFences_ptr=" + PtrHex(vkResetFences_ptr));

  vkAcquireNextImageKHR_ptr=VkGetDevProc(vkDevice,"vkAcquireNextImageKHR");
  DebugLog("vkAcquireNextImageKHR_ptr=" + PtrHex(vkAcquireNextImageKHR_ptr));

  vkQueueSubmit_ptr=VkGetDevProc(vkDevice,"vkQueueSubmit");
  DebugLog("vkQueueSubmit_ptr=" + PtrHex(vkQueueSubmit_ptr));

  vkQueuePresentKHR_ptr=VkGetDevProc(vkDevice,"vkQueuePresentKHR");
  DebugLog("vkQueuePresentKHR_ptr=" + PtrHex(vkQueuePresentKHR_ptr));

  vkDeviceWaitIdle_ptr=VkGetDevProc(vkDevice,"vkDeviceWaitIdle");
  DebugLog("vkDeviceWaitIdle_ptr=" + PtrHex(vkDeviceWaitIdle_ptr));

  vkResetCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkResetCommandBuffer");
  DebugLog("vkResetCommandBuffer_ptr=" + PtrHex(vkResetCommandBuffer_ptr));

  vkCreateBuffer_ptr=VkGetDevProc(vkDevice,"vkCreateBuffer");

  vkGetBufferMemoryRequirements_ptr=VkGetDevProc(vkDevice,"vkGetBufferMemoryRequirements");

  vkAllocateMemory_ptr=VkGetDevProc(vkDevice,"vkAllocateMemory");

  vkBindBufferMemory_ptr=VkGetDevProc(vkDevice,"vkBindBufferMemory");

  vkMapMemory_ptr=VkGetDevProc(vkDevice,"vkMapMemory");

  vkUnmapMemory_ptr=VkGetDevProc(vkDevice,"vkUnmapMemory");

  DebugLog("Device functions loaded");

}

// Create Vulkan instance
function CreateVulkanInstance():Boolean{

  DebugLog("Creating Vulkan instance...");

  var appName=Marshal.StringToHGlobalAnsi("Hello Vulkan");

  var engName=Marshal.StringToHGlobalAnsi("No Engine");

  var ext1=Marshal.StringToHGlobalAnsi("VK_KHR_surface");

  var ext2=Marshal.StringToHGlobalAnsi("VK_KHR_win32_surface");

  var appInfo=Marshal.AllocHGlobal(48);
  ClearMem(appInfo,48);

  Marshal.WriteInt32(appInfo,0,VK_STRUCTURE_TYPE_APPLICATION_INFO);

  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?16:8,appName);

  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?32:16,engName);

  Marshal.WriteInt32(appInfo,(IntPtr.Size==8)?44:24,VK_API_VERSION_1_4);

  var extArr=Marshal.AllocHGlobal(int(IntPtr.Size*2));

  Marshal.WriteIntPtr(extArr,0,ext1);
  Marshal.WriteIntPtr(extArr,IntPtr.Size,ext2);

  var createInfo=Marshal.AllocHGlobal(64);
  ClearMem(createInfo,64);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(createInfo,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(createInfo,24,appInfo);
    Marshal.WriteInt32(createInfo,48,2);
    Marshal.WriteIntPtr(createInfo,56,extArr);
  }

  else{
    Marshal.WriteInt32(createInfo,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(createInfo,12,appInfo);
    Marshal.WriteInt32(createInfo,24,2);
    Marshal.WriteIntPtr(createInfo,28,extArr);
  }

  var instPtr=Marshal.AllocHGlobal(int(IntPtr.Size));

  var result=int(VK_Invoke("Create3",[vkCreateInstance_ptr,createInfo,IntPtr.Zero,instPtr]));

  if(result==VK_SUCCESS){
    vkInstance=Marshal.ReadIntPtr(instPtr);
    DebugLog("Instance: "+vkInstance);
  }

  else{
    DebugLog("Failed: "+result);
  }

  Marshal.FreeHGlobal(instPtr);
  Marshal.FreeHGlobal(createInfo);
  Marshal.FreeHGlobal(appInfo);

  Marshal.FreeHGlobal(appName);
  Marshal.FreeHGlobal(engName);
  Marshal.FreeHGlobal(extArr);

  Marshal.FreeHGlobal(ext1);
  Marshal.FreeHGlobal(ext2);

  return result==VK_SUCCESS;

}

// Select physical device
function SelectPhysicalDevice():Boolean{

  DebugLog("Selecting physical device...");

  var cntPtr=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(cntPtr,0,0);

  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,IntPtr.Zero]);

  var cnt=Marshal.ReadInt32(cntPtr);

  if(cnt==0){
    Marshal.FreeHGlobal(cntPtr);
    return false;
  }

  var devs=Marshal.AllocHGlobal(int(IntPtr.Size*cnt));

  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,devs]);

  vkPhysicalDevice=Marshal.ReadIntPtr(devs);

  DebugLog("Physical device: "+vkPhysicalDevice);

  Marshal.FreeHGlobal(cntPtr);
  Marshal.FreeHGlobal(devs);

  return true;

}

// Find a graphics-capable queue family
function FindGraphicsQueueFamily():Boolean{

  var cntPtr=Marshal.AllocHGlobal(4);

  Marshal.WriteInt32(cntPtr,0,0);

  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,IntPtr.Zero]);

  var cnt=Marshal.ReadInt32(cntPtr);

  var props=Marshal.AllocHGlobal(int(24*cnt));

  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,props]);

  for(var i=0;
  i<cnt;
  i++){
    if((Marshal.ReadInt32(props,i*24)&VK_QUEUE_GRAPHICS_BIT)!=0){
      vkGraphicsQueueFamilyIndex=uint(i);
      DebugLog("Graphics queue family: "+i);
      Marshal.FreeHGlobal(cntPtr);
      Marshal.FreeHGlobal(props);
      return true;
    }
  }

  Marshal.FreeHGlobal(cntPtr);
  Marshal.FreeHGlobal(props);
  return false;

}

// Create logical device
function CreateLogicalDevice():Boolean{

  DebugLog("Creating logical device...");

  var priority=Marshal.AllocHGlobal(4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,priority,4);

  var queueInfo=Marshal.AllocHGlobal(40);
  ClearMem(queueInfo,40);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(queueInfo,0,VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    Marshal.WriteInt32(queueInfo,20,int(vkGraphicsQueueFamilyIndex));
    Marshal.WriteInt32(queueInfo,24,1);
    Marshal.WriteIntPtr(queueInfo,32,priority);
  }

  else{
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
    Marshal.WriteInt32(devInfo,20,1);
    Marshal.WriteIntPtr(devInfo,24,queueInfo);
    Marshal.WriteInt32(devInfo,48,1);
    Marshal.WriteIntPtr(devInfo,56,extArr);
  }

  else{
    Marshal.WriteInt32(devInfo,0,VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    Marshal.WriteInt32(devInfo,12,1);
    Marshal.WriteIntPtr(devInfo,16,queueInfo);
    Marshal.WriteInt32(devInfo,28,1);
    Marshal.WriteIntPtr(devInfo,32,extArr);
  }

  var devPtr=Marshal.AllocHGlobal(int(IntPtr.Size));

  var result=int(VK_Invoke("Create4",[vkCreateDevice_ptr,vkPhysicalDevice,devInfo,IntPtr.Zero,devPtr]));

  if(result==VK_SUCCESS){
    vkDevice=Marshal.ReadIntPtr(devPtr);
    DebugLog("Device: "+vkDevice);
  }

  Marshal.FreeHGlobal(devPtr);
  Marshal.FreeHGlobal(devInfo);
  Marshal.FreeHGlobal(queueInfo);

  Marshal.FreeHGlobal(priority);
  Marshal.FreeHGlobal(extArr);
  Marshal.FreeHGlobal(swapExt);

  return result==VK_SUCCESS;

}

// Get device queue
function GetGraphicsQueue():void{

  var qPtr=Marshal.AllocHGlobal(int(IntPtr.Size));

  VK_Invoke("Void4",[vkGetDeviceQueue_ptr,vkDevice,uint(vkGraphicsQueueFamilyIndex),uint(0),qPtr]);

  vkGraphicsQueue=Marshal.ReadIntPtr(qPtr);

  Marshal.FreeHGlobal(qPtr);

  DebugLog("Graphics queue: "+vkGraphicsQueue);

}

// ===== Part 4: Surface, swapchain, and shaders =====

// Create Win32 surface
function CreateWin32Surface(hInst:IntPtr,hWnd:IntPtr):Boolean{

  DebugLog("Creating Win32 surface...");

  var ci=Marshal.AllocHGlobal(40);
  ClearMem(ci,40);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,24,hInst);
    Marshal.WriteIntPtr(ci,32,hWnd);
  }

  else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,12,hInst);
    Marshal.WriteIntPtr(ci,16,hWnd);
  }

  var sPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreateWin32SurfaceKHR_ptr,vkInstance,ci,IntPtr.Zero,sPtr]));

  if(r==VK_SUCCESS){
    vkSurface=ReadU64(sPtr,0);
    DebugLog("Surface: "+vkSurface);
  }

  Marshal.FreeHGlobal(sPtr);
  Marshal.FreeHGlobal(ci);

  return r==VK_SUCCESS;

}

// Create swapchain
function CreateSwapchain():Boolean{

  DebugLog("Creating swapchain...");

  var ci=Marshal.AllocHGlobal(104);
  ClearMem(ci,104);

  if(IntPtr.Size==8){

    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,24,vkSurface);

    Marshal.WriteInt32(ci,32,2);
    Marshal.WriteInt32(ci,36,VK_FORMAT_B8G8R8A8_SRGB);

    Marshal.WriteInt32(ci,40,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);

    Marshal.WriteInt32(ci,44,int(windowWidth));
    Marshal.WriteInt32(ci,48,int(windowHeight));

    Marshal.WriteInt32(ci,52,1);
    Marshal.WriteInt32(ci,56,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);

    Marshal.WriteInt32(ci,60,VK_SHARING_MODE_EXCLUSIVE);
    Marshal.WriteInt32(ci,80,1);

    Marshal.WriteInt32(ci,84,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR);
    Marshal.WriteInt32(ci,88,VK_PRESENT_MODE_FIFO_KHR);

    Marshal.WriteInt32(ci,92,1);

  }
  else{

    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,12,vkSurface);

    Marshal.WriteInt32(ci,20,2);
    Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB);

    Marshal.WriteInt32(ci,28,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);

    Marshal.WriteInt32(ci,32,int(windowWidth));
    Marshal.WriteInt32(ci,36,int(windowHeight));

    Marshal.WriteInt32(ci,40,1);
    Marshal.WriteInt32(ci,44,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);

    Marshal.WriteInt32(ci,48,VK_SHARING_MODE_EXCLUSIVE);
    Marshal.WriteInt32(ci,60,1);

    Marshal.WriteInt32(ci,64,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR);
    Marshal.WriteInt32(ci,68,VK_PRESENT_MODE_FIFO_KHR);

    Marshal.WriteInt32(ci,72,1);

  }

  var swPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreateSwapchainKHR_ptr,vkDevice,ci,IntPtr.Zero,swPtr]));

  if(r==VK_SUCCESS){
    vkSwapchain=ReadU64(swPtr,0);
    DebugLog("Swapchain: "+vkSwapchain);
  }

  Marshal.FreeHGlobal(swPtr);
  Marshal.FreeHGlobal(ci);

  return r==VK_SUCCESS;

}

// Get swapchain images
function GetSwapchainImages():Boolean{

  var cntPtr=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(cntPtr,0,0);

  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,IntPtr.Zero]);

  vkSwapchainImageCount=uint(Marshal.ReadInt32(cntPtr));

  var imgs=Marshal.AllocHGlobal(int(8*vkSwapchainImageCount));

  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,imgs]);

  vkSwapchainImages=new ulong[vkSwapchainImageCount];

  for(var i:uint=0;
  i<vkSwapchainImageCount;
  i++)vkSwapchainImages[i]=ReadU64(imgs,int(i*8));

  DebugLog("Swapchain images: "+vkSwapchainImageCount);

  Marshal.FreeHGlobal(cntPtr);
  Marshal.FreeHGlobal(imgs);

  return true;

}

// Create image views
function CreateImageViews():Boolean{

  vkSwapchainImageViews=new ulong[vkSwapchainImageCount];

  var ci=Marshal.AllocHGlobal(80);

  for(var i:uint=0;
  i<vkSwapchainImageCount;
  i++){

    ClearMem(ci,80);

    if(IntPtr.Size==8){

      Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
      WriteU64(ci,24,vkSwapchainImages[i]);

      Marshal.WriteInt32(ci,32,VK_IMAGE_VIEW_TYPE_2D);
      Marshal.WriteInt32(ci,36,VK_FORMAT_B8G8R8A8_SRGB);

      Marshal.WriteInt32(ci,56,VK_IMAGE_ASPECT_COLOR_BIT);
      Marshal.WriteInt32(ci,64,1);
      Marshal.WriteInt32(ci,72,1);

    }
    else{

      Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
      WriteU64(ci,12,vkSwapchainImages[i]);

      Marshal.WriteInt32(ci,20,VK_IMAGE_VIEW_TYPE_2D);
      Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB);

      Marshal.WriteInt32(ci,44,VK_IMAGE_ASPECT_COLOR_BIT);
      Marshal.WriteInt32(ci,52,1);
      Marshal.WriteInt32(ci,60,1);

    }

    var ivPtr=Marshal.AllocHGlobal(8);

    var r=int(VK_Invoke("Create4",[vkCreateImageView_ptr,vkDevice,ci,IntPtr.Zero,ivPtr]));

    if(r!=VK_SUCCESS){
      Marshal.FreeHGlobal(ivPtr);
      Marshal.FreeHGlobal(ci);
      return false;
    }

    vkSwapchainImageViews[i]=ReadU64(ivPtr,0);

    Marshal.FreeHGlobal(ivPtr);

  }

  Marshal.FreeHGlobal(ci);

  DebugLog("Image views created");

  return true;

}

// SPIR-V vertex shader
function GetVertexShaderSpirV():byte[]{

  return [
  0x03,0x02,0x23,0x07,0x00,0x00,0x01,0x00,0x0b,0x00,0x0d,0x00,0x24,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x11,0x00,0x02,0x00,0x01,0x00,0x00,0x00,0x0b,0x00,0x06,0x00,
  0x01,0x00,0x00,0x00,0x47,0x4c,0x53,0x4c,0x2e,0x73,0x74,0x64,0x2e,0x34,0x35,0x30,
  0x00,0x00,0x00,0x00,0x0e,0x00,0x03,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x0f,0x00,0x09,0x00,0x00,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x6d,0x61,0x69,0x6e,
  0x00,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,0x12,0x00,0x00,0x00,0x1c,0x00,0x00,0x00,
  0x1e,0x00,0x00,0x00,0x03,0x00,0x03,0x00,0x02,0x00,0x00,0x00,0xc2,0x01,0x00,0x00,
  0x05,0x00,0x04,0x00,0x04,0x00,0x00,0x00,0x6d,0x61,0x69,0x6e,0x00,0x00,0x00,0x00,
  0x05,0x00,0x06,0x00,0x0b,0x00,0x00,0x00,0x67,0x6c,0x5f,0x50,0x65,0x72,0x56,0x65,
  0x72,0x74,0x65,0x78,0x00,0x00,0x00,0x00,0x06,0x00,0x06,0x00,0x0b,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x67,0x6c,0x5f,0x50,0x6f,0x73,0x69,0x74,0x69,0x6f,0x6e,0x00,
  0x06,0x00,0x07,0x00,0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x67,0x6c,0x5f,0x50,
  0x6f,0x69,0x6e,0x74,0x53,0x69,0x7a,0x65,0x00,0x00,0x00,0x00,0x06,0x00,0x07,0x00,
  0x0b,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x67,0x6c,0x5f,0x43,0x6c,0x69,0x70,0x44,
  0x69,0x73,0x74,0x61,0x6e,0x63,0x65,0x00,0x06,0x00,0x07,0x00,0x0b,0x00,0x00,0x00,
  0x03,0x00,0x00,0x00,0x67,0x6c,0x5f,0x43,0x75,0x6c,0x6c,0x44,0x69,0x73,0x74,0x61,
  0x6e,0x63,0x65,0x00,0x05,0x00,0x03,0x00,0x0d,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x05,0x00,0x05,0x00,0x12,0x00,0x00,0x00,0x69,0x6e,0x50,0x6f,0x73,0x69,0x74,0x69,
  0x6f,0x6e,0x00,0x00,0x05,0x00,0x05,0x00,0x1c,0x00,0x00,0x00,0x66,0x72,0x61,0x67,
  0x43,0x6f,0x6c,0x6f,0x72,0x00,0x00,0x00,0x05,0x00,0x04,0x00,0x1e,0x00,0x00,0x00,
  0x69,0x6e,0x43,0x6f,0x6c,0x6f,0x72,0x00,0x48,0x00,0x05,0x00,0x0b,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x0b,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x48,0x00,0x05,0x00,
  0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x48,0x00,0x05,0x00,0x0b,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x0b,0x00,0x00,0x00,
  0x03,0x00,0x00,0x00,0x48,0x00,0x05,0x00,0x0b,0x00,0x00,0x00,0x03,0x00,0x00,0x00,
  0x0b,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x47,0x00,0x03,0x00,0x0b,0x00,0x00,0x00,
  0x02,0x00,0x00,0x00,0x47,0x00,0x04,0x00,0x12,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x47,0x00,0x04,0x00,0x1c,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x47,0x00,0x04,0x00,0x1e,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,
  0x01,0x00,0x00,0x00,0x13,0x00,0x02,0x00,0x02,0x00,0x00,0x00,0x21,0x00,0x03,0x00,
  0x03,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x16,0x00,0x03,0x00,0x06,0x00,0x00,0x00,
  0x20,0x00,0x00,0x00,0x17,0x00,0x04,0x00,0x07,0x00,0x00,0x00,0x06,0x00,0x00,0x00,
  0x04,0x00,0x00,0x00,0x15,0x00,0x04,0x00,0x08,0x00,0x00,0x00,0x20,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x2b,0x00,0x04,0x00,0x08,0x00,0x00,0x00,0x09,0x00,0x00,0x00,
  0x01,0x00,0x00,0x00,0x1c,0x00,0x04,0x00,0x0a,0x00,0x00,0x00,0x06,0x00,0x00,0x00,
  0x09,0x00,0x00,0x00,0x1e,0x00,0x06,0x00,0x0b,0x00,0x00,0x00,0x07,0x00,0x00,0x00,
  0x06,0x00,0x00,0x00,0x0a,0x00,0x00,0x00,0x0a,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x0c,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x0b,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x0c,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x15,0x00,0x04,0x00,
  0x0e,0x00,0x00,0x00,0x20,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x2b,0x00,0x04,0x00,
  0x0e,0x00,0x00,0x00,0x0f,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x17,0x00,0x04,0x00,
  0x10,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x11,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x11,0x00,0x00,0x00,0x12,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x2b,0x00,0x04,0x00,
  0x06,0x00,0x00,0x00,0x14,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x2b,0x00,0x04,0x00,
  0x06,0x00,0x00,0x00,0x15,0x00,0x00,0x00,0x00,0x00,0x80,0x3f,0x20,0x00,0x04,0x00,
  0x19,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x17,0x00,0x04,0x00,
  0x1a,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x1b,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x1a,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x1b,0x00,0x00,0x00,0x1c,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x1d,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x1a,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x1d,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x36,0x00,0x05,0x00,
  0x02,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x03,0x00,0x00,0x00,
  0xf8,0x00,0x02,0x00,0x05,0x00,0x00,0x00,0x3d,0x00,0x04,0x00,0x10,0x00,0x00,0x00,
  0x13,0x00,0x00,0x00,0x12,0x00,0x00,0x00,0x51,0x00,0x05,0x00,0x06,0x00,0x00,0x00,
  0x16,0x00,0x00,0x00,0x13,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x51,0x00,0x05,0x00,
  0x06,0x00,0x00,0x00,0x17,0x00,0x00,0x00,0x13,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x50,0x00,0x07,0x00,0x07,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x16,0x00,0x00,0x00,
  0x17,0x00,0x00,0x00,0x14,0x00,0x00,0x00,0x15,0x00,0x00,0x00,0x41,0x00,0x05,0x00,
  0x19,0x00,0x00,0x00,0x1a,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,0x0f,0x00,0x00,0x00,
  0x3e,0x00,0x03,0x00,0x1a,0x00,0x00,0x00,0x18,0x00,0x00,0x00,0x3d,0x00,0x04,0x00,
  0x1a,0x00,0x00,0x00,0x1f,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,0x3e,0x00,0x03,0x00,
  0x1c,0x00,0x00,0x00,0x1f,0x00,0x00,0x00,0xfd,0x00,0x01,0x00,0x38,0x00,0x01,0x00
  ];

}

// SPIR-V fragment shader
function GetFragmentShaderSpirV():byte[]{

  return [
  0x03,0x02,0x23,0x07,0x00,0x00,0x01,0x00,0x0b,0x00,0x0d,0x00,0x14,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x11,0x00,0x02,0x00,0x01,0x00,0x00,0x00,0x0b,0x00,0x06,0x00,
  0x01,0x00,0x00,0x00,0x47,0x4c,0x53,0x4c,0x2e,0x73,0x74,0x64,0x2e,0x34,0x35,0x30,
  0x00,0x00,0x00,0x00,0x0e,0x00,0x03,0x00,0x00,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x0f,0x00,0x07,0x00,0x04,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x6d,0x61,0x69,0x6e,
  0x00,0x00,0x00,0x00,0x09,0x00,0x00,0x00,0x0c,0x00,0x00,0x00,0x10,0x00,0x03,0x00,
  0x04,0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x03,0x00,0x03,0x00,0x02,0x00,0x00,0x00,
  0xc2,0x01,0x00,0x00,0x05,0x00,0x04,0x00,0x04,0x00,0x00,0x00,0x6d,0x61,0x69,0x6e,
  0x00,0x00,0x00,0x00,0x05,0x00,0x05,0x00,0x09,0x00,0x00,0x00,0x6f,0x75,0x74,0x43,
  0x6f,0x6c,0x6f,0x72,0x00,0x00,0x00,0x00,0x05,0x00,0x05,0x00,0x0c,0x00,0x00,0x00,
  0x66,0x72,0x61,0x67,0x43,0x6f,0x6c,0x6f,0x72,0x00,0x00,0x00,0x47,0x00,0x04,0x00,
  0x09,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x47,0x00,0x04,0x00,
  0x0c,0x00,0x00,0x00,0x1e,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x13,0x00,0x02,0x00,
  0x02,0x00,0x00,0x00,0x21,0x00,0x03,0x00,0x03,0x00,0x00,0x00,0x02,0x00,0x00,0x00,
  0x16,0x00,0x03,0x00,0x06,0x00,0x00,0x00,0x20,0x00,0x00,0x00,0x17,0x00,0x04,0x00,
  0x07,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x08,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x08,0x00,0x00,0x00,0x09,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x17,0x00,0x04,0x00,
  0x0a,0x00,0x00,0x00,0x06,0x00,0x00,0x00,0x03,0x00,0x00,0x00,0x20,0x00,0x04,0x00,
  0x0b,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x0a,0x00,0x00,0x00,0x3b,0x00,0x04,0x00,
  0x0b,0x00,0x00,0x00,0x0c,0x00,0x00,0x00,0x01,0x00,0x00,0x00,0x2b,0x00,0x04,0x00,
  0x06,0x00,0x00,0x00,0x0e,0x00,0x00,0x00,0x00,0x00,0x80,0x3f,0x36,0x00,0x05,0x00,
  0x02,0x00,0x00,0x00,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x03,0x00,0x00,0x00,
  0xf8,0x00,0x02,0x00,0x05,0x00,0x00,0x00,0x3d,0x00,0x04,0x00,0x0a,0x00,0x00,0x00,
  0x0d,0x00,0x00,0x00,0x0c,0x00,0x00,0x00,0x51,0x00,0x05,0x00,0x06,0x00,0x00,0x00,
  0x0f,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x51,0x00,0x05,0x00,
  0x06,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,0x01,0x00,0x00,0x00,
  0x51,0x00,0x05,0x00,0x06,0x00,0x00,0x00,0x11,0x00,0x00,0x00,0x0d,0x00,0x00,0x00,
  0x02,0x00,0x00,0x00,0x50,0x00,0x07,0x00,0x07,0x00,0x00,0x00,0x12,0x00,0x00,0x00,
  0x0f,0x00,0x00,0x00,0x10,0x00,0x00,0x00,0x11,0x00,0x00,0x00,0x0e,0x00,0x00,0x00,
  0x3e,0x00,0x03,0x00,0x09,0x00,0x00,0x00,0x12,0x00,0x00,0x00,0xfd,0x00,0x01,0x00,
  0x38,0x00,0x01,0x00
  ];

}

// Create shader module
function CreateShaderModule(spirv:byte[]):ulong{

  if(spirv==null){
    DebugLog("CreateShaderModule: spirv is null");
    return 0;
  }

  if((spirv.length % 4) != 0){
    DebugLog("SPIR-V size is not a multiple of 4: " + spirv.length);
    return 0;
  }

  var handle=GCHandle.Alloc(spirv, GCHandleType.Pinned);
  var codePtr=handle.AddrOfPinnedObject();

  var ci=Marshal.AllocHGlobal(40);
  ClearMem(ci,40);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    WriteU64(ci,24,ulong(spirv.length));
    Marshal.WriteIntPtr(ci,32,codePtr);
  }

  else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    Marshal.WriteInt32(ci,12,spirv.length);
    Marshal.WriteIntPtr(ci,16,codePtr);
  }

  var modPtr=Marshal.AllocHGlobal(8);

  DebugLog("vkCreateShaderModule_ptr=" + PtrHex(vkCreateShaderModule_ptr) + ", spirvBytes=" + spirv.length);
  // Dump first 16 bytes of SPIR-V
  try { DebugLog("SPV[0..15]=" + DumpHex(codePtr, 16)); } catch(_e) {}
  try { DebugLog("VkShaderModuleCreateInfo=" + DumpHex(ci, 40)); } catch(_e2) {}
  var r:int;
  // Call directly from vulkan-1.dll to avoid function-pointer invocation issues
  r = int(InvokeWin32(
    "vulkan-1.dll",
    Type.GetType("System.Int32"),
    "vkCreateShaderModule",
    [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")],
    [vkDevice, ci, IntPtr.Zero, modPtr]
  ));

  var mod:ulong=(r==VK_SUCCESS)?ReadU64(modPtr,0):0;

  Marshal.FreeHGlobal(modPtr);
  Marshal.FreeHGlobal(ci);
  handle.Free();

  return mod;

}

// ===== Part 5: Render pass, pipeline, and resources =====

// Create render pass
function CreateRenderPass():Boolean{

  DebugLog("Creating render pass...");

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
    Marshal.WriteInt32(subpass,24,1);
    Marshal.WriteIntPtr(subpass,32,colorRef);
  }

  else{
    Marshal.WriteInt32(subpass,4,VK_PIPELINE_BIND_POINT_GRAPHICS);
    Marshal.WriteInt32(subpass,16,1);
    Marshal.WriteIntPtr(subpass,20,colorRef);
  }

  var dep=Marshal.AllocHGlobal(28);

  Marshal.WriteInt32(dep,0,-1);
  Marshal.WriteInt32(dep,4,0);
  Marshal.WriteInt32(dep,8,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

  Marshal.WriteInt32(dep,12,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  Marshal.WriteInt32(dep,16,0);
  Marshal.WriteInt32(dep,20,VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);

  var ci=Marshal.AllocHGlobal(64);
  ClearMem(ci,64);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,20,1);
    Marshal.WriteIntPtr(ci,24,attach);
    Marshal.WriteInt32(ci,32,1);
    Marshal.WriteIntPtr(ci,40,subpass);
    Marshal.WriteInt32(ci,48,1);
    Marshal.WriteIntPtr(ci,56,dep);
  }

  else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,12,1);
    Marshal.WriteIntPtr(ci,16,attach);
    Marshal.WriteInt32(ci,20,1);
    Marshal.WriteIntPtr(ci,24,subpass);
    Marshal.WriteInt32(ci,28,1);
    Marshal.WriteIntPtr(ci,32,dep);
  }

  var rpPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreateRenderPass_ptr,vkDevice,ci,IntPtr.Zero,rpPtr]));

  if(r==VK_SUCCESS){
    vkRenderPass=ReadU64(rpPtr,0);
    DebugLog("Render pass: "+vkRenderPass);
  }

  Marshal.FreeHGlobal(rpPtr);
  Marshal.FreeHGlobal(ci);
  Marshal.FreeHGlobal(dep);
  Marshal.FreeHGlobal(subpass);
  Marshal.FreeHGlobal(colorRef);
  Marshal.FreeHGlobal(attach);

  return r==VK_SUCCESS;

}

// Create pipeline layout
function CreatePipelineLayout():Boolean{

  var ci=Marshal.AllocHGlobal(48);
  ClearMem(ci,48);

  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);

  var plPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreatePipelineLayout_ptr,vkDevice,ci,IntPtr.Zero,plPtr]));

  if(r==VK_SUCCESS){
    vkPipelineLayout=ReadU64(plPtr,0);
    DebugLog("Pipeline layout: "+vkPipelineLayout);
  }

  Marshal.FreeHGlobal(plPtr);
  Marshal.FreeHGlobal(ci);

  return r==VK_SUCCESS;

}

// Create graphics pipeline
function CreateGraphicsPipeline():Boolean{

  DebugLog("Creating graphics pipeline...");

  var vertSpv:byte[]=null;
  var fragSpv:byte[]=null;
  try{
    var vertSrc=ReadShaderText("hello.vert", VERT_GLSL);
    var fragSrc=ReadShaderText("hello.frag", FRAG_GLSL);
    vertSpv=ShadercCompile(vertSrc,SHADERC_SHADER_KIND_VERTEX,"hello.vert","main");
    fragSpv=ShadercCompile(fragSrc,SHADERC_SHADER_KIND_FRAGMENT,"hello.frag","main");
    DebugLog("shaderc compile OK: vert="+vertSpv.length+", frag="+fragSpv.length);
  }catch(ex){
    DebugLog("shaderc compile failed, fallback to embedded SPIR-V: "+ex.ToString());
    vertSpv=GetVertexShaderSpirV();
    fragSpv=GetFragmentShaderSpirV();
  }

  var vertMod=CreateShaderModule(vertSpv);

  var fragMod=CreateShaderModule(fragSpv);

  if(vertMod==0||fragMod==0)return false;

  var mainName=Marshal.StringToHGlobalAnsi("main");

  var stageSize=(IntPtr.Size==8)?48:32;

  var stages=Marshal.AllocHGlobal(int(stageSize*2));
  ClearMem(stages,stageSize*2);

  // Vertex
  Marshal.WriteInt32(stages,0,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);

  Marshal.WriteInt32(stages,(IntPtr.Size==8)?20:12,VK_SHADER_STAGE_VERTEX_BIT);

  WriteU64(stages,(IntPtr.Size==8)?24:16,vertMod);

  Marshal.WriteIntPtr(stages,(IntPtr.Size==8)?32:24,mainName);

  // Fragment
  Marshal.WriteInt32(stages,stageSize,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);

  Marshal.WriteInt32(stages,stageSize+((IntPtr.Size==8)?20:12),VK_SHADER_STAGE_FRAGMENT_BIT);

  WriteU64(stages,stageSize+((IntPtr.Size==8)?24:16),fragMod);

  Marshal.WriteIntPtr(stages,stageSize+((IntPtr.Size==8)?32:24),mainName);

  // Vertex input
  var bindDesc=Marshal.AllocHGlobal(12);
  Marshal.WriteInt32(bindDesc,0,0);
  Marshal.WriteInt32(bindDesc,4,20);
  Marshal.WriteInt32(bindDesc,8,VK_VERTEX_INPUT_RATE_VERTEX);

  var attrDesc=Marshal.AllocHGlobal(32);

  Marshal.WriteInt32(attrDesc,0,0);
  Marshal.WriteInt32(attrDesc,4,0);
  Marshal.WriteInt32(attrDesc,8,VK_FORMAT_R32G32_SFLOAT);
  Marshal.WriteInt32(attrDesc,12,0);

  Marshal.WriteInt32(attrDesc,16,1);
  Marshal.WriteInt32(attrDesc,20,0);
  Marshal.WriteInt32(attrDesc,24,VK_FORMAT_R32G32B32_SFLOAT);
  Marshal.WriteInt32(attrDesc,28,8);

  var vertexInput=Marshal.AllocHGlobal(48);
  ClearMem(vertexInput,48);

  Marshal.WriteInt32(vertexInput,0,VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(vertexInput,20,1);
    Marshal.WriteIntPtr(vertexInput,24,bindDesc);
    Marshal.WriteInt32(vertexInput,32,2);
    Marshal.WriteIntPtr(vertexInput,40,attrDesc);
  }

  else{
    Marshal.WriteInt32(vertexInput,12,1);
    Marshal.WriteIntPtr(vertexInput,16,bindDesc);
    Marshal.WriteInt32(vertexInput,20,2);
    Marshal.WriteIntPtr(vertexInput,24,attrDesc);
  }

  // Input assembly
  var inputAsm=Marshal.AllocHGlobal(32);
  ClearMem(inputAsm,32);

  Marshal.WriteInt32(inputAsm,0,VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);

  Marshal.WriteInt32(inputAsm,(IntPtr.Size==8)?20:12,VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);

  // Viewport state
  var viewportState=Marshal.AllocHGlobal(48);
  ClearMem(viewportState,48);

  Marshal.WriteInt32(viewportState,0,VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);

  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?20:12,1);
  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?32:20,1);

  // Rasterization
  var raster=Marshal.AllocHGlobal(64);
  ClearMem(raster,64);

  Marshal.WriteInt32(raster,0,VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);

  Marshal.WriteInt32(raster,(IntPtr.Size==8)?28:20,VK_POLYGON_MODE_FILL);

  Marshal.WriteInt32(raster,(IntPtr.Size==8)?32:24,VK_CULL_MODE_BACK_BIT);

  Marshal.WriteInt32(raster,(IntPtr.Size==8)?36:28,VK_FRONT_FACE_CLOCKWISE);

  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,IntPtr.Add(raster, int(((IntPtr.Size==8))?56:48)),4);

  // Multisample
  var multisample=Marshal.AllocHGlobal(48);
  ClearMem(multisample,48);

  Marshal.WriteInt32(multisample,0,VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);

  Marshal.WriteInt32(multisample,(IntPtr.Size==8)?20:12,VK_SAMPLE_COUNT_1_BIT);

  // Color blend
  var blendAttach=Marshal.AllocHGlobal(32);
  ClearMem(blendAttach,32);
  Marshal.WriteInt32(blendAttach,28,VK_COLOR_COMPONENT_RGBA);

  var colorBlend=Marshal.AllocHGlobal(56);
  ClearMem(colorBlend,56);

  Marshal.WriteInt32(colorBlend,0,VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(colorBlend,28,1);
    Marshal.WriteIntPtr(colorBlend,32,blendAttach);
  }

  else{
    Marshal.WriteInt32(colorBlend,20,1);
    Marshal.WriteIntPtr(colorBlend,24,blendAttach);
  }

  // Dynamic state
  var dynStates=Marshal.AllocHGlobal(8);
  Marshal.WriteInt32(dynStates,0,VK_DYNAMIC_STATE_VIEWPORT);
  Marshal.WriteInt32(dynStates,4,VK_DYNAMIC_STATE_SCISSOR);

  var dynState=Marshal.AllocHGlobal(32);
  ClearMem(dynState,32);

  Marshal.WriteInt32(dynState,0,VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(dynState,20,2);
    Marshal.WriteIntPtr(dynState,24,dynStates);
  }

  else{
    Marshal.WriteInt32(dynState,12,2);
    Marshal.WriteIntPtr(dynState,16,dynStates);
  }

  // Pipeline create info
  var pipeInfo=Marshal.AllocHGlobal(144);
  ClearMem(pipeInfo,144);

  Marshal.WriteInt32(pipeInfo,0,VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);

  if(IntPtr.Size==8){

    Marshal.WriteInt32(pipeInfo,20,2);
    Marshal.WriteIntPtr(pipeInfo,24,stages);

    Marshal.WriteIntPtr(pipeInfo,32,vertexInput);
    Marshal.WriteIntPtr(pipeInfo,40,inputAsm);

    Marshal.WriteIntPtr(pipeInfo,56,viewportState);
    Marshal.WriteIntPtr(pipeInfo,64,raster);

    Marshal.WriteIntPtr(pipeInfo,72,multisample);
    Marshal.WriteIntPtr(pipeInfo,88,colorBlend);

    Marshal.WriteIntPtr(pipeInfo,96,dynState);

    WriteU64(pipeInfo,104,vkPipelineLayout);
    WriteU64(pipeInfo,112,vkRenderPass);

    Marshal.WriteInt32(pipeInfo,136,-1);

  }
  else{

    Marshal.WriteInt32(pipeInfo,12,2);
    Marshal.WriteIntPtr(pipeInfo,16,stages);

    Marshal.WriteIntPtr(pipeInfo,20,vertexInput);
    Marshal.WriteIntPtr(pipeInfo,24,inputAsm);

    Marshal.WriteIntPtr(pipeInfo,32,viewportState);
    Marshal.WriteIntPtr(pipeInfo,36,raster);

    Marshal.WriteIntPtr(pipeInfo,40,multisample);
    Marshal.WriteIntPtr(pipeInfo,48,colorBlend);

    Marshal.WriteIntPtr(pipeInfo,52,dynState);

    WriteU64(pipeInfo,56,vkPipelineLayout);
    WriteU64(pipeInfo,64,vkRenderPass);

    Marshal.WriteInt32(pipeInfo,84,-1);

  }

  var pipePtr=Marshal.AllocHGlobal(8);

  var r=int(createVulkanInvoker.InvokeMember("CreatePipe",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateGraphicsPipelines_ptr,vkDevice,ulong(0),uint(1),pipeInfo,IntPtr.Zero,pipePtr]));

  if(r==VK_SUCCESS){
    vkGraphicsPipeline=ReadU64(pipePtr,0);
    DebugLog("Graphics pipeline: "+vkGraphicsPipeline);
  }

  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkDestroyShaderModule_ptr,vkDevice,vertMod,IntPtr.Zero]);

  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkDestroyShaderModule_ptr,vkDevice,fragMod,IntPtr.Zero]);

  Marshal.FreeHGlobal(pipePtr);
  Marshal.FreeHGlobal(pipeInfo);
  Marshal.FreeHGlobal(dynState);
  Marshal.FreeHGlobal(dynStates);

  Marshal.FreeHGlobal(colorBlend);
  Marshal.FreeHGlobal(blendAttach);
  Marshal.FreeHGlobal(multisample);
  Marshal.FreeHGlobal(raster);

  Marshal.FreeHGlobal(viewportState);
  Marshal.FreeHGlobal(inputAsm);
  Marshal.FreeHGlobal(vertexInput);

  Marshal.FreeHGlobal(attrDesc);
  Marshal.FreeHGlobal(bindDesc);
  Marshal.FreeHGlobal(stages);
  Marshal.FreeHGlobal(mainName);

  return r==VK_SUCCESS;

}

// Create framebuffers
function CreateFramebuffers():Boolean{

  DebugLog("Creating framebuffers...");

  vkFramebuffers=new ulong[vkSwapchainImageCount];

  var ci=Marshal.AllocHGlobal(64);
  var attachPtr=Marshal.AllocHGlobal(8);

  for(var i:uint=0;
  i<vkSwapchainImageCount;
  i++){

    ClearMem(ci,64);
    WriteU64(attachPtr,0,vkSwapchainImageViews[i]);

    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);

    if(IntPtr.Size==8){
      WriteU64(ci,24,vkRenderPass);
      Marshal.WriteInt32(ci,32,1);
      Marshal.WriteIntPtr(ci,40,attachPtr);
      Marshal.WriteInt32(ci,48,int(windowWidth));
      Marshal.WriteInt32(ci,52,int(windowHeight));
      Marshal.WriteInt32(ci,56,1);
    }

    else{
      WriteU64(ci,12,vkRenderPass);
      Marshal.WriteInt32(ci,20,1);
      Marshal.WriteIntPtr(ci,24,attachPtr);
      Marshal.WriteInt32(ci,28,int(windowWidth));
      Marshal.WriteInt32(ci,32,int(windowHeight));
      Marshal.WriteInt32(ci,36,1);
    }

    var fbPtr=Marshal.AllocHGlobal(8);

    var r=int(VK_Invoke("Create4",[vkCreateFramebuffer_ptr,vkDevice,ci,IntPtr.Zero,fbPtr]));

    if(r!=VK_SUCCESS){
      Marshal.FreeHGlobal(fbPtr);
      Marshal.FreeHGlobal(attachPtr);
      Marshal.FreeHGlobal(ci);
      return false;
    }

    vkFramebuffers[i]=ReadU64(fbPtr,0);
    Marshal.FreeHGlobal(fbPtr);

  }

  Marshal.FreeHGlobal(attachPtr);
  Marshal.FreeHGlobal(ci);

  DebugLog("Framebuffers created");

  return true;

}

// Create command pool
function CreateCommandPool():Boolean{

  var ci=Marshal.AllocHGlobal(24);
  ClearMem(ci,24);

  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);

  Marshal.WriteInt32(ci,(IntPtr.Size==8)?16:8,VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);

  Marshal.WriteInt32(ci,(IntPtr.Size==8)?20:12,int(vkGraphicsQueueFamilyIndex));

  var poolPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreateCommandPool_ptr,vkDevice,ci,IntPtr.Zero,poolPtr]));

  if(r==VK_SUCCESS){
    vkCommandPool=ReadU64(poolPtr,0);
    DebugLog("Command pool: "+vkCommandPool);
  }

  Marshal.FreeHGlobal(poolPtr);
  Marshal.FreeHGlobal(ci);

  return r==VK_SUCCESS;

}

// Allocate command buffers
function AllocateCommandBuffers():Boolean{

  var ai=Marshal.AllocHGlobal(32);
  ClearMem(ai,32);

  Marshal.WriteInt32(ai,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);

  if(IntPtr.Size==8){
    WriteU64(ai,16,vkCommandPool);
    Marshal.WriteInt32(ai,24,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    Marshal.WriteInt32(ai,28,1);
  }

  else{
    WriteU64(ai,8,vkCommandPool);
    Marshal.WriteInt32(ai,16,VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    Marshal.WriteInt32(ai,20,1);
  }

  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));

  var r=int(VK_Invoke("Create3",[vkAllocateCommandBuffers_ptr,vkDevice,ai,cbPtr]));

  if(r==VK_SUCCESS){
    vkCommandBuffer=Marshal.ReadIntPtr(cbPtr);
    DebugLog("Command buffer: "+vkCommandBuffer);
  }

  Marshal.FreeHGlobal(cbPtr);
  Marshal.FreeHGlobal(ai);

  return r==VK_SUCCESS;

}

// Create synchronization objects
function CreateSyncObjects():Boolean{

  var semInfo=Marshal.AllocHGlobal(24);
  ClearMem(semInfo,24);
  Marshal.WriteInt32(semInfo,0,VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO);

  var fenceInfo=Marshal.AllocHGlobal(24);
  ClearMem(fenceInfo,24);

  Marshal.WriteInt32(fenceInfo,0,VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);

  Marshal.WriteInt32(fenceInfo,(IntPtr.Size==8)?16:8,VK_FENCE_CREATE_SIGNALED_BIT);

  var ptr=Marshal.AllocHGlobal(8);

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);

  vkImageAvailableSemaphore=ReadU64(ptr,0);

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);

  vkRenderFinishedSemaphore=ReadU64(ptr,0);

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateFence_ptr,vkDevice,fenceInfo,IntPtr.Zero,ptr]);

  vkInFlightFence=ReadU64(ptr,0);

  Marshal.FreeHGlobal(ptr);
  Marshal.FreeHGlobal(semInfo);
  Marshal.FreeHGlobal(fenceInfo);

  DebugLog("Sync objects created");

  return true;

}

// Create vertex buffer
function CreateVertexBuffer():Boolean{

  DebugLog("Creating vertex buffer...");

  var verts=new float[15];

  verts[0]=0.0;
  verts[1]=-0.5;
  verts[2]=1.0;
  verts[3]=0.0;
  verts[4]=0.0;
  // Top, Red
  verts[5]=0.5;
  verts[6]=0.5;
  verts[7]=0.0;
  verts[8]=1.0;
  verts[9]=0.0;
  // Right, Green
  verts[10]=-0.5;
  verts[11]=0.5;
  verts[12]=0.0;
  verts[13]=0.0;
  verts[14]=1.0;
  // Left, Blue
  var bufSize:ulong=60;

  var bufInfo=Marshal.AllocHGlobal(56);
  ClearMem(bufInfo,56);

  Marshal.WriteInt32(bufInfo,0,VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO);

  if(IntPtr.Size==8){
    WriteU64(bufInfo,24,bufSize);
    Marshal.WriteInt32(bufInfo,32,VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    Marshal.WriteInt32(bufInfo,36,VK_SHARING_MODE_EXCLUSIVE);
  }

  else{
    WriteU64(bufInfo,12,bufSize);
    Marshal.WriteInt32(bufInfo,20,VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    Marshal.WriteInt32(bufInfo,24,VK_SHARING_MODE_EXCLUSIVE);
  }

  var bufPtr=Marshal.AllocHGlobal(8);

  var r=int(VK_Invoke("Create4",[vkCreateBuffer_ptr,vkDevice,bufInfo,IntPtr.Zero,bufPtr]));

  if(r!=VK_SUCCESS){
    Marshal.FreeHGlobal(bufPtr);
    Marshal.FreeHGlobal(bufInfo);
    return false;
  }

  vkVertexBuffer=ReadU64(bufPtr,0);

  var allocInfo=Marshal.AllocHGlobal(32);
  ClearMem(allocInfo,32);

  Marshal.WriteInt32(allocInfo,0,VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);

  if(IntPtr.Size==8){
    WriteU64(allocInfo,16,bufSize);
    Marshal.WriteInt32(allocInfo,24,0);
  }

  else{
    WriteU64(allocInfo,8,bufSize);
    Marshal.WriteInt32(allocInfo,16,0);
  }

  var memPtr=Marshal.AllocHGlobal(8);

  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkAllocateMemory_ptr,vkDevice,allocInfo,IntPtr.Zero,memPtr]);

  vkVertexBufferMemory=ReadU64(memPtr,0);

  createVulkanInvoker.InvokeMember("Bind",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkBindBufferMemory_ptr,vkDevice,vkVertexBuffer,vkVertexBufferMemory,ulong(0)]);

  var dataPtr=Marshal.AllocHGlobal(int(IntPtr.Size));

  createVulkanInvoker.InvokeMember("Map",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkMapMemory_ptr,vkDevice,vkVertexBufferMemory,ulong(0),bufSize,uint(0),dataPtr]);

  var mapped=Marshal.ReadIntPtr(dataPtr);

  for(var i=0;
  i<verts.length;
  i++)Marshal.Copy(BitConverter.GetBytes(verts[i]),0,IntPtr.Add(mapped, int(i*4)),4);

  createVulkanInvoker.InvokeMember("Unmap",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkUnmapMemory_ptr,vkDevice,vkVertexBufferMemory]);

  Marshal.FreeHGlobal(dataPtr);
  Marshal.FreeHGlobal(memPtr);
  Marshal.FreeHGlobal(allocInfo);
  Marshal.FreeHGlobal(bufPtr);
  Marshal.FreeHGlobal(bufInfo);

  DebugLog("Vertex buffer created");

  return true;

}

// ===== Part 6: Render loop and main =====

// Record command buffers
function RecordCommandBuffer(imgIdx:uint):Boolean{

  createVulkanInvoker.InvokeMember("ResetCmd",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkResetCommandBuffer_ptr,vkCommandBuffer,uint(0)]);

  var beginInfo=Marshal.AllocHGlobal(32);
  ClearMem(beginInfo,32);
  Marshal.WriteInt32(beginInfo,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);

  VK_Invoke("Create2",[vkBeginCommandBuffer_ptr,vkCommandBuffer,beginInfo]);

  var clearVal=Marshal.AllocHGlobal(16);

  Marshal.Copy(BitConverter.GetBytes(float(0.1)),0,clearVal,4);
  Marshal.Copy(BitConverter.GetBytes(float(0.1)),0,IntPtr.Add(clearVal, int(4)),4);

  Marshal.Copy(BitConverter.GetBytes(float(0.2)),0,IntPtr.Add(clearVal, int(8)),4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,IntPtr.Add(clearVal, int(12)),4);

  var rpBegin=Marshal.AllocHGlobal(64);
  ClearMem(rpBegin,64);
  Marshal.WriteInt32(rpBegin,0,VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);

  if(IntPtr.Size==8){
    WriteU64(rpBegin,16,vkRenderPass);
    WriteU64(rpBegin,24,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,40,int(windowWidth));
    Marshal.WriteInt32(rpBegin,44,int(windowHeight));
    Marshal.WriteInt32(rpBegin,48,1);
    Marshal.WriteIntPtr(rpBegin,56,clearVal);
  }

  else{
    WriteU64(rpBegin,8,vkRenderPass);
    WriteU64(rpBegin,16,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,32,int(windowWidth));
    Marshal.WriteInt32(rpBegin,36,int(windowHeight));
    Marshal.WriteInt32(rpBegin,40,1);
    Marshal.WriteIntPtr(rpBegin,44,clearVal);
  }

  createVulkanInvoker.InvokeMember("BeginRP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdBeginRenderPass_ptr,vkCommandBuffer,rpBegin,uint(VK_SUBPASS_CONTENTS_INLINE)]);

  createVulkanInvoker.InvokeMember("BindPipe",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdBindPipeline_ptr,vkCommandBuffer,uint(VK_PIPELINE_BIND_POINT_GRAPHICS),vkGraphicsPipeline]);

  var viewport=Marshal.AllocHGlobal(24);

  Marshal.Copy(BitConverter.GetBytes(float(0)),0,viewport,4);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport, int(4)),4);

  Marshal.Copy(BitConverter.GetBytes(float(windowWidth)),0,IntPtr.Add(viewport, int(8)),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowHeight)),0,IntPtr.Add(viewport, int(12)),4);

  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport, int(16)),4);
  Marshal.Copy(BitConverter.GetBytes(float(1)),0,IntPtr.Add(viewport, int(20)),4);

  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdSetViewport_ptr,vkCommandBuffer,uint(0),uint(1),viewport]);

  var scissor=Marshal.AllocHGlobal(16);
  Marshal.WriteInt32(scissor,0,0);
  Marshal.WriteInt32(scissor,4,0);
  Marshal.WriteInt32(scissor,8,int(windowWidth));
  Marshal.WriteInt32(scissor,12,int(windowHeight));

  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdSetScissor_ptr,vkCommandBuffer,uint(0),uint(1),scissor]);

  var bufs=Marshal.AllocHGlobal(8);
  var offs=Marshal.AllocHGlobal(8);
  WriteU64(bufs,0,vkVertexBuffer);
  WriteU64(offs,0,ulong(0));

  createVulkanInvoker.InvokeMember("BindVB",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdBindVertexBuffers_ptr,vkCommandBuffer,uint(0),uint(1),bufs,offs]);

  createVulkanInvoker.InvokeMember("Draw",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdDraw_ptr,vkCommandBuffer,uint(3),uint(1),uint(0),uint(0)]);

  VK_Invoke("Void1",[vkCmdEndRenderPass_ptr,vkCommandBuffer]);

  createVulkanInvoker.InvokeMember("Ret1",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkEndCommandBuffer_ptr,vkCommandBuffer]);

  Marshal.FreeHGlobal(offs);
  Marshal.FreeHGlobal(bufs);
  Marshal.FreeHGlobal(scissor);
  Marshal.FreeHGlobal(viewport);
  Marshal.FreeHGlobal(rpBegin);
  Marshal.FreeHGlobal(clearVal);
  Marshal.FreeHGlobal(beginInfo);

  return true;

}

// Draw a frame
function DrawFrame():void{

  var fencePtr=Marshal.AllocHGlobal(8);
  WriteU64(fencePtr,0,vkInFlightFence);

  createVulkanInvoker.InvokeMember("WaitFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkWaitForFences_ptr,vkDevice,uint(1),fencePtr,uint(1),ulong(0xFFFFFFFFFFFFFFFF)]);

  createVulkanInvoker.InvokeMember("ResetFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkResetFences_ptr,vkDevice,uint(1),fencePtr]);

  var imgIdxPtr=Marshal.AllocHGlobal(4);

  createVulkanInvoker.InvokeMember("Acquire",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkAcquireNextImageKHR_ptr,vkDevice,vkSwapchain,ulong(0xFFFFFFFFFFFFFFFF),vkImageAvailableSemaphore,ulong(0),imgIdxPtr]);

  var imgIdx=uint(Marshal.ReadInt32(imgIdxPtr));

  RecordCommandBuffer(imgIdx);

  var waitSem=Marshal.AllocHGlobal(8);
  WriteU64(waitSem,0,vkImageAvailableSemaphore);

  var sigSem=Marshal.AllocHGlobal(8);
  WriteU64(sigSem,0,vkRenderFinishedSemaphore);

  var waitStage=Marshal.AllocHGlobal(4);
  Marshal.WriteInt32(waitStage,0,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  Marshal.WriteIntPtr(cbPtr,0,vkCommandBuffer);

  var submitInfo=Marshal.AllocHGlobal(72);
  ClearMem(submitInfo,72);
  Marshal.WriteInt32(submitInfo,0,VK_STRUCTURE_TYPE_SUBMIT_INFO);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(submitInfo,16,1);
    Marshal.WriteIntPtr(submitInfo,24,waitSem);
    Marshal.WriteIntPtr(submitInfo,32,waitStage);
    Marshal.WriteInt32(submitInfo,40,1);
    Marshal.WriteIntPtr(submitInfo,48,cbPtr);
    Marshal.WriteInt32(submitInfo,56,1);
    Marshal.WriteIntPtr(submitInfo,64,sigSem);
  }

  else{
    Marshal.WriteInt32(submitInfo,8,1);
    Marshal.WriteIntPtr(submitInfo,12,waitSem);
    Marshal.WriteIntPtr(submitInfo,16,waitStage);
    Marshal.WriteInt32(submitInfo,20,1);
    Marshal.WriteIntPtr(submitInfo,24,cbPtr);
    Marshal.WriteInt32(submitInfo,28,1);
    Marshal.WriteIntPtr(submitInfo,32,sigSem);
  }

  createVulkanInvoker.InvokeMember("Submit",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkQueueSubmit_ptr,vkGraphicsQueue,uint(1),submitInfo,vkInFlightFence]);

  var swPtr=Marshal.AllocHGlobal(8);
  WriteU64(swPtr,0,vkSwapchain);

  var presentInfo=Marshal.AllocHGlobal(64);
  ClearMem(presentInfo,64);
  Marshal.WriteInt32(presentInfo,0,VK_STRUCTURE_TYPE_PRESENT_INFO_KHR);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(presentInfo,16,1);
    Marshal.WriteIntPtr(presentInfo,24,sigSem);
    Marshal.WriteInt32(presentInfo,32,1);
    Marshal.WriteIntPtr(presentInfo,40,swPtr);
    Marshal.WriteIntPtr(presentInfo,48,imgIdxPtr);
  }

  else{
    Marshal.WriteInt32(presentInfo,8,1);
    Marshal.WriteIntPtr(presentInfo,12,sigSem);
    Marshal.WriteInt32(presentInfo,16,1);
    Marshal.WriteIntPtr(presentInfo,20,swPtr);
    Marshal.WriteIntPtr(presentInfo,24,imgIdxPtr);
  }

  createVulkanInvoker.InvokeMember("Present",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkQueuePresentKHR_ptr,vkGraphicsQueue,presentInfo]);

  Marshal.FreeHGlobal(presentInfo);
  Marshal.FreeHGlobal(swPtr);
  Marshal.FreeHGlobal(submitInfo);
  Marshal.FreeHGlobal(cbPtr);
  Marshal.FreeHGlobal(waitStage);
  Marshal.FreeHGlobal(sigSem);
  Marshal.FreeHGlobal(waitSem);
  Marshal.FreeHGlobal(imgIdxPtr);
  Marshal.FreeHGlobal(fencePtr);

}

// Register window class
function RegisterWindowClass(hInst:IntPtr):Boolean{

  var defProc=GetProcAddress(GetModuleHandle("user32.dll"),"DefWindowProcA");

  var brush=GetStockObject(WHITE_BRUSH);

  var className=Marshal.StringToHGlobalAnsi("vulkan14");

  var cbWndClass:int=(IntPtr.Size==8)?80:48;

  var wndClass=Marshal.AllocHGlobal(int(cbWndClass));
  ClearMem(wndClass,cbWndClass);

  if(IntPtr.Size==8){
    Marshal.WriteInt32(wndClass,0,cbWndClass);
    Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc);
    Marshal.WriteIntPtr(wndClass,24,hInst);
    Marshal.WriteIntPtr(wndClass,48,brush);
    Marshal.WriteIntPtr(wndClass,64,className);
  }

  else{
    Marshal.WriteInt32(wndClass,0,cbWndClass);
    Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc);
    Marshal.WriteIntPtr(wndClass,20,hInst);
    Marshal.WriteIntPtr(wndClass,32,brush);
    Marshal.WriteIntPtr(wndClass,40,className);
  }

  var atom=InvokeWin32("user32.dll",Type.GetType("System.UInt16"),"RegisterClassExA",[Type.GetType("System.IntPtr")],[wndClass]);

  Marshal.FreeHGlobal(className);
  Marshal.FreeHGlobal(wndClass);

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

// Main entry point
function Main():void{

  DebugLog("=== Vulkan 1.4 Triangle Demo ===");
  DumpInvokerMethods();

  if(createVulkanInvoker==null){
    DebugLog("Failed to create invoker");
    return;
  }

  var hInst=GetModuleHandle(null);

  try{

    if(!LoadVulkan())return;

    if(!CreateVulkanInstance())return;

    LoadInstanceFunctions();

    if(!SelectPhysicalDevice())return;

    if(!FindGraphicsQueueFamily())return;

    if(!CreateLogicalDevice())return;

    LoadDeviceFunctions();

    GetGraphicsQueue();

    if(!RegisterWindowClass(hInst))return;

    var hWnd=CreateWindowEx(0,"vulkan14","Hello, Vulkan 1.4!",WS_OVERLAPPEDWINDOW|WS_VISIBLE,CW_USEDEFAULT,CW_USEDEFAULT,int(windowWidth),int(windowHeight),IntPtr.Zero,IntPtr.Zero,hInst,IntPtr.Zero);

    if(hWnd==IntPtr.Zero){
      DebugLog("Failed to create window");
      return;
    }

    ShowWindow(hWnd,SW_SHOW);
    UpdateWindow(hWnd);

    if(!CreateWin32Surface(hInst,hWnd)){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateSwapchain()){
      DestroyWindow(hWnd);
      return;
    }

    if(!GetSwapchainImages()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateImageViews()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateRenderPass()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreatePipelineLayout()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateGraphicsPipeline()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateFramebuffers()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateCommandPool()){
      DestroyWindow(hWnd);
      return;
    }

    if(!AllocateCommandBuffers()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateVertexBuffer()){
      DestroyWindow(hWnd);
      return;
    }

    if(!CreateSyncObjects()){
      DestroyWindow(hWnd);
      return;
    }

    DebugLog("Initialization complete!");

    var msg=AllocateMsgStruct();

    var quit=false;

    while(!quit){

      if(PeekMessage(msg,IntPtr.Zero,0,0,PM_REMOVE)){
        if(GetMessageID(msg)==WM_QUIT)quit=true;
        else{
          TranslateMessage(msg);
          DispatchMessage(msg);
        }
      }

      else{
        if(!IsWindow(hWnd))PostQuitMessage(0);
        else{
          DrawFrame();
          Sleep(16);
        }
      }

    }

    VK_Invoke("Void1",[vkDeviceWaitIdle_ptr,vkDevice]);

    Marshal.FreeHGlobal(msg);

    DebugLog("=== Demo completed ===");

  }
  catch(e) {

    DebugLog("FATAL: " + e.ToString());

    throw e;

  }

}

Main();

