//  Microsoft (R) .NET Framework IL Disassembler.  Version 4.0.30319.1
//  Copyright (c) Microsoft Corporation. All rights reserved.

// Metadata version: v2.0.50727
.module extern user32.dll
.module extern gdi32.dll
.module extern kernel32.dll
.assembly extern mscorlib
{
  .publickeytoken = (B7 7A 5C 56 19 34 E0 89 )                         // .zV.4..
  .ver 2:0:0:0
}
.assembly Hello
{
  .custom instance void [mscorlib]System.Runtime.CompilerServices.CompilationRelaxationsAttribute::.ctor(int32) = ( 01 00 08 00 00 00 00 00 ) 
  .custom instance void [mscorlib]System.Runtime.CompilerServices.RuntimeCompatibilityAttribute::.ctor() = ( 01 00 01 00 54 02 16 57 72 61 70 4E 6F 6E 45 78   // ....T..WrapNonEx
                                                                                                             63 65 70 74 69 6F 6E 54 68 72 6F 77 73 01 )       // ceptionThrows.
  .hash algorithm 0x00008004
  .ver 0:0:0:0
}
.module Hello.exe
// MVID: {BEAF0F56-F7B6-4F51-B26E-C0D153A452A2}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0002       // WINDOWS_GUI
.corflags 0x00000001    //  ILONLY
// Image base: 0x00410000


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

  .class auto ansi sealed nested private WndProcDelegate
         extends [mscorlib]System.MulticastDelegate
  {
    .method public hidebysig specialname rtspecialname 
            instance void  .ctor(object 'object',
                                 native int 'method') runtime managed
    {
    } // end of method WndProcDelegate::.ctor

    .method public hidebysig newslot virtual 
            instance native int  Invoke(native int hWnd,
                                        uint32 uMsg,
                                        native int wParam,
                                        native int lParam) runtime managed
    {
    } // end of method WndProcDelegate::Invoke

    .method public hidebysig newslot virtual 
            instance class [mscorlib]System.IAsyncResult 
            BeginInvoke(native int hWnd,
                        uint32 uMsg,
                        native int wParam,
                        native int lParam,
                        class [mscorlib]System.AsyncCallback callback,
                        object 'object') runtime managed
    {
    } // end of method WndProcDelegate::BeginInvoke

    .method public hidebysig newslot virtual 
            instance native int  EndInvoke(class [mscorlib]System.IAsyncResult result) runtime managed
    {
    } // end of method WndProcDelegate::EndInvoke

  } // end of class WndProcDelegate

  .class sequential autochar sealed nested private beforefieldinit WNDCLASSEX
         extends [mscorlib]System.ValueType
  {
    .field public uint32 cbSize
    .field public uint32 style
    .field public class Hello/WndProcDelegate lpfnWndProc
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
    // コード サイズ       98 (0x62)
    .maxstack  5
    .locals init (valuetype Hello/PAINTSTRUCT V_0,
             native int V_1,
             string V_2,
             native int V_3,
             uint32 V_4)
    IL_0000:  nop
    IL_0001:  ldloca.s   V_0
    IL_0003:  initobj    Hello/PAINTSTRUCT
    IL_0009:  ldstr      "Hello, Win32 GUI(MSIL) World!"
    IL_000e:  stloc.2
    IL_000f:  ldarg.1
    IL_0010:  stloc.s    V_4
    IL_0012:  ldloc.s    V_4
    IL_0014:  ldc.i4.2
    IL_0015:  beq.s      IL_0043

    IL_0017:  ldloc.s    V_4
    IL_0019:  ldc.i4.s   15
    IL_001b:  beq.s      IL_001f

    IL_001d:  br.s       IL_004c

    IL_001f:  ldarg.0
    IL_0020:  ldloca.s   V_0
    IL_0022:  call       native int Hello::BeginPaint(native int,
                                                      valuetype Hello/PAINTSTRUCT&)
    IL_0027:  stloc.1
    IL_0028:  ldloc.1
    IL_0029:  ldc.i4.0
    IL_002a:  ldc.i4.0
    IL_002b:  ldloc.2
    IL_002c:  ldloc.2
    IL_002d:  callvirt   instance int32 [mscorlib]System.String::get_Length()
    IL_0032:  call       native int Hello::TextOut(native int,
                                                   int32,
                                                   int32,
                                                   string,
                                                   int32)
    IL_0037:  pop
    IL_0038:  ldarg.0
    IL_0039:  ldloca.s   V_0
    IL_003b:  call       native int Hello::EndPaint(native int,
                                                    valuetype Hello/PAINTSTRUCT&)
    IL_0040:  pop
    IL_0041:  br.s       IL_0058

    IL_0043:  ldc.i4.0
    IL_0044:  call       void Hello::PostQuitMessage(int32)
    IL_0049:  nop
    IL_004a:  br.s       IL_0058

    IL_004c:  ldarg.0
    IL_004d:  ldarg.1
    IL_004e:  ldarg.2
    IL_004f:  ldarg.3
    IL_0050:  call       native int Hello::DefWindowProc(native int,
                                                         uint32,
                                                         native int,
                                                         native int)
    IL_0055:  stloc.3
    IL_0056:  br.s       IL_0060

    IL_0058:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_005d:  stloc.3
    IL_005e:  br.s       IL_0060

    IL_0060:  ldloc.3
    IL_0061:  ret
  } // end of method Hello::WndProc

  .method private hidebysig static int32 
          WinMain(string[] args) cil managed
  {
    // コード サイズ       358 (0x166)
    .maxstack  12
    .locals init (native int V_0,
             valuetype Hello/WNDCLASSEX V_1,
             native int V_2,
             valuetype Hello/MSG V_3,
             int32 V_4,
             bool V_5)
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
    IL_0021:  box        Hello/WNDCLASSEX
    IL_0026:  call       int32 [mscorlib]System.Runtime.InteropServices.Marshal::SizeOf(object)
    IL_002b:  stfld      uint32 Hello/WNDCLASSEX::cbSize
    IL_0030:  ldloca.s   V_1
    IL_0032:  ldc.i4.3
    IL_0033:  stfld      uint32 Hello/WNDCLASSEX::style
    IL_0038:  ldloca.s   V_1
    IL_003a:  ldnull
    IL_003b:  ldftn      native int Hello::WndProc(native int,
                                                   uint32,
                                                   native int,
                                                   native int)
    IL_0041:  newobj     instance void Hello/WndProcDelegate::.ctor(object,
                                                                   native int)
    IL_0046:  stfld      class Hello/WndProcDelegate Hello/WNDCLASSEX::lpfnWndProc
    IL_004b:  ldloca.s   V_1
    IL_004d:  ldc.i4.0
    IL_004e:  stfld      int32 Hello/WNDCLASSEX::cbClsExtra
    IL_0053:  ldloca.s   V_1
    IL_0055:  ldc.i4.0
    IL_0056:  stfld      int32 Hello/WNDCLASSEX::cbWndExtra
    IL_005b:  ldloca.s   V_1
    IL_005d:  ldloc.0
    IL_005e:  stfld      native int Hello/WNDCLASSEX::hInstance
    IL_0063:  ldloca.s   V_1
    IL_0065:  ldloc.0
    IL_0066:  ldc.i4     0x7f00
    IL_006b:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int32)
    IL_0070:  call       native int Hello::LoadIcon(native int,
                                                    native int)
    IL_0075:  stfld      native int Hello/WNDCLASSEX::hIcon
    IL_007a:  ldloca.s   V_1
    IL_007c:  ldloc.0
    IL_007d:  ldc.i4     0x7f00
    IL_0082:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int32)
    IL_0087:  call       native int Hello::LoadIcon(native int,
                                                    native int)
    IL_008c:  stfld      native int Hello/WNDCLASSEX::hCursor
    IL_0091:  ldloca.s   V_1
    IL_0093:  ldc.i4.6
    IL_0094:  conv.i8
    IL_0095:  newobj     instance void [mscorlib]System.IntPtr::.ctor(int64)
    IL_009a:  stfld      native int Hello/WNDCLASSEX::hbrBackground
    IL_009f:  ldloca.s   V_1
    IL_00a1:  ldstr      ""
    IL_00a6:  stfld      string Hello/WNDCLASSEX::lpszMenuName
    IL_00ab:  ldloca.s   V_1
    IL_00ad:  ldstr      "helloWindow"
    IL_00b2:  stfld      string Hello/WNDCLASSEX::lpszClassName
    IL_00b7:  ldloca.s   V_1
    IL_00b9:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00be:  stfld      native int Hello/WNDCLASSEX::hIconSm
    IL_00c3:  ldloca.s   V_1
    IL_00c5:  call       int16 Hello::RegisterClassEx(valuetype Hello/WNDCLASSEX&)
    IL_00ca:  pop
    IL_00cb:  ldc.i4.0
    IL_00cc:  ldloca.s   V_1
    IL_00ce:  ldfld      string Hello/WNDCLASSEX::lpszClassName
    IL_00d3:  ldstr      "Hello, World!"
    IL_00d8:  ldc.i4     0xcf0000
    IL_00dd:  ldc.i4     0x80000000
    IL_00e2:  ldc.i4     0x80000000
    IL_00e7:  ldc.i4     0x280
    IL_00ec:  ldc.i4     0x1e0
    IL_00f1:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00f6:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_00fb:  ldloca.s   V_1
    IL_00fd:  ldfld      native int Hello/WNDCLASSEX::hInstance
    IL_0102:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_0107:  call       native int Hello::CreateWindowEx(uint32,
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
    IL_010c:  stloc.2
    IL_010d:  ldloc.2
    IL_010e:  ldc.i4.s   10
    IL_0110:  call       bool Hello::ShowWindow(native int,
                                                uint32)
    IL_0115:  pop
    IL_0116:  ldloc.2
    IL_0117:  call       bool Hello::UpdateWindow(native int)
    IL_011c:  pop
    IL_011d:  ldloca.s   V_3
    IL_011f:  initobj    Hello/MSG
    IL_0125:  br.s       IL_0139

    IL_0127:  nop
    IL_0128:  ldloca.s   V_3
    IL_012a:  call       int32 Hello::TranslateMessage(valuetype Hello/MSG&)
    IL_012f:  pop
    IL_0130:  ldloca.s   V_3
    IL_0132:  call       native int Hello::DispatchMessage(valuetype Hello/MSG&)
    IL_0137:  pop
    IL_0138:  nop
    IL_0139:  ldloca.s   V_3
    IL_013b:  ldsfld     native int [mscorlib]System.IntPtr::Zero
    IL_0140:  ldc.i4.0
    IL_0141:  ldc.i4.0
    IL_0142:  call       int32 Hello::GetMessage(valuetype Hello/MSG&,
                                                 native int,
                                                 uint32,
                                                 uint32)
    IL_0147:  ldc.i4.0
    IL_0148:  ceq
    IL_014a:  ldc.i4.0
    IL_014b:  ceq
    IL_014d:  stloc.s    V_5
    IL_014f:  ldloc.s    V_5
    IL_0151:  brtrue.s   IL_0127

    IL_0153:  ldloca.s   V_3
    IL_0155:  ldfld      native int Hello/MSG::wParam
    IL_015a:  call       int32 [mscorlib]System.IntPtr::op_Explicit(native int)
    IL_015f:  stloc.s    V_4
    IL_0161:  br.s       IL_0163

    IL_0163:  ldloc.s    V_4
    IL_0165:  ret
  } // end of method Hello::WinMain

  .method private hidebysig static int32 
          Main(string[] args) cil managed
  {
    .entrypoint
    .custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = ( 01 00 00 00 ) 
    // コード サイズ       12 (0xc)
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
    // コード サイズ       7 (0x7)
    .maxstack  8
    IL_0000:  ldarg.0
    IL_0001:  call       instance void [mscorlib]System.Object::.ctor()
    IL_0006:  ret
  } // end of method Hello::.ctor

} // end of class Hello
