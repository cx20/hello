// Hello.js (JScript.NET)
// OpenGL 4.6 + D3D11 + Vulkan 1.4 via Windows.UI.Composition (WinRT desktop interop)
// Compile: jsc /target:winexe Hello.js
//
// Strategy:
// JScript.NET cannot express modern unsafe interop comfortably, so this file
// compiles and runs the C# WinRT composition sample at runtime.

import System;
import System.CodeDom.Compiler;
import Microsoft.CSharp;
import System.IO;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;

try {
  File.AppendAllText("Hello.bootstrap.log",
    "loaded " + DateTime.Now.ToString("HH:mm:ss.fff") + "\r\n");
} catch (ignoredBoot) {}

var gLogFile:String = null;
var gFallbackLog:String = null;

function SafeAppend(path:String, line:String):void {
  try {
    if (path != null && path.Length > 0) {
      File.AppendAllText(path, line + "\r\n");
    }
  } catch (ignored) {}
}

function NowText():String {
  return DateTime.Now.ToString("HH:mm:ss.fff");
}

// Writes logs to DebugView and also mirrors them to a local text file.
function Dbg(msg:String):void {
  var pidText = "0";
  try {
    pidText = System.Diagnostics.Process.GetCurrentProcess().Id.ToString();
  } catch (ignoredPid) {}

  var timeText = "";
  try {
    timeText = NowText();
  } catch (ignoredTime) {}

  var line = "[JSNet.WinRT.Comp][" + pidText + "] " + timeText + " " + msg;
  SafeAppend(gFallbackLog, line);
  SafeAppend(gLogFile, line);
  try {
    var domain = AppDomain.CurrentDomain;
    var aname  = new AssemblyName("_DbgAsm");
    var asmB   = domain.DefineDynamicAssembly(aname, AssemblyBuilderAccess.Run);
    var modB   = asmB.DefineDynamicModule("_DbgMod");
    var typeB  = modB.DefineType("_DbgType",
                   TypeAttributes.Public | TypeAttributes.BeforeFieldInit);
    var methB  = typeB.DefineMethod("OutputDebugStringA",
                   MethodAttributes.Public | MethodAttributes.HideBySig |
                   MethodAttributes.Static | MethodAttributes.PinvokeImpl,
                   Type.GetType("System.Void"),
                   [Type.GetType("System.String")]);
    var ctor   = DllImportAttribute.GetConstructor([Type.GetType("System.String")]);
    methB.SetCustomAttribute(new CustomAttributeBuilder(ctor, ["kernel32.dll"]));
    typeB.CreateType().InvokeMember("OutputDebugStringA",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, [line]);
  } catch(ignoredDbg) {}
}

function FindCSharpSource():String {
  // We run from this sample directory in normal usage.
  var candidate = "..\\..\\..\\..\\csharp\\winrt\\composition\\triangle_multi\\Hello.cs";
  Dbg("FindCSharpSource: candidate=" + candidate + " exists=" + File.Exists(candidate));
  if (File.Exists(candidate)) return candidate;

  // Fallback: absolute path when current directory changed.
  var root = "C:\\github\\hello\\dotnet\\csharp\\winrt\\composition\\triangle_multi\\Hello.cs";
  Dbg("FindCSharpSource: fallback=" + root + " exists=" + File.Exists(root));
  if (File.Exists(root)) return root;

  throw new Exception("C# source not found: " + candidate + " / " + root);
}

// Rewrites a few C# 7 "out variable declaration" forms into
// C# 5-compatible syntax for legacy CodeDom compilers.
function RewriteForLegacyCSharp(source:String):String {
  var patched = source;

  patched = patched.Replace(
    "BeginPaint(hWnd, out PAINTSTRUCT ps);",
    "PAINTSTRUCT ps; BeginPaint(hWnd, out ps);"
  );
  patched = patched.Replace(
    "hr = WindowsCreateString(className, (uint)className.Length, out IntPtr hstr);",
    "IntPtr hstr; hr = WindowsCreateString(className, (uint)className.Length, out hstr);"
  );
  patched = patched.Replace(
    "int hr = ((CreateTexture2DDelegate)VT(device, 5, typeof(CreateTexture2DDelegate)))(device, ref desc, IntPtr.Zero, out IntPtr tex);",
    "IntPtr tex; int hr = ((CreateTexture2DDelegate)VT(device, 5, typeof(CreateTexture2DDelegate)))(device, ref desc, IntPtr.Zero, out tex);"
  );
  patched = patched.Replace(
    "int hr = ((MapDelegate)VT(ctx, 14, typeof(MapDelegate)))(ctx, resource, 0, D3D11_MAP_WRITE, 0, out D3D11_MAPPED_SUBRESOURCE map);",
    "D3D11_MAPPED_SUBRESOURCE map; int hr = ((MapDelegate)VT(ctx, 14, typeof(MapDelegate)))(ctx, resource, 0, D3D11_MAP_WRITE, 0, out map);"
  );
  patched = patched.Replace(
    "vkGetPhysicalDeviceMemoryProperties(g_vkPhysicalDevice, out var memProps);",
    "VkPhysMemProps memProps; vkGetPhysicalDeviceMemoryProperties(g_vkPhysicalDevice, out memProps);"
  );
  patched = patched.Replace(
    "vkGetImageMemoryRequirements(g_vkDevice, g_vkImage, out var ir);",
    "VkMemReq ir; vkGetImageMemoryRequirements(g_vkDevice, g_vkImage, out ir);"
  );
  patched = patched.Replace(
    "vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuffer, out var br);",
    "VkMemReq br; vkGetBufferMemoryRequirements(g_vkDevice, g_vkReadbackBuffer, out br);"
  );
  patched = patched.Replace(
    "vkMapMemory(g_vkDevice, g_vkReadbackMemory, 0, (ulong)(WIDTH * HEIGHT * 4), 0, out IntPtr src);",
    "IntPtr src; vkMapMemory(g_vkDevice, g_vkReadbackMemory, 0, (ulong)(WIDTH * HEIGHT * 4), 0, out src);"
  );

  return patched;
}

function CompileAndRun():int {
  Dbg("CompileAndRun: start");

  // Keep shader file lookup stable for the delegated C# sample.
  var exePath = Assembly.GetExecutingAssembly().Location;
  var sampleDir = Path.GetDirectoryName(exePath);
  if (sampleDir != null && sampleDir.Length > 0) {
    Environment.CurrentDirectory = sampleDir;
    Dbg("CurrentDirectory set to: " + sampleDir);
  }
  Dbg("hello.vert exists=" + File.Exists("hello.vert"));
  Dbg("hello.frag exists=" + File.Exists("hello.frag"));

  var csPath = FindCSharpSource();
  Dbg("Using C# source: " + csPath);

  var source = File.ReadAllText(csPath);
  Dbg("C# source length=" + source.Length);
  source = RewriteForLegacyCSharp(source);
  Dbg("C# source patched length=" + source.Length);
  var provider = new CSharpCodeProvider();
  var cp = new CompilerParameters();
  cp.GenerateInMemory = true;
  cp.GenerateExecutable = false;
  cp.CompilerOptions = "/unsafe";
  cp.ReferencedAssemblies.Add("System.dll");
  cp.ReferencedAssemblies.Add("System.Core.dll");
  Dbg("C# compile: begin");

  var result = provider.CompileAssemblyFromSource(cp, source);
  Dbg("C# compile: done");
  if (result.Errors != null && result.Errors.Count > 0) {
    Dbg("C# compile diagnostics count=" + result.Errors.Count);
    for (var d = 0; d < result.Errors.Count; d++) {
      Dbg("C# diag[" + d + "] " + result.Errors[d].ToString());
    }
  }
  if (result.Errors.HasErrors) {
    Dbg("C# compile failed: " + result.Errors.Count + " errors");
    var text = "C# compile failed:\n";
    for (var i = 0; i < result.Errors.Count; i++) {
      text += result.Errors[i].ToString() + "\n";
    }
    throw new Exception(text);
  }

  Dbg("C# compile succeeded");
  var asm = result.CompiledAssembly;
  Dbg("Compiled assembly full name: " + asm.FullName);
  var helloType = asm.GetType("Hello");
  if (helloType == null) throw new Exception("Type 'Hello' not found in compiled assembly.");
  Dbg("Type resolved: " + helloType.FullName);

  var main = helloType.GetMethod(
    "Main",
    BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic
  );
  if (main == null) throw new Exception("Hello.Main not found.");
  Dbg("Method resolved: " + main.ToString());

  Dbg("Invoking Hello.Main");
  // C# sample signature: static unsafe int Main(string[] args)
  var retObj = null;
  try {
    retObj = main.Invoke(null, [new String[0]]);
  } catch (tie : TargetInvocationException) {
    Dbg("TargetInvocationException: " + tie.ToString());
    if (tie.InnerException != null) {
      Dbg("InnerException: " + tie.InnerException.ToString());
    }
    throw;
  }
  var exitCode = 0;
  if (retObj != null) {
    exitCode = Convert.ToInt32(retObj);
  }
  Dbg("Hello.Main returned exitCode=" + exitCode);
  return exitCode;
}

var gExitCode : int = 0;

function Main():int {
  try {
    var exePath = Assembly.GetExecutingAssembly().Location;
    var sampleDir = Path.GetDirectoryName(exePath);
    gFallbackLog = Path.Combine(Path.GetTempPath(), "jsnet_winrt_composition_triangle_multi.log");
    SafeAppend(gFallbackLog, "==== process start ====");
    if (sampleDir != null && sampleDir.Length > 0) {
      gLogFile = Path.Combine(sampleDir, "Hello.debug.log");
    } else {
      gLogFile = "Hello.debug.log";
    }
    Dbg("Main: start");
    Dbg("Assembly location: " + exePath);
    Dbg("CurrentDirectory(initial): " + Environment.CurrentDirectory);

    gExitCode = CompileAndRun();
    Environment.ExitCode = gExitCode;
    Dbg("Main: end exitCode=" + gExitCode);
    return gExitCode;
  } catch (ex : Exception) {
    SafeAppend(gFallbackLog, "Main catch: " + ex.ToString());
    Dbg("Main: unhandled exception: " + ex.ToString());
    Environment.ExitCode = -1;
    return -1;
  }
}

Main();
