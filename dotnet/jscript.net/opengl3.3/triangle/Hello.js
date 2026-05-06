import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;
import System.Text;
import System.Threading;
import System.CodeDom.Compiler;
import Microsoft.CSharp;

// Debug utility
function DebugLog(message:String): void {
  Console.WriteLine("[DEBUG] " + message);
}

// Dynamic C# compiler for function pointer invocation
var createOpenGLInvoker = (function() {
    var source = [
        "using System;",
        "using System.Runtime.InteropServices;",
        "public static class OpenGLInvoker {",
        "  // Delegates for OpenGL 3.3 functions",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate uint GLCreateShader(uint shaderType);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLDeleteShader(uint shader);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLShaderSource(uint shader, int count, IntPtr strings, IntPtr lengths);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLCompileShader(uint shader);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLGetShaderiv(uint shader, uint pname, IntPtr parameters);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate uint GLCreateProgram();",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLDeleteProgram(uint program);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLAttachShader(uint program, uint shader);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLLinkProgram(uint program);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLGetProgramiv(uint program, uint pname, IntPtr parameters);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLUseProgram(uint program);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLGenBuffers(int n, IntPtr buffers);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLDeleteBuffers(int n, IntPtr buffers);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLBindBuffer(uint target, uint buffer);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLBufferData(uint target, IntPtr size, IntPtr data, uint usage);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate int GLGetAttribLocation(uint program, IntPtr name);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLEnableVertexAttribArray(uint index);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLVertexAttribPointer(uint index, int size, uint type, bool normalized, int stride, IntPtr pointer);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate void GLDisableVertexAttribArray(uint index);",
        "  [UnmanagedFunctionPointer(CallingConvention.StdCall)]",
        "  public delegate IntPtr WGLCreateContextAttribsARB(IntPtr hDC, IntPtr hShareContext, IntPtr attribList);",
        "",
        "  // Invoke functions",
        "  public static uint InvokeGLCreateShader(IntPtr funcPtr, uint shaderType) {",
        "    var func = (GLCreateShader)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLCreateShader));",
        "    return func(shaderType);",
        "  }",
        "  public static void InvokeGLDeleteShader(IntPtr funcPtr, uint shader) {",
        "    var func = (GLDeleteShader)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLDeleteShader));",
        "    func(shader);",
        "  }",
        "  public static void InvokeGLShaderSource(IntPtr funcPtr, uint shader, int count, IntPtr strings, IntPtr lengths) {",
        "    var func = (GLShaderSource)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLShaderSource));",
        "    func(shader, count, strings, lengths);",
        "  }",
        "  public static void InvokeGLCompileShader(IntPtr funcPtr, uint shader) {",
        "    var func = (GLCompileShader)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLCompileShader));",
        "    func(shader);",
        "  }",
        "  public static void InvokeGLGetShaderiv(IntPtr funcPtr, uint shader, uint pname, IntPtr parameters) {",
        "    var func = (GLGetShaderiv)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLGetShaderiv));",
        "    func(shader, pname, parameters);",
        "  }",
        "  public static uint InvokeGLCreateProgram(IntPtr funcPtr) {",
        "    var func = (GLCreateProgram)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLCreateProgram));",
        "    return func();",
        "  }",
        "  public static void InvokeGLDeleteProgram(IntPtr funcPtr, uint program) {",
        "    var func = (GLDeleteProgram)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLDeleteProgram));",
        "    func(program);",
        "  }",
        "  public static void InvokeGLAttachShader(IntPtr funcPtr, uint program, uint shader) {",
        "    var func = (GLAttachShader)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLAttachShader));",
        "    func(program, shader);",
        "  }",
        "  public static void InvokeGLLinkProgram(IntPtr funcPtr, uint program) {",
        "    var func = (GLLinkProgram)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLLinkProgram));",
        "    func(program);",
        "  }",
        "  public static void InvokeGLGetProgramiv(IntPtr funcPtr, uint program, uint pname, IntPtr parameters) {",
        "    var func = (GLGetProgramiv)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLGetProgramiv));",
        "    func(program, pname, parameters);",
        "  }",
        "  public static void InvokeGLUseProgram(IntPtr funcPtr, uint program) {",
        "    var func = (GLUseProgram)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLUseProgram));",
        "    func(program);",
        "  }",
        "  public static void InvokeGLGenBuffers(IntPtr funcPtr, int n, IntPtr buffers) {",
        "    var func = (GLGenBuffers)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLGenBuffers));",
        "    func(n, buffers);",
        "  }",
        "  public static void InvokeGLDeleteBuffers(IntPtr funcPtr, int n, IntPtr buffers) {",
        "    var func = (GLDeleteBuffers)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLDeleteBuffers));",
        "    func(n, buffers);",
        "  }",
        "  public static void InvokeGLBindBuffer(IntPtr funcPtr, uint target, uint buffer) {",
        "    var func = (GLBindBuffer)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLBindBuffer));",
        "    func(target, buffer);",
        "  }",
        "  public static void InvokeGLBufferData(IntPtr funcPtr, uint target, IntPtr size, IntPtr data, uint usage) {",
        "    var func = (GLBufferData)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLBufferData));",
        "    func(target, size, data, usage);",
        "  }",
        "  public static int InvokeGLGetAttribLocation(IntPtr funcPtr, uint program, IntPtr name) {",
        "    var func = (GLGetAttribLocation)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLGetAttribLocation));",
        "    return func(program, name);",
        "  }",
        "  public static void InvokeGLEnableVertexAttribArray(IntPtr funcPtr, uint index) {",
        "    var func = (GLEnableVertexAttribArray)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLEnableVertexAttribArray));",
        "    func(index);",
        "  }",
        "  public static void InvokeGLVertexAttribPointer(IntPtr funcPtr, uint index, int size, uint type, bool normalized, int stride, IntPtr pointer) {",
        "    var func = (GLVertexAttribPointer)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLVertexAttribPointer));",
        "    func(index, size, type, normalized, stride, pointer);",
        "  }",
        "  public static void InvokeGLDisableVertexAttribArray(IntPtr funcPtr, uint index) {",
        "    var func = (GLDisableVertexAttribArray)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(GLDisableVertexAttribArray));",
        "    func(index);",
        "  }",
        "  public static IntPtr InvokeWGLCreateContextAttribsARB(IntPtr funcPtr, IntPtr hDC, IntPtr hShareContext, IntPtr attribList) {",
        "    var func = (WGLCreateContextAttribsARB)Marshal.GetDelegateForFunctionPointer(funcPtr, typeof(WGLCreateContextAttribsARB));",
        "    return func(hDC, hShareContext, attribList);",
        "  }",
        "}",
    ].join("\n");

    var cp = CodeDomProvider.CreateProvider("CSharp");
    var cps = new CompilerParameters();
    cps.GenerateInMemory = true;
    var cr = cp.CompileAssemblyFromSource(cps, source);

    if (cr.Errors.HasErrors) {
        DebugLog("C# compilation errors:");
        for (var i = 0; i < cr.Errors.Count; i++) {
            DebugLog(cr.Errors[i].ToString());
        }
        return null;
    }

    var asm = cr.CompiledAssembly;
    var invokerType = asm.GetType("OpenGLInvoker");
    return invokerType;
})();

// Dynamic P/Invoke utility function
function InvokeWin32(dllName:String, returnType:Type, methodName:String, parameterTypes:Type[], parameters:Object[]): Object {
  DebugLog("Invoking " + dllName + "!" + methodName);

  var domain = AppDomain.CurrentDomain;
  var name = new AssemblyName("PInvokeAssembly");
  var assembly = domain.DefineDynamicAssembly(name, AssemblyBuilderAccess.Run);
  var module = assembly.DefineDynamicModule("PInvokeModule");
  var type = module.DefineType("PInvokeType", TypeAttributes.Public | TypeAttributes.BeforeFieldInit);

  var attrs = 6 | 128 | 16 | 8192; // Public | HideBySig | Static | PinvokeImpl
  var method = type.DefineMethod(methodName, attrs, returnType, parameterTypes);

  var ctorArgs = new Array(Type.GetType("System.String"));
  var ctor = DllImportAttribute.GetConstructor(ctorArgs);
  var attr = new CustomAttributeBuilder(ctor, new Array(dllName));
  method.SetCustomAttribute(attr);

  var realType = type.CreateType();
  var result = realType.InvokeMember(
    methodName,
    BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
    null,
    null,
    parameters
  );

  DebugLog("Result of " + methodName + " is " + result);
  return result;
}

// Win32 constants
const WS_OVERLAPPED       = 0x00000000;
const WS_CAPTION          = 0x00C00000;
const WS_SYSMENU          = 0x00080000;
const WS_THICKFRAME       = 0x00040000;
const WS_MINIMIZEBOX      = 0x00020000;
const WS_MAXIMIZEBOX      = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE          = 0x10000000;

const CW_USEDEFAULT       = -2147483648;
const SW_SHOW             = 5;

const WM_QUIT             = 0x0012;
const WM_DESTROY          = 0x0002;

const PM_REMOVE           = 0x0001;

const CS_OWNDC            = 0x0020;

const PFD_DRAW_TO_WINDOW  = 0x00000004;
const PFD_SUPPORT_OPENGL  = 0x00000020;
const PFD_DOUBLEBUFFER    = 0x00000001;
const PFD_TYPE_RGBA       = 0;
const PFD_MAIN_PLANE      = 0;

// OpenGL constants
const GL_COLOR_BUFFER_BIT = 0x00004000;
const GL_FLOAT            = 0x1406;
const GL_TRIANGLES        = 0x0004;

// OpenGL 3.3 specific constants
const GL_VERTEX_SHADER    = 0x8B31;
const GL_FRAGMENT_SHADER  = 0x8B30;
const GL_COMPILE_STATUS   = 0x8B81;
const GL_LINK_STATUS      = 0x8B82;
const GL_ARRAY_BUFFER     = 0x8892;
const GL_STATIC_DRAW      = 0x88E4;

const WHITE_BRUSH         = 0;

// Global variables for OpenGL 3.3 function pointers
var glCreateShader_ptr: IntPtr;
var glDeleteShader_ptr: IntPtr;
var glShaderSource_ptr: IntPtr;
var glCompileShader_ptr: IntPtr;
var glGetShaderiv_ptr: IntPtr;
var glCreateProgram_ptr: IntPtr;
var glDeleteProgram_ptr: IntPtr;
var glAttachShader_ptr: IntPtr;
var glLinkProgram_ptr: IntPtr;
var glGetProgramiv_ptr: IntPtr;
var glUseProgram_ptr: IntPtr;
var glGenBuffers_ptr: IntPtr;
var glDeleteBuffers_ptr: IntPtr;
var glBindBuffer_ptr: IntPtr;
var glBufferData_ptr: IntPtr;
var glGetAttribLocation_ptr: IntPtr;
var glEnableVertexAttribArray_ptr: IntPtr;
var glVertexAttribPointer_ptr: IntPtr;
var glDisableVertexAttribArray_ptr: IntPtr;
var wglCreateContextAttribsARB_ptr: IntPtr;

// Win32 API function wrappers
function GetModuleHandle(lpModuleName:String): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.String")];
  var parameters:Object[] = [lpModuleName];
  return InvokeWin32("kernel32.dll", Type.GetType("System.IntPtr"), "GetModuleHandleA", paramTypes, parameters);
}

function GetProcAddress(hModule: IntPtr, procName: String): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.String")];
  var parameters:Object[] = [hModule, procName];
  return InvokeWin32("kernel32.dll", Type.GetType("System.IntPtr"), "GetProcAddress", paramTypes, parameters);
}

function CreateWindowEx(dwExStyle:int, lpClassName:String, lpWindowName:String, dwStyle:int,
                        x:int, y:int, nWidth:int, nHeight:int,
                        hWndParent:IntPtr, hMenu:IntPtr, hInstance:IntPtr, lpParam:IntPtr): IntPtr {
  var paramTypes:Type[] = [
    Type.GetType("System.Int32"), Type.GetType("System.String"), Type.GetType("System.String"),
    Type.GetType("System.Int32"), Type.GetType("System.Int32"), Type.GetType("System.Int32"),
    Type.GetType("System.Int32"), Type.GetType("System.Int32"), Type.GetType("System.IntPtr"),
    Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")
  ];
  var parameters:Object[] = [dwExStyle, lpClassName, lpWindowName, dwStyle, x, y, nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "CreateWindowExA", paramTypes, parameters);
}

function ShowWindow(hWnd:IntPtr, nCmdShow:int): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.Int32")];
  var parameters:Object[] = [hWnd, nCmdShow];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "ShowWindow", paramTypes, parameters);
}

function UpdateWindow(hWnd:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "UpdateWindow", paramTypes, parameters);
}

function GetDC(hWnd:IntPtr): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "GetDC", paramTypes, parameters);
}

function ReleaseDC(hWnd:IntPtr, hDC:IntPtr): int {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd, hDC];
  return InvokeWin32("user32.dll", Type.GetType("System.Int32"), "ReleaseDC", paramTypes, parameters);
}

function DestroyWindow(hWnd:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "DestroyWindow", paramTypes, parameters);
}

function PostQuitMessage(nExitCode:int): void {
  var paramTypes:Type[] = [Type.GetType("System.Int32")];
  var parameters:Object[] = [nExitCode];
  InvokeWin32("user32.dll", Type.GetType("System.Void"), "PostQuitMessage", paramTypes, parameters);
}

function PeekMessage(lpMsg:IntPtr, hWnd:IntPtr, wMsgFilterMin:uint, wMsgFilterMax:uint, wRemoveMsg:uint): Boolean {
  var paramTypes:Type[] = [
    Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"),
    Type.GetType("System.UInt32"), Type.GetType("System.UInt32"),
    Type.GetType("System.UInt32")
  ];
  var parameters:Object[] = [lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "PeekMessageA", paramTypes, parameters);
}

function TranslateMessage(lpMsg:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [lpMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "TranslateMessage", paramTypes, parameters);
}

function DispatchMessage(lpMsg:IntPtr): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [lpMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "DispatchMessageA", paramTypes, parameters);
}

function Sleep(dwMilliseconds:uint): void {
  var paramTypes:Type[] = [Type.GetType("System.UInt32")];
  var parameters:Object[] = [dwMilliseconds];
  InvokeWin32("kernel32.dll", Type.GetType("System.Void"), "Sleep", paramTypes, parameters);
}

// GDI and OpenGL functions
function ChoosePixelFormat(hdc:IntPtr, ppfd:IntPtr): int {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc, ppfd];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Int32"), "ChoosePixelFormat", paramTypes, parameters);
}

function SetPixelFormat(hdc:IntPtr, iPixelFormat:int, ppfd:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.Int32"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc, iPixelFormat, ppfd];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "SetPixelFormat", paramTypes, parameters);
}

function SwapBuffers(hdc:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "SwapBuffers", paramTypes, parameters);
}

function wglCreateContext(hdc:IntPtr): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc];
  return InvokeWin32("opengl32.dll", Type.GetType("System.IntPtr"), "wglCreateContext", paramTypes, parameters);
}

function wglMakeCurrent(hdc:IntPtr, hglrc:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc, hglrc];
  return InvokeWin32("opengl32.dll", Type.GetType("System.Boolean"), "wglMakeCurrent", paramTypes, parameters);
}

function wglDeleteContext(hglrc:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hglrc];
  return InvokeWin32("opengl32.dll", Type.GetType("System.Boolean"), "wglDeleteContext", paramTypes, parameters);
}

function wglGetProcAddress(procName:String): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.String")];
  var parameters:Object[] = [procName];
  return InvokeWin32("opengl32.dll", Type.GetType("System.IntPtr"), "wglGetProcAddress", paramTypes, parameters);
}

function glClearColor(red:float, green:float, blue:float, alpha:float): void {
  var paramTypes:Type[] = [
    Type.GetType("System.Single"), Type.GetType("System.Single"),
    Type.GetType("System.Single"), Type.GetType("System.Single")
  ];
  var parameters:Object[] = [red, green, blue, alpha];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glClearColor", paramTypes, parameters);
}

function glClear(mask:uint): void {
  var paramTypes:Type[] = [Type.GetType("System.UInt32")];
  var parameters:Object[] = [mask];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glClear", paramTypes, parameters);
}

function glViewport(x:int, y:int, width:int, height:int): void {
  var paramTypes:Type[] = [
    Type.GetType("System.Int32"), Type.GetType("System.Int32"),
    Type.GetType("System.Int32"), Type.GetType("System.Int32")
  ];
  var parameters:Object[] = [x, y, width, height];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glViewport", paramTypes, parameters);
}

function glDrawArrays(mode:uint, first:int, count:int): void {
  var paramTypes:Type[] = [
    Type.GetType("System.UInt32"), Type.GetType("System.Int32"),
    Type.GetType("System.Int32")
  ];
  var parameters:Object[] = [mode, first, count];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glDrawArrays", paramTypes, parameters);
}

function GetStockObject(nIndex:int): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.Int32")];
  var parameters:Object[] = [nIndex];
  return InvokeWin32("gdi32.dll", Type.GetType("System.IntPtr"), "GetStockObject", paramTypes, parameters);
}

// wglCreateContextAttribsARB wrapper (via function pointer)
function wglCreateContextAttribsARBInvoke(hDC:IntPtr, hShareContext:IntPtr, attribList:IntPtr): IntPtr {
  try {
    var args = new Object[4];
    args[0] = wglCreateContextAttribsARB_ptr;
    args[1] = hDC;
    args[2] = hShareContext;
    args[3] = attribList;
    var result = createOpenGLInvoker.InvokeMember(
      "InvokeWGLCreateContextAttribsARB",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null,
      null,
      args
    );
    DebugLog("wglCreateContextAttribsARB returned: " + result);
    return IntPtr(result);
  } catch (e) {
    DebugLog("Error in wglCreateContextAttribsARB: " + e.Message);
    return IntPtr.Zero;
  }
}

// Load OpenGL 3.3 extension functions
function LoadOpenGL3Extensions(): Boolean {
  DebugLog("Loading OpenGL 3.3 extensions...");

  if (createOpenGLInvoker == null) {
    DebugLog("Failed to create OpenGL invoker");
    return false;
  }

  try {
    glCreateShader_ptr = wglGetProcAddress("glCreateShader");
    glDeleteShader_ptr = wglGetProcAddress("glDeleteShader");
    glShaderSource_ptr = wglGetProcAddress("glShaderSource");
    glCompileShader_ptr = wglGetProcAddress("glCompileShader");
    glGetShaderiv_ptr = wglGetProcAddress("glGetShaderiv");
    glCreateProgram_ptr = wglGetProcAddress("glCreateProgram");
    glDeleteProgram_ptr = wglGetProcAddress("glDeleteProgram");
    glAttachShader_ptr = wglGetProcAddress("glAttachShader");
    glLinkProgram_ptr = wglGetProcAddress("glLinkProgram");
    glGetProgramiv_ptr = wglGetProcAddress("glGetProgramiv");
    glUseProgram_ptr = wglGetProcAddress("glUseProgram");
    glGenBuffers_ptr = wglGetProcAddress("glGenBuffers");
    glDeleteBuffers_ptr = wglGetProcAddress("glDeleteBuffers");
    glBindBuffer_ptr = wglGetProcAddress("glBindBuffer");
    glBufferData_ptr = wglGetProcAddress("glBufferData");
    glGetAttribLocation_ptr = wglGetProcAddress("glGetAttribLocation");
    glEnableVertexAttribArray_ptr = wglGetProcAddress("glEnableVertexAttribArray");
    glVertexAttribPointer_ptr = wglGetProcAddress("glVertexAttribPointer");
    glDisableVertexAttribArray_ptr = wglGetProcAddress("glDisableVertexAttribArray");

    var functionsLoaded = 0;
    if (glCreateShader_ptr != IntPtr.Zero) functionsLoaded++;
    if (glShaderSource_ptr != IntPtr.Zero) functionsLoaded++;
    if (glCompileShader_ptr != IntPtr.Zero) functionsLoaded++;
    if (glCreateProgram_ptr != IntPtr.Zero) functionsLoaded++;
    if (glGenBuffers_ptr != IntPtr.Zero) functionsLoaded++;

    DebugLog("OpenGL 3.3 extension functions found: " + functionsLoaded + "/19");
    return (functionsLoaded >= 5);

  } catch (e) {
    DebugLog("Exception loading OpenGL 3.3 extensions: " + e.Message);
    return false;
  }
}

// OpenGL 3.3 function wrappers using C# invoker
function glCreateShader(shaderType:uint): uint {
  try {
    var args = new Object[2];
    args[0] = glCreateShader_ptr;
    args[1] = shaderType;
    var result = createOpenGLInvoker.InvokeMember(
      "InvokeGLCreateShader",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
    DebugLog("glCreateShader returned: " + result);
    return uint(result);
  } catch (e) {
    DebugLog("Error in glCreateShader: " + e.Message);
    return 0;
  }
}

function glDeleteShader(shader:uint): void {
  try {
    var args = new Object[2];
    args[0] = glDeleteShader_ptr;
    args[1] = shader;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLDeleteShader",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glDeleteShader: " + e.Message);
  }
}

function glShaderSource(shader:uint, count:int, strings:IntPtr, lengths:IntPtr): void {
  try {
    var args = new Object[5];
    args[0] = glShaderSource_ptr;
    args[1] = shader;
    args[2] = count;
    args[3] = strings;
    args[4] = lengths;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLShaderSource",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glShaderSource: " + e.Message);
  }
}

function glCompileShader(shader:uint): void {
  try {
    var args = new Object[2];
    args[0] = glCompileShader_ptr;
    args[1] = shader;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLCompileShader",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glCompileShader: " + e.Message);
  }
}

function glGetShaderiv(shader:uint, pname:uint, params:IntPtr): void {
  try {
    var args = new Object[4];
    args[0] = glGetShaderiv_ptr;
    args[1] = shader;
    args[2] = pname;
    args[3] = params;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLGetShaderiv",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glGetShaderiv: " + e.Message);
  }
}

function glCreateProgram(): uint {
  try {
    var args = new Object[1];
    args[0] = glCreateProgram_ptr;
    var result = createOpenGLInvoker.InvokeMember(
      "InvokeGLCreateProgram",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
    DebugLog("glCreateProgram returned: " + result);
    return uint(result);
  } catch (e) {
    DebugLog("Error in glCreateProgram: " + e.Message);
    return 0;
  }
}

function glDeleteProgram(program:uint): void {
  try {
    var args = new Object[2];
    args[0] = glDeleteProgram_ptr;
    args[1] = program;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLDeleteProgram",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glDeleteProgram: " + e.Message);
  }
}

function glAttachShader(program:uint, shader:uint): void {
  try {
    var args = new Object[3];
    args[0] = glAttachShader_ptr;
    args[1] = program;
    args[2] = shader;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLAttachShader",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glAttachShader: " + e.Message);
  }
}

function glLinkProgram(program:uint): void {
  try {
    var args = new Object[2];
    args[0] = glLinkProgram_ptr;
    args[1] = program;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLLinkProgram",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glLinkProgram: " + e.Message);
  }
}

function glGetProgramiv(program:uint, pname:uint, params:IntPtr): void {
  try {
    var args = new Object[4];
    args[0] = glGetProgramiv_ptr;
    args[1] = program;
    args[2] = pname;
    args[3] = params;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLGetProgramiv",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glGetProgramiv: " + e.Message);
  }
}

function glUseProgram(program:uint): void {
  try {
    var args = new Object[2];
    args[0] = glUseProgram_ptr;
    args[1] = program;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLUseProgram",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glUseProgram: " + e.Message);
  }
}

function glGenBuffers(n:int, buffers:IntPtr): void {
  try {
    var args = new Object[3];
    args[0] = glGenBuffers_ptr;
    args[1] = n;
    args[2] = buffers;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLGenBuffers",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glGenBuffers: " + e.Message);
  }
}

function glDeleteBuffers(n:int, buffers:IntPtr): void {
  try {
    var args = new Object[3];
    args[0] = glDeleteBuffers_ptr;
    args[1] = n;
    args[2] = buffers;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLDeleteBuffers",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glDeleteBuffers: " + e.Message);
  }
}

function glBindBuffer(target:uint, buffer:uint): void {
  try {
    var args = new Object[3];
    args[0] = glBindBuffer_ptr;
    args[1] = target;
    args[2] = buffer;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLBindBuffer",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glBindBuffer: " + e.Message);
  }
}

function glBufferData(target:uint, size:int, data:IntPtr, usage:uint): void {
  try {
    var args = new Object[5];
    args[0] = glBufferData_ptr;
    args[1] = target;
    args[2] = new IntPtr(size);
    args[3] = data;
    args[4] = usage;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLBufferData",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glBufferData: " + e.Message);
  }
}

function glGetAttribLocation(program:uint, name:String): int {
  try {
    var namePtr = Marshal.StringToHGlobalAnsi(name);
    var args = new Object[3];
    args[0] = glGetAttribLocation_ptr;
    args[1] = program;
    args[2] = namePtr;
    var result = createOpenGLInvoker.InvokeMember(
      "InvokeGLGetAttribLocation",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
    Marshal.FreeHGlobal(namePtr);
    DebugLog("glGetAttribLocation: " + name + " = " + result);
    return int(result);
  } catch (e) {
    DebugLog("Error in glGetAttribLocation: " + e.Message);
    return -1;
  }
}

function glEnableVertexAttribArray(index:uint): void {
  try {
    var args = new Object[2];
    args[0] = glEnableVertexAttribArray_ptr;
    args[1] = index;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLEnableVertexAttribArray",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glEnableVertexAttribArray: " + e.Message);
  }
}

function glVertexAttribPointer(index:uint, size:int, type:uint, normalized:Boolean, stride:int, pointer:IntPtr): void {
  try {
    var args = new Object[7];
    args[0] = glVertexAttribPointer_ptr;
    args[1] = index;
    args[2] = size;
    args[3] = type;
    args[4] = normalized;
    args[5] = stride;
    args[6] = pointer;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLVertexAttribPointer",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glVertexAttribPointer: " + e.Message);
  }
}

function glDisableVertexAttribArray(index:uint): void {
  try {
    var args = new Object[2];
    args[0] = glDisableVertexAttribArray_ptr;
    args[1] = index;
    createOpenGLInvoker.InvokeMember(
      "InvokeGLDisableVertexAttribArray",
      BindingFlags.Public | BindingFlags.Static | BindingFlags.InvokeMethod,
      null, null, args
    );
  } catch (e) {
    DebugLog("Error in glDisableVertexAttribArray: " + e.Message);
  }
}

// Shader compilation helpers
function CreateShaderFromSource(shaderType:uint, source:String): uint {
  DebugLog("Creating shader of type " + shaderType);

  var shader = glCreateShader(shaderType);
  if (shader == 0) {
    DebugLog("Failed to create shader");
    return 0;
  }

  var sourcePtr = Marshal.StringToHGlobalAnsi(source);
  var sourcePtrArray = Marshal.AllocHGlobal(int(IntPtr.Size));
  Marshal.WriteIntPtr(sourcePtrArray, 0, sourcePtr);

  glShaderSource(shader, 1, sourcePtrArray, IntPtr.Zero);
  glCompileShader(shader);

  var statusPtr = Marshal.AllocHGlobal(int(4));
  glGetShaderiv(shader, GL_COMPILE_STATUS, statusPtr);
  var status = Marshal.ReadInt32(statusPtr);

  Marshal.FreeHGlobal(sourcePtr);
  Marshal.FreeHGlobal(sourcePtrArray);
  Marshal.FreeHGlobal(statusPtr);

  if (status == 0) {
    DebugLog("Shader compilation failed");
    glDeleteShader(shader);
    return 0;
  }

  DebugLog("Shader compiled successfully: " + shader);
  return shader;
}

function CreateShaderProgram(): uint {
  DebugLog("Creating shader program");

  var vertexShaderSource =
    "#version 330 core\n" +
    "layout(location = 0) in vec2 position;\n" +
    "layout(location = 1) in vec3 color;\n" +
    "out vec3 fragColor;\n" +
    "void main() {\n" +
    "  gl_Position = vec4(position, 0.0, 1.0);\n" +
    "  fragColor = color;\n" +
    "}\n";

  var fragmentShaderSource =
    "#version 330 core\n" +
    "in vec3 fragColor;\n" +
    "out vec4 outColor;\n" +
    "void main() {\n" +
    "  outColor = vec4(fragColor, 1.0);\n" +
    "}\n";

  var vertexShader = CreateShaderFromSource(GL_VERTEX_SHADER, vertexShaderSource);
  if (vertexShader == 0) {
    DebugLog("Failed to create vertex shader");
    return 0;
  }

  var fragmentShader = CreateShaderFromSource(GL_FRAGMENT_SHADER, fragmentShaderSource);
  if (fragmentShader == 0) {
    DebugLog("Failed to create fragment shader");
    glDeleteShader(vertexShader);
    return 0;
  }

  var program = glCreateProgram();
  if (program == 0) {
    DebugLog("Failed to create program");
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    return 0;
  }

  glAttachShader(program, vertexShader);
  glAttachShader(program, fragmentShader);
  glLinkProgram(program);

  var statusPtr = Marshal.AllocHGlobal(int(4));
  glGetProgramiv(program, GL_LINK_STATUS, statusPtr);
  var status = Marshal.ReadInt32(statusPtr);
  Marshal.FreeHGlobal(statusPtr);

  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  if (status == 0) {
    DebugLog("Program linking failed");
    glDeleteProgram(program);
    return 0;
  }

  DebugLog("Shader program created successfully: " + program);
  return program;
}

// Vertex data and VBO management
function CreateTriangleVBO(): uint {
  DebugLog("Creating triangle VBO");

  var vertices = new float[15]; // 3 vertices * 5 components (x, y, r, g, b)

  // Vertex 0: top center, red
  vertices[0] = 0.0;   // x
  vertices[1] = 0.5;   // y
  vertices[2] = 1.0;   // r
  vertices[3] = 0.0;   // g
  vertices[4] = 0.0;   // b

  // Vertex 1: bottom right, green
  vertices[5] = 0.5;   // x
  vertices[6] = -0.5;  // y
  vertices[7] = 0.0;   // r
  vertices[8] = 1.0;   // g
  vertices[9] = 0.0;   // b

  // Vertex 2: bottom left, blue
  vertices[10] = -0.5; // x
  vertices[11] = -0.5; // y
  vertices[12] = 0.0;  // r
  vertices[13] = 0.0;  // g
  vertices[14] = 1.0;  // b

  var vertexDataSize : int = vertices.length * 4;
  var vertexDataPtr = Marshal.AllocHGlobal(int(vertexDataSize));

  for (var i = 0; i < vertices.length; i++) {
    var floatBytes = BitConverter.GetBytes(vertices[i]);
    for (var j = 0; j < 4; j++) {
      Marshal.WriteByte(vertexDataPtr, i * 4 + j, floatBytes[j]);
    }
  }

  var vboPtr = Marshal.AllocHGlobal(int(4));
  glGenBuffers(1, vboPtr);
  var vbo = Marshal.ReadInt32(vboPtr);
  Marshal.FreeHGlobal(vboPtr);

  if (vbo == 0) {
    DebugLog("Failed to generate VBO");
    Marshal.FreeHGlobal(vertexDataPtr);
    return 0;
  }

  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, vertexDataSize, vertexDataPtr, GL_STATIC_DRAW);

  Marshal.FreeHGlobal(vertexDataPtr);

  DebugLog("Triangle VBO created successfully: " + vbo);
  return vbo;
}

// OpenGL 3.3 triangle rendering
function DrawTriangle(program:uint, vbo:uint): void {
  glUseProgram(program);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);

  var positionLocation = glGetAttribLocation(program, "position");
  var colorLocation = glGetAttribLocation(program, "color");

  if (positionLocation >= 0) {
    glEnableVertexAttribArray(positionLocation);
    glVertexAttribPointer(positionLocation, 2, GL_FLOAT, false, 20, IntPtr.Zero);
  }

  if (colorLocation >= 0) {
    glEnableVertexAttribArray(colorLocation);
    var colorOffset = new IntPtr(8);
    glVertexAttribPointer(colorLocation, 3, GL_FLOAT, false, 20, colorOffset);
  }

  glDrawArrays(GL_TRIANGLES, 0, 3);

  if (positionLocation >= 0) glDisableVertexAttribArray(positionLocation);
  if (colorLocation >= 0) glDisableVertexAttribArray(colorLocation);
}

// MSG structure allocation
function AllocateMsgStruct(): IntPtr {
  var cbMsg: int = (IntPtr.Size == 8) ? 48 : 28;
  var buffer = Marshal.AllocHGlobal(int(cbMsg));
  for (var i = 0; i < cbMsg; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  return buffer;
}

function GetMessageIDFromMSG(msgPtr:IntPtr): uint {
  var offset = (IntPtr.Size == 8) ? 8 : 4;
  return Marshal.ReadInt32(msgPtr, offset);
}

// PIXELFORMATDESCRIPTOR allocation
function AllocatePixelFormatDescriptor(): IntPtr {
  var buffer = Marshal.AllocHGlobal(int(40));
  for (var i = 0; i < 40; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  Marshal.WriteInt16(buffer, 0, 40);
  Marshal.WriteInt16(buffer, 2, 1);
  return buffer;
}

function SetupPixelFormat(pfd:IntPtr): void {
  Marshal.WriteInt32(pfd, 4, PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER);
  Marshal.WriteByte(pfd, 8, PFD_TYPE_RGBA);
  Marshal.WriteByte(pfd, 9, 32);
  Marshal.WriteByte(pfd, 23, 24);
  Marshal.WriteByte(pfd, 26, PFD_MAIN_PLANE);
}

// OpenGL 3.3 context initialization using wglCreateContextAttribsARB
function EnableOpenGL(hWnd:IntPtr, hDC:IntPtr): IntPtr {
  DebugLog("Enabling OpenGL 3.3");
  var pfd = AllocatePixelFormatDescriptor();
  SetupPixelFormat(pfd);

  var iFormat = ChoosePixelFormat(hDC, pfd);
  if (iFormat == 0) {
    DebugLog("ChoosePixelFormat failed");
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  var result = SetPixelFormat(hDC, iFormat, pfd);
  if (!result) {
    DebugLog("SetPixelFormat failed");
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  // Create a temporary legacy context to obtain wglCreateContextAttribsARB
  var hRC_old = wglCreateContext(hDC);
  if (hRC_old == IntPtr.Zero) {
    DebugLog("wglCreateContext (temp) failed");
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  wglMakeCurrent(hDC, hRC_old);

  wglCreateContextAttribsARB_ptr = wglGetProcAddress("wglCreateContextAttribsARB");
  if (wglCreateContextAttribsARB_ptr == IntPtr.Zero) {
    DebugLog("wglCreateContextAttribsARB not available");
    wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
    wglDeleteContext(hRC_old);
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  // Create the OpenGL 3.3 context
  var hRC = wglCreateContextAttribsARBInvoke(hDC, IntPtr.Zero, IntPtr.Zero);
  if (hRC == IntPtr.Zero) {
    DebugLog("wglCreateContextAttribsARB failed");
    wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
    wglDeleteContext(hRC_old);
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  wglMakeCurrent(hDC, hRC);
  wglDeleteContext(hRC_old);

  DebugLog("OpenGL 3.3 context successfully created");
  Marshal.FreeHGlobal(pfd);

  glViewport(0, 0, 640, 480);

  return hRC;
}

// OpenGL cleanup
function DisableOpenGL(hDC:IntPtr, hRC:IntPtr): void {
  wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
  wglDeleteContext(hRC);
}

// Window class registration
function RegisterWindowClass(hInstance: IntPtr): Boolean {
  DebugLog("Registering window class");

  var defWndProcPtr = GetProcAddress(GetModuleHandle("user32.dll"), "DefWindowProcA");
  if (defWndProcPtr == IntPtr.Zero) {
    DebugLog("Failed to get DefWindowProcA address");
    return false;
  }

  var className = "opengl33";
  var classNamePtr = Marshal.StringToHGlobalAnsi(className);
  var hWhiteBrush = GetStockObject(WHITE_BRUSH);
  var cbWndClassEx : int = (IntPtr.Size == 8) ? 80 : 48;
  var wndClassExPtr = Marshal.AllocHGlobal(int(cbWndClassEx));

  for (var i = 0; i < cbWndClassEx; i++) {
    Marshal.WriteByte(wndClassExPtr, i, 0);
  }

  if (IntPtr.Size == 8) {
    Marshal.WriteInt32(wndClassExPtr,   0, cbWndClassEx);
    Marshal.WriteInt32(wndClassExPtr,   4, CS_OWNDC);
    Marshal.WriteIntPtr(wndClassExPtr,  8, defWndProcPtr);
    Marshal.WriteInt32(wndClassExPtr,  16, 0);
    Marshal.WriteInt32(wndClassExPtr,  20, 0);
    Marshal.WriteIntPtr(wndClassExPtr, 24, hInstance);
    Marshal.WriteIntPtr(wndClassExPtr, 32, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 40, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 48, hWhiteBrush);
    Marshal.WriteIntPtr(wndClassExPtr, 56, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 64, classNamePtr);
    Marshal.WriteIntPtr(wndClassExPtr, 72, IntPtr.Zero);
  } else {
    Marshal.WriteInt32(wndClassExPtr,   0, cbWndClassEx);
    Marshal.WriteInt32(wndClassExPtr,   4, CS_OWNDC);
    Marshal.WriteIntPtr(wndClassExPtr,  8, defWndProcPtr);
    Marshal.WriteInt32(wndClassExPtr,  12, 0);
    Marshal.WriteInt32(wndClassExPtr,  16, 0);
    Marshal.WriteIntPtr(wndClassExPtr, 20, hInstance);
    Marshal.WriteIntPtr(wndClassExPtr, 24, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 28, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 32, hWhiteBrush);
    Marshal.WriteIntPtr(wndClassExPtr, 36, IntPtr.Zero);
    Marshal.WriteIntPtr(wndClassExPtr, 40, classNamePtr);
    Marshal.WriteIntPtr(wndClassExPtr, 44, IntPtr.Zero);
  }

  var paramTypesReg:Type[] = [Type.GetType("System.IntPtr")];
  var parametersReg:Object[] = [wndClassExPtr];
  var atom = InvokeWin32("user32.dll", Type.GetType("System.UInt16"), "RegisterClassExA", paramTypesReg, parametersReg);
  DebugLog("RegisterClassExA returned atom: " + atom);

  Marshal.FreeHGlobal(classNamePtr);
  Marshal.FreeHGlobal(wndClassExPtr);

  var success = (atom != 0);
  DebugLog("RegisterWindowClass " + (success ? "succeeded" : "failed"));
  return success;
}

function IsWindow(hWnd:IntPtr): Boolean {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "IsWindow", paramTypes, parameters);
}

// Main entry point
function Main(): void {
  DebugLog("Main started - OpenGL 3.3 Triangle Demo");
  var hInstance = GetModuleHandle(null);

  if (!RegisterWindowClass(hInstance)) {
    DebugLog("Window class registration failed");
    return;
  }

  var WINDOW_TITLE = "Hello, World!";
  var hWnd = CreateWindowEx(
    0, "opengl33", WINDOW_TITLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
    CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
    IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero
  );

  if (hWnd == IntPtr.Zero) {
    DebugLog("Failed to create window");
    return;
  }

  ShowWindow(hWnd, SW_SHOW);
  UpdateWindow(hWnd);

  var hDC = GetDC(hWnd);
  if (hDC == IntPtr.Zero) {
    DebugLog("Failed to get device context");
    return;
  }

  var hRC = EnableOpenGL(hWnd, hDC);
  if (hRC == IntPtr.Zero) {
    DebugLog("Failed to enable OpenGL");
    ReleaseDC(hWnd, hDC);
    DestroyWindow(hWnd);
    return;
  }

  if (!LoadOpenGL3Extensions()) {
    DebugLog("Failed to load OpenGL 3.3 extensions");
    DisableOpenGL(hDC, hRC);
    ReleaseDC(hWnd, hDC);
    DestroyWindow(hWnd);
    return;
  }

  var shaderProgram = CreateShaderProgram();
  if (shaderProgram == 0) {
    DebugLog("Failed to create shader program");
    DisableOpenGL(hDC, hRC);
    ReleaseDC(hWnd, hDC);
    DestroyWindow(hWnd);
    return;
  }

  var triangleVBO = CreateTriangleVBO();
  if (triangleVBO == 0) {
    DebugLog("Failed to create triangle VBO");
    glDeleteProgram(shaderProgram);
    DisableOpenGL(hDC, hRC);
    ReleaseDC(hWnd, hDC);
    DestroyWindow(hWnd);
    return;
  }

  var msgPtr = AllocateMsgStruct();
  var bQuit = false;

  DebugLog("Entering message loop");
  while (!bQuit) {
    if (PeekMessage(msgPtr, IntPtr.Zero, 0, 0, PM_REMOVE)) {
      var msg = GetMessageIDFromMSG(msgPtr);
      if (msg == WM_QUIT) {
        bQuit = true;
      } else {
        TranslateMessage(msgPtr);
        DispatchMessage(msgPtr);
      }
    } else {
      if (!IsWindow(hWnd)) {
        PostQuitMessage(0);
      } else {
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        DrawTriangle(shaderProgram, triangleVBO);
        SwapBuffers(hDC);
        Sleep(16);
      }
    }
  }

  var vboPtr = Marshal.AllocHGlobal(int(4));
  Marshal.WriteInt32(vboPtr, 0, triangleVBO);
  glDeleteBuffers(1, vboPtr);
  Marshal.FreeHGlobal(vboPtr);

  glDeleteProgram(shaderProgram);
  DisableOpenGL(hDC, hRC);
  ReleaseDC(hWnd, hDC);
  DestroyWindow(hWnd);
  Marshal.FreeHGlobal(msgPtr);

  DebugLog("Main ended normally - OpenGL 3.3 Triangle Demo completed");
}

Main();
