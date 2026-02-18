// Harmonograph.js - JScript.NET Vulkan 1.4 Harmonograph via Compute Shader
// Build : jsc /platform:x64 /nologo Harmonograph.js && Harmonograph.exe
// Requires: vulkan-1.dll, shaderc_shared.dll (Vulkan SDK)
// Shaders : hello.vert, hello.frag, hello.comp  (place next to the .exe)
//
// Architecture:
//   1. Compute pass (once at startup)
//        hello.comp fills two SSBOs: Positions(vec4[N]) and Colors(vec4[N])
//   2. Graphics loop
//        hello.vert reads SSBOs via descriptor bindings; no VBO needed
//        hello.frag outputs the per-vertex color
//   Both pipelines share one VkDescriptorSetLayout / VkDescriptorSet.

import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;
import System.Text;
import System.CodeDom.Compiler;
import System.IO;

// ============================================================
// Debug helpers
// ============================================================
function DebugLog(message:String):void{
  Console.WriteLine("[DEBUG] "+message);
}

function PtrHex(p:IntPtr):String{
  if(p==IntPtr.Zero) return "0x0";
  if(IntPtr.Size==8){
    var v:long=p.ToInt64();
    if(v<0) v=v+9223372036854775807+9223372036854775809;
    return "0x"+v.toString(16);
  }else{
    var v32:int=p.ToInt32();
    if(v32<0) v32=v32+0x100000000;
    return "0x"+v32.toString(16);
  }
}

function ArgStr(a:Object):String{
  if(a==null) return "null";
  if(a.GetType().FullName=="System.IntPtr") return PtrHex(IntPtr(a));
  var t=a.GetType().FullName;
  if(t=="System.UInt64") return "0x"+System.UInt64(a).ToString("X");
  if(t=="System.UInt32") return "0x"+System.UInt32(a).ToString("X");
  if(t=="System.Int32")  return String(a);
  if(t=="System.Single") return String(a);
  return a.ToString();
}

function ArgsStr(args:Object[]):String{
  if(args==null) return "";
  var s="";
  for(var i=0;i<args.length;i++){
    if(i>0) s+=", ";
    s+=ArgStr(args[i]);
  }
  return s;
}

function VK_Invoke(method:String,args:Object[]):Object{
  DebugLog("VK."+method+"("+ArgsStr(args)+")");
  try{
    return createVulkanInvoker.InvokeMember(
      method,BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,
      null,null,args);
  }catch(e){
    DebugLog("VK."+method+" threw: "+e.ToString());
    throw e;
  }
}

// ============================================================
// VulkanInvoker - runtime-compiled C# helper class
// Extended with compute/descriptor delegates.
// ============================================================
var createVulkanInvoker=(function(){
  var src=
  "using System; using System.Runtime.InteropServices;\n"+
  "public static class VulkanInvoker {\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate IntPtr DGetProcAddr(IntPtr inst,IntPtr name);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate2(IntPtr p1,IntPtr p2);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate3(IntPtr p1,IntPtr p2,IntPtr p3);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreate4(IntPtr p1,IntPtr p2,IntPtr p3,IntPtr p4);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DRet1(IntPtr p1);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid1(IntPtr p1);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid2(IntPtr p1,IntPtr p2);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid3(IntPtr p1,IntPtr p2,IntPtr p3);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DVoid4(IntPtr p1,uint p2,uint p3,IntPtr p4);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DBindPipeline(IntPtr cmd,uint bind,ulong pipe);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DSetViewport(IntPtr cmd,uint first,uint cnt,IntPtr vp);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDraw(IntPtr cmd,uint vc,uint ic,uint fv,uint fi);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DBeginRP(IntPtr cmd,IntPtr info,uint cont);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DSubmit(IntPtr q,uint cnt,IntPtr sub,ulong fence);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DPresent(IntPtr q,IntPtr info);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DAcquire(IntPtr dev,ulong sc,ulong to,ulong sem,ulong fence,IntPtr idx);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DWaitFence(IntPtr dev,uint cnt,IntPtr f,uint all,ulong to);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DResetFence(IntPtr dev,uint cnt,IntPtr f);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DResetCmd(IntPtr cmd,uint flags);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DMap(IntPtr dev,ulong mem,ulong off,ulong sz,uint fl,IntPtr pp);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DUnmap(IntPtr dev,ulong mem);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DBind(IntPtr dev,ulong buf,ulong mem,ulong off);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDestroy2(IntPtr dev,ulong h);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DDestroy3(IntPtr dev,ulong h,IntPtr alloc);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DGetImages(IntPtr dev,ulong sc,IntPtr cnt,IntPtr img);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int DCreatePipe(IntPtr dev,ulong cache,uint cnt,IntPtr info,IntPtr alloc,IntPtr pipe);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DGetBufMemReq(IntPtr dev,ulong buf,IntPtr pReqs);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DUpdateDS(IntPtr dev,uint wc,IntPtr writes,uint cc,IntPtr copies);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DCmdDispatch(IntPtr cmd,uint x,uint y,uint z);\n"+
  "  [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate void DCmdBindDS(IntPtr cmd,uint bp,ulong layout,uint first,uint cnt,IntPtr sets,uint dc,IntPtr doffs);\n"+
  "  public static IntPtr GetProc(IntPtr f,IntPtr i,IntPtr n){return((DGetProcAddr)Marshal.GetDelegateForFunctionPointer(f,typeof(DGetProcAddr)))(i,n);}\n"+
  "  public static int Create2(IntPtr f,IntPtr a,IntPtr b){return((DCreate2)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate2)))(a,b);}\n"+
  "  public static int Create3(IntPtr f,IntPtr a,IntPtr b,IntPtr c){return((DCreate3)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate3)))(a,b,c);}\n"+
  "  public static int Create4(IntPtr f,IntPtr a,IntPtr b,IntPtr c,IntPtr d){return((DCreate4)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreate4)))(a,b,c,d);}\n"+
  "  public static int Ret1(IntPtr f,IntPtr a){return((DRet1)Marshal.GetDelegateForFunctionPointer(f,typeof(DRet1)))(a);}\n"+
  "  public static void Void1(IntPtr f,IntPtr a){((DVoid1)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid1)))(a);}\n"+
  "  public static void Void2(IntPtr f,IntPtr a,IntPtr b){((DVoid2)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid2)))(a,b);}\n"+
  "  public static void Void3(IntPtr f,IntPtr a,IntPtr b,IntPtr c){((DVoid3)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid3)))(a,b,c);}\n"+
  "  public static void Void4(IntPtr f,IntPtr a,uint b,uint c,IntPtr d){((DVoid4)Marshal.GetDelegateForFunctionPointer(f,typeof(DVoid4)))(a,b,c,d);}\n"+
  "  public static void BindPipe(IntPtr f,IntPtr c,uint b,ulong p){((DBindPipeline)Marshal.GetDelegateForFunctionPointer(f,typeof(DBindPipeline)))(c,b,p);}\n"+
  "  public static void SetVP(IntPtr f,IntPtr c,uint a,uint b,IntPtr v){((DSetViewport)Marshal.GetDelegateForFunctionPointer(f,typeof(DSetViewport)))(c,a,b,v);}\n"+
  "  public static void Draw(IntPtr f,IntPtr c,uint vc,uint ic,uint fv,uint fi){((DDraw)Marshal.GetDelegateForFunctionPointer(f,typeof(DDraw)))(c,vc,ic,fv,fi);}\n"+
  "  public static void BeginRP(IntPtr f,IntPtr c,IntPtr i,uint co){((DBeginRP)Marshal.GetDelegateForFunctionPointer(f,typeof(DBeginRP)))(c,i,co);}\n"+
  "  public static int Submit(IntPtr f,IntPtr q,uint c,IntPtr s,ulong fe){return((DSubmit)Marshal.GetDelegateForFunctionPointer(f,typeof(DSubmit)))(q,c,s,fe);}\n"+
  "  public static int Present(IntPtr f,IntPtr q,IntPtr i){return((DPresent)Marshal.GetDelegateForFunctionPointer(f,typeof(DPresent)))(q,i);}\n"+
  "  public static int Acquire(IntPtr f,IntPtr d,ulong sc,ulong to,ulong sem,ulong fe,IntPtr i){return((DAcquire)Marshal.GetDelegateForFunctionPointer(f,typeof(DAcquire)))(d,sc,to,sem,fe,i);}\n"+
  "  public static int WaitFence(IntPtr f,IntPtr d,uint c,IntPtr fe,uint a,ulong t){return((DWaitFence)Marshal.GetDelegateForFunctionPointer(f,typeof(DWaitFence)))(d,c,fe,a,t);}\n"+
  "  public static int ResetFence(IntPtr f,IntPtr d,uint c,IntPtr fe){return((DResetFence)Marshal.GetDelegateForFunctionPointer(f,typeof(DResetFence)))(d,c,fe);}\n"+
  "  public static int ResetCmd(IntPtr f,IntPtr c,uint fl){return((DResetCmd)Marshal.GetDelegateForFunctionPointer(f,typeof(DResetCmd)))(c,fl);}\n"+
  "  public static int Map(IntPtr f,IntPtr d,ulong m,ulong o,ulong s,uint fl,IntPtr p){return((DMap)Marshal.GetDelegateForFunctionPointer(f,typeof(DMap)))(d,m,o,s,fl,p);}\n"+
  "  public static void Unmap(IntPtr f,IntPtr d,ulong m){((DUnmap)Marshal.GetDelegateForFunctionPointer(f,typeof(DUnmap)))(d,m);}\n"+
  "  public static int Bind(IntPtr f,IntPtr d,ulong b,ulong m,ulong o){return((DBind)Marshal.GetDelegateForFunctionPointer(f,typeof(DBind)))(d,b,m,o);}\n"+
  "  public static void Destroy2(IntPtr f,IntPtr d,ulong h){((DDestroy2)Marshal.GetDelegateForFunctionPointer(f,typeof(DDestroy2)))(d,h);}\n"+
  "  public static void Destroy3(IntPtr f,IntPtr d,ulong h,IntPtr a){((DDestroy3)Marshal.GetDelegateForFunctionPointer(f,typeof(DDestroy3)))(d,h,a);}\n"+
  "  public static int GetImages(IntPtr f,IntPtr d,ulong sc,IntPtr c,IntPtr i){return((DGetImages)Marshal.GetDelegateForFunctionPointer(f,typeof(DGetImages)))(d,sc,c,i);}\n"+
  "  public static int CreatePipe(IntPtr f,IntPtr d,ulong ca,uint c,IntPtr i,IntPtr a,IntPtr p){return((DCreatePipe)Marshal.GetDelegateForFunctionPointer(f,typeof(DCreatePipe)))(d,ca,c,i,a,p);}\n"+
  "  public static void GetBufMemReq(IntPtr f,IntPtr d,ulong b,IntPtr r){((DGetBufMemReq)Marshal.GetDelegateForFunctionPointer(f,typeof(DGetBufMemReq)))(d,b,r);}\n"+
  "  public static void UpdateDS(IntPtr f,IntPtr d,uint wc,IntPtr w,uint cc,IntPtr c){((DUpdateDS)Marshal.GetDelegateForFunctionPointer(f,typeof(DUpdateDS)))(d,wc,w,cc,c);}\n"+
  "  public static void CmdDispatch(IntPtr f,IntPtr cmd,uint x,uint y,uint z){((DCmdDispatch)Marshal.GetDelegateForFunctionPointer(f,typeof(DCmdDispatch)))(cmd,x,y,z);}\n"+
  "  public static void CmdBindDS(IntPtr f,IntPtr cmd,uint bp,ulong layout,uint first,uint cnt,IntPtr sets,uint dc,IntPtr doffs){((DCmdBindDS)Marshal.GetDelegateForFunctionPointer(f,typeof(DCmdBindDS)))(cmd,bp,layout,first,cnt,sets,dc,doffs);}\n"+
  "}";

  var cp=CodeDomProvider.CreateProvider("CSharp");
  var cps=new CompilerParameters();
  cps.GenerateInMemory=true;
  var cr=cp.CompileAssemblyFromSource(cps,src);
  if(cr.Errors.HasErrors){
    for(var i=0;i<cr.Errors.Count;i++) DebugLog(cr.Errors[i].ToString());
    return null;
  }
  return cr.CompiledAssembly.GetType("VulkanInvoker");
})();

// ============================================================
// Dynamic P/Invoke (StdCall and Cdecl)
// ============================================================
function InvokeWin32(dll:String,ret:Type,name:String,types:Type[],args:Object[]):Object{
  var dom=AppDomain.CurrentDomain;
  var asm=dom.DefineDynamicAssembly(new AssemblyName("P"+name),AssemblyBuilderAccess.Run);
  var mod=asm.DefineDynamicModule("M");
  var typ=mod.DefineType("T",TypeAttributes.Public);
  var meth=typ.DefineMethod(name,6|128|16|8192,ret,types);
  meth.SetCustomAttribute(new CustomAttributeBuilder(
    DllImportAttribute.GetConstructor([Type.GetType("System.String")]),[dll]));
  return typ.CreateType().InvokeMember(
    name,BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,args);
}

function InvokeCdecl(dll:String,ret:Type,name:String,types:Type[],args:Object[]):Object{
  var dom=AppDomain.CurrentDomain;
  var asm=dom.DefineDynamicAssembly(new AssemblyName("P"+name+"C"),AssemblyBuilderAccess.Run);
  var mod=asm.DefineDynamicModule("M");
  var typ=mod.DefineType("T",TypeAttributes.Public);
  var meth=typ.DefineMethod(name,6|128|16|8192,ret,types);
  var ctor=DllImportAttribute.GetConstructor([Type.GetType("System.String")]);
  var prop=DllImportAttribute.GetProperty("CallingConvention",BindingFlags.Public|BindingFlags.Instance);
  var ctorArgs:Object[]=new Object[1]; ctorArgs[0]=dll;
  if(prop!=null){
    var props:PropertyInfo[]=new PropertyInfo[1]; props[0]=prop;
    var propVals:Object[]=new Object[1]; propVals[0]=CallingConvention.Cdecl;
    meth.SetCustomAttribute(new CustomAttributeBuilder(ctor,ctorArgs,props,propVals));
  }else{
    meth.SetCustomAttribute(new CustomAttributeBuilder(ctor,ctorArgs));
  }
  return typ.CreateType().InvokeMember(
    name,BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,args);
}

// ============================================================
// Constants
// ============================================================
// Win32
const WS_OVERLAPPEDWINDOW=0x00CF0000, WS_VISIBLE=0x10000000, CW_USEDEFAULT=-2147483648;
const SW_SHOW=5, WM_QUIT=0x0012, PM_REMOVE=1, CS_OWNDC=0x0020, WHITE_BRUSH=0;

// Vulkan result / structure types
const VK_SUCCESS=0;
const VK_STRUCTURE_TYPE_APPLICATION_INFO=0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO=1;
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO=2;
const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO=3;
const VK_STRUCTURE_TYPE_SUBMIT_INFO=4;
const VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO=5;
const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO=8;
const VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO=9;
const VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO=12;
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
const VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO=29;
const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO=30;
const VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO=32;
const VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO=33;
const VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO=34;
const VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET=35;
const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO=37;
const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO=38;
const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO=39;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO=40;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO=42;
const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO=43;
const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR=1000009000;
const VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR=1000001000;
const VK_STRUCTURE_TYPE_PRESENT_INFO_KHR=1000001001;

// Vulkan enums / flags
const VK_QUEUE_GRAPHICS_BIT=1;
const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT=2;
const VK_COMMAND_BUFFER_LEVEL_PRIMARY=0;
const VK_FENCE_CREATE_SIGNALED_BIT=1;
const VK_PIPELINE_BIND_POINT_GRAPHICS=0;
const VK_PIPELINE_BIND_POINT_COMPUTE=1;
const VK_SUBPASS_CONTENTS_INLINE=0;
const VK_PRIMITIVE_TOPOLOGY_POINT_LIST=0;   // one draw call per sample point
const VK_POLYGON_MODE_FILL=0;
const VK_CULL_MODE_NONE=0;
const VK_FRONT_FACE_CLOCKWISE=1;
const VK_SAMPLE_COUNT_1_BIT=1;
const VK_DYNAMIC_STATE_VIEWPORT=0;
const VK_DYNAMIC_STATE_SCISSOR=1;
const VK_SHADER_STAGE_VERTEX_BIT=1;
const VK_SHADER_STAGE_FRAGMENT_BIT=16;
const VK_SHADER_STAGE_COMPUTE_BIT=0x20;
const VK_FORMAT_B8G8R8A8_SRGB=50;
const VK_COLOR_SPACE_SRGB_NONLINEAR_KHR=0;
const VK_PRESENT_MODE_FIFO_KHR=2;
const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT=16;
const VK_SHARING_MODE_EXCLUSIVE=0;
const VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR=1;
const VK_IMAGE_VIEW_TYPE_2D=1;
const VK_IMAGE_ASPECT_COLOR_BIT=1;
const VK_ATTACHMENT_LOAD_OP_CLEAR=1;
const VK_ATTACHMENT_STORE_OP_STORE=0;
const VK_ATTACHMENT_LOAD_OP_DONT_CARE=2;
const VK_ATTACHMENT_STORE_OP_DONT_CARE=1;
const VK_IMAGE_LAYOUT_UNDEFINED=0;
const VK_IMAGE_LAYOUT_PRESENT_SRC_KHR=1000001002;
const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL=2;
const VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT=0x400;
const VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT=0x100;
const VK_BUFFER_USAGE_STORAGE_BUFFER_BIT=0x20;
const VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT=0x10;
const VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT=2;
const VK_MEMORY_PROPERTY_HOST_COHERENT_BIT=4;
const VK_COLOR_COMPONENT_RGBA=15;
const VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER=6;
const VK_DESCRIPTOR_TYPE_STORAGE_BUFFER=7;
const VK_API_VERSION_1_4=((1<<22)|(4<<12));

// shaderc kind constants
const SHADERC_SHADER_KIND_VERTEX=0;
const SHADERC_SHADER_KIND_FRAGMENT=1;
const SHADERC_SHADER_KIND_COMPUTE=2;
const SHADERC_STATUS_SUCCESS=0;

// Harmonograph point count
const NUM_POINTS=50000;

// ============================================================
// Global Vulkan handles
// ============================================================
var vkInstance:IntPtr=IntPtr.Zero, vkPhysicalDevice:IntPtr=IntPtr.Zero, vkDevice:IntPtr=IntPtr.Zero;
var vkSurface:ulong=0, vkSwapchain:ulong=0, vkRenderPass:ulong=0;
var vkPipelineLayout:ulong=0, vkGraphicsPipeline:ulong=0;
var vkCommandPool:ulong=0, vkCommandBuffer:IntPtr=IntPtr.Zero;
var vkGraphicsQueue:IntPtr=IntPtr.Zero;
var vkImageAvailableSemaphore:ulong=0, vkRenderFinishedSemaphore:ulong=0, vkInFlightFence:ulong=0;
var vkSwapchainImages:ulong[]=null, vkSwapchainImageViews:ulong[]=null, vkFramebuffers:ulong[]=null;
var vkSwapchainImageCount:uint=0, vkGraphicsQueueFamilyIndex:uint=0;
var windowWidth:uint=800, windowHeight:uint=600;

// Compute/descriptor/buffer resources
var vkPosBuffer:ulong=0, vkPosBufferMemory:ulong=0;
var vkColBuffer:ulong=0, vkColBufferMemory:ulong=0;
var vkUboBuffer:ulong=0, vkUboBufferMemory:ulong=0;
var vkDescriptorSetLayout:ulong=0;
var vkDescriptorPool:ulong=0;
var vkDescriptorSet:ulong=0;
var vkComputePipelineLayout:ulong=0;
var vkComputePipeline:ulong=0;

// Function pointers
var vkGetInstanceProcAddr_ptr:IntPtr=IntPtr.Zero, vkCreateInstance_ptr:IntPtr=IntPtr.Zero;
var vkGetDeviceProcAddr_ptr:IntPtr=IntPtr.Zero;
var vkEnumeratePhysicalDevices_ptr:IntPtr=IntPtr.Zero;
var vkGetPhysicalDeviceQueueFamilyProperties_ptr:IntPtr=IntPtr.Zero;
var vkCreateDevice_ptr:IntPtr=IntPtr.Zero, vkGetDeviceQueue_ptr:IntPtr=IntPtr.Zero;
var vkCreateWin32SurfaceKHR_ptr:IntPtr=IntPtr.Zero;
var vkCreateSwapchainKHR_ptr:IntPtr=IntPtr.Zero;
var vkGetSwapchainImagesKHR_ptr:IntPtr=IntPtr.Zero;
var vkCreateImageView_ptr:IntPtr=IntPtr.Zero;
var vkCreateShaderModule_ptr:IntPtr=IntPtr.Zero, vkDestroyShaderModule_ptr:IntPtr=IntPtr.Zero;
var vkCreatePipelineLayout_ptr:IntPtr=IntPtr.Zero;
var vkCreateRenderPass_ptr:IntPtr=IntPtr.Zero;
var vkCreateGraphicsPipelines_ptr:IntPtr=IntPtr.Zero;
var vkCreateFramebuffer_ptr:IntPtr=IntPtr.Zero;
var vkCreateCommandPool_ptr:IntPtr=IntPtr.Zero;
var vkAllocateCommandBuffers_ptr:IntPtr=IntPtr.Zero;
var vkBeginCommandBuffer_ptr:IntPtr=IntPtr.Zero, vkEndCommandBuffer_ptr:IntPtr=IntPtr.Zero;
var vkCmdBeginRenderPass_ptr:IntPtr=IntPtr.Zero, vkCmdEndRenderPass_ptr:IntPtr=IntPtr.Zero;
var vkCmdBindPipeline_ptr:IntPtr=IntPtr.Zero;
var vkCmdSetViewport_ptr:IntPtr=IntPtr.Zero, vkCmdSetScissor_ptr:IntPtr=IntPtr.Zero;
var vkCmdDraw_ptr:IntPtr=IntPtr.Zero;
var vkCreateSemaphore_ptr:IntPtr=IntPtr.Zero, vkCreateFence_ptr:IntPtr=IntPtr.Zero;
var vkWaitForFences_ptr:IntPtr=IntPtr.Zero, vkResetFences_ptr:IntPtr=IntPtr.Zero;
var vkAcquireNextImageKHR_ptr:IntPtr=IntPtr.Zero;
var vkQueueSubmit_ptr:IntPtr=IntPtr.Zero, vkQueuePresentKHR_ptr:IntPtr=IntPtr.Zero;
var vkQueueWaitIdle_ptr:IntPtr=IntPtr.Zero;
var vkDeviceWaitIdle_ptr:IntPtr=IntPtr.Zero;
var vkResetCommandBuffer_ptr:IntPtr=IntPtr.Zero;
var vkAllocateMemory_ptr:IntPtr=IntPtr.Zero;
var vkGetPhysicalDeviceMemoryProperties_ptr:IntPtr=IntPtr.Zero;
var vkGetBufferMemoryRequirements_ptr:IntPtr=IntPtr.Zero;
var vkCreateBuffer_ptr:IntPtr=IntPtr.Zero;
var vkBindBufferMemory_ptr:IntPtr=IntPtr.Zero;
var vkMapMemory_ptr:IntPtr=IntPtr.Zero, vkUnmapMemory_ptr:IntPtr=IntPtr.Zero;
// Compute/descriptor function pointers
var vkCreateDescriptorSetLayout_ptr:IntPtr=IntPtr.Zero;
var vkCreateDescriptorPool_ptr:IntPtr=IntPtr.Zero;
var vkAllocateDescriptorSets_ptr:IntPtr=IntPtr.Zero;
var vkUpdateDescriptorSets_ptr:IntPtr=IntPtr.Zero;
var vkCreateComputePipelines_ptr:IntPtr=IntPtr.Zero;
var vkCmdDispatch_ptr:IntPtr=IntPtr.Zero;
var vkCmdBindDescriptorSets_ptr:IntPtr=IntPtr.Zero;

// ============================================================
// Memory / utility helpers
// ============================================================
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

function WriteFloat(p:IntPtr,offset:int,v:float):void{
  Marshal.Copy(BitConverter.GetBytes(v),0,IntPtr.Add(p,offset),4);
}

// ============================================================
// Win32 API wrappers
// ============================================================
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
  return InvokeWin32("user32.dll",Type.GetType("System.Boolean"),"PeekMessageA",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32"),Type.GetType("System.UInt32")],
    [m,h,mn,mx,rm]);
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

// ============================================================
// shaderc - runtime GLSL to SPIR-V compilation
// ============================================================
var g_shadercDll:String=null;

function ResolveShadercDll():String{
  if(g_shadercDll!=null) return g_shadercDll;
  try{
    var sdk=Environment.GetEnvironmentVariable("VULKAN_SDK");
    if(sdk!=null&&sdk!=""){
      var p1=Path.Combine(sdk,"Bin","shaderc_shared.dll");
      if(File.Exists(p1)){ g_shadercDll=p1; return g_shadercDll; }
      var p2=Path.Combine(sdk,"Bin64","shaderc_shared.dll");
      if(File.Exists(p2)){ g_shadercDll=p2; return g_shadercDll; }
    }
    var local=Path.Combine(Environment.CurrentDirectory,"shaderc_shared.dll");
    if(File.Exists(local)){ g_shadercDll=local; return g_shadercDll; }
  }catch(_e){}
  g_shadercDll="shaderc_shared.dll";
  return g_shadercDll;
}

function ShadercCompile(source:String,kind:int,filename:String,entry:String):byte[]{
  var dll=ResolveShadercDll();
  DebugLog("shaderc: compiling "+filename);

  var compiler:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compiler_initialize",new Array(),new Array());
  if(compiler==IntPtr.Zero) throw new Exception("shaderc_compiler_initialize failed");

  var options:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_compile_options_initialize",new Array(),new Array());
  if(options==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("shaderc_compile_options_initialize failed");
  }

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

  Marshal.FreeHGlobal(entryPtr); Marshal.FreeHGlobal(filePtr); Marshal.FreeHGlobal(srcPtr);

  if(result==IntPtr.Zero){
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("shaderc_compile_into_spv returned NULL");
  }

  var status:int=int(InvokeCdecl(dll,Type.GetType("System.Int32"),"shaderc_result_get_compilation_status",[Type.GetType("System.IntPtr")],[result]));
  if(status!=SHADERC_STATUS_SUCCESS){
    var errPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_error_message",[Type.GetType("System.IntPtr")],[result]);
    var errMsg:String=(errPtr==IntPtr.Zero)?"(no message)":Marshal.PtrToStringAnsi(errPtr);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
    InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);
    throw new Exception("Shader compile failed ("+status+"): "+errMsg);
  }

  var len:ulong=ulong(InvokeCdecl(dll,Type.GetType("System.UInt64"),"shaderc_result_get_length",[Type.GetType("System.IntPtr")],[result]));
  var bytesPtr:IntPtr=InvokeCdecl(dll,Type.GetType("System.IntPtr"),"shaderc_result_get_bytes",[Type.GetType("System.IntPtr")],[result]);
  var outBytes:byte[]=new byte[int(len)];
  Marshal.Copy(bytesPtr,outBytes,0,int(len));

  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_result_release",[Type.GetType("System.IntPtr")],[result]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compile_options_release",[Type.GetType("System.IntPtr")],[options]);
  InvokeCdecl(dll,Type.GetType("System.Void"),"shaderc_compiler_release",[Type.GetType("System.IntPtr")],[compiler]);

  DebugLog("shaderc: "+filename+" => "+outBytes.length+" bytes SPIR-V");
  return outBytes;
}

// ============================================================
// Embedded GLSL fallbacks (mirrors the project .glsl files)
// Primary source is always the project shader files.
// ============================================================

// Fallback vertex shader: reads positions/colors directly from SSBOs.
const VERT_GLSL_FALLBACK=
"#version 450\n"+
"layout(std430, binding = 0) buffer Positions { vec4 pos[]; };\n"+
"layout(std430, binding = 1) buffer Colors    { vec4 col[]; };\n"+
"layout(location = 0) out vec4 vColor;\n"+
"void main(){\n"+
"  uint idx = uint(gl_VertexIndex);\n"+
"  gl_Position = pos[idx];\n"+
"  vColor = col[idx];\n"+
"}\n";

// Fallback fragment shader: pass-through color.
const FRAG_GLSL_FALLBACK=
"#version 450\n"+
"layout(location = 0) in  vec4 vColor;\n"+
"layout(location = 0) out vec4 outColor;\n"+
"void main(){ outColor = vColor; }\n";

// Fallback compute shader: mirrors hello.comp exactly.
const COMP_GLSL_FALLBACK=
"#version 450\n"+
"layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;\n"+
"layout(std430, binding = 0) buffer Positions { vec4 pos[]; };\n"+
"layout(std430, binding = 1) buffer Colors    { vec4 col[]; };\n"+
"layout(std140, binding = 2) uniform Params {\n"+
"  uint  max_num; float dt; float scale; float pad0;\n"+
"  float A1; float f1; float p1; float d1;\n"+
"  float A2; float f2; float p2; float d2;\n"+
"  float A3; float f3; float p3; float d3;\n"+
"  float A4; float f4; float p4; float d4;\n"+
"} u;\n"+
"vec3 hsv2rgb(float h,float s,float v){\n"+
"  float c=v*s; float hp=h/60.0; float x=c*(1.0-abs(mod(hp,2.0)-1.0));\n"+
"  vec3 rgb;\n"+
"  if(hp<1.0) rgb=vec3(c,x,0.0); else if(hp<2.0) rgb=vec3(x,c,0.0);\n"+
"  else if(hp<3.0) rgb=vec3(0.0,c,x); else if(hp<4.0) rgb=vec3(0.0,x,c);\n"+
"  else if(hp<5.0) rgb=vec3(x,0.0,c); else rgb=vec3(c,0.0,x);\n"+
"  return rgb+vec3(v-c);\n"+
"}\n"+
"void main(){\n"+
"  uint idx=gl_GlobalInvocationID.x;\n"+
"  if(idx>=u.max_num) return;\n"+
"  float t=float(idx)*u.dt;\n"+
"  float PI=3.141592653589793;\n"+
"  float x=u.A1*sin(u.f1*t+PI*u.p1)*exp(-u.d1*t)+u.A2*sin(u.f2*t+PI*u.p2)*exp(-u.d2*t);\n"+
"  float y=u.A3*sin(u.f3*t+PI*u.p3)*exp(-u.d3*t)+u.A4*sin(u.f4*t+PI*u.p4)*exp(-u.d4*t);\n"+
"  vec2 p=vec2(x,y)*u.scale;\n"+
"  pos[idx]=vec4(p.x,p.y,0.0,1.0);\n"+
"  float hue=mod((t/20.0)*360.0,360.0);\n"+
"  col[idx]=vec4(hsv2rgb(hue,1.0,1.0),1.0);\n"+
"}\n";

// Read a shader file from disk, falling back to the embedded GLSL string.
function ReadShaderText(fileName:String,fallback:String):String{
  try{
    var path=Path.Combine(Environment.CurrentDirectory,fileName);
    if(File.Exists(path)){
      DebugLog("Reading shader: "+path);
      return File.ReadAllText(path);
    }
  }catch(_e){}
  DebugLog("Shader not found on disk, using embedded fallback: "+fileName);
  return fallback;
}

// ============================================================
// Vulkan initialisation
// ============================================================
function VkGetProc(inst:IntPtr,name:String):IntPtr{
  var np=Marshal.StringToHGlobalAnsi(name);
  var r=IntPtr(createVulkanInvoker.InvokeMember("GetProc",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetInstanceProcAddr_ptr,inst,np]));
  Marshal.FreeHGlobal(np);
  return r;
}

function VkGetDevProc(dev:IntPtr,name:String):IntPtr{
  if(vkGetDeviceProcAddr_ptr==IntPtr.Zero){
    vkGetDeviceProcAddr_ptr=VkGetProc(vkInstance,"vkGetDeviceProcAddr");
  }
  var np=Marshal.StringToHGlobalAnsi(name);
  var r=IntPtr(createVulkanInvoker.InvokeMember("GetProc",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetDeviceProcAddr_ptr,dev,np]));
  Marshal.FreeHGlobal(np);
  return r;
}

function LoadVulkan():Boolean{
  DebugLog("Loading Vulkan...");
  var lib=LoadLibrary("vulkan-1.dll");
  if(lib==IntPtr.Zero){ DebugLog("Failed to load vulkan-1.dll"); return false; }
  vkGetInstanceProcAddr_ptr=GetProcAddress(lib,"vkGetInstanceProcAddr");
  if(vkGetInstanceProcAddr_ptr==IntPtr.Zero){ DebugLog("Failed to get vkGetInstanceProcAddr"); return false; }
  vkCreateInstance_ptr=VkGetProc(IntPtr.Zero,"vkCreateInstance");
  DebugLog("Vulkan loaded");
  return true;
}

function CreateVulkanInstance():Boolean{
  DebugLog("Creating Vulkan instance...");
  var appName=Marshal.StringToHGlobalAnsi("Harmonograph");
  var engName=Marshal.StringToHGlobalAnsi("No Engine");
  var ext1=Marshal.StringToHGlobalAnsi("VK_KHR_surface");
  var ext2=Marshal.StringToHGlobalAnsi("VK_KHR_win32_surface");

  var appInfo=Marshal.AllocHGlobal(48); ClearMem(appInfo,48);
  Marshal.WriteInt32(appInfo,0,VK_STRUCTURE_TYPE_APPLICATION_INFO);
  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?16:8,appName);
  Marshal.WriteIntPtr(appInfo,(IntPtr.Size==8)?32:16,engName);
  Marshal.WriteInt32(appInfo,(IntPtr.Size==8)?44:24,VK_API_VERSION_1_4);

  var extArr=Marshal.AllocHGlobal(int(IntPtr.Size*2));
  Marshal.WriteIntPtr(extArr,0,ext1); Marshal.WriteIntPtr(extArr,IntPtr.Size,ext2);

  var ci=Marshal.AllocHGlobal(64); ClearMem(ci,64);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(ci,24,appInfo); Marshal.WriteInt32(ci,48,2); Marshal.WriteIntPtr(ci,56,extArr);
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    Marshal.WriteIntPtr(ci,12,appInfo); Marshal.WriteInt32(ci,24,2); Marshal.WriteIntPtr(ci,28,extArr);
  }

  var instPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  var r=int(VK_Invoke("Create3",[vkCreateInstance_ptr,ci,IntPtr.Zero,instPtr]));
  if(r==VK_SUCCESS) vkInstance=Marshal.ReadIntPtr(instPtr);

  Marshal.FreeHGlobal(instPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(appInfo);
  Marshal.FreeHGlobal(appName); Marshal.FreeHGlobal(engName); Marshal.FreeHGlobal(extArr);
  Marshal.FreeHGlobal(ext1); Marshal.FreeHGlobal(ext2);
  return r==VK_SUCCESS;
}

function SelectPhysicalDevice():Boolean{
  var cntPtr=Marshal.AllocHGlobal(4); Marshal.WriteInt32(cntPtr,0,0);
  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,IntPtr.Zero]);
  var cnt=Marshal.ReadInt32(cntPtr);
  if(cnt==0){ Marshal.FreeHGlobal(cntPtr); return false; }
  var devs=Marshal.AllocHGlobal(int(IntPtr.Size*cnt));
  VK_Invoke("Create3",[vkEnumeratePhysicalDevices_ptr,vkInstance,cntPtr,devs]);
  vkPhysicalDevice=Marshal.ReadIntPtr(devs);
  DebugLog("Physical device: "+vkPhysicalDevice);
  Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(devs);
  return true;
}

function FindGraphicsQueueFamily():Boolean{
  var cntPtr=Marshal.AllocHGlobal(4); Marshal.WriteInt32(cntPtr,0,0);
  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,IntPtr.Zero]);
  var cnt=Marshal.ReadInt32(cntPtr);
  var props=Marshal.AllocHGlobal(int(24*cnt));
  VK_Invoke("Void3",[vkGetPhysicalDeviceQueueFamilyProperties_ptr,vkPhysicalDevice,cntPtr,props]);
  for(var i=0;i<cnt;i++){
    if((Marshal.ReadInt32(props,i*24)&VK_QUEUE_GRAPHICS_BIT)!=0){
      vkGraphicsQueueFamilyIndex=uint(i);
      DebugLog("Queue family: "+i);
      Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(props);
      return true;
    }
  }
  Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(props);
  return false;
}

function CreateLogicalDevice():Boolean{
  DebugLog("Creating logical device...");
  var priority=Marshal.AllocHGlobal(4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,priority,4);

  var queueInfo=Marshal.AllocHGlobal(40); ClearMem(queueInfo,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(queueInfo,0,VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    Marshal.WriteInt32(queueInfo,20,int(vkGraphicsQueueFamilyIndex));
    Marshal.WriteInt32(queueInfo,24,1); Marshal.WriteIntPtr(queueInfo,32,priority);
  }else{
    Marshal.WriteInt32(queueInfo,0,VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    Marshal.WriteInt32(queueInfo,12,int(vkGraphicsQueueFamilyIndex));
    Marshal.WriteInt32(queueInfo,16,1); Marshal.WriteIntPtr(queueInfo,20,priority);
  }

  var swapExt=Marshal.StringToHGlobalAnsi("VK_KHR_swapchain");
  var extArr=Marshal.AllocHGlobal(int(IntPtr.Size)); Marshal.WriteIntPtr(extArr,0,swapExt);

  var devInfo=Marshal.AllocHGlobal(72); ClearMem(devInfo,72);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(devInfo,0,VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    Marshal.WriteInt32(devInfo,20,1); Marshal.WriteIntPtr(devInfo,24,queueInfo);
    Marshal.WriteInt32(devInfo,48,1); Marshal.WriteIntPtr(devInfo,56,extArr);
  }else{
    Marshal.WriteInt32(devInfo,0,VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    Marshal.WriteInt32(devInfo,12,1); Marshal.WriteIntPtr(devInfo,16,queueInfo);
    Marshal.WriteInt32(devInfo,28,1); Marshal.WriteIntPtr(devInfo,32,extArr);
  }

  var devPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  var r=int(VK_Invoke("Create4",[vkCreateDevice_ptr,vkPhysicalDevice,devInfo,IntPtr.Zero,devPtr]));
  if(r==VK_SUCCESS){ vkDevice=Marshal.ReadIntPtr(devPtr); DebugLog("Device: "+vkDevice); }

  Marshal.FreeHGlobal(devPtr); Marshal.FreeHGlobal(devInfo); Marshal.FreeHGlobal(queueInfo);
  Marshal.FreeHGlobal(priority); Marshal.FreeHGlobal(extArr); Marshal.FreeHGlobal(swapExt);
  return r==VK_SUCCESS;
}

function GetGraphicsQueue():void{
  var qPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  VK_Invoke("Void4",[vkGetDeviceQueue_ptr,vkDevice,uint(vkGraphicsQueueFamilyIndex),uint(0),qPtr]);
  vkGraphicsQueue=Marshal.ReadIntPtr(qPtr);
  Marshal.FreeHGlobal(qPtr);
  DebugLog("Queue: "+vkGraphicsQueue);
}

function LoadInstanceFunctions():void{
  vkEnumeratePhysicalDevices_ptr=VkGetProc(vkInstance,"vkEnumeratePhysicalDevices");
  vkGetPhysicalDeviceQueueFamilyProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceQueueFamilyProperties");
  vkCreateDevice_ptr=VkGetProc(vkInstance,"vkCreateDevice");
  vkCreateWin32SurfaceKHR_ptr=VkGetProc(vkInstance,"vkCreateWin32SurfaceKHR");
  vkGetPhysicalDeviceMemoryProperties_ptr=VkGetProc(vkInstance,"vkGetPhysicalDeviceMemoryProperties");
  DebugLog("Instance functions loaded");
}

function LoadDeviceFunctions():void{
  vkGetDeviceQueue_ptr=VkGetDevProc(vkDevice,"vkGetDeviceQueue");
  vkCreateSwapchainKHR_ptr=VkGetDevProc(vkDevice,"vkCreateSwapchainKHR");
  vkGetSwapchainImagesKHR_ptr=VkGetDevProc(vkDevice,"vkGetSwapchainImagesKHR");
  vkCreateImageView_ptr=VkGetDevProc(vkDevice,"vkCreateImageView");
  vkCreateShaderModule_ptr=VkGetDevProc(vkDevice,"vkCreateShaderModule");
  vkDestroyShaderModule_ptr=VkGetDevProc(vkDevice,"vkDestroyShaderModule");
  vkCreatePipelineLayout_ptr=VkGetDevProc(vkDevice,"vkCreatePipelineLayout");
  vkCreateRenderPass_ptr=VkGetDevProc(vkDevice,"vkCreateRenderPass");
  vkCreateGraphicsPipelines_ptr=VkGetDevProc(vkDevice,"vkCreateGraphicsPipelines");
  vkCreateFramebuffer_ptr=VkGetDevProc(vkDevice,"vkCreateFramebuffer");
  vkCreateCommandPool_ptr=VkGetDevProc(vkDevice,"vkCreateCommandPool");
  vkAllocateCommandBuffers_ptr=VkGetDevProc(vkDevice,"vkAllocateCommandBuffers");
  vkBeginCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkBeginCommandBuffer");
  vkEndCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkEndCommandBuffer");
  vkCmdBeginRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdBeginRenderPass");
  vkCmdEndRenderPass_ptr=VkGetDevProc(vkDevice,"vkCmdEndRenderPass");
  vkCmdBindPipeline_ptr=VkGetDevProc(vkDevice,"vkCmdBindPipeline");
  vkCmdSetViewport_ptr=VkGetDevProc(vkDevice,"vkCmdSetViewport");
  vkCmdSetScissor_ptr=VkGetDevProc(vkDevice,"vkCmdSetScissor");
  vkCmdDraw_ptr=VkGetDevProc(vkDevice,"vkCmdDraw");
  vkCreateSemaphore_ptr=VkGetDevProc(vkDevice,"vkCreateSemaphore");
  vkCreateFence_ptr=VkGetDevProc(vkDevice,"vkCreateFence");
  vkWaitForFences_ptr=VkGetDevProc(vkDevice,"vkWaitForFences");
  vkResetFences_ptr=VkGetDevProc(vkDevice,"vkResetFences");
  vkAcquireNextImageKHR_ptr=VkGetDevProc(vkDevice,"vkAcquireNextImageKHR");
  vkQueueSubmit_ptr=VkGetDevProc(vkDevice,"vkQueueSubmit");
  vkQueuePresentKHR_ptr=VkGetDevProc(vkDevice,"vkQueuePresentKHR");
  vkQueueWaitIdle_ptr=VkGetDevProc(vkDevice,"vkQueueWaitIdle");
  vkDeviceWaitIdle_ptr=VkGetDevProc(vkDevice,"vkDeviceWaitIdle");
  vkResetCommandBuffer_ptr=VkGetDevProc(vkDevice,"vkResetCommandBuffer");
  vkCreateBuffer_ptr=VkGetDevProc(vkDevice,"vkCreateBuffer");
  vkGetBufferMemoryRequirements_ptr=VkGetDevProc(vkDevice,"vkGetBufferMemoryRequirements");
  vkAllocateMemory_ptr=VkGetDevProc(vkDevice,"vkAllocateMemory");
  vkBindBufferMemory_ptr=VkGetDevProc(vkDevice,"vkBindBufferMemory");
  vkMapMemory_ptr=VkGetDevProc(vkDevice,"vkMapMemory");
  vkUnmapMemory_ptr=VkGetDevProc(vkDevice,"vkUnmapMemory");
  // Compute / descriptor functions
  vkCreateDescriptorSetLayout_ptr=VkGetDevProc(vkDevice,"vkCreateDescriptorSetLayout");
  vkCreateDescriptorPool_ptr=VkGetDevProc(vkDevice,"vkCreateDescriptorPool");
  vkAllocateDescriptorSets_ptr=VkGetDevProc(vkDevice,"vkAllocateDescriptorSets");
  vkUpdateDescriptorSets_ptr=VkGetDevProc(vkDevice,"vkUpdateDescriptorSets");
  vkCreateComputePipelines_ptr=VkGetDevProc(vkDevice,"vkCreateComputePipelines");
  vkCmdDispatch_ptr=VkGetDevProc(vkDevice,"vkCmdDispatch");
  vkCmdBindDescriptorSets_ptr=VkGetDevProc(vkDevice,"vkCmdBindDescriptorSets");
  DebugLog("All device functions loaded");
}

// ============================================================
// Surface / swapchain
// ============================================================
function CreateWin32Surface(hInst:IntPtr,hWnd:IntPtr):Boolean{
  DebugLog("Creating Win32 surface...");
  var ci=Marshal.AllocHGlobal(40); ClearMem(ci,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,24,hInst); Marshal.WriteIntPtr(ci,32,hWnd);
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR);
    Marshal.WriteIntPtr(ci,12,hInst); Marshal.WriteIntPtr(ci,16,hWnd);
  }
  var sfPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateWin32SurfaceKHR_ptr,vkInstance,ci,IntPtr.Zero,sfPtr]));
  if(r==VK_SUCCESS){ vkSurface=ReadU64(sfPtr,0); DebugLog("Surface: "+vkSurface); }
  Marshal.FreeHGlobal(sfPtr); Marshal.FreeHGlobal(ci);
  return r==VK_SUCCESS;
}

function CreateSwapchain():Boolean{
  DebugLog("Creating swapchain...");
  var ci=Marshal.AllocHGlobal(80); ClearMem(ci,80);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,16,vkSurface); Marshal.WriteInt32(ci,24,2);
    Marshal.WriteInt32(ci,28,VK_FORMAT_B8G8R8A8_SRGB); Marshal.WriteInt32(ci,32,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
    Marshal.WriteInt32(ci,36,int(windowWidth)); Marshal.WriteInt32(ci,40,int(windowHeight));
    Marshal.WriteInt32(ci,44,1); Marshal.WriteInt32(ci,48,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);
    Marshal.WriteInt32(ci,52,VK_SHARING_MODE_EXCLUSIVE); Marshal.WriteInt32(ci,64,1);
    Marshal.WriteInt32(ci,68,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR); Marshal.WriteInt32(ci,72,VK_PRESENT_MODE_FIFO_KHR);
    Marshal.WriteInt32(ci,76,1);
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR);
    WriteU64(ci,12,vkSurface); Marshal.WriteInt32(ci,20,2);
    Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB); Marshal.WriteInt32(ci,28,VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
    Marshal.WriteInt32(ci,32,int(windowWidth)); Marshal.WriteInt32(ci,36,int(windowHeight));
    Marshal.WriteInt32(ci,40,1); Marshal.WriteInt32(ci,44,VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT);
    Marshal.WriteInt32(ci,48,VK_SHARING_MODE_EXCLUSIVE); Marshal.WriteInt32(ci,60,1);
    Marshal.WriteInt32(ci,64,VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR); Marshal.WriteInt32(ci,68,VK_PRESENT_MODE_FIFO_KHR);
    Marshal.WriteInt32(ci,72,1);
  }
  var swPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateSwapchainKHR_ptr,vkDevice,ci,IntPtr.Zero,swPtr]));
  if(r==VK_SUCCESS){ vkSwapchain=ReadU64(swPtr,0); DebugLog("Swapchain: "+vkSwapchain); }
  Marshal.FreeHGlobal(swPtr); Marshal.FreeHGlobal(ci);
  return r==VK_SUCCESS;
}

function GetSwapchainImages():Boolean{
  var cntPtr=Marshal.AllocHGlobal(4); Marshal.WriteInt32(cntPtr,0,0);
  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,IntPtr.Zero]);
  vkSwapchainImageCount=uint(Marshal.ReadInt32(cntPtr));
  var imgs=Marshal.AllocHGlobal(int(8*vkSwapchainImageCount));
  createVulkanInvoker.InvokeMember("GetImages",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkGetSwapchainImagesKHR_ptr,vkDevice,vkSwapchain,cntPtr,imgs]);
  vkSwapchainImages=new ulong[vkSwapchainImageCount];
  for(var i:uint=0;i<vkSwapchainImageCount;i++) vkSwapchainImages[i]=ReadU64(imgs,int(i*8));
  DebugLog("Swapchain images: "+vkSwapchainImageCount);
  Marshal.FreeHGlobal(cntPtr); Marshal.FreeHGlobal(imgs);
  return true;
}

function CreateImageViews():Boolean{
  vkSwapchainImageViews=new ulong[vkSwapchainImageCount];
  var ci=Marshal.AllocHGlobal(80);
  for(var i:uint=0;i<vkSwapchainImageCount;i++){
    ClearMem(ci,80);
    if(IntPtr.Size==8){
      Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
      WriteU64(ci,24,vkSwapchainImages[i]); Marshal.WriteInt32(ci,32,VK_IMAGE_VIEW_TYPE_2D);
      Marshal.WriteInt32(ci,36,VK_FORMAT_B8G8R8A8_SRGB); Marshal.WriteInt32(ci,56,VK_IMAGE_ASPECT_COLOR_BIT);
      Marshal.WriteInt32(ci,64,1); Marshal.WriteInt32(ci,72,1);
    }else{
      Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
      WriteU64(ci,12,vkSwapchainImages[i]); Marshal.WriteInt32(ci,20,VK_IMAGE_VIEW_TYPE_2D);
      Marshal.WriteInt32(ci,24,VK_FORMAT_B8G8R8A8_SRGB); Marshal.WriteInt32(ci,44,VK_IMAGE_ASPECT_COLOR_BIT);
      Marshal.WriteInt32(ci,52,1); Marshal.WriteInt32(ci,60,1);
    }
    var ivPtr=Marshal.AllocHGlobal(8);
    var r=int(VK_Invoke("Create4",[vkCreateImageView_ptr,vkDevice,ci,IntPtr.Zero,ivPtr]));
    if(r!=VK_SUCCESS){ Marshal.FreeHGlobal(ivPtr); Marshal.FreeHGlobal(ci); return false; }
    vkSwapchainImageViews[i]=ReadU64(ivPtr,0);
    Marshal.FreeHGlobal(ivPtr);
  }
  Marshal.FreeHGlobal(ci);
  DebugLog("Image views created");
  return true;
}

// ============================================================
// Shader module creation (direct Win32 call)
// ============================================================
function CreateShaderModule(spirv:byte[]):ulong{
  if(spirv==null||spirv.length==0||spirv.length%4!=0){
    DebugLog("Bad SPIR-V (size="+(spirv==null?0:spirv.length)+")");
    return 0;
  }
  var handle=GCHandle.Alloc(spirv,GCHandleType.Pinned);
  var codePtr=handle.AddrOfPinnedObject();
  var ci=Marshal.AllocHGlobal(40); ClearMem(ci,40);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    WriteU64(ci,24,ulong(spirv.length)); Marshal.WriteIntPtr(ci,32,codePtr);
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    Marshal.WriteInt32(ci,12,spirv.length); Marshal.WriteIntPtr(ci,16,codePtr);
  }
  var modPtr=Marshal.AllocHGlobal(8);
  var r:int=int(InvokeWin32("vulkan-1.dll",Type.GetType("System.Int32"),"vkCreateShaderModule",
    [Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr"),Type.GetType("System.IntPtr")],
    [vkDevice,ci,IntPtr.Zero,modPtr]));
  var mod:ulong=(r==VK_SUCCESS)?ReadU64(modPtr,0):0;
  if(r!=VK_SUCCESS) DebugLog("vkCreateShaderModule failed: "+r);
  Marshal.FreeHGlobal(modPtr); Marshal.FreeHGlobal(ci); handle.Free();
  return mod;
}

// ============================================================
// Memory allocation helpers
// ============================================================

// Find a memory type index satisfying typeBits and required property flags.
function FindMemoryType(typeBitsParam:int,requiredProps:uint):int{
  // VkPhysicalDeviceMemoryProperties layout (x64/x86 same):
  //   memoryTypeCount(4), [memoryTypes: 32 * {propertyFlags(4)+heapIndex(4)}],
  //   memoryHeapCount(4), ...
  //   sizeof = 4 + 32*8 + 4 + 16*16 = approx 524 bytes → allocate 600 to be safe
  var memPropsPtr=Marshal.AllocHGlobal(600); ClearMem(memPropsPtr,600);
  VK_Invoke("Void2",[vkGetPhysicalDeviceMemoryProperties_ptr,vkPhysicalDevice,memPropsPtr]);
  var typeCount:int=Marshal.ReadInt32(memPropsPtr,0);
  for(var i:int=0;i<typeCount;i++){
    var propFlags:int=Marshal.ReadInt32(memPropsPtr,4+i*8);
    if(((typeBitsParam>>i)&1)!=0&&(uint(propFlags)&requiredProps)==requiredProps){
      Marshal.FreeHGlobal(memPropsPtr);
      return i;
    }
  }
  Marshal.FreeHGlobal(memPropsPtr);
  DebugLog("No suitable memory type found (typeBits=0x"+typeBitsParam.toString(16)+" props=0x"+requiredProps.toString(16)+")");
  return -1;
}

// Create a VkBuffer + VkDeviceMemory and return handles via outHandles array.
//   outHandles[0] = VkBuffer (ulong), outHandles[1] = VkDeviceMemory (ulong)
function AllocateGpuBuffer(size:ulong,usage:uint,memProps:uint,outHandles:Array):Boolean{
  var ci=Marshal.AllocHGlobal(56); ClearMem(ci,56);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO);
  if(IntPtr.Size==8){
    WriteU64(ci,24,size); Marshal.WriteInt32(ci,32,int(usage)); Marshal.WriteInt32(ci,36,VK_SHARING_MODE_EXCLUSIVE);
  }else{
    WriteU64(ci,12,size); Marshal.WriteInt32(ci,20,int(usage)); Marshal.WriteInt32(ci,24,VK_SHARING_MODE_EXCLUSIVE);
  }
  var bufPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateBuffer_ptr,vkDevice,ci,IntPtr.Zero,bufPtr]));
  if(r!=VK_SUCCESS){ Marshal.FreeHGlobal(bufPtr); Marshal.FreeHGlobal(ci); return false; }
  var buf:ulong=ReadU64(bufPtr,0);

  // VkMemoryRequirements: size(8), alignment(8), memoryTypeBits(4) → 20 bytes
  var memReq=Marshal.AllocHGlobal(24); ClearMem(memReq,24);
  createVulkanInvoker.InvokeMember("GetBufMemReq",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkGetBufferMemoryRequirements_ptr,vkDevice,buf,memReq]);
  var reqSize:ulong=ReadU64(memReq,0);
  var typeBits:int=Marshal.ReadInt32(memReq,16);

  var memType:int=FindMemoryType(typeBits,memProps);
  if(memType<0){
    memType=FindMemoryType(typeBits,uint(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT));
  }
  if(memType<0){ Marshal.FreeHGlobal(memReq); Marshal.FreeHGlobal(bufPtr); Marshal.FreeHGlobal(ci); return false; }

  var ai=Marshal.AllocHGlobal(32); ClearMem(ai,32);
  Marshal.WriteInt32(ai,0,VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
  if(IntPtr.Size==8){ WriteU64(ai,16,reqSize); Marshal.WriteInt32(ai,24,memType); }
  else              { WriteU64(ai,8,reqSize);  Marshal.WriteInt32(ai,16,memType); }
  var memPtr=Marshal.AllocHGlobal(8);
  r=int(VK_Invoke("Create4",[vkAllocateMemory_ptr,vkDevice,ai,IntPtr.Zero,memPtr]));
  if(r!=VK_SUCCESS){ Marshal.FreeHGlobal(memPtr); Marshal.FreeHGlobal(ai); Marshal.FreeHGlobal(memReq); Marshal.FreeHGlobal(bufPtr); Marshal.FreeHGlobal(ci); return false; }
  var mem:ulong=ReadU64(memPtr,0);

  createVulkanInvoker.InvokeMember("Bind",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkBindBufferMemory_ptr,vkDevice,buf,mem,ulong(0)]);

  outHandles[0]=buf; outHandles[1]=mem;
  Marshal.FreeHGlobal(memPtr); Marshal.FreeHGlobal(ai);
  Marshal.FreeHGlobal(memReq); Marshal.FreeHGlobal(bufPtr); Marshal.FreeHGlobal(ci);
  return true;
}

// ============================================================
// Buffer setup: SSBOs (pos, col) and UBO (harmonograph params)
// ============================================================
function CreateSSBOBuffers():Boolean{
  DebugLog("Creating position and color SSBOs...");
  var ssboSize:ulong=ulong(NUM_POINTS)*16; // NUM_POINTS * sizeof(vec4)
  var usage:uint=uint(VK_BUFFER_USAGE_STORAGE_BUFFER_BIT);
  var memProps:uint=uint(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  var h=new Array(2);
  if(!AllocateGpuBuffer(ssboSize,usage,memProps,h)){ DebugLog("Pos SSBO failed"); return false; }
  vkPosBuffer=ulong(h[0]); vkPosBufferMemory=ulong(h[1]);
  if(!AllocateGpuBuffer(ssboSize,usage,memProps,h)){ DebugLog("Col SSBO failed"); return false; }
  vkColBuffer=ulong(h[0]); vkColBufferMemory=ulong(h[1]);
  DebugLog("SSBOs created (each "+ssboSize+" bytes)");
  return true;
}

// Create and fill the harmonograph parameter uniform buffer.
// Layout mirrors the std140 Params block in hello.comp:
//   uint  max_num; float dt; float scale; float pad0;         // offset  0
//   float A1; float f1; float p1; float d1;                   // offset 16
//   float A2; float f2; float p2; float d2;                   // offset 32
//   float A3; float f3; float p3; float d3;                   // offset 48
//   float A4; float f4; float p4; float d4;                   // offset 64
function CreateUniformBuffer():Boolean{
  DebugLog("Creating harmonograph parameter UBO...");
  var uboSize:ulong=ulong(80);
  var usage:uint=uint(VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
  var memProps:uint=uint(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  var h=new Array(2);
  if(!AllocateGpuBuffer(uboSize,usage,memProps,h)){ DebugLog("UBO failed"); return false; }
  vkUboBuffer=ulong(h[0]); vkUboBufferMemory=ulong(h[1]);

  // Map, fill, unmap
  var dpStore=Marshal.AllocHGlobal(int(IntPtr.Size));
  createVulkanInvoker.InvokeMember("Map",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkMapMemory_ptr,vkDevice,vkUboBufferMemory,ulong(0),uboSize,uint(0),dpStore]);
  var mapped=Marshal.ReadIntPtr(dpStore);

  // max_num, dt, scale, pad0
  Marshal.WriteInt32(mapped,0,int(uint(NUM_POINTS))); // max_num
  WriteFloat(mapped,4,0.005);                         // dt  (t_max = N*0.005 = 250)
  WriteFloat(mapped,8,0.40);                          // scale (NDC range roughly)
  WriteFloat(mapped,12,0.0);                          // pad0

  // Oscillator x1: A1, f1, p1, d1
  WriteFloat(mapped,16,1.0); WriteFloat(mapped,20,2.0);
  WriteFloat(mapped,24,0.0); WriteFloat(mapped,28,0.002);

  // Oscillator x2: A2, f2, p2, d2
  WriteFloat(mapped,32,1.0); WriteFloat(mapped,36,3.0);
  WriteFloat(mapped,40,0.5); WriteFloat(mapped,44,0.002);

  // Oscillator y1: A3, f3, p3, d3
  WriteFloat(mapped,48,1.0); WriteFloat(mapped,52,3.0);
  WriteFloat(mapped,56,0.0); WriteFloat(mapped,60,0.002);

  // Oscillator y2: A4, f4, p4, d4
  WriteFloat(mapped,64,1.0); WriteFloat(mapped,68,2.0);
  WriteFloat(mapped,72,0.5); WriteFloat(mapped,76,0.002);

  createVulkanInvoker.InvokeMember("Unmap",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkUnmapMemory_ptr,vkDevice,vkUboBufferMemory]);
  Marshal.FreeHGlobal(dpStore);
  DebugLog("UBO filled");
  return true;
}

// ============================================================
// Descriptor set layout, pool, set
// ============================================================

// Three bindings shared by compute and graphics shaders:
//   binding 0 = Positions SSBO (STORAGE_BUFFER, vertex+compute)
//   binding 1 = Colors    SSBO (STORAGE_BUFFER, vertex+compute)
//   binding 2 = Params    UBO  (UNIFORM_BUFFER, compute only)
function CreateDescriptorSetLayout():Boolean{
  DebugLog("Creating descriptor set layout...");
  // VkDescriptorSetLayoutBinding
  //   x64: binding(4)+type(4)+count(4)+stages(4)+pImmSamplers(8) = 24
  //   x86: binding(4)+type(4)+count(4)+stages(4)+pImmSamplers(4) = 20
  var bindSz:int=(IntPtr.Size==8)?24:20;
  var bindings=Marshal.AllocHGlobal(int(3*bindSz)); ClearMem(bindings,3*bindSz);

  Marshal.WriteInt32(bindings,0,  0); // binding 0
  Marshal.WriteInt32(bindings,4,  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER);
  Marshal.WriteInt32(bindings,8,  1);
  Marshal.WriteInt32(bindings,12, VK_SHADER_STAGE_VERTEX_BIT|VK_SHADER_STAGE_COMPUTE_BIT);

  Marshal.WriteInt32(bindings,bindSz+0,  1); // binding 1
  Marshal.WriteInt32(bindings,bindSz+4,  VK_DESCRIPTOR_TYPE_STORAGE_BUFFER);
  Marshal.WriteInt32(bindings,bindSz+8,  1);
  Marshal.WriteInt32(bindings,bindSz+12, VK_SHADER_STAGE_VERTEX_BIT|VK_SHADER_STAGE_COMPUTE_BIT);

  Marshal.WriteInt32(bindings,2*bindSz+0,  2); // binding 2
  Marshal.WriteInt32(bindings,2*bindSz+4,  VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);
  Marshal.WriteInt32(bindings,2*bindSz+8,  1);
  Marshal.WriteInt32(bindings,2*bindSz+12, VK_SHADER_STAGE_COMPUTE_BIT);

  // VkDescriptorSetLayoutCreateInfo
  //   x64: sType(0),pNext(8),flags(16),bindingCount(20),pBindings(24) → 32
  //   x86: sType(0),pNext(4),flags(8), bindingCount(12),pBindings(16) → 20
  var ciSz:int=(IntPtr.Size==8)?32:20;
  var ci=Marshal.AllocHGlobal(int(ciSz)); ClearMem(ci,int(ciSz));
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(ci,20,3); Marshal.WriteIntPtr(ci,24,bindings); }
  else              { Marshal.WriteInt32(ci,12,3); Marshal.WriteIntPtr(ci,16,bindings); }

  var slPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateDescriptorSetLayout_ptr,vkDevice,ci,IntPtr.Zero,slPtr]));
  if(r==VK_SUCCESS){ vkDescriptorSetLayout=ReadU64(slPtr,0); DebugLog("DSL: "+vkDescriptorSetLayout); }

  Marshal.FreeHGlobal(slPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(bindings);
  return r==VK_SUCCESS;
}

function CreateDescriptorPool():Boolean{
  DebugLog("Creating descriptor pool...");
  // Two pool-size entries: STORAGE_BUFFER×2 and UNIFORM_BUFFER×1
  var poolSizes=Marshal.AllocHGlobal(16); ClearMem(poolSizes,16);
  Marshal.WriteInt32(poolSizes,0,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER); Marshal.WriteInt32(poolSizes,4,2);
  Marshal.WriteInt32(poolSizes,8,VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER);  Marshal.WriteInt32(poolSizes,12,1);

  // VkDescriptorPoolCreateInfo
  //   x64: sType(0),pNext(8),flags(16),maxSets(20),poolSizeCount(24),pPoolSizes(32) → 40
  //   x86: sType(0),pNext(4),flags(8), maxSets(12),poolSizeCount(16),pPoolSizes(20) → 24
  var ciSz:int=(IntPtr.Size==8)?40:24;
  var ci=Marshal.AllocHGlobal(int(ciSz)); ClearMem(ci,int(ciSz));
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(ci,20,1); Marshal.WriteInt32(ci,24,2); Marshal.WriteIntPtr(ci,32,poolSizes); }
  else              { Marshal.WriteInt32(ci,12,1); Marshal.WriteInt32(ci,16,2); Marshal.WriteIntPtr(ci,20,poolSizes); }

  var dpPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateDescriptorPool_ptr,vkDevice,ci,IntPtr.Zero,dpPtr]));
  if(r==VK_SUCCESS){ vkDescriptorPool=ReadU64(dpPtr,0); DebugLog("Pool: "+vkDescriptorPool); }
  Marshal.FreeHGlobal(dpPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(poolSizes);
  return r==VK_SUCCESS;
}

function AllocateDescriptorSets():Boolean{
  DebugLog("Allocating descriptor set...");
  var slArr=Marshal.AllocHGlobal(8); WriteU64(slArr,0,vkDescriptorSetLayout);

  // VkDescriptorSetAllocateInfo
  //   x64: sType(0),pNext(8),pool(16),count(24),pSetLayouts(32) → 40
  //   x86: sType(0),pNext(4),pool(8), count(16),pSetLayouts(20) → 24
  var aiSz:int=(IntPtr.Size==8)?40:24;
  var ai=Marshal.AllocHGlobal(int(aiSz)); ClearMem(ai,int(aiSz));
  Marshal.WriteInt32(ai,0,VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO);
  if(IntPtr.Size==8){ WriteU64(ai,16,vkDescriptorPool); Marshal.WriteInt32(ai,24,1); Marshal.WriteIntPtr(ai,32,slArr); }
  else              { WriteU64(ai,8,vkDescriptorPool);  Marshal.WriteInt32(ai,16,1); Marshal.WriteIntPtr(ai,20,slArr); }

  var dsPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create3",[vkAllocateDescriptorSets_ptr,vkDevice,ai,dsPtr]));
  if(r==VK_SUCCESS){ vkDescriptorSet=ReadU64(dsPtr,0); DebugLog("DS: "+vkDescriptorSet); }
  Marshal.FreeHGlobal(dsPtr); Marshal.FreeHGlobal(ai); Marshal.FreeHGlobal(slArr);
  return r==VK_SUCCESS;
}

function UpdateDescriptorSets():void{
  DebugLog("Updating descriptor sets...");
  // VkDescriptorBufferInfo: buffer(8), offset(8), range(8) = 24 bytes (x86/x64 same)
  var biPos=Marshal.AllocHGlobal(24); ClearMem(biPos,24);
  WriteU64(biPos,0,vkPosBuffer); WriteU64(biPos,16,ulong(NUM_POINTS)*16);

  var biCol=Marshal.AllocHGlobal(24); ClearMem(biCol,24);
  WriteU64(biCol,0,vkColBuffer); WriteU64(biCol,16,ulong(NUM_POINTS)*16);

  var biUbo=Marshal.AllocHGlobal(24); ClearMem(biUbo,24);
  WriteU64(biUbo,0,vkUboBuffer); WriteU64(biUbo,16,ulong(80));

  // VkWriteDescriptorSet offsets
  //   x64: sType(0),pNext(8),dstSet(16),dstBinding(24),dstElem(28),
  //        count(32),type(36),pImageInfo(40),pBufferInfo(48),pTexelBV(56) → 64
  //   x86: sType(0),pNext(4),dstSet(8), dstBinding(16),dstElem(20),
  //        count(24),type(28),pImageInfo(32),pBufferInfo(36),pTexelBV(40) → 44
  var wdsSz:int=(IntPtr.Size==8)?64:44;
  var writes=Marshal.AllocHGlobal(int(3*wdsSz)); ClearMem(writes,3*wdsSz);

  var w0=writes;
  Marshal.WriteInt32(w0,0,VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET);
  if(IntPtr.Size==8){
    WriteU64(w0,16,vkDescriptorSet); Marshal.WriteInt32(w0,24,0);
    Marshal.WriteInt32(w0,32,1); Marshal.WriteInt32(w0,36,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER); Marshal.WriteIntPtr(w0,48,biPos);
  }else{
    WriteU64(w0,8,vkDescriptorSet);  Marshal.WriteInt32(w0,16,0);
    Marshal.WriteInt32(w0,24,1); Marshal.WriteInt32(w0,28,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER); Marshal.WriteIntPtr(w0,36,biPos);
  }

  var w1=IntPtr.Add(writes,int(wdsSz));
  Marshal.WriteInt32(w1,0,VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET);
  if(IntPtr.Size==8){
    WriteU64(w1,16,vkDescriptorSet); Marshal.WriteInt32(w1,24,1);
    Marshal.WriteInt32(w1,32,1); Marshal.WriteInt32(w1,36,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER); Marshal.WriteIntPtr(w1,48,biCol);
  }else{
    WriteU64(w1,8,vkDescriptorSet);  Marshal.WriteInt32(w1,16,1);
    Marshal.WriteInt32(w1,24,1); Marshal.WriteInt32(w1,28,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER); Marshal.WriteIntPtr(w1,36,biCol);
  }

  var w2=IntPtr.Add(writes,int(2*wdsSz));
  Marshal.WriteInt32(w2,0,VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET);
  if(IntPtr.Size==8){
    WriteU64(w2,16,vkDescriptorSet); Marshal.WriteInt32(w2,24,2);
    Marshal.WriteInt32(w2,32,1); Marshal.WriteInt32(w2,36,VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER); Marshal.WriteIntPtr(w2,48,biUbo);
  }else{
    WriteU64(w2,8,vkDescriptorSet);  Marshal.WriteInt32(w2,16,2);
    Marshal.WriteInt32(w2,24,1); Marshal.WriteInt32(w2,28,VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER); Marshal.WriteIntPtr(w2,36,biUbo);
  }

  createVulkanInvoker.InvokeMember("UpdateDS",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkUpdateDescriptorSets_ptr,vkDevice,uint(3),writes,uint(0),IntPtr.Zero]);

  Marshal.FreeHGlobal(writes);
  Marshal.FreeHGlobal(biUbo); Marshal.FreeHGlobal(biCol); Marshal.FreeHGlobal(biPos);
  DebugLog("Descriptor sets updated");
}

// ============================================================
// Pipeline layouts
// ============================================================

// Graphics pipeline layout with shared descriptor set layout
function CreatePipelineLayout():Boolean{
  DebugLog("Creating graphics pipeline layout...");
  var slArr=Marshal.AllocHGlobal(8); WriteU64(slArr,0,vkDescriptorSetLayout);

  // VkPipelineLayoutCreateInfo
  //   x64: sType(0),pNext(8),flags(16),setCount(20),pSets(24),pcCount(32),pPC(40) → 48
  //   x86: sType(0),pNext(4),flags(8), setCount(12),pSets(16),pcCount(20),pPC(24) → 28
  var ci=Marshal.AllocHGlobal(48); ClearMem(ci,48);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,slArr); }
  else              { Marshal.WriteInt32(ci,12,1); Marshal.WriteIntPtr(ci,16,slArr); }

  var plPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreatePipelineLayout_ptr,vkDevice,ci,IntPtr.Zero,plPtr]));
  if(r==VK_SUCCESS){ vkPipelineLayout=ReadU64(plPtr,0); DebugLog("Graphics PL: "+vkPipelineLayout); }
  Marshal.FreeHGlobal(plPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(slArr);
  return r==VK_SUCCESS;
}

// Compute pipeline layout (same descriptor set layout)
function CreateComputePipelineLayout():Boolean{
  DebugLog("Creating compute pipeline layout...");
  var slArr=Marshal.AllocHGlobal(8); WriteU64(slArr,0,vkDescriptorSetLayout);
  var ci=Marshal.AllocHGlobal(48); ClearMem(ci,48);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,slArr); }
  else              { Marshal.WriteInt32(ci,12,1); Marshal.WriteIntPtr(ci,16,slArr); }
  var plPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreatePipelineLayout_ptr,vkDevice,ci,IntPtr.Zero,plPtr]));
  if(r==VK_SUCCESS){ vkComputePipelineLayout=ReadU64(plPtr,0); DebugLog("Compute PL: "+vkComputePipelineLayout); }
  Marshal.FreeHGlobal(plPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(slArr);
  return r==VK_SUCCESS;
}

// ============================================================
// Compute pipeline (hello.comp)
// ============================================================
function CreateComputePipeline():Boolean{
  DebugLog("Creating compute pipeline...");
  var compSrc=ReadShaderText("hello.comp",COMP_GLSL_FALLBACK);
  var compSpv:byte[]=ShadercCompile(compSrc,SHADERC_SHADER_KIND_COMPUTE,"hello.comp","main");
  var compMod:ulong=CreateShaderModule(compSpv);
  if(compMod==0){ DebugLog("Compute shader module failed"); return false; }

  var mainName=Marshal.StringToHGlobalAnsi("main");

  // Build VkComputePipelineCreateInfo with embedded VkPipelineShaderStageCreateInfo.
  //
  // x64 offsets within the outer struct:
  //   [0]  sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO (29)
  //   [8]  pNext = null
  //   [16] flags = 0
  //   [20] stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO (18)
  //   [28] stage.pNext = null
  //   [36] stage.flags = 0
  //   [40] stage.stage = VK_SHADER_STAGE_COMPUTE_BIT (0x20)
  //   [44] stage.module (uint64)
  //   [52] stage.pName (ptr)
  //   [60] stage.pSpecializationInfo = null
  //   [68] layout (uint64)
  //   [76] basePipelineHandle (uint64) = 0
  //   [84] basePipelineIndex = -1
  // Total x64: ~88 bytes. Allocate 96.
  //
  // x86 offsets (smaller pointers):
  //   [0]  sType
  //   [4]  pNext = null
  //   [8]  flags = 0
  //   [12] stage.sType
  //   [16] stage.pNext = null
  //   [20] stage.flags = 0
  //   [24] stage.stage
  //   [28] stage.module (uint64)
  //   [36] stage.pName (ptr 4 bytes)
  //   [40] stage.pSpecializationInfo = null
  //   [44] layout (uint64)
  //   [52] basePipelineHandle (uint64) = 0
  //   [60] basePipelineIndex = -1
  // Total x86: ~64 bytes. Allocate 80.
  var ciSz:int=(IntPtr.Size==8)?96:80;
  var ci=Marshal.AllocHGlobal(int(ciSz)); ClearMem(ci,int(ciSz));

  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO);
    // Embedded stage
    Marshal.WriteInt32(ci,20,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    Marshal.WriteInt32(ci,40,VK_SHADER_STAGE_COMPUTE_BIT);
    WriteU64(ci,44,compMod);
    Marshal.WriteIntPtr(ci,52,mainName);
    // layout
    WriteU64(ci,68,vkComputePipelineLayout);
    Marshal.WriteInt32(ci,84,-1); // basePipelineIndex
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO);
    Marshal.WriteInt32(ci,12,VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    Marshal.WriteInt32(ci,24,VK_SHADER_STAGE_COMPUTE_BIT);
    WriteU64(ci,28,compMod);
    Marshal.WriteIntPtr(ci,36,mainName);
    WriteU64(ci,44,vkComputePipelineLayout);
    Marshal.WriteInt32(ci,60,-1);
  }

  var pipePtr=Marshal.AllocHGlobal(8);
  // vkCreateComputePipelines(device, pipelineCache=0, createInfoCount=1, pCreateInfos, alloc, pPipelines)
  var r=int(createVulkanInvoker.InvokeMember("CreatePipe",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateComputePipelines_ptr,vkDevice,ulong(0),uint(1),ci,IntPtr.Zero,pipePtr]));

  if(r==VK_SUCCESS){ vkComputePipeline=ReadU64(pipePtr,0); DebugLog("Compute pipeline: "+vkComputePipeline); }
  else DebugLog("vkCreateComputePipelines failed: "+r);

  // Destroy compute shader module (no longer needed after pipeline creation)
  createVulkanInvoker.InvokeMember("Destroy3",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkDestroyShaderModule_ptr,vkDevice,compMod,IntPtr.Zero]);

  Marshal.FreeHGlobal(pipePtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(mainName);
  return r==VK_SUCCESS;
}

// ============================================================
// Run the compute shader once to fill the SSBOs
// ============================================================
function RunComputePass():void{
  DebugLog("Running compute pass...");

  // Allocate a transient command buffer for the compute dispatch
  var cbAI=Marshal.AllocHGlobal(32); ClearMem(cbAI,32);
  Marshal.WriteInt32(cbAI,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
  if(IntPtr.Size==8){
    WriteU64(cbAI,16,vkCommandPool); Marshal.WriteInt32(cbAI,24,VK_COMMAND_BUFFER_LEVEL_PRIMARY); Marshal.WriteInt32(cbAI,28,1);
  }else{
    WriteU64(cbAI,8,vkCommandPool); Marshal.WriteInt32(cbAI,16,VK_COMMAND_BUFFER_LEVEL_PRIMARY); Marshal.WriteInt32(cbAI,20,1);
  }
  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  VK_Invoke("Create3",[vkAllocateCommandBuffers_ptr,vkDevice,cbAI,cbPtr]);
  var compCb=Marshal.ReadIntPtr(cbPtr);
  Marshal.FreeHGlobal(cbPtr); Marshal.FreeHGlobal(cbAI);
  DebugLog("Compute command buffer: "+compCb);

  // Begin command buffer
  var beginInfo=Marshal.AllocHGlobal(32); ClearMem(beginInfo,32);
  Marshal.WriteInt32(beginInfo,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
  VK_Invoke("Create2",[vkBeginCommandBuffer_ptr,compCb,beginInfo]);

  // Bind compute pipeline
  createVulkanInvoker.InvokeMember("BindPipe",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdBindPipeline_ptr,compCb,uint(VK_PIPELINE_BIND_POINT_COMPUTE),vkComputePipeline]);

  // Bind descriptor set (binding 0,1,2 contain pos SSBO, col SSBO, params UBO)
  var dsArr=Marshal.AllocHGlobal(8); WriteU64(dsArr,0,vkDescriptorSet);
  createVulkanInvoker.InvokeMember("CmdBindDS",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdBindDescriptorSets_ptr,compCb,uint(VK_PIPELINE_BIND_POINT_COMPUTE),
     vkComputePipelineLayout,uint(0),uint(1),dsArr,uint(0),IntPtr.Zero]);
  Marshal.FreeHGlobal(dsArr);

  // Dispatch: hello.comp uses local_size_x=256, so ceil(NUM_POINTS/256) groups
  var groups:uint=uint((NUM_POINTS+255)/256);
  createVulkanInvoker.InvokeMember("CmdDispatch",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdDispatch_ptr,compCb,groups,uint(1),uint(1)]);
  DebugLog("Dispatched "+groups+" groups x 256 threads");

  VK_Invoke("Ret1",[vkEndCommandBuffer_ptr,compCb]);

  // Submit and wait idle
  var submitInfo=Marshal.AllocHGlobal(64); ClearMem(submitInfo,64);
  Marshal.WriteInt32(submitInfo,0,VK_STRUCTURE_TYPE_SUBMIT_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(submitInfo,20+8,1); Marshal.WriteIntPtr(submitInfo,32+8,compCb); }
  else              { Marshal.WriteInt32(submitInfo,12+4,1); Marshal.WriteIntPtr(submitInfo,16+4,compCb); }

  // Simpler: we write cmdBufferCount=1 and pCommandBuffers pointer
  // VkSubmitInfo x64: sType(0),pNext(8),waitSemCount(16),pWaitSems(24),pWaitDstStageMask(32),
  //                   cmdBufCount(40),pCmdBufs(48),signalSemCount(56),pSignalSems(64) → 72 bytes
  // Redo with correct layout:
  Marshal.FreeHGlobal(submitInfo);
  var cbArr=Marshal.AllocHGlobal(int(IntPtr.Size)); Marshal.WriteIntPtr(cbArr,0,compCb);
  submitInfo=Marshal.AllocHGlobal(72); ClearMem(submitInfo,72);
  Marshal.WriteInt32(submitInfo,0,VK_STRUCTURE_TYPE_SUBMIT_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(submitInfo,40,1); Marshal.WriteIntPtr(submitInfo,48,cbArr); }
  else              { Marshal.WriteInt32(submitInfo,20,1); Marshal.WriteIntPtr(submitInfo,24,cbArr); }

  createVulkanInvoker.InvokeMember("Submit",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkQueueSubmit_ptr,vkGraphicsQueue,uint(1),submitInfo,ulong(0)]);
  VK_Invoke("Void1",[vkQueueWaitIdle_ptr,vkGraphicsQueue]);

  Marshal.FreeHGlobal(cbArr); Marshal.FreeHGlobal(submitInfo); Marshal.FreeHGlobal(beginInfo);
  DebugLog("Compute pass complete");
}

// ============================================================
// Render pass
// ============================================================
function CreateRenderPass():Boolean{
  DebugLog("Creating render pass...");
  var attach=Marshal.AllocHGlobal(36); ClearMem(attach,36);
  Marshal.WriteInt32(attach,4,VK_FORMAT_B8G8R8A8_SRGB); Marshal.WriteInt32(attach,8,VK_SAMPLE_COUNT_1_BIT);
  Marshal.WriteInt32(attach,12,VK_ATTACHMENT_LOAD_OP_CLEAR); Marshal.WriteInt32(attach,16,VK_ATTACHMENT_STORE_OP_STORE);
  Marshal.WriteInt32(attach,20,VK_ATTACHMENT_LOAD_OP_DONT_CARE); Marshal.WriteInt32(attach,24,VK_ATTACHMENT_STORE_OP_DONT_CARE);
  Marshal.WriteInt32(attach,28,VK_IMAGE_LAYOUT_UNDEFINED); Marshal.WriteInt32(attach,32,VK_IMAGE_LAYOUT_PRESENT_SRC_KHR);

  var colorRef=Marshal.AllocHGlobal(8);
  Marshal.WriteInt32(colorRef,0,0); Marshal.WriteInt32(colorRef,4,VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

  var subpass=Marshal.AllocHGlobal(72); ClearMem(subpass,72);
  if(IntPtr.Size==8){ Marshal.WriteInt32(subpass,4,VK_PIPELINE_BIND_POINT_GRAPHICS); Marshal.WriteInt32(subpass,24,1); Marshal.WriteIntPtr(subpass,32,colorRef); }
  else              { Marshal.WriteInt32(subpass,4,VK_PIPELINE_BIND_POINT_GRAPHICS); Marshal.WriteInt32(subpass,16,1); Marshal.WriteIntPtr(subpass,20,colorRef); }

  var dep=Marshal.AllocHGlobal(28);
  Marshal.WriteInt32(dep,0,-1); Marshal.WriteInt32(dep,4,0);
  Marshal.WriteInt32(dep,8,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  Marshal.WriteInt32(dep,12,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
  Marshal.WriteInt32(dep,16,0); Marshal.WriteInt32(dep,20,VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT);

  var ci=Marshal.AllocHGlobal(64); ClearMem(ci,64);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,attach);
    Marshal.WriteInt32(ci,32,1); Marshal.WriteIntPtr(ci,40,subpass);
    Marshal.WriteInt32(ci,48,1); Marshal.WriteIntPtr(ci,56,dep);
  }else{
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    Marshal.WriteInt32(ci,12,1); Marshal.WriteIntPtr(ci,16,attach);
    Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,subpass);
    Marshal.WriteInt32(ci,28,1); Marshal.WriteIntPtr(ci,32,dep);
  }

  var rpPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateRenderPass_ptr,vkDevice,ci,IntPtr.Zero,rpPtr]));
  if(r==VK_SUCCESS){ vkRenderPass=ReadU64(rpPtr,0); DebugLog("Render pass: "+vkRenderPass); }
  Marshal.FreeHGlobal(rpPtr); Marshal.FreeHGlobal(ci); Marshal.FreeHGlobal(dep);
  Marshal.FreeHGlobal(subpass); Marshal.FreeHGlobal(colorRef); Marshal.FreeHGlobal(attach);
  return r==VK_SUCCESS;
}

// ============================================================
// Graphics pipeline (hello.vert + hello.frag)
// No vertex buffer: the vertex shader reads positions from the SSBO.
// ============================================================
function CreateGraphicsPipeline():Boolean{
  DebugLog("Creating graphics pipeline...");

  // Compile vertex and fragment shaders via shaderc
  var vertSrc=ReadShaderText("hello.vert",VERT_GLSL_FALLBACK);
  var fragSrc=ReadShaderText("hello.frag",FRAG_GLSL_FALLBACK);
  var vertSpv:byte[]=ShadercCompile(vertSrc,SHADERC_SHADER_KIND_VERTEX,"hello.vert","main");
  var fragSpv:byte[]=ShadercCompile(fragSrc,SHADERC_SHADER_KIND_FRAGMENT,"hello.frag","main");

  var vertMod:ulong=CreateShaderModule(vertSpv);
  var fragMod:ulong=CreateShaderModule(fragSpv);
  if(vertMod==0||fragMod==0){ DebugLog("Shader module creation failed"); return false; }

  var mainName=Marshal.StringToHGlobalAnsi("main");

  // VkPipelineShaderStageCreateInfo
  //   x64: sType(0),pNext(8),flags(16),stage(20),module(24)[u64],pName(32),pSpecInfo(40) → 48
  //   x86: sType(0),pNext(4),flags(8), stage(12),module(16)[u64],pName(24),pSpecInfo(28) → 32
  var stageSize:int=(IntPtr.Size==8)?48:32;
  var stages=Marshal.AllocHGlobal(int(stageSize*2)); ClearMem(stages,stageSize*2);

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

  // Empty vertex input state – no VBO, vertex data comes from SSBOs
  var vertexInput=Marshal.AllocHGlobal(48); ClearMem(vertexInput,48);
  Marshal.WriteInt32(vertexInput,0,VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);

  // Input assembly: point list (one dot per harmonograph sample)
  var inputAsm=Marshal.AllocHGlobal(32); ClearMem(inputAsm,32);
  Marshal.WriteInt32(inputAsm,0,VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);
  Marshal.WriteInt32(inputAsm,(IntPtr.Size==8)?20:12,VK_PRIMITIVE_TOPOLOGY_POINT_LIST);

  // Viewport state (dynamic)
  var viewportState=Marshal.AllocHGlobal(48); ClearMem(viewportState,48);
  Marshal.WriteInt32(viewportState,0,VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);
  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?20:12,1);
  Marshal.WriteInt32(viewportState,(IntPtr.Size==8)?32:20,1);

  // Rasterisation
  var raster=Marshal.AllocHGlobal(64); ClearMem(raster,64);
  Marshal.WriteInt32(raster,0,VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?28:20,VK_POLYGON_MODE_FILL);
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?32:24,VK_CULL_MODE_NONE); // no culling for points
  Marshal.WriteInt32(raster,(IntPtr.Size==8)?36:28,VK_FRONT_FACE_CLOCKWISE);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)),0,IntPtr.Add(raster,(IntPtr.Size==8)?56:48),4); // lineWidth

  // Multisample
  var multisample=Marshal.AllocHGlobal(48); ClearMem(multisample,48);
  Marshal.WriteInt32(multisample,0,VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);
  Marshal.WriteInt32(multisample,(IntPtr.Size==8)?20:12,VK_SAMPLE_COUNT_1_BIT);

  // Color blend (single attachment, no blending)
  var blendAttach=Marshal.AllocHGlobal(32); ClearMem(blendAttach,32);
  Marshal.WriteInt32(blendAttach,28,VK_COLOR_COMPONENT_RGBA);

  var colorBlend=Marshal.AllocHGlobal(56); ClearMem(colorBlend,56);
  Marshal.WriteInt32(colorBlend,0,VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(colorBlend,28,1); Marshal.WriteIntPtr(colorBlend,32,blendAttach); }
  else              { Marshal.WriteInt32(colorBlend,20,1); Marshal.WriteIntPtr(colorBlend,24,blendAttach); }

  // Dynamic states: viewport + scissor
  var dynStates=Marshal.AllocHGlobal(8);
  Marshal.WriteInt32(dynStates,0,VK_DYNAMIC_STATE_VIEWPORT);
  Marshal.WriteInt32(dynStates,4,VK_DYNAMIC_STATE_SCISSOR);

  var dynState=Marshal.AllocHGlobal(32); ClearMem(dynState,32);
  Marshal.WriteInt32(dynState,0,VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO);
  if(IntPtr.Size==8){ Marshal.WriteInt32(dynState,20,2); Marshal.WriteIntPtr(dynState,24,dynStates); }
  else              { Marshal.WriteInt32(dynState,12,2); Marshal.WriteIntPtr(dynState,16,dynStates); }

  // VkGraphicsPipelineCreateInfo
  //   x64: sType(0),pNext(8),flags(16),stageCount(20),pStages(24),
  //        pVertexInputState(32),pInputAssemblyState(40),pTessellationState(48),pViewportState(56),
  //        pRasterizationState(64),pMultisampleState(72),pDepthStencilState(80),pColorBlendState(88),
  //        pDynamicState(96),layout(104)[u64],renderPass(112)[u64],subpass(120),
  //        basePipelineHandle(124)[u64],basePipelineIndex(132) → 136 bytes
  var pipeInfo=Marshal.AllocHGlobal(144); ClearMem(pipeInfo,144);
  Marshal.WriteInt32(pipeInfo,0,VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(pipeInfo,20,2); Marshal.WriteIntPtr(pipeInfo,24,stages);
    Marshal.WriteIntPtr(pipeInfo,32,vertexInput); Marshal.WriteIntPtr(pipeInfo,40,inputAsm);
    Marshal.WriteIntPtr(pipeInfo,56,viewportState); Marshal.WriteIntPtr(pipeInfo,64,raster);
    Marshal.WriteIntPtr(pipeInfo,72,multisample);   Marshal.WriteIntPtr(pipeInfo,88,colorBlend);
    Marshal.WriteIntPtr(pipeInfo,96,dynState);
    WriteU64(pipeInfo,104,vkPipelineLayout); WriteU64(pipeInfo,112,vkRenderPass);
    Marshal.WriteInt32(pipeInfo,132,-1);
  }else{
    Marshal.WriteInt32(pipeInfo,12,2); Marshal.WriteIntPtr(pipeInfo,16,stages);
    Marshal.WriteIntPtr(pipeInfo,20,vertexInput); Marshal.WriteIntPtr(pipeInfo,24,inputAsm);
    Marshal.WriteIntPtr(pipeInfo,32,viewportState); Marshal.WriteIntPtr(pipeInfo,36,raster);
    Marshal.WriteIntPtr(pipeInfo,40,multisample);   Marshal.WriteIntPtr(pipeInfo,48,colorBlend);
    Marshal.WriteIntPtr(pipeInfo,52,dynState);
    WriteU64(pipeInfo,56,vkPipelineLayout); WriteU64(pipeInfo,64,vkRenderPass);
    Marshal.WriteInt32(pipeInfo,84,-1);
  }

  var pipePtr=Marshal.AllocHGlobal(8);
  var r=int(createVulkanInvoker.InvokeMember("CreatePipe",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCreateGraphicsPipelines_ptr,vkDevice,ulong(0),uint(1),pipeInfo,IntPtr.Zero,pipePtr]));
  if(r==VK_SUCCESS){ vkGraphicsPipeline=ReadU64(pipePtr,0); DebugLog("Graphics pipeline: "+vkGraphicsPipeline); }
  else DebugLog("vkCreateGraphicsPipelines failed: "+r);

  // Destroy shader modules after pipeline is created
  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkDestroyShaderModule_ptr,vkDevice,vertMod,IntPtr.Zero]);
  createVulkanInvoker.InvokeMember("Destroy3",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkDestroyShaderModule_ptr,vkDevice,fragMod,IntPtr.Zero]);

  Marshal.FreeHGlobal(pipePtr); Marshal.FreeHGlobal(pipeInfo);
  Marshal.FreeHGlobal(dynState); Marshal.FreeHGlobal(dynStates);
  Marshal.FreeHGlobal(colorBlend); Marshal.FreeHGlobal(blendAttach);
  Marshal.FreeHGlobal(multisample); Marshal.FreeHGlobal(raster);
  Marshal.FreeHGlobal(viewportState); Marshal.FreeHGlobal(inputAsm);
  Marshal.FreeHGlobal(vertexInput); Marshal.FreeHGlobal(stages); Marshal.FreeHGlobal(mainName);
  return r==VK_SUCCESS;
}

// ============================================================
// Framebuffers, command pool/buffer, sync objects
// ============================================================
function CreateFramebuffers():Boolean{
  vkFramebuffers=new ulong[vkSwapchainImageCount];
  var ci=Marshal.AllocHGlobal(64);
  var attachPtr=Marshal.AllocHGlobal(8);
  for(var i:uint=0;i<vkSwapchainImageCount;i++){
    ClearMem(ci,64); WriteU64(attachPtr,0,vkSwapchainImageViews[i]);
    Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
    if(IntPtr.Size==8){
      WriteU64(ci,24,vkRenderPass); Marshal.WriteInt32(ci,32,1); Marshal.WriteIntPtr(ci,40,attachPtr);
      Marshal.WriteInt32(ci,48,int(windowWidth)); Marshal.WriteInt32(ci,52,int(windowHeight)); Marshal.WriteInt32(ci,56,1);
    }else{
      WriteU64(ci,12,vkRenderPass); Marshal.WriteInt32(ci,20,1); Marshal.WriteIntPtr(ci,24,attachPtr);
      Marshal.WriteInt32(ci,28,int(windowWidth)); Marshal.WriteInt32(ci,32,int(windowHeight)); Marshal.WriteInt32(ci,36,1);
    }
    var fbPtr=Marshal.AllocHGlobal(8);
    var r=int(VK_Invoke("Create4",[vkCreateFramebuffer_ptr,vkDevice,ci,IntPtr.Zero,fbPtr]));
    if(r!=VK_SUCCESS){ Marshal.FreeHGlobal(fbPtr); Marshal.FreeHGlobal(attachPtr); Marshal.FreeHGlobal(ci); return false; }
    vkFramebuffers[i]=ReadU64(fbPtr,0);
    Marshal.FreeHGlobal(fbPtr);
  }
  Marshal.FreeHGlobal(attachPtr); Marshal.FreeHGlobal(ci);
  DebugLog("Framebuffers created");
  return true;
}

function CreateCommandPool():Boolean{
  var ci=Marshal.AllocHGlobal(24); ClearMem(ci,24);
  Marshal.WriteInt32(ci,0,VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);
  Marshal.WriteInt32(ci,(IntPtr.Size==8)?16:8,VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
  Marshal.WriteInt32(ci,(IntPtr.Size==8)?20:12,int(vkGraphicsQueueFamilyIndex));
  var poolPtr=Marshal.AllocHGlobal(8);
  var r=int(VK_Invoke("Create4",[vkCreateCommandPool_ptr,vkDevice,ci,IntPtr.Zero,poolPtr]));
  if(r==VK_SUCCESS){ vkCommandPool=ReadU64(poolPtr,0); DebugLog("Command pool: "+vkCommandPool); }
  Marshal.FreeHGlobal(poolPtr); Marshal.FreeHGlobal(ci);
  return r==VK_SUCCESS;
}

function AllocateCommandBuffers():Boolean{
  var ai=Marshal.AllocHGlobal(32); ClearMem(ai,32);
  Marshal.WriteInt32(ai,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
  if(IntPtr.Size==8){ WriteU64(ai,16,vkCommandPool); Marshal.WriteInt32(ai,24,VK_COMMAND_BUFFER_LEVEL_PRIMARY); Marshal.WriteInt32(ai,28,1); }
  else              { WriteU64(ai,8,vkCommandPool);  Marshal.WriteInt32(ai,16,VK_COMMAND_BUFFER_LEVEL_PRIMARY); Marshal.WriteInt32(ai,20,1); }
  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size));
  var r=int(VK_Invoke("Create3",[vkAllocateCommandBuffers_ptr,vkDevice,ai,cbPtr]));
  if(r==VK_SUCCESS){ vkCommandBuffer=Marshal.ReadIntPtr(cbPtr); DebugLog("Command buffer: "+vkCommandBuffer); }
  Marshal.FreeHGlobal(cbPtr); Marshal.FreeHGlobal(ai);
  return r==VK_SUCCESS;
}

function CreateSyncObjects():Boolean{
  var semInfo=Marshal.AllocHGlobal(24); ClearMem(semInfo,24);
  Marshal.WriteInt32(semInfo,0,VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO);

  var fenceInfo=Marshal.AllocHGlobal(24); ClearMem(fenceInfo,24);
  Marshal.WriteInt32(fenceInfo,0,VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);
  Marshal.WriteInt32(fenceInfo,(IntPtr.Size==8)?16:8,VK_FENCE_CREATE_SIGNALED_BIT);

  var ptr=Marshal.AllocHGlobal(8);
  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);
  vkImageAvailableSemaphore=ReadU64(ptr,0);
  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateSemaphore_ptr,vkDevice,semInfo,IntPtr.Zero,ptr]);
  vkRenderFinishedSemaphore=ReadU64(ptr,0);
  createVulkanInvoker.InvokeMember("Create4",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCreateFence_ptr,vkDevice,fenceInfo,IntPtr.Zero,ptr]);
  vkInFlightFence=ReadU64(ptr,0);

  Marshal.FreeHGlobal(ptr); Marshal.FreeHGlobal(fenceInfo); Marshal.FreeHGlobal(semInfo);
  DebugLog("Sync objects created");
  return true;
}

// ============================================================
// Window class registration
// ============================================================
function RegisterWindowClass(hInst:IntPtr):Boolean{
  var defProc=GetProcAddress(GetModuleHandle("user32.dll"),"DefWindowProcA");
  var brush=GetStockObject(WHITE_BRUSH);
  var className=Marshal.StringToHGlobalAnsi("harmonograph");
  var cbWndClass:int=(IntPtr.Size==8)?80:48;
  var wndClass=Marshal.AllocHGlobal(int(cbWndClass)); ClearMem(wndClass,cbWndClass);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(wndClass,0,cbWndClass); Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc); Marshal.WriteIntPtr(wndClass,24,hInst);
    Marshal.WriteIntPtr(wndClass,48,brush); Marshal.WriteIntPtr(wndClass,64,className);
  }else{
    Marshal.WriteInt32(wndClass,0,cbWndClass); Marshal.WriteInt32(wndClass,4,CS_OWNDC);
    Marshal.WriteIntPtr(wndClass,8,defProc); Marshal.WriteIntPtr(wndClass,20,hInst);
    Marshal.WriteIntPtr(wndClass,32,brush); Marshal.WriteIntPtr(wndClass,40,className);
  }
  var atom=InvokeWin32("user32.dll",Type.GetType("System.UInt16"),"RegisterClassExA",[Type.GetType("System.IntPtr")],[wndClass]);
  Marshal.FreeHGlobal(className); Marshal.FreeHGlobal(wndClass);
  return atom!=0;
}

// ============================================================
// Render loop – record and submit one frame
// ============================================================
function RecordCommandBuffer(imgIdx:uint):void{
  createVulkanInvoker.InvokeMember("ResetCmd",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkResetCommandBuffer_ptr,vkCommandBuffer,uint(0)]);

  var beginInfo=Marshal.AllocHGlobal(32); ClearMem(beginInfo,32);
  Marshal.WriteInt32(beginInfo,0,VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
  VK_Invoke("Create2",[vkBeginCommandBuffer_ptr,vkCommandBuffer,beginInfo]);

  // Clear color: dark background to make the Lissajous pattern pop
  var clearVal=Marshal.AllocHGlobal(16);
  Marshal.Copy(BitConverter.GetBytes(float(0.05)),0,clearVal,4);
  Marshal.Copy(BitConverter.GetBytes(float(0.05)),0,IntPtr.Add(clearVal,4),4);
  Marshal.Copy(BitConverter.GetBytes(float(0.10)),0,IntPtr.Add(clearVal,8),4);
  Marshal.Copy(BitConverter.GetBytes(float(1.0)), 0,IntPtr.Add(clearVal,12),4);

  var rpBegin=Marshal.AllocHGlobal(64); ClearMem(rpBegin,64);
  Marshal.WriteInt32(rpBegin,0,VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
  if(IntPtr.Size==8){
    WriteU64(rpBegin,16,vkRenderPass); WriteU64(rpBegin,24,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,40,int(windowWidth)); Marshal.WriteInt32(rpBegin,44,int(windowHeight));
    Marshal.WriteInt32(rpBegin,48,1); Marshal.WriteIntPtr(rpBegin,56,clearVal);
  }else{
    WriteU64(rpBegin,8,vkRenderPass); WriteU64(rpBegin,16,vkFramebuffers[imgIdx]);
    Marshal.WriteInt32(rpBegin,32,int(windowWidth)); Marshal.WriteInt32(rpBegin,36,int(windowHeight));
    Marshal.WriteInt32(rpBegin,40,1); Marshal.WriteIntPtr(rpBegin,44,clearVal);
  }

  createVulkanInvoker.InvokeMember("BeginRP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdBeginRenderPass_ptr,vkCommandBuffer,rpBegin,uint(VK_SUBPASS_CONTENTS_INLINE)]);

  // Bind graphics pipeline
  createVulkanInvoker.InvokeMember("BindPipe",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdBindPipeline_ptr,vkCommandBuffer,uint(VK_PIPELINE_BIND_POINT_GRAPHICS),vkGraphicsPipeline]);

  // Set dynamic viewport
  var viewport=Marshal.AllocHGlobal(24);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,viewport,4);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport,4),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowWidth)),0,IntPtr.Add(viewport,8),4);
  Marshal.Copy(BitConverter.GetBytes(float(windowHeight)),0,IntPtr.Add(viewport,12),4);
  Marshal.Copy(BitConverter.GetBytes(float(0)),0,IntPtr.Add(viewport,16),4);
  Marshal.Copy(BitConverter.GetBytes(float(1)),0,IntPtr.Add(viewport,20),4);
  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdSetViewport_ptr,vkCommandBuffer,uint(0),uint(1),viewport]);

  // Set dynamic scissor
  var scissor=Marshal.AllocHGlobal(16);
  Marshal.WriteInt32(scissor,0,0); Marshal.WriteInt32(scissor,4,0);
  Marshal.WriteInt32(scissor,8,int(windowWidth)); Marshal.WriteInt32(scissor,12,int(windowHeight));
  createVulkanInvoker.InvokeMember("SetVP",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdSetScissor_ptr,vkCommandBuffer,uint(0),uint(1),scissor]);

  // Bind descriptor set so the vertex shader can access the SSBOs
  var dsArr=Marshal.AllocHGlobal(8); WriteU64(dsArr,0,vkDescriptorSet);
  createVulkanInvoker.InvokeMember("CmdBindDS",
    BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,
    [vkCmdBindDescriptorSets_ptr,vkCommandBuffer,uint(VK_PIPELINE_BIND_POINT_GRAPHICS),
     vkPipelineLayout,uint(0),uint(1),dsArr,uint(0),IntPtr.Zero]);
  Marshal.FreeHGlobal(dsArr);

  // Draw all harmonograph points (no VBO – vertex shader reads from SSBO by gl_VertexIndex)
  createVulkanInvoker.InvokeMember("Draw",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkCmdDraw_ptr,vkCommandBuffer,uint(NUM_POINTS),uint(1),uint(0),uint(0)]);

  VK_Invoke("Void1",[vkCmdEndRenderPass_ptr,vkCommandBuffer]);
  createVulkanInvoker.InvokeMember("Ret1",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkEndCommandBuffer_ptr,vkCommandBuffer]);

  Marshal.FreeHGlobal(scissor); Marshal.FreeHGlobal(viewport);
  Marshal.FreeHGlobal(rpBegin); Marshal.FreeHGlobal(clearVal); Marshal.FreeHGlobal(beginInfo);
}

function DrawFrame():void{
  var fencePtr=Marshal.AllocHGlobal(8); WriteU64(fencePtr,0,vkInFlightFence);
  createVulkanInvoker.InvokeMember("WaitFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkWaitForFences_ptr,vkDevice,uint(1),fencePtr,uint(1),ulong(0xFFFFFFFFFFFFFFFF)]);
  createVulkanInvoker.InvokeMember("ResetFence",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkResetFences_ptr,vkDevice,uint(1),fencePtr]);

  var imgIdxPtr=Marshal.AllocHGlobal(4); Marshal.WriteInt32(imgIdxPtr,0,0);
  createVulkanInvoker.InvokeMember("Acquire",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkAcquireNextImageKHR_ptr,vkDevice,vkSwapchain,ulong(0xFFFFFFFFFFFFFFFF),vkImageAvailableSemaphore,ulong(0),imgIdxPtr]);
  var imgIdx:uint=uint(Marshal.ReadInt32(imgIdxPtr,0));

  RecordCommandBuffer(imgIdx);

  var waitSem=Marshal.AllocHGlobal(8); WriteU64(waitSem,0,vkImageAvailableSemaphore);
  var sigSem=Marshal.AllocHGlobal(8);  WriteU64(sigSem,0,vkRenderFinishedSemaphore);
  var waitStage=Marshal.AllocHGlobal(4); Marshal.WriteInt32(waitStage,0,VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

  var cbPtr=Marshal.AllocHGlobal(int(IntPtr.Size)); Marshal.WriteIntPtr(cbPtr,0,vkCommandBuffer);

  var submitInfo=Marshal.AllocHGlobal(72); ClearMem(submitInfo,72);
  Marshal.WriteInt32(submitInfo,0,VK_STRUCTURE_TYPE_SUBMIT_INFO);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(submitInfo,16,1); Marshal.WriteIntPtr(submitInfo,24,waitSem); Marshal.WriteIntPtr(submitInfo,32,waitStage);
    Marshal.WriteInt32(submitInfo,40,1); Marshal.WriteIntPtr(submitInfo,48,cbPtr);
    Marshal.WriteInt32(submitInfo,56,1); Marshal.WriteIntPtr(submitInfo,64,sigSem);
  }else{
    Marshal.WriteInt32(submitInfo,8,1); Marshal.WriteIntPtr(submitInfo,12,waitSem); Marshal.WriteIntPtr(submitInfo,16,waitStage);
    Marshal.WriteInt32(submitInfo,20,1); Marshal.WriteIntPtr(submitInfo,24,cbPtr);
    Marshal.WriteInt32(submitInfo,28,1); Marshal.WriteIntPtr(submitInfo,32,sigSem);
  }

  createVulkanInvoker.InvokeMember("Submit",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkQueueSubmit_ptr,vkGraphicsQueue,uint(1),submitInfo,vkInFlightFence]);

  var swPtr=Marshal.AllocHGlobal(8); WriteU64(swPtr,0,vkSwapchain);

  var presentInfo=Marshal.AllocHGlobal(48); ClearMem(presentInfo,48);
  Marshal.WriteInt32(presentInfo,0,VK_STRUCTURE_TYPE_PRESENT_INFO_KHR);
  if(IntPtr.Size==8){
    Marshal.WriteInt32(presentInfo,16,1); Marshal.WriteIntPtr(presentInfo,24,sigSem);
    Marshal.WriteInt32(presentInfo,32,1); Marshal.WriteIntPtr(presentInfo,40,swPtr); Marshal.WriteIntPtr(presentInfo,48-IntPtr.Size,imgIdxPtr);
  }else{
    Marshal.WriteInt32(presentInfo,8,1); Marshal.WriteIntPtr(presentInfo,12,sigSem);
    Marshal.WriteInt32(presentInfo,16,1); Marshal.WriteIntPtr(presentInfo,20,swPtr); Marshal.WriteIntPtr(presentInfo,24,imgIdxPtr);
  }

  createVulkanInvoker.InvokeMember("Present",BindingFlags.Public|BindingFlags.Static|BindingFlags.InvokeMethod,null,null,[vkQueuePresentKHR_ptr,vkGraphicsQueue,presentInfo]);

  Marshal.FreeHGlobal(presentInfo); Marshal.FreeHGlobal(swPtr);
  Marshal.FreeHGlobal(submitInfo); Marshal.FreeHGlobal(cbPtr);
  Marshal.FreeHGlobal(waitStage); Marshal.FreeHGlobal(sigSem); Marshal.FreeHGlobal(waitSem);
  Marshal.FreeHGlobal(imgIdxPtr); Marshal.FreeHGlobal(fencePtr);
}

// Helper to read message ID from MSG struct
function AllocateMsgStruct():IntPtr{
  var sz:int=(IntPtr.Size==8)?48:28;
  var buf=Marshal.AllocHGlobal(int(sz)); ClearMem(buf,sz);
  return buf;
}

function GetMessageID(msg:IntPtr):uint{
  return uint(Marshal.ReadInt32(msg,(IntPtr.Size==8)?8:4));
}

// ============================================================
// Main
// ============================================================
function Main():void{
  DebugLog("=== Vulkan 1.4 Harmonograph Demo ===");

  if(createVulkanInvoker==null){ DebugLog("VulkanInvoker compilation failed"); return; }

  var hInst=GetModuleHandle(null);

  try{
    if(!LoadVulkan()) return;
    if(!CreateVulkanInstance()) return;
    LoadInstanceFunctions();
    if(!SelectPhysicalDevice()) return;
    if(!FindGraphicsQueueFamily()) return;
    if(!CreateLogicalDevice()) return;
    LoadDeviceFunctions();
    GetGraphicsQueue();

    // ---- Descriptor setup (must happen before pipeline layout) ----
    if(!CreateDescriptorSetLayout()) return;
    if(!CreateDescriptorPool()) return;
    if(!AllocateDescriptorSets()) return;
    if(!CreateSSBOBuffers()) return;
    if(!CreateUniformBuffer()) return;
    UpdateDescriptorSets();

    // ---- Compute pipeline (computes the harmonograph into SSBOs) ----
    if(!CreateComputePipelineLayout()) return;
    if(!CreateComputePipeline()) return;

    // ---- Window and swapchain ----
    if(!RegisterWindowClass(hInst)) return;
    var hWnd=CreateWindowEx(0,"harmonograph","Vulkan 1.4 Harmonograph",
      WS_OVERLAPPEDWINDOW|WS_VISIBLE,CW_USEDEFAULT,CW_USEDEFAULT,
      int(windowWidth),int(windowHeight),IntPtr.Zero,IntPtr.Zero,hInst,IntPtr.Zero);
    if(hWnd==IntPtr.Zero){ DebugLog("Failed to create window"); return; }
    ShowWindow(hWnd,SW_SHOW); UpdateWindow(hWnd);

    if(!CreateWin32Surface(hInst,hWnd)){ DestroyWindow(hWnd); return; }
    if(!CreateSwapchain()){ DestroyWindow(hWnd); return; }
    if(!GetSwapchainImages()){ DestroyWindow(hWnd); return; }
    if(!CreateImageViews()){ DestroyWindow(hWnd); return; }
    if(!CreateRenderPass()){ DestroyWindow(hWnd); return; }

    // ---- Graphics pipeline (reads SSBOs, draws points) ----
    if(!CreatePipelineLayout()) return;
    if(!CreateGraphicsPipeline()){ DestroyWindow(hWnd); return; }
    if(!CreateFramebuffers()){ DestroyWindow(hWnd); return; }
    if(!CreateCommandPool()){ DestroyWindow(hWnd); return; }
    if(!AllocateCommandBuffers()){ DestroyWindow(hWnd); return; }
    if(!CreateSyncObjects()){ DestroyWindow(hWnd); return; }

    // ---- Run compute pass once to fill the harmonograph SSBOs ----
    RunComputePass();

    DebugLog("Initialization complete – entering render loop");

    var msg=AllocateMsgStruct();
    var quit=false;

    while(!quit){
      if(PeekMessage(msg,IntPtr.Zero,0,0,PM_REMOVE)){
        if(GetMessageID(msg)==WM_QUIT) quit=true;
        else{ TranslateMessage(msg); DispatchMessage(msg); }
      }else{
        if(!IsWindow(hWnd)) PostQuitMessage(0);
        else{ DrawFrame(); Sleep(16); }
      }
    }

    VK_Invoke("Void1",[vkDeviceWaitIdle_ptr,vkDevice]);
    Marshal.FreeHGlobal(msg);
    DebugLog("=== Harmonograph demo exited cleanly ===");

  }catch(e){
    DebugLog("FATAL: "+e.ToString());
    throw e;
  }
}

Main();
