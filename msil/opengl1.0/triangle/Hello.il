.assembly Hello
{
	.custom instance void [mscorlib]System.Runtime.CompilerServices.CompilationRelaxationsAttribute::.ctor(int32) = (
		01 00 08 00 00 00 00 00
	)
	.custom instance void [mscorlib]System.Runtime.CompilerServices.RuntimeCompatibilityAttribute::.ctor() = (
		01 00 01 00 54 02 16 57 72 61 70 4e 6f 6e 45 78
		63 65 70 74 69 6f 6e 54 68 72 6f 77 73 01
	)
	.custom instance void [mscorlib]System.Diagnostics.DebuggableAttribute::.ctor(valuetype [mscorlib]System.Diagnostics.DebuggableAttribute/DebuggingModes) = (
		01 00 07 01 00 00 00 00
	)
	.hash algorithm 0x00008004 // SHA1
	.ver 0:0:0:0
}

.module Hello.exe
// MVID: {733AFF0D-CA3D-4172-A307-B43169890740}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0002 // WindowsGui
.corflags 0x00000001 // ILOnly

.class private auto ansi beforefieldinit HelloForm
	extends [System.Windows.Forms]System.Windows.Forms.Form
{
	// Nested Types
	.class nested public sequential ansi sealed beforefieldinit PIXELFORMATDESCRIPTOR
		extends [mscorlib]System.ValueType
	{
		// Fields
		.field public uint16 nSize
		.field public uint16 nVersion
		.field public uint32 dwFlags
		.field public uint8 iPixelType
		.field public uint8 cColorBits
		.field public uint8 cRedBits
		.field public uint8 cRedShift
		.field public uint8 cGreenBits
		.field public uint8 cGreenShift
		.field public uint8 cBlueBits
		.field public uint8 cBlueShift
		.field public uint8 cAlphaBits
		.field public uint8 cAlphaShift
		.field public uint8 cAccumBits
		.field public uint8 cAccumRedBits
		.field public uint8 cAccumGreenBits
		.field public uint8 cAccumBlueBits
		.field public uint8 cAccumAlphaBits
		.field public uint8 cDepthBits
		.field public uint8 cStencilBits
		.field public uint8 cAuxBuffers
		.field public uint8 iLayerType
		.field public uint8 bReserved
		.field public uint32 dwLayerMask
		.field public uint32 dwVisibleMask
		.field public uint32 dwDamageMask

	} // end of class PIXELFORMATDESCRIPTOR


	// Fields
	.field private static literal int32 GL_TRIANGLES = int32(4)
	.field private static literal int32 GL_COLOR_BUFFER_BIT = int32(16384)
	.field private static literal int32 PFD_TYPE_RGBA = int32(0)
	.field private static literal int32 PFD_DOUBLEBUFFER = int32(1)
	.field private static literal int32 PFD_DRAW_TO_WINDOW = int32(4)
	.field private static literal int32 PFD_SUPPORT_OPENGL = int32(32)
	.field private native int hDC
	.field private native int hGLRC

	// Methods
	.method private hidebysig static pinvokeimpl("user32.dll" winapi) 
		native int GetDC (
			native int ptr
		) cil managed preservesig 
	{
	} // end of method HelloForm::GetDC

	.method private hidebysig static pinvokeimpl("user32.dll" winapi) 
		native int ReleaseDC (
			native int hWnd,
			native int hDc
		) cil managed preservesig 
	{
	} // end of method HelloForm::ReleaseDC

	.method private hidebysig static pinvokeimpl("gdi32.dll" winapi) 
		int32 ChoosePixelFormat (
			native int hdc,
			[in] valuetype HelloForm/PIXELFORMATDESCRIPTOR& pfd
		) cil managed preservesig 
	{
	} // end of method HelloForm::ChoosePixelFormat

	.method private hidebysig static pinvokeimpl("gdi32.dll" winapi) 
		bool SetPixelFormat (
			native int hdc,
			int32 format,
			[in] valuetype HelloForm/PIXELFORMATDESCRIPTOR& pfd
		) cil managed preservesig 
	{
	} // end of method HelloForm::SetPixelFormat

	.method private hidebysig static pinvokeimpl("gdi32.dll" winapi) 
		bool SwapBuffers (
			native int hDC
		) cil managed preservesig 
	{
	} // end of method HelloForm::SwapBuffers

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		native int wglCreateContext (
			native int hdc
		) cil managed preservesig 
	{
	} // end of method HelloForm::wglCreateContext

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		int32 wglMakeCurrent (
			native int hdc,
			native int hglrc
		) cil managed preservesig 
	{
	} // end of method HelloForm::wglMakeCurrent

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		int32 wglDeleteContext (
			native int hglrc
		) cil managed preservesig 
	{
	} // end of method HelloForm::wglDeleteContext

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glClearColor (
			float32 red,
			float32 green,
			float32 blue,
			float32 alpha
		) cil managed preservesig 
	{
	} // end of method HelloForm::glClearColor

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glClear (
			uint32 mask
		) cil managed preservesig 
	{
	} // end of method HelloForm::glClear

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glBegin (
			uint32 mode
		) cil managed preservesig 
	{
	} // end of method HelloForm::glBegin

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glColor3f (
			float32 red,
			float32 green,
			float32 blue
		) cil managed preservesig 
	{
	} // end of method HelloForm::glColor3f

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glVertex2f (
			float32 x,
			float32 y
		) cil managed preservesig 
	{
	} // end of method HelloForm::glVertex2f

	.method private hidebysig static pinvokeimpl("opengl32.dll" winapi) 
		void glEnd () cil managed preservesig 
	{
	} // end of method HelloForm::glEnd

	.method public hidebysig specialname rtspecialname 
		instance void .ctor () cil managed 
	{
		// Method begins at RVA 0x2050
		// Header size: 12
		// Code size: 67 (0x43)
		.maxstack 3

		// hDC = (IntPtr)0;
		IL_0000: ldarg.0
		IL_0001: ldc.i4.0
		IL_0002: call native int [mscorlib]System.IntPtr::op_Explicit(int32)
		IL_0007: stfld native int HelloForm::hDC
		// hGLRC = (IntPtr)0;
		IL_000c: ldarg.0
		IL_000d: ldc.i4.0
		IL_000e: call native int [mscorlib]System.IntPtr::op_Explicit(int32)
		IL_0013: stfld native int HelloForm::hGLRC
		// base..ctor();
		IL_0018: ldarg.0
		IL_0019: call instance void [System.Windows.Forms]System.Windows.Forms.Form::.ctor()
		// (no C# code)
		IL_001e: nop
		// base.Size = new Size(640, 480);
		IL_001f: nop
		IL_0020: ldarg.0
		IL_0021: ldc.i4 640
		IL_0026: ldc.i4 480
		IL_002b: newobj instance void [System.Drawing]System.Drawing.Size::.ctor(int32, int32)
		IL_0030: call instance void [System.Windows.Forms]System.Windows.Forms.Form::set_Size(valuetype [System.Drawing]System.Drawing.Size)
		// Text = "Hello, World!";
		IL_0035: nop
		IL_0036: ldarg.0
		IL_0037: ldstr "Hello, World!"
		IL_003c: callvirt instance void [System.Windows.Forms]System.Windows.Forms.Control::set_Text(string)
		// }
		IL_0041: nop
		IL_0042: ret
	} // end of method HelloForm::.ctor

	.method family hidebysig virtual 
		instance void OnHandleCreated (
			class [mscorlib]System.EventArgs e
		) cil managed 
	{
		// Method begins at RVA 0x20a0
		// Header size: 12
		// Code size: 142 (0x8e)
		.maxstack 3
		.locals init (
			[0] valuetype HelloForm/PIXELFORMATDESCRIPTOR,
			[1] int32
		)

		// {
		IL_0000: nop
		// base.OnHandleCreated(e);
		IL_0001: ldarg.0
		IL_0002: ldarg.1
		IL_0003: call instance void [System.Windows.Forms]System.Windows.Forms.Form::OnHandleCreated(class [mscorlib]System.EventArgs)
		// (no C# code)
		IL_0008: nop
		// PIXELFORMATDESCRIPTOR pfd = default(PIXELFORMATDESCRIPTOR);
		IL_0009: ldloca.s 0
		IL_000b: initobj HelloForm/PIXELFORMATDESCRIPTOR
		// pfd.dwFlags = 37u;
		IL_0011: ldloca.s 0
		IL_0013: ldc.i4.s 37
		IL_0015: stfld uint32 HelloForm/PIXELFORMATDESCRIPTOR::dwFlags
		// pfd.iPixelType = 0;
		IL_001a: ldloca.s 0
		IL_001c: ldc.i4.0
		IL_001d: stfld uint8 HelloForm/PIXELFORMATDESCRIPTOR::iPixelType
		// pfd.cColorBits = 32;
		IL_0022: ldloca.s 0
		IL_0024: ldc.i4.s 32
		IL_0026: stfld uint8 HelloForm/PIXELFORMATDESCRIPTOR::cColorBits
		// pfd.cAlphaBits = 8;
		IL_002b: ldloca.s 0
		IL_002d: ldc.i4.8
		IL_002e: stfld uint8 HelloForm/PIXELFORMATDESCRIPTOR::cAlphaBits
		// pfd.cDepthBits = 24;
		IL_0033: ldloca.s 0
		IL_0035: ldc.i4.s 24
		IL_0037: stfld uint8 HelloForm/PIXELFORMATDESCRIPTOR::cDepthBits
		// hDC = GetDC(base.Handle);
		IL_003c: ldarg.0
		IL_003d: ldarg.0
		IL_003e: call instance native int [System.Windows.Forms]System.Windows.Forms.Control::get_Handle()
		IL_0043: call native int HelloForm::GetDC(native int)
		IL_0048: stfld native int HelloForm::hDC
		// int format = ChoosePixelFormat(hDC, ref pfd);
		IL_004d: ldarg.0
		IL_004e: ldfld native int HelloForm::hDC
		IL_0053: ldloca.s 0
		IL_0055: call int32 HelloForm::ChoosePixelFormat(native int, valuetype HelloForm/PIXELFORMATDESCRIPTOR&)
		IL_005a: stloc.1
		// SetPixelFormat(hDC, format, ref pfd);
		IL_005b: ldarg.0
		IL_005c: ldfld native int HelloForm::hDC
		IL_0061: ldloc.1
		IL_0062: ldloca.s 0
		IL_0064: call bool HelloForm::SetPixelFormat(native int, int32, valuetype HelloForm/PIXELFORMATDESCRIPTOR&)
		IL_0069: pop
		// hGLRC = wglCreateContext(hDC);
		IL_006a: ldarg.0
		IL_006b: ldarg.0
		IL_006c: ldfld native int HelloForm::hDC
		IL_0071: call native int HelloForm::wglCreateContext(native int)
		IL_0076: stfld native int HelloForm::hGLRC
		// wglMakeCurrent(hDC, hGLRC);
		IL_007b: ldarg.0
		IL_007c: ldfld native int HelloForm::hDC
		IL_0081: ldarg.0
		IL_0082: ldfld native int HelloForm::hGLRC
		IL_0087: call int32 HelloForm::wglMakeCurrent(native int, native int)
		IL_008c: pop
		// }
		IL_008d: ret
	} // end of method HelloForm::OnHandleCreated

	.method family hidebysig virtual 
		instance void OnPaint (
			class [System.Windows.Forms]System.Windows.Forms.PaintEventArgs e
		) cil managed 
	{
		// Method begins at RVA 0x213c
		// Header size: 12
		// Code size: 183 (0xb7)
		.maxstack 4

		// {
		IL_0000: nop
		// base.OnPaint(e);
		IL_0001: ldarg.0
		IL_0002: ldarg.1
		IL_0003: call instance void [System.Windows.Forms]System.Windows.Forms.Form::OnPaint(class [System.Windows.Forms]System.Windows.Forms.PaintEventArgs)
		// glClearColor(0f, 0f, 0f, 1f);
		IL_0008: nop
		IL_0009: ldc.r4 0.0
		IL_000e: ldc.r4 0.0
		IL_0013: ldc.r4 0.0
		IL_0018: ldc.r4 1
		IL_001d: call void HelloForm::glClearColor(float32, float32, float32, float32)
		// glClear(16384u);
		IL_0022: nop
		IL_0023: ldc.i4 16384
		IL_0028: call void HelloForm::glClear(uint32)
		// glBegin(4u);
		IL_002d: nop
		IL_002e: ldc.i4.4
		IL_002f: call void HelloForm::glBegin(uint32)
		// glColor3f(1f, 0f, 0f);
		IL_0034: nop
		IL_0035: ldc.r4 1
		IL_003a: ldc.r4 0.0
		IL_003f: ldc.r4 0.0
		IL_0044: call void HelloForm::glColor3f(float32, float32, float32)
		// glVertex2f(0f, 0.5f);
		IL_0049: nop
		IL_004a: ldc.r4 0.0
		IL_004f: ldc.r4 0.5
		IL_0054: call void HelloForm::glVertex2f(float32, float32)
		// glColor3f(0f, 1f, 0f);
		IL_0059: nop
		IL_005a: ldc.r4 0.0
		IL_005f: ldc.r4 1
		IL_0064: ldc.r4 0.0
		IL_0069: call void HelloForm::glColor3f(float32, float32, float32)
		// glVertex2f(0.5f, -0.5f);
		IL_006e: nop
		IL_006f: ldc.r4 0.5
		IL_0074: ldc.r4 -0.5
		IL_0079: call void HelloForm::glVertex2f(float32, float32)
		// glColor3f(0f, 0f, 1f);
		IL_007e: nop
		IL_007f: ldc.r4 0.0
		IL_0084: ldc.r4 0.0
		IL_0089: ldc.r4 1
		IL_008e: call void HelloForm::glColor3f(float32, float32, float32)
		// glVertex2f(-0.5f, -0.5f);
		IL_0093: nop
		IL_0094: ldc.r4 -0.5
		IL_0099: ldc.r4 -0.5
		IL_009e: call void HelloForm::glVertex2f(float32, float32)
		// glEnd();
		IL_00a3: nop
		IL_00a4: call void HelloForm::glEnd()
		// SwapBuffers(hDC);
		IL_00a9: nop
		IL_00aa: ldarg.0
		IL_00ab: ldfld native int HelloForm::hDC
		IL_00b0: call bool HelloForm::SwapBuffers(native int)
		IL_00b5: pop
		// }
		IL_00b6: ret
	} // end of method HelloForm::OnPaint

	.method private hidebysig static 
		void Main () cil managed 
	{
		.custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = (
			01 00 00 00
		)
		// Method begins at RVA 0x2200
		// Header size: 12
		// Code size: 15 (0xf)
		.maxstack 1
		.entrypoint
		.locals init (
			[0] class HelloForm
		)

		// {
		IL_0000: nop
		// HelloForm mainForm = new HelloForm();
		IL_0001: newobj instance void HelloForm::.ctor()
		IL_0006: stloc.0
		// Application.Run(mainForm);
		IL_0007: ldloc.0
		IL_0008: call void [System.Windows.Forms]System.Windows.Forms.Application::Run(class [System.Windows.Forms]System.Windows.Forms.Form)
		// }
		IL_000d: nop
		IL_000e: ret
	} // end of method HelloForm::Main

} // end of class HelloForm
