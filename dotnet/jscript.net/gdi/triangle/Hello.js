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

// Constants
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

const GRADIENT_FILL_TRIANGLE = 0x00000002;

// Win32 API function wrappers
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

// Additional GDI functions for triangle drawing
function MoveToEx(hdc:IntPtr, x:int, y:int, lpPoint:IntPtr):Boolean {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"),
    Type.GetType("System.IntPtr")
  ];
  var parameters:Object[] = [hdc, x, y, lpPoint];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "MoveToEx", parameterTypes, parameters);
}

function LineTo(hdc:IntPtr, x:int, y:int):Boolean {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32")
  ];
  var parameters:Object[] = [hdc, x, y];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "LineTo", parameterTypes, parameters);
}

function CreatePen(fnPenStyle:int, nWidth:int, crColor:uint):IntPtr {
  var parameterTypes:Type[] = [
    Type.GetType("System.Int32"), 
    Type.GetType("System.Int32"), 
    Type.GetType("System.UInt32")
  ];
  var parameters:Object[] = [fnPenStyle, nWidth, crColor];
  return InvokeWin32("gdi32.dll", Type.GetType("System.IntPtr"), "CreatePen", parameterTypes, parameters);
}

function SelectObject(hdc:IntPtr, hgdiobj:IntPtr):IntPtr {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr"), Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hdc, hgdiobj];
  return InvokeWin32("gdi32.dll", Type.GetType("System.IntPtr"), "SelectObject", parameterTypes, parameters);
}

function DeleteObject(hObject:IntPtr):Boolean {
  var parameterTypes:Type[] = [Type.GetType("System.IntPtr")];
  var parameters:Object[] = [hObject];
  return InvokeWin32("gdi32.dll", Type.GetType("System.Boolean"), "DeleteObject", parameterTypes, parameters);
}

// GradientFill function (experimental)
function GradientFill(hdc:IntPtr, pVertex:IntPtr, nVertex:uint, pMesh:IntPtr, nMesh:uint, ulMode:uint):Boolean {
  var parameterTypes:Type[] = [
    Type.GetType("System.IntPtr"),  // hdc
    Type.GetType("System.IntPtr"),  // pVertex (TRIVERTEX array)
    Type.GetType("System.UInt32"),  // nVertex
    Type.GetType("System.IntPtr"),  // pMesh (GRADIENT_TRIANGLE)
    Type.GetType("System.UInt32"),  // nMesh
    Type.GetType("System.UInt32")   // ulMode
  ];
  var parameters:Object[] = [hdc, pVertex, nVertex, pMesh, nMesh, ulMode];
  return InvokeWin32("msimg32.dll", Type.GetType("System.Boolean"), "GradientFill", parameterTypes, parameters);
}

// Structure allocation helpers
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

// Create TRIVERTEX array in memory (corrected structure size)
function CreateTRIVERTEXArray():IntPtr {
  var arrayBuffer = Marshal.AllocHGlobal(48); // 3 vertices * 16 bytes each (not 20)
  
  var WIDTH = 640;
  var HEIGHT = 480;
  
  // Color values (16-bit color components)
  var COLOR_MAX = short(65535);  // 0xFFFF
  var COLOR_ZERO = short(0);     // 0x0000
  
  // TRIVERTEX structure is 16 bytes:
  // LONG x (4 bytes) + LONG y (4 bytes) + COLOR16 Red (2 bytes) + 
  // COLOR16 Green (2 bytes) + COLOR16 Blue (2 bytes) + COLOR16 Alpha (2 bytes)
  
  // Vertex 0 (top center, red) - offset 0
  Marshal.WriteInt32(arrayBuffer, 0, WIDTH / 2);     // x = 320
  Marshal.WriteInt32(arrayBuffer, 4, HEIGHT / 4);    // y = 120
  Marshal.WriteInt16(arrayBuffer, 8, COLOR_MAX);     // Red
  Marshal.WriteInt16(arrayBuffer, 10, COLOR_ZERO);   // Green
  Marshal.WriteInt16(arrayBuffer, 12, COLOR_ZERO);   // Blue
  Marshal.WriteInt16(arrayBuffer, 14, COLOR_ZERO);   // Alpha
  
  // Vertex 1 (bottom right, green) - offset 16
  Marshal.WriteInt32(arrayBuffer, 16, WIDTH * 3 / 4); // x = 480
  Marshal.WriteInt32(arrayBuffer, 20, HEIGHT * 3 / 4); // y = 360
  Marshal.WriteInt16(arrayBuffer, 24, COLOR_ZERO);    // Red
  Marshal.WriteInt16(arrayBuffer, 26, COLOR_MAX);     // Green
  Marshal.WriteInt16(arrayBuffer, 28, COLOR_ZERO);    // Blue
  Marshal.WriteInt16(arrayBuffer, 30, COLOR_ZERO);    // Alpha
  
  // Vertex 2 (bottom left, blue) - offset 32
  Marshal.WriteInt32(arrayBuffer, 32, WIDTH / 4);     // x = 160
  Marshal.WriteInt32(arrayBuffer, 36, HEIGHT * 3 / 4); // y = 360
  Marshal.WriteInt16(arrayBuffer, 40, COLOR_ZERO);    // Red
  Marshal.WriteInt16(arrayBuffer, 42, COLOR_ZERO);    // Green
  Marshal.WriteInt16(arrayBuffer, 44, COLOR_MAX);     // Blue
  Marshal.WriteInt16(arrayBuffer, 46, COLOR_ZERO);    // Alpha
  
  // Debug output
  Console.WriteLine("TRIVERTEX Array created (corrected structure):");
  Console.WriteLine("Vertex 0 (Red):   (" + (WIDTH / 2) + ", " + (HEIGHT / 4) + ")");
  Console.WriteLine("Vertex 1 (Green): (" + (WIDTH * 3 / 4) + ", " + (HEIGHT * 3 / 4) + ")");
  Console.WriteLine("Vertex 2 (Blue):  (" + (WIDTH / 4) + ", " + (HEIGHT * 3 / 4) + ")");
  
  return arrayBuffer;
}

// GRADIENT_TRIANGLE structure allocation (12 bytes)
function AllocateGRADIENT_TRIANGLE(v1:uint, v2:uint, v3:uint):IntPtr {
  var buffer = Marshal.AllocHGlobal(12);
  Marshal.WriteInt32(buffer, 0, v1);  // Vertex1 (4 bytes)
  Marshal.WriteInt32(buffer, 4, v2);  // Vertex2 (4 bytes)
  Marshal.WriteInt32(buffer, 8, v3);  // Vertex3 (4 bytes)
  return buffer;
}

// Gradient triangle drawing function
function DrawGradientTriangle(hdc:IntPtr) {
  try {
    Console.WriteLine("Attempting to draw gradient triangle...");
    
    // Create TRIVERTEX array
    var vertexArray = CreateTRIVERTEXArray();
    
    // Create GRADIENT_TRIANGLE structure
    var triangleStruct = AllocateGRADIENT_TRIANGLE(0, 1, 2);
    
    // Call GradientFill
    var result = GradientFill(hdc, vertexArray, 3, triangleStruct, 1, GRADIENT_FILL_TRIANGLE);
    
    if (result) {
      Console.WriteLine("Gradient triangle drawn successfully!");
    } else {
      Console.WriteLine("GradientFill failed - falling back to line triangle");
      // Fallback to line triangle
      DrawTriangle(hdc);
    }
    
    // Cleanup
    Marshal.FreeHGlobal(vertexArray);
    Marshal.FreeHGlobal(triangleStruct);
    
  } catch (e) {
    Console.WriteLine("Error in DrawGradientTriangle: " + e.Message);
    // Fallback to line triangle
    DrawTriangle(hdc);
  }
}

// Triangle drawing function (fallback)
function DrawTriangle(hdc:IntPtr) {
  var WIDTH = 640;
  var HEIGHT = 480;
  
  // Calculate triangle points
  var x1 = WIDTH / 2;      // Top vertex
  var y1 = HEIGHT / 4;
  var x2 = WIDTH * 3 / 4;  // Bottom right vertex
  var y2 = HEIGHT * 3 / 4;
  var x3 = WIDTH / 4;      // Bottom left vertex
  var y3 = HEIGHT * 3 / 4;
  
  // Create a colored pen (red color: 0x000000FF in BGR format)
  var hPen = CreatePen(0, 2, 0x000000FF); // PS_SOLID=0, width=2, red color
  var hOldPen = SelectObject(hdc, hPen);
  
  // Draw triangle outline
  MoveToEx(hdc, x1, y1, IntPtr.Zero);  // Move to top vertex
  LineTo(hdc, x2, y2);                 // Line to bottom right
  LineTo(hdc, x3, y3);                 // Line to bottom left
  LineTo(hdc, x1, y1);                 // Line back to top
  
  // Restore old pen and cleanup
  SelectObject(hdc, hOldPen);
  DeleteObject(hPen);
  
  // Add text label
  var text = "Line Triangle (fallback)";
  TextOut(hdc, 10, 30, text, lstrlen(text));
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
      Console.WriteLine("Failed to create window");
      return;
    }
    
    ShowWindow(hWnd, SW_SHOW);
    UpdateWindow(hWnd);
    
    var hdc = GetDC(hWnd);
    
    if (hdc != IntPtr.Zero) {
      var rect = AllocateRect();
      GetClientRect(hWnd, rect);
      
      // Fill background with white
      var hBrush = GetStockObject(WHITE_BRUSH);
      FillRect(hdc, rect, hBrush);
      
      // Try to draw gradient triangle, fallback to line triangle
      DrawGradientTriangle(hdc);
      
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
