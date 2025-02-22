import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;
import System.Text;
import System.Threading;

// Debug utility
function DebugLog(message:String): void {
  Console.WriteLine("[DEBUG] " + message);
}

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

const GL_TRIANGLES        = 0x0004;
const GL_COLOR_BUFFER_BIT = 0x00004000;
const GL_PROJECTION       = 0x1701;
const GL_MODELVIEW        = 0x1700;

const WHITE_BRUSH         = 0;

// Win32 API function wrappers
function GetModuleHandle(lpModuleName:String): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.String")];
  var parameters:Object[] = [lpModuleName];
  return InvokeWin32("kernel32.dll", Type.GetType("System.IntPtr"), "GetModuleHandleA", paramTypes, parameters);
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

function DefWindowProc(hWnd:IntPtr, Msg:uint, wParam:IntPtr, lParam:IntPtr): IntPtr {
  var paramTypes:Type[] = [
    Type.GetType("System.IntPtr"), Type.GetType("System.UInt32"),
    Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")
  ];
  var parameters:Object[] = [hWnd, Msg, wParam, lParam];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "DefWindowProcA", paramTypes, parameters);
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

function glBegin(mode:uint): void {
  var paramTypes:Type[] = [Type.GetType("System.UInt32")];
  var parameters:Object[] = [mode];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glBegin", paramTypes, parameters);
}

function glEnd(): void {
  var paramTypes:Type[] = [];
  var parameters:Object[] = [];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glEnd", paramTypes, parameters);
}

function glColor3f(red:float, green:float, blue:float): void {
  var paramTypes:Type[] = [
    Type.GetType("System.Single"), Type.GetType("System.Single"),
    Type.GetType("System.Single")
  ];
  var parameters:Object[] = [red, green, blue];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glColor3f", paramTypes, parameters);
}

function glVertex2f(x:float, y:float): void {
  var paramTypes:Type[] = [Type.GetType("System.Single"), Type.GetType("System.Single")];
  var parameters:Object[] = [x, y];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glVertex2f", paramTypes, parameters);
}

function glViewport(x:int, y:int, width:int, height:int): void {
  var paramTypes:Type[] = [
    Type.GetType("System.Int32"), Type.GetType("System.Int32"),
    Type.GetType("System.Int32"), Type.GetType("System.Int32")
  ];
  var parameters:Object[] = [x, y, width, height];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glViewport", paramTypes, parameters);
}

function glMatrixMode(mode:uint): void {
  var paramTypes:Type[] = [Type.GetType("System.UInt32")];
  var parameters:Object[] = [mode];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glMatrixMode", paramTypes, parameters);
}

function glLoadIdentity(): void {
  var paramTypes:Type[] = [];
  var parameters:Object[] = [];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glLoadIdentity", paramTypes, parameters);
}

function glOrtho(left:double, right:double, bottom:double, top:double, zNear:double, zFar:double): void {
  var paramTypes:Type[] = [
    Type.GetType("System.Double"), Type.GetType("System.Double"),
    Type.GetType("System.Double"), Type.GetType("System.Double"),
    Type.GetType("System.Double"), Type.GetType("System.Double")
  ];
  var parameters:Object[] = [left, right, bottom, top, zNear, zFar];
  InvokeWin32("opengl32.dll", Type.GetType("System.Void"), "glOrtho", paramTypes, parameters);
}

// GetStockObject wrapper
function GetStockObject(nIndex:int): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.Int32")];
  var parameters:Object[] = [nIndex];
  return InvokeWin32("gdi32.dll", Type.GetType("System.IntPtr"), "GetStockObject", paramTypes, parameters);
}

// MSG structure allocation
function AllocateMsgStruct(): IntPtr {
  var cbMsg: int = (IntPtr.Size == 8) ? 48 : 28;
  var buffer = Marshal.AllocHGlobal(cbMsg);
  for (var i = 0; i < cbMsg; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  DebugLog("Allocated MSG struct at " + buffer);
  return buffer;
}

function GetMessageIDFromMSG(msgPtr:IntPtr): uint {
  var offset = (IntPtr.Size == 8) ? 8 : 4;
  var msgId = Marshal.ReadInt32(msgPtr, offset);
  DebugLog("Message ID from MSG struct: " + msgId);
  return msgId;
}

// PIXELFORMATDESCRIPTOR allocation
function AllocatePixelFormatDescriptor(): IntPtr {
  var buffer = Marshal.AllocHGlobal(40);
  for (var i = 0; i < 40; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  Marshal.WriteInt16(buffer, 0, 40);
  Marshal.WriteInt16(buffer, 2, 1);
  DebugLog("Allocated PixelFormatDescriptor at " + buffer);
  return buffer;
}

function SetupPixelFormat(pfd:IntPtr): void {
  Marshal.WriteInt32(pfd, 4, PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER);
  Marshal.WriteByte(pfd, 8, PFD_TYPE_RGBA);
  Marshal.WriteByte(pfd, 9, 32);
  Marshal.WriteByte(pfd, 23, 24);
  Marshal.WriteByte(pfd, 26, PFD_MAIN_PLANE);
  DebugLog("Pixel format descriptor set up correctly");
}

// Simple triangle drawing
function DrawTriangle(): void {
  glBegin(GL_TRIANGLES);
  glColor3f(1.0, 0.0, 0.0);
  glVertex2f(0.0, 0.5);
  glColor3f(0.0, 1.0, 0.0);
  glVertex2f(0.5, -0.5);
  glColor3f(0.0, 0.0, 1.0);
  glVertex2f(-0.5, -0.5);
  glEnd();
  DebugLog("Triangle drawn");
}

// OpenGL initialization
function EnableOpenGL(hWnd:IntPtr, hDC:IntPtr): IntPtr {
  DebugLog("Enabling OpenGL");
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

  var hRC = wglCreateContext(hDC);
  if (hRC == IntPtr.Zero) {
    DebugLog("wglCreateContext failed");
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  result = wglMakeCurrent(hDC, hRC);
  if (!result) {
    DebugLog("wglMakeCurrent failed");
    wglDeleteContext(hRC);
    Marshal.FreeHGlobal(pfd);
    return IntPtr.Zero;
  }

  DebugLog("OpenGL context successfully created");
  Marshal.FreeHGlobal(pfd);

  glViewport(0, 0, 640, 480);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(-1, 1, -1, 1, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();

  return hRC;
}

// OpenGL cleanup
function DisableOpenGL(hDC:IntPtr, hRC:IntPtr): void {
  DebugLog("Disabling OpenGL");
  wglMakeCurrent(IntPtr.Zero, IntPtr.Zero);
  wglDeleteContext(hRC);
}

// GetProcAddress definition
function GetProcAddress(hModule: IntPtr, procName: String): IntPtr {
  var paramTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.String")];
  var parameters:Object[] = [hModule, procName];
  return InvokeWin32("kernel32.dll", Type.GetType("System.IntPtr"), "GetProcAddress", paramTypes, parameters);
}

// Window class registration (RegisterClassExA)
function RegisterWindowClass(hInstance: IntPtr): Boolean {
  DebugLog("Registering window class");

  var defWndProcPtr = GetProcAddress(GetModuleHandle("user32.dll"), "DefWindowProcA");
  if (defWndProcPtr == IntPtr.Zero) {
    DebugLog("Failed to get DefWindowProcA address");
  }

  var className = "opengl";
  var classNamePtr = Marshal.StringToHGlobalAnsi(className);
  var hWhiteBrush = GetStockObject(WHITE_BRUSH);
  var cbWndClassEx : int = (IntPtr.Size == 8) ? 80 : 48;
  var wndClassExPtr = Marshal.AllocHGlobal(cbWndClassEx);

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

// Main entry point
function Main(): void {
  DebugLog("Main started");
  var hInstance = GetModuleHandle(null);
  DebugLog("GetModuleHandle() returned " + hInstance);

  if (!RegisterWindowClass(hInstance)) {
    DebugLog("Window class registration failed");
    return;
  }

  var WINDOW_TITLE = "Hello, World!";
  DebugLog("Creating window");
  var hWnd = CreateWindowEx(
    0, "opengl", WINDOW_TITLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE,
    CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
    IntPtr.Zero, IntPtr.Zero, hInstance, IntPtr.Zero
  );

  if (hWnd == IntPtr.Zero) {
    DebugLog("Failed to create window (hWnd is zero)");
    return;
  }
  DebugLog("Window created successfully: " + hWnd);

  ShowWindow(hWnd, SW_SHOW);
  UpdateWindow(hWnd);

  var hDC = GetDC(hWnd);
  DebugLog("GetDC returned " + hDC);
  if (hDC == IntPtr.Zero) {
    DebugLog("Failed to get device context (hDC is zero)");
    return;
  }

  var hRC = EnableOpenGL(hWnd, hDC);
  if (hRC == IntPtr.Zero) {
    DebugLog("Failed to enable OpenGL");
    ReleaseDC(hWnd, hDC);
    DestroyWindow(hWnd);
    return;
  }

  var msgPtr = AllocateMsgStruct();
  var bQuit = false;

  DebugLog("Entering message loop");
  while (!bQuit) {
    if (PeekMessage(msgPtr, hWnd, 0, 0, PM_REMOVE)) {
      var msg = GetMessageIDFromMSG(msgPtr);
      if (msg == WM_QUIT) {
        DebugLog("WM_QUIT received -> exiting loop");
        bQuit = true;
      } else if (msg == WM_DESTROY) {
        DebugLog("WM_DESTROY detected -> PostQuitMessage(0)");
        PostQuitMessage(0);
      } else {
        TranslateMessage(msgPtr);
        DispatchMessage(msgPtr);
      }
    } else {
      glClearColor(0.0, 0.0, 0.2, 1.0);
      glClear(GL_COLOR_BUFFER_BIT);
      DrawTriangle();
      SwapBuffers(hDC);
      Sleep(10);
    }
  }

  DebugLog("Exiting message loop");
  
  // Cleanup
  DisableOpenGL(hDC, hRC);
  DebugLog("Released OpenGL resources");
  ReleaseDC(hWnd, hDC);
  DebugLog("Released DC");
  DestroyWindow(hWnd);
  DebugLog("Destroyed window");
  Marshal.FreeHGlobal(msgPtr);
  DebugLog("Freed MSG struct");

  DebugLog("Main ended normally");
}

Main();
