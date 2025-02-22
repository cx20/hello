import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime.InteropServices;
import System.Text;
import System.Threading;

// Invoke a Win32 P/Invoke call.
function InvokeWin32(dllName:String, returnType:Type,
  methodName:String, parameterTypes:Type[], parameters:Object[])
{
  var domain = AppDomain.CurrentDomain;
  var name = new System.Reflection.AssemblyName('PInvokeAssembly');
  var assembly = domain.DefineDynamicAssembly(name, AssemblyBuilderAccess.Run);
  var module = assembly.DefineDynamicModule('PInvokeModule');
  var type = module.DefineType('PInvokeType',TypeAttributes.Public + TypeAttributes.BeforeFieldInit);
  
  var method = type.DefineMethod(methodName, MethodAttributes.Public + MethodAttributes.HideBySig + 
               MethodAttributes.Static + MethodAttributes.PinvokeImpl, returnType, parameterTypes);
  
  var ctor = System.Runtime.InteropServices.DllImportAttribute.GetConstructor([Type.GetType("System.String")]);
  var attr = new System.Reflection.Emit.CustomAttributeBuilder(ctor, [dllName]);
  method.SetCustomAttribute(attr);
  
  var realType = type.CreateType();
  return realType.InvokeMember(methodName, BindingFlags.Public + BindingFlags.Static + 
         BindingFlags.InvokeMethod, null, null, parameters);
}

const WS_OVERLAPPED  = 0x00000000;
const WS_CAPTION     = 0x00C00000;
const WS_SYSMENU     = 0x00080000;
const WS_THICKFRAME  = 0x00040000;
const WS_MINIMIZEBOX = 0x00020000;
const WS_MAXIMIZEBOX = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE     = 0x10000000;
const WS_CHILD       = 0x40000000;

const CW_USEDEFAULT  = -2147483648;
const SW_SHOW        = 5;

const WM_PAINT       = 0x000F;
const WM_CLOSE       = 0x0010;
const WM_DESTROY     = 0x0002;

const SRCCOPY        = 0x00CC0020;
const WHITE_BRUSH    = 0;
const BLACK_BRUSH    = 4;

function GetModuleHandle(lpModuleName:String):IntPtr {
  var parameterTypes:Type[] = [Type.GetType("System.String")];
  var parameters:Object[] = [lpModuleName];
  return InvokeWin32("kernel32.dll", Type.GetType("System.IntPtr"), "GetModuleHandleA", parameterTypes, parameters);
}

function CreateWindowEx(dwExStyle:int, lpClassName:String, lpWindowName:String, 
                       dwStyle:int, x:int, y:int, nWidth:int, nHeight:int,
                       hWndParent:IntPtr, hMenu:IntPtr, hInstance:IntPtr, lpParam:IntPtr):IntPtr {
  var parameterTypes:Type[] = [
    Type.GetType("System.Int32"), 
    Type.GetType("System.String"), 
    Type.GetType("System.String"),
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"),
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.IntPtr"),
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.IntPtr")
  ];
  var parameters:Object[] = [
    dwExStyle, lpClassName, lpWindowName, dwStyle, x, y, nWidth, nHeight,
    hWndParent, hMenu, hInstance, lpParam
  ];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "CreateWindowExA", parameterTypes, parameters);
}

function ShowWindow(hWnd:IntPtr, nCmdShow:int):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.Int32")];
  var parameters:Object[] = [hWnd, nCmdShow];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "ShowWindow", parameterTypes, parameters);
}

function UpdateWindow(hWnd:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "UpdateWindow", parameterTypes, parameters);
}

function IsWindow(hWnd:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "IsWindow", parameterTypes, parameters);
}

function DestroyWindow(hWnd:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "DestroyWindow", parameterTypes, parameters);
}

function PostQuitMessage(nExitCode:int):void {
  var parameterTypes:Type[] = [Type.GetType("System.Int32")];
  var parameters:Object[] = [nExitCode];
  InvokeWin32("user32.dll", Type.GetType("System.Void"), "PostQuitMessage", parameterTypes, parameters);
}

function InvalidateRect(hWnd:IntPtr, lpRect:IntPtr, bErase:Boolean):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"), Type.GetType("System.Boolean")];
  var parameters:Object[] = [hWnd, lpRect, bErase];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "InvalidateRect", parameterTypes, parameters);
}

function GetDC(hWnd:IntPtr):IntPtr {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "GetDC", parameterTypes, parameters);
}

function ReleaseDC(hWnd:IntPtr, hDC:IntPtr):int {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd, hDC];
  return InvokeWin32("user32.dll", Type.GetType("System.Int32"), "ReleaseDC", parameterTypes, parameters);
}

function GetClientRect(hWnd:IntPtr, lpRect:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hWnd, lpRect];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "GetClientRect", parameterTypes, parameters);
}

function FillRect(hdc:IntPtr, lprc:IntPtr, hbr:IntPtr):int {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc, lprc, hbr];
  return InvokeWin32("user32.dll", Type.GetType("System.Int32"), "FillRect", parameterTypes, parameters);
}

function GetStockObject(fnObject:int):IntPtr {
  var parameterTypes:Type[] = [Type.GetType("System.Int32")];
  var parameters:Object[] = [fnObject];
  return InvokeWin32("gdi32.dll", Type.GetType("System.IntPtr"), "GetStockObject", parameterTypes, parameters);
}

function TextOut(hdc:IntPtr, x:int, y:int, lpString:String, c:int):Boolean {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"),
    Type.GetType("System.String"), 
    Type.GetType("System.Int32")
  ];
  var parameters:Object[] = [hdc, x, y, lpString, c];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "TextOutA", parameterTypes, parameters);
}

function lstrlen(lpString:String):int {
  var parameterTypes:Type[] = [Type.GetType("System.String")];
  var parameters:Object[] = [lpString];
  return InvokeWin32("kernel32.dll", Type.GetType("System.Int32"), "lstrlenA", parameterTypes, parameters);
}

function PeekMessage(lpMsg:IntPtr, hWnd:IntPtr, wMsgFilterMin:uint, wMsgFilterMax:uint, wRemoveMsg:uint):Boolean {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.UInt32"),
    Type.GetType("System.UInt32"), 
    Type.GetType("System.UInt32")
  ];
  var parameters:Object[] = [lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "PeekMessageA", parameterTypes, parameters);
}

function GetMessage(lpMsg:IntPtr, hWnd:IntPtr, wMsgFilterMin:uint, wMsgFilterMax:uint):int {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.IntPtr"),
    Type.GetType("System.UInt32"), 
    Type.GetType("System.UInt32")
  ];
  var parameters:Object[] = [lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax];
  return InvokeWin32("user32.dll", Type.GetType("System.Int32"), "GetMessageA", parameterTypes, parameters);
}

function TranslateMessage(lpMsg:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [lpMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.Boolean"), "TranslateMessage", parameterTypes, parameters);
}

function DispatchMessage(lpMsg:IntPtr):IntPtr {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [lpMsg];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "DispatchMessageA", parameterTypes, parameters);
}

function SendMessage(hWnd:IntPtr, Msg:uint, wParam:IntPtr, lParam:IntPtr):IntPtr {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.UInt32"),
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.IntPtr")
  ];
  var parameters:Object[] = [hWnd, Msg, wParam, lParam];
  return InvokeWin32("user32.dll", Type.GetType("System.IntPtr"), "SendMessageA", parameterTypes, parameters);
}

function GetMessageFromMSG(msgPtr:IntPtr):uint {
  return Marshal.ReadInt32(msgPtr, 4);
}

function AllocateRect():IntPtr {
  var buffer = Marshal.AllocHGlobal(16); // Size of the RECT structure
  // Initialize with 0
  for (var i = 0; i < 16; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  return buffer;
}

function AllocateMsgStruct():IntPtr {
  var buffer = Marshal.AllocHGlobal(28); // Size of the MSG structure
  // Initialize with 0
  for (var i = 0; i < 28; i++) {
    Marshal.WriteByte(buffer, i, 0);
  }
  return buffer;
}

function Main() {
  try {
    var hInstance = GetModuleHandle(null);
    var WINDOW_TITLE = "Hello, World!";
    
    var hWnd = CreateWindowEx(
      0,
      "STATIC",
      WINDOW_TITLE,
      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      CW_USEDEFAULT, CW_USEDEFAULT,
      640,
      480,
      IntPtr.Zero,
      IntPtr.Zero,
      hInstance,
      IntPtr.Zero
    );
    
    if (hWnd == IntPtr.Zero) {
      return;
    }
    
    ShowWindow(hWnd, SW_SHOW);
    UpdateWindow(hWnd);
    
    var hdc = GetDC(hWnd);
    
    if (hdc != IntPtr.Zero) {
      var rect = AllocateRect();
      GetClientRect(hWnd, rect);
      
      var hBrush = GetStockObject(WHITE_BRUSH);
      FillRect(hdc, rect, hBrush);
      
      var text = "Hello, Win32 GUI(JScript.NET) World!";
      TextOut(hdc, 0, 0, text, lstrlen(text));
      
      ReleaseDC(hWnd, hdc);
      Marshal.FreeHGlobal(rect);
    }
    
    var msgPtr = AllocateMsgStruct();
    
    while (GetMessage(msgPtr, IntPtr.Zero, 0, 0) > 0) {
      TranslateMessage(msgPtr);
      DispatchMessage(msgPtr);
      
      if (!IsWindow(hWnd)) {
        break;
      }
    }
    
    Marshal.FreeHGlobal(msgPtr);
    
  } catch (e) {
    Console.WriteLine(e.Message);
    Console.WriteLine(e.StackTrace);
  }
}

Main();
