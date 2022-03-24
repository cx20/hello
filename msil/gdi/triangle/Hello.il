//  Microsoft (R) .NET Framework IL Disassembler.  Version 4.8.4084.0
//  Copyright (c) Microsoft Corporation. All rights reserved.

// Metadata version: v4.0.30319
.module extern user32.dll
.module extern gdi32.dll
.module extern msimg32.dll
.module extern kernel32.dll
.assembly extern mscorlib
{
  .publickeytoken = (B7 7A 5C 56 19 34 E0 89 )                         // .z\V.4..
  .ver 4:0:0:0
}
.assembly Hello
{
  .custom instance void [mscorlib]System.Runtime.CompilerServices.CompilationRelaxationsAttribute::.ctor(int32) = ( 01 00 08 00 00 00 00 00 ) 
  .custom instance void [mscorlib]System.Runtime.CompilerServices.RuntimeCompatibilityAttribute::.ctor() = ( 01 00 01 00 54 02 16 57 72 61 70 4E 6F 6E 45 78   // ....T..WrapNonEx
                                                                                                             63 65 70 74 69 6F 6E 54 68 72 6F 77 73 01 )       // ceptionThrows.

  //  .custom instance void [mscorlib]System.Diagnostics.DebuggableAttribute::.ctor(valuetype [mscorlib]System.Diagnostics.DebuggableAttribute/DebuggingModes) = ( 01 00 07 01 00 00 00 00 ) 

  .permissionset reqmin
             = {[mscorlib]System.Security.Permissions.SecurityPermissionAttribute = {property bool 'SkipVerification' = bool(true)}}
  .hash algorithm 0x00008004
  .ver 0:0:0:0
}
.module Hello.exe
// MVID: {DD79F8A7-9DCB-4999-A913-852B1A386A8F}
.custom instance void [mscorlib]System.Security.UnverifiableCodeAttribute::.ctor() = ( 01 00 00 00 ) 
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0002       // WINDOWS_GUI
.corflags 0x00000001    //  ILONLY
// Image base: 0x0000012C915B0000


// =============== CLASS MEMBERS DECLARATION ===================

.class private auto ansi beforefieldinit Hello
       extends [mscorlib]System.Object
{
  .class sequential ansi sealed nested private beforefieldinit POINT
         extends [mscorlib]System.ValueType
  {
    .field public int32 x
    .field public int32 y
  } // end of class POINT

  .class sequential ansi sealed nested private beforefieldinit MSG
         extends [mscorlib]System.ValueType
  {
    .field public native int hwnd
    .field public uint32 message
    .field public native int wParam
    .field public native int lParam
    .field public uint32 time
    .field public valuetype Hello/POINT pt
  } // end of class MSG

  .class auto ansi sealed nested private WndProcDelgate
         extends [mscorlib]System.MulticastDelegate
  {
    .method public hidebysig specialname rtspecialname 
            instance void  .ctor(object 'object',
                                 native int 'method') runtime managed
    {
    } // end of method WndProcDelgate::.ctor

    .method public hidebysig newslot virtual 
            instance native int  Invoke(native int hWnd,
                                        uint32 uMsg,
                                        native int wParam,
                                        native int lParam) runtime managed
    {
    } // end of method WndProcDelgate::Invoke

    .method public hidebysig newslot virtual 
            instance class [mscorlib]System.IAsyncResult 
            BeginInvoke(native int hWnd,
                        uint32 uMsg,
                        native int wParam,
                        native int lParam,
                        class [mscorlib]System.AsyncCallback callback,
                        object 'object') runtime managed
    {
    } // end of method WndProcDelgate::BeginInvoke

    .method public hidebysig newslot virtual 
            instance native int  EndInvoke(class [mscorlib]System.IAsyncResult result) runtime managed
    {
    } // end of method WndProcDelgate::EndInvoke

  } // end of class WndProcDelgate

  .class sequential autochar sealed nested private beforefieldinit WNDCLASSEX
         extends [mscorlib]System.ValueType
  {
    .field public uint32 cbSize
    .field public uint32 style
    .field public class Hello/WndProcDelgate lpfnWndProc
    .field public int32 cbClsExtra
    .field public int32 cbWndExtra
    .field public native int hInstance
    .field public native int hIcon
    .field public native int hCursor
    .field public native int hbrBackground
    .field public string lpszMenuName
    .field public string lpszClassName
    .field public native int hIconSm
  } // end of class WNDCLASSEX

  .class sequential ansi sealed nested private beforefieldinit RECT
         extends [mscorlib]System.ValueType
  {
    .field public int32 Left
    .field public int32 Top
    .field public int32 Right
    .field public int32 Bottom
  } // end of class RECT

  .class sequential ansi sealed nested private beforefieldinit PAINTSTRUCT
         extends [mscorlib]System.ValueType
  {
    .field public native int hdc
    .field public int32 fErase
    .field public valuetype Hello/RECT rcPaint
    .field public int32 fRestore
    .field public int32 fIncUpdate
    .field public  marshal( fixed array [32]) uint8[] rgbReserved
  } // end of class PAINTSTRUCT

  .class sequential ansi sealed nested private beforefieldinit TRIVERTEX
         extends [mscorlib]System.ValueType
  {
    .field public int32 x
    .field public int32 y
    .field public uint16 Red
    .field public uint16 Green
    .field public uint16 Blue
    .field public uint16 Alpha
  } // end of class TRIVERTEX

  .class sequential ansi sealed nested private beforefieldinit GRADIENT_TRIANGLE
         extends [mscorlib]System.ValueType
  {
    .field public uint32 Vertex1
    .field public uint32 Vertex2
    .field public uint32 Vertex3
  } // end of class GRADIENT_TRIANGLE

  .field private static literal uint32 WS_OVERLAPPED = uint32(0x00000000)
  .field private static literal uint32 WS_POPUP = uint32(0x80000000)
  .field private static literal uint32 WS_CHILD = uint32(0x40000000)
  .field private static literal uint32 WS_MINIMIZE = uint32(0x20000000)
  .field private static literal uint32 WS_VISIBLE = uint32(0x10000000)
  .field private static literal uint32 WS_DISABLED = uint32(0x08000000)
  .field private static literal uint32 WS_CLIPSIBLINGS = uint32(0x04000000)
  .field private static literal uint32 WS_CLIPCHILDREN = uint32(0x02000000)
  .field private static literal uint32 WS_MAXIMIZE = uint32(0x01000000)
  .field private static literal uint32 WS_CAPTION = uint32(0x00C00000)
  .field private static literal uint32 WS_BORDER = uint32(0x00800000)
  .field private static literal uint32 WS_DLGFRAME = uint32(0x00400000)
  .field private static literal uint32 WS_VSCROLL = uint32(0x00200000)
  .field private static literal uint32 WS_HSCROLL = uint32(0x00100000)
  .field private static literal uint32 WS_SYSMENU = uint32(0x00080000)
  .field private static literal uint32 WS_THICKFRAME = uint32(0x00040000)
  .field private static literal uint32 WS_GROUP = uint32(0x00020000)
  .field private static literal uint32 WS_TABSTOP = uint32(0x00010000)
  .field private static literal uint32 WS_MINIMIZEBOX = uint32(0x00020000)
  .field private static literal uint32 WS_MAXIMIZEBOX = uint32(0x00010000)
  .field private static literal uint32 WS_TILED = uint32(0x00000000)
  .field private static literal uint32 WS_ICONIC = uint32(0x20000000)
  .field private static literal uint32 WS_SIZEBOX = uint32(0x00040000)
  .field private static literal uint32 WS_TILEDWINDOW = uint32(0x00CF0000)
  .field private static literal uint32 WS_OVERLAPPEDWINDOW = uint32(0x00CF0000)
  .field private static literal uint32 WS_POPUPWINDOW = uint32(0x80880000)
  .field private static literal uint32 WS_CHILDWINDOW = uint32(0x40000000)
  .field private static literal uint32 WM_CREATE = uint32(0x00000001)
  .field private static literal uint32 WM_DESTROY = uint32(0x00000002)
  .field private static literal uint32 WM_PAINT = uint32(0x0000000F)
  .field private static literal uint32 WM_CLOSE = uint32(0x00000010)
  .field private static literal uint32 WM_COMMAND = uint32(0x00000111)
  .field private static literal uint32 COLOR_WINDOW = uint32(0x00000005)
  .field private static literal uint32 COLOR_BTNFACE = uint32(0x0000000F)
  .field private static literal uint32 CS_VREDRAW = uint32(0x00000001)
  .field private static literal uint32 CS_HREDRAW = uint32(0x00000002)
  .field private static literal int32 CW_USEDEFAULT = int32(0x80000000)
  .field private static literal uint32 SW_SHOWDEFAULT = uint32(0x0000000A)
  .field private static literal int32 IDI_APPLICATION = int32(0x00007F00)
  .field private static literal int32 IDC_ARROW = int32(0x00007F00)
  .field private static literal uint32 GRADIENT_FILL_TRIANGLE = uint32(0x00000002)
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  LoadCursor(native int hInstance,
                                 native int lpCursorName) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  LoadIcon(native int hInstance,
                               native int lpIconName) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          int16  RegisterClassEx(valuetype Hello/WNDCLASSEX& pcWndClassEx) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  CreateWindowEx(uint32 dwExStyle,
                                     string lpClassName,
                                     string lpWindowName,
                                     uint32 dwStyle,
                                     int32 x,
                                     int32 y,
                                     int32 nWidth,
                                     int32 nHeight,
                                     native int hWndParent,
                                     native int hMenu,
                                     native int hInstance,
                                     native int lpParam) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          bool  ShowWindow(native int hWnd,
                           uint32 nCmdShow) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          bool  UpdateWindow(native int hWnd) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          int32  GetMessage([out] valuetype Hello/MSG& lpMsg,
                            native int hWnd,
                            uint32 wMsgFilterMin,
                            uint32 wMsgFilterMax) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          int32  TranslateMessage([in] valuetype Hello/MSG& lpMsg) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  DispatchMessage([in] valuetype Hello/MSG& lpMsg) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          void  PostQuitMessage(int32 nExitCode) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  DefWindowProc(native int hWnd,
                                    uint32 uMsg,
                                    native int wParam,
                                    native int lParam) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  BeginPaint(native int hWnd,
                                 [out] valuetype Hello/PAINTSTRUCT& lpPaint) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
          native int  EndPaint(native int hWnd,
                               valuetype Hello/PAINTSTRUCT& lpPaint) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("gdi32.dll" autochar winapi) 
          native int  TextOut(native int hdc,
                              int32 x,
                              int32 y,
                              string lpString,
                              int32 nCount) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("msimg32.dll" autochar winapi) 
          int32  GradientFill(native int hdc,
                              valuetype Hello/TRIVERTEX[] pVertex,
                              uint32 nVertex,
                              void* pMesh,
                              uint32 nMesh,
                              uint32 ulMode) cil managed preservesig
  {
  }
  .method private hidebysig static pinvokeimpl("kernel32.dll" autochar winapi) 
          native int  GetModuleHandle(string lpModuleName) cil managed preservesig
  {
  }
  .method private hidebysig static native int 
          WndProc(native int hWnd,
                  uint32 uMsg,
                  native int wParam,
                  native int lParam) cil managed
  {
    // Code Size       87 (0x57)
    .maxstack  4
    .locals init (valuetype Hello/PAINTSTRUCT V_0,
             native int V_1,
             uint32 V_2,
             uint32 V_3,
             native int V_4)
    IL_0000:  nop
    IL_0001:  ldloca.s   V_0
    IL_0003:  initobj    Hello/PAINTSTRUCT
    IL_0009:  ldarg.1
    IL_000a:  stloc.3
    IL_000b:  ldloc.3
    IL_000c:  stloc.2
    IL_000d:  ldloc.2
    IL_000e:  ldc.i4.2
    IL_000f:  beq.s      IL_0035

    IL_0011:  br.s       IL_0013

    IL_0013:  ldloc.2
    IL_0014:  ldc.i4.s   15
    IL_0016:  beq.s      IL_001a

    IL_0018:  br.s       IL_003e

    IL_001a:  ldarg.0
    IL_001b:  ldloca.s   V_0
    IL_001d:  call       native int Hello::BeginPaint(native int,
                                                      valuetype Hello/PAINTSTRUCT&)
    IL_0022:  stloc.1
    IL_0023:  ldloc.1
    IL_0024:  call       void Hello::OnPaint(native int)
    IL_0029:  nop
    IL_002a:  ldarg.0
    IL_002b:  ldloca.s   V_0
    IL_002d:  call       native int Hello::EndPaint(native int,
                                                    valuetype Hello/PAINTSTRUCT&)
    IL_0032:  pop
    IL_0033:  br.s       IL_004b

    IL_0035:  ldc.i4.0
    IL_0036:  call       void Hello::PostQuitMessage(int32)
    IL_003b:  nop
    IL_003c:  br.s       IL_004b

    IL_003e:  ldarg.0
    IL_003f:  ldarg.1
    IL_0040:  ldarg.2
    IL_0041:  ldarg.3
    IL_0042:  call       native int Hello::DefWindowProc(native int,
                                                         uint32,
                                                         native int,
                                                         native int)
    IL_0047:  stloc.s    V_4
    IL_0049:  br.s       IL_0054

    IL_004b:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_0050:  stloc.s    V_4
    IL_0052:  br.s       IL_0054

    IL_0054:  ldloc.s    V_4
    IL_0056:  ret
  } // end of method Hello::WndProc

  .method private hidebysig static void  OnPaint(native int hdc) cil managed
  {
    // Code Size       9 (0x9)
    .maxstack  8
    IL_0000:  nop
    IL_0001:  ldarg.0
    IL_0002:  call       void Hello::DrawTriangle(native int)
    IL_0007:  nop
    IL_0008:  ret
  } // end of method Hello::OnPaint

  .method private hidebysig static void  DrawTriangle(native int hdc) cil managed
  {
    // Code Size       323 (0x143)
    .maxstack  6
    .locals init (int32 V_0,
             int32 V_1,
             valuetype Hello/TRIVERTEX[] V_2,
             valuetype Hello/GRADIENT_TRIANGLE V_3)
    IL_0000:  nop
    IL_0001:  ldc.i4     0x280
    IL_0006:  stloc.0
    IL_0007:  ldc.i4     0x1e0
    IL_000c:  stloc.1
    IL_000d:  ldc.i4.3
    IL_000e:  newarr     Hello/TRIVERTEX
    IL_0013:  stloc.2
    IL_0014:  ldloc.2
    IL_0015:  ldc.i4.0
    IL_0016:  ldelema    Hello/TRIVERTEX
    IL_001b:  ldloc.0
    IL_001c:  ldc.i4.2
    IL_001d:  div
    IL_001e:  stfld      int32 Hello/TRIVERTEX::x
    IL_0023:  ldloc.2
    IL_0024:  ldc.i4.0
    IL_0025:  ldelema    Hello/TRIVERTEX
    IL_002a:  ldloc.1
    IL_002b:  ldc.i4.4
    IL_002c:  div
    IL_002d:  stfld      int32 Hello/TRIVERTEX::y
    IL_0032:  ldloc.2
    IL_0033:  ldc.i4.0
    IL_0034:  ldelema    Hello/TRIVERTEX
    IL_0039:  ldc.i4     0xffff
    IL_003e:  stfld      uint16 Hello/TRIVERTEX::Red
    IL_0043:  ldloc.2
    IL_0044:  ldc.i4.0
    IL_0045:  ldelema    Hello/TRIVERTEX
    IL_004a:  ldc.i4.0
    IL_004b:  stfld      uint16 Hello/TRIVERTEX::Green
    IL_0050:  ldloc.2
    IL_0051:  ldc.i4.0
    IL_0052:  ldelema    Hello/TRIVERTEX
    IL_0057:  ldc.i4.0
    IL_0058:  stfld      uint16 Hello/TRIVERTEX::Blue
    IL_005d:  ldloc.2
    IL_005e:  ldc.i4.0
    IL_005f:  ldelema    Hello/TRIVERTEX
    IL_0064:  ldc.i4.0
    IL_0065:  stfld      uint16 Hello/TRIVERTEX::Alpha
    IL_006a:  ldloc.2
    IL_006b:  ldc.i4.1
    IL_006c:  ldelema    Hello/TRIVERTEX
    IL_0071:  ldloc.0
    IL_0072:  ldc.i4.3
    IL_0073:  mul
    IL_0074:  ldc.i4.4
    IL_0075:  div
    IL_0076:  stfld      int32 Hello/TRIVERTEX::x
    IL_007b:  ldloc.2
    IL_007c:  ldc.i4.1
    IL_007d:  ldelema    Hello/TRIVERTEX
    IL_0082:  ldloc.1
    IL_0083:  ldc.i4.3
    IL_0084:  mul
    IL_0085:  ldc.i4.4
    IL_0086:  div
    IL_0087:  stfld      int32 Hello/TRIVERTEX::y
    IL_008c:  ldloc.2
    IL_008d:  ldc.i4.1
    IL_008e:  ldelema    Hello/TRIVERTEX
    IL_0093:  ldc.i4.0
    IL_0094:  stfld      uint16 Hello/TRIVERTEX::Red
    IL_0099:  ldloc.2
    IL_009a:  ldc.i4.1
    IL_009b:  ldelema    Hello/TRIVERTEX
    IL_00a0:  ldc.i4     0xffff
    IL_00a5:  stfld      uint16 Hello/TRIVERTEX::Green
    IL_00aa:  ldloc.2
    IL_00ab:  ldc.i4.1
    IL_00ac:  ldelema    Hello/TRIVERTEX
    IL_00b1:  ldc.i4.0
    IL_00b2:  stfld      uint16 Hello/TRIVERTEX::Blue
    IL_00b7:  ldloc.2
    IL_00b8:  ldc.i4.1
    IL_00b9:  ldelema    Hello/TRIVERTEX
    IL_00be:  ldc.i4.0
    IL_00bf:  stfld      uint16 Hello/TRIVERTEX::Alpha
    IL_00c4:  ldloc.2
    IL_00c5:  ldc.i4.2
    IL_00c6:  ldelema    Hello/TRIVERTEX
    IL_00cb:  ldloc.0
    IL_00cc:  ldc.i4.4
    IL_00cd:  div
    IL_00ce:  stfld      int32 Hello/TRIVERTEX::x
    IL_00d3:  ldloc.2
    IL_00d4:  ldc.i4.2
    IL_00d5:  ldelema    Hello/TRIVERTEX
    IL_00da:  ldloc.1
    IL_00db:  ldc.i4.3
    IL_00dc:  mul
    IL_00dd:  ldc.i4.4
    IL_00de:  div
    IL_00df:  stfld      int32 Hello/TRIVERTEX::y
    IL_00e4:  ldloc.2
    IL_00e5:  ldc.i4.2
    IL_00e6:  ldelema    Hello/TRIVERTEX
    IL_00eb:  ldc.i4.0
    IL_00ec:  stfld      uint16 Hello/TRIVERTEX::Red
    IL_00f1:  ldloc.2
    IL_00f2:  ldc.i4.2
    IL_00f3:  ldelema    Hello/TRIVERTEX
    IL_00f8:  ldc.i4.0
    IL_00f9:  stfld      uint16 Hello/TRIVERTEX::Green
    IL_00fe:  ldloc.2
    IL_00ff:  ldc.i4.2
    IL_0100:  ldelema    Hello/TRIVERTEX
    IL_0105:  ldc.i4     0xffff
    IL_010a:  stfld      uint16 Hello/TRIVERTEX::Blue
    IL_010f:  ldloc.2
    IL_0110:  ldc.i4.2
    IL_0111:  ldelema    Hello/TRIVERTEX
    IL_0116:  ldc.i4.0
    IL_0117:  stfld      uint16 Hello/TRIVERTEX::Alpha
    IL_011c:  ldloca.s   V_3
    IL_011e:  ldc.i4.0
    IL_011f:  stfld      uint32 Hello/GRADIENT_TRIANGLE::Vertex1
    IL_0124:  ldloca.s   V_3
    IL_0126:  ldc.i4.1
    IL_0127:  stfld      uint32 Hello/GRADIENT_TRIANGLE::Vertex2
    IL_012c:  ldloca.s   V_3
    IL_012e:  ldc.i4.2
    IL_012f:  stfld      uint32 Hello/GRADIENT_TRIANGLE::Vertex3
    IL_0134:  ldarg.0
    IL_0135:  ldloc.2
    IL_0136:  ldc.i4.3
    IL_0137:  ldloca.s   V_3
    IL_0139:  conv.u
    IL_013a:  ldc.i4.1
    IL_013b:  ldc.i4.2
    IL_013c:  call       int32 Hello::GradientFill(native int,
                                                   valuetype Hello/TRIVERTEX[],
                                                   uint32,
                                                   void*,
                                                   uint32,
                                                   uint32)
    IL_0141:  pop
    IL_0142:  ret
  } // end of method Hello::DrawTriangle

  .method private hidebysig static int32 
          WinMain(string[] args) cil managed
  {
    // Code Size       347 (0x15b)
    .maxstack  12
    .locals init (native int V_0,
             valuetype Hello/WNDCLASSEX V_1,
             native int V_2,
             valuetype Hello/MSG V_3,
             bool V_4,
             int32 V_5)
    IL_0000:  nop
    IL_0001:  ldtoken    Hello
    IL_0006:  call       class [mscorlib]System.Type [mscorlib]System.Type::GetTypeFromHandle(valuetype [mscorlib]System.RuntimeTypeHandle)
    IL_000b:  callvirt   instance class [mscorlib]System.Reflection.Module [mscorlib]System.Type::get_Module()
    IL_0010:  call       native int [mscorlib]System.Runtime.InteropServices.Marshal::GetHINSTANCE(class [mscorlib]System.Reflection.Module)
    IL_0015:  stloc.0
    IL_0016:  ldloca.s   V_1
    IL_0018:  initobj    Hello/WNDCLASSEX
    IL_001e:  ldloca.s   V_1
    IL_0020:  ldloc.1
    IL_0021:  call       int32 [mscorlib]System.Runtime.InteropServices.Marshal::SizeOf<valuetype Hello/WNDCLASSEX>(!!0)
    IL_0026:  stfld      uint32 Hello/WNDCLASSEX::cbSize
    IL_002b:  ldloca.s   V_1
    IL_002d:  ldc.i4.3
    IL_002e:  stfld      uint32 Hello/WNDCLASSEX::style
    IL_0033:  ldloca.s   V_1
    IL_0035:  ldnull
    IL_0036:  ldftn      native int Hello::WndProc(native int,
                                                   uint32,
                                                   native int,
                                                   native int)
    IL_003c:  newobj     instance void Hello/WndProcDelgate::.ctor(object,
                                                                   native int)
    IL_0041:  stfld      class Hello/WndProcDelgate Hello/WNDCLASSEX::lpfnWndProc
    IL_0046:  ldloca.s   V_1
    IL_0048:  ldc.i4.0
    IL_0049:  stfld      int32 Hello/WNDCLASSEX::cbClsExtra
    IL_004e:  ldloca.s   V_1
    IL_0050:  ldc.i4.0
    IL_0051:  stfld      int32 Hello/WNDCLASSEX::cbWndExtra
    IL_0056:  ldloca.s   V_1
    IL_0058:  ldloc.0
    IL_0059:  stfld      native int Hello/WNDCLASSEX::hInstance
    IL_005e:  ldloca.s   V_1
    IL_0060:  ldloc.0
    IL_0061:  ldc.i4     0x7f00
    IL_0066:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int32)
    IL_006b:  call       native int Hello::LoadIcon(native int,
                                                    native int)
    IL_0070:  stfld      native int Hello/WNDCLASSEX::hIcon
    IL_0075:  ldloca.s   V_1
    IL_0077:  ldloc.0
    IL_0078:  ldc.i4     0x7f00
    IL_007d:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int32)
    IL_0082:  call       native int Hello::LoadIcon(native int,
                                                    native int)
    IL_0087:  stfld      native int Hello/WNDCLASSEX::hCursor
    IL_008c:  ldloca.s   V_1
    IL_008e:  ldc.i4.6
    IL_008f:  conv.i8
    IL_0090:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int64)
    IL_0095:  stfld      native int Hello/WNDCLASSEX::hbrBackground
    IL_009a:  ldloca.s   V_1
    IL_009c:  ldstr      ""
    IL_00a1:  stfld      string Hello/WNDCLASSEX::lpszMenuName
    IL_00a6:  ldloca.s   V_1
    IL_00a8:  ldstr      "helloWindow"
    IL_00ad:  stfld      string Hello/WNDCLASSEX::lpszClassName
    IL_00b2:  ldloca.s   V_1
    IL_00b4:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00b9:  stfld      native int Hello/WNDCLASSEX::hIconSm
    IL_00be:  ldloca.s   V_1
    IL_00c0:  call       int16 Hello::RegisterClassEx(valuetype Hello/WNDCLASSEX&)
    IL_00c5:  pop
    IL_00c6:  ldc.i4.0
    IL_00c7:  ldloc.1
    IL_00c8:  ldfld      string Hello/WNDCLASSEX::lpszClassName
    IL_00cd:  ldstr      "Hello, World!"
    IL_00d2:  ldc.i4     0xcf0000
    IL_00d7:  ldc.i4     0x80000000
    IL_00dc:  ldc.i4     0x80000000
    IL_00e1:  ldc.i4     0x280
    IL_00e6:  ldc.i4     0x1e0
    IL_00eb:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00f0:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00f5:  ldloc.1
    IL_00f6:  ldfld      native int Hello/WNDCLASSEX::hInstance
    IL_00fb:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_0100:  call       native int Hello::CreateWindowEx(uint32,
                                                          string,
                                                          string,
                                                          uint32,
                                                          int32,
                                                          int32,
                                                          int32,
                                                          int32,
                                                          native int,
                                                          native int,
                                                          native int,
                                                          native int)
    IL_0105:  stloc.2
    IL_0106:  ldloc.2
    IL_0107:  ldc.i4.s   10
    IL_0109:  call       bool Hello::ShowWindow(native int,
                                                uint32)
    IL_010e:  pop
    IL_010f:  ldloc.2
    IL_0110:  call       bool Hello::UpdateWindow(native int)
    IL_0115:  pop
    IL_0116:  ldloca.s   V_3
    IL_0118:  initobj    Hello/MSG
    IL_011e:  br.s       IL_0132

    IL_0120:  nop
    IL_0121:  ldloca.s   V_3
    IL_0123:  call       int32 Hello::TranslateMessage(valuetype Hello/MSG&)
    IL_0128:  pop
    IL_0129:  ldloca.s   V_3
    IL_012b:  call       native int Hello::DispatchMessage(valuetype Hello/MSG&)
    IL_0130:  pop
    IL_0131:  nop
    IL_0132:  ldloca.s   V_3
    IL_0134:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_0139:  ldc.i4.0
    IL_013a:  ldc.i4.0
    IL_013b:  call       int32 Hello::GetMessage(valuetype Hello/MSG&,
                                                 native int,
                                                 uint32,
                                                 uint32)
    IL_0140:  ldc.i4.0
    IL_0141:  cgt.un
    IL_0143:  stloc.s    V_4
    IL_0145:  ldloc.s    V_4
    IL_0147:  brtrue.s   IL_0120

    IL_0149:  ldloc.3
    IL_014a:  ldfld      native int Hello/MSG::wParam
    IL_014f:  call       int32 [mscorlib]System.IntPtr::op_Explicit(native int)
    IL_0154:  stloc.s    V_5
    IL_0156:  br.s       IL_0158

    IL_0158:  ldloc.s    V_5
    IL_015a:  ret
  } // end of method Hello::WinMain

  .method private hidebysig static int32 
          Main(string[] args) cil managed
  {
    .entrypoint
    .custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = ( 01 00 00 00 ) 
    // Code Size       12 (0xc)
    .maxstack  1
    .locals init (int32 V_0)
    IL_0000:  nop
    IL_0001:  ldarg.0
    IL_0002:  call       int32 Hello::WinMain(string[])
    IL_0007:  stloc.0
    IL_0008:  br.s       IL_000a

    IL_000a:  ldloc.0
    IL_000b:  ret
  } // end of method Hello::Main

  .method public hidebysig specialname rtspecialname 
          instance void  .ctor() cil managed
  {
    // Code Size       8 (0x8)
    .maxstack  8
    IL_0000:  ldarg.0
    IL_0001:  call       instance void [mscorlib]System.Object::.ctor()
    IL_0006:  nop
    IL_0007:  ret
  } // end of method Hello::.ctor

} // end of class Hello


// =============================================================
