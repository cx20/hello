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
// MVID: {0C5EF483-BAEE-4CF7-9C4C-98F18C1E5E9E}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0002 // WindowsGui
.corflags 0x00000001 // ILOnly

.class private auto ansi beforefieldinit HelloForm
	extends [System.Windows.Forms]System.Windows.Forms.Form
{
	// Methods
	.method public hidebysig specialname rtspecialname 
		instance void .ctor () cil managed 
	{
		// Method begins at RVA 0x2050
		// Header size: 1
		// Code size: 43 (0x2b)
		.maxstack 8

		// {
		IL_0000: ldarg.0
		// (no C# code)
		IL_0001: call instance void [System.Windows.Forms]System.Windows.Forms.Form::.ctor()
		IL_0006: nop
		// base.Size = new Size(640, 480);
		IL_0007: nop
		IL_0008: ldarg.0
		IL_0009: ldc.i4 640
		IL_000e: ldc.i4 480
		IL_0013: newobj instance void [System.Drawing]System.Drawing.Size::.ctor(int32, int32)
		IL_0018: call instance void [System.Windows.Forms]System.Windows.Forms.Form::set_Size(valuetype [System.Drawing]System.Drawing.Size)
		// Text = "Hello, World!";
		IL_001d: nop
		IL_001e: ldarg.0
		IL_001f: ldstr "Hello, World!"
		IL_0024: callvirt instance void [System.Windows.Forms]System.Windows.Forms.Control::set_Text(string)
		// }
		IL_0029: nop
		IL_002a: ret
	} // end of method HelloForm::.ctor

	.method family hidebysig virtual 
		instance void OnPaint (
			class [System.Windows.Forms]System.Windows.Forms.PaintEventArgs e
		) cil managed 
	{
		// Method begins at RVA 0x207c
		// Header size: 12
		// Code size: 248 (0xf8)
		.maxstack 8
		.locals init (
			[0] int32,
			[1] int32,
			[2] class [System.Drawing]System.Drawing.Drawing2D.GraphicsPath,
			[3] valuetype [System.Drawing]System.Drawing.Point[],
			[4] class [System.Drawing]System.Drawing.Drawing2D.PathGradientBrush,
			[5] valuetype [System.Drawing]System.Drawing.Size
		)

		// {
		IL_0000: nop
		// int num = base.Size.Width;
		IL_0001: ldarg.0
		IL_0002: call instance valuetype [System.Drawing]System.Drawing.Size [System.Windows.Forms]System.Windows.Forms.Form::get_Size()
		IL_0007: stloc.s 5
		// int num2 = base.Size.Height;
		IL_0009: ldloca.s 5
		IL_000b: call instance int32 [System.Drawing]System.Drawing.Size::get_Width()
		IL_0010: stloc.0
		IL_0011: ldarg.0
		IL_0012: call instance valuetype [System.Drawing]System.Drawing.Size [System.Windows.Forms]System.Windows.Forms.Form::get_Size()
		IL_0017: stloc.s 5
		// GraphicsPath graphicsPath = new GraphicsPath();
		IL_0019: ldloca.s 5
		IL_001b: call instance int32 [System.Drawing]System.Drawing.Size::get_Height()
		IL_0020: stloc.1
		IL_0021: newobj instance void [System.Drawing]System.Drawing.Drawing2D.GraphicsPath::.ctor()
		IL_0026: stloc.2
		// 	Point[] points = new Point[3]
		// 	{
		// 		new Point(num / 2, num2 / 4),
		// 		new Point(num * 3 / 4, num2 * 3 / 4),
		// 		new Point(num / 4, num2 * 3 / 4)
		// 	};
		IL_0027: ldc.i4.3
		IL_0028: newarr [System.Drawing]System.Drawing.Point
		IL_002d: dup
		IL_002e: ldc.i4.0
		IL_002f: ldloc.0
		IL_0030: ldc.i4.2
		IL_0031: div
		IL_0032: ldloc.1
		IL_0033: ldc.i4.4
		IL_0034: div
		IL_0035: newobj instance void [System.Drawing]System.Drawing.Point::.ctor(int32, int32)
		IL_003a: stelem [System.Drawing]System.Drawing.Point
		IL_003f: dup
		IL_0040: ldc.i4.1
		IL_0041: ldloc.0
		IL_0042: ldc.i4.3
		IL_0043: mul
		IL_0044: ldc.i4.4
		IL_0045: div
		IL_0046: ldloc.1
		IL_0047: ldc.i4.3
		IL_0048: mul
		IL_0049: ldc.i4.4
		IL_004a: div
		IL_004b: newobj instance void [System.Drawing]System.Drawing.Point::.ctor(int32, int32)
		IL_0050: stelem [System.Drawing]System.Drawing.Point
		IL_0055: dup
		IL_0056: ldc.i4.2
		IL_0057: ldloc.0
		IL_0058: ldc.i4.4
		IL_0059: div
		IL_005a: ldloc.1
		IL_005b: ldc.i4.3
		IL_005c: mul
		IL_005d: ldc.i4.4
		IL_005e: div
		IL_005f: newobj instance void [System.Drawing]System.Drawing.Point::.ctor(int32, int32)
		IL_0064: stelem [System.Drawing]System.Drawing.Point
		IL_0069: stloc.3
		// graphicsPath.AddLines(points);
		IL_006a: ldloc.2
		IL_006b: ldloc.3
		IL_006c: callvirt instance void [System.Drawing]System.Drawing.Drawing2D.GraphicsPath::AddLines(valuetype [System.Drawing]System.Drawing.Point[])
		// PathGradientBrush pathGradientBrush = new PathGradientBrush(graphicsPath);
		IL_0071: nop
		IL_0072: ldloc.2
		IL_0073: newobj instance void [System.Drawing]System.Drawing.Drawing2D.PathGradientBrush::.ctor(class [System.Drawing]System.Drawing.Drawing2D.GraphicsPath)
		IL_0078: stloc.s 4
		// pathGradientBrush.CenterColor = Color.FromArgb(255, 85, 85, 85);
		IL_007a: ldloc.s 4
		IL_007c: ldc.i4 255
		IL_0081: ldc.i4.s 85
		IL_0083: ldc.i4.s 85
		IL_0085: ldc.i4.s 85
		IL_0087: call valuetype [System.Drawing]System.Drawing.Color [System.Drawing]System.Drawing.Color::FromArgb(int32, int32, int32, int32)
		IL_008c: callvirt instance void [System.Drawing]System.Drawing.Drawing2D.PathGradientBrush::set_CenterColor(valuetype [System.Drawing]System.Drawing.Color)
		// 	pathGradientBrush.SurroundColors = new Color[3]
		// 	{
		// 		Color.FromArgb(255, 255, 0, 0),
		// 		Color.FromArgb(255, 0, 255, 0),
		// 		Color.FromArgb(255, 0, 0, 255)
		// 	};
		IL_0091: nop
		IL_0092: ldloc.s 4
		IL_0094: ldc.i4.3
		IL_0095: newarr [System.Drawing]System.Drawing.Color
		IL_009a: dup
		IL_009b: ldc.i4.0
		IL_009c: ldc.i4 255
		IL_00a1: ldc.i4 255
		IL_00a6: ldc.i4.0
		IL_00a7: ldc.i4.0
		IL_00a8: call valuetype [System.Drawing]System.Drawing.Color [System.Drawing]System.Drawing.Color::FromArgb(int32, int32, int32, int32)
		IL_00ad: stelem [System.Drawing]System.Drawing.Color
		IL_00b2: dup
		IL_00b3: ldc.i4.1
		IL_00b4: ldc.i4 255
		IL_00b9: ldc.i4.0
		IL_00ba: ldc.i4 255
		IL_00bf: ldc.i4.0
		IL_00c0: call valuetype [System.Drawing]System.Drawing.Color [System.Drawing]System.Drawing.Color::FromArgb(int32, int32, int32, int32)
		IL_00c5: stelem [System.Drawing]System.Drawing.Color
		IL_00ca: dup
		IL_00cb: ldc.i4.2
		IL_00cc: ldc.i4 255
		IL_00d1: ldc.i4.0
		IL_00d2: ldc.i4.0
		IL_00d3: ldc.i4 255
		IL_00d8: call valuetype [System.Drawing]System.Drawing.Color [System.Drawing]System.Drawing.Color::FromArgb(int32, int32, int32, int32)
		IL_00dd: stelem [System.Drawing]System.Drawing.Color
		// (no C# code)
		IL_00e2: callvirt instance void [System.Drawing]System.Drawing.Drawing2D.PathGradientBrush::set_SurroundColors(valuetype [System.Drawing]System.Drawing.Color[])
		// e.Graphics.FillPath(pathGradientBrush, graphicsPath);
		IL_00e7: nop
		IL_00e8: ldarg.1
		IL_00e9: callvirt instance class [System.Drawing]System.Drawing.Graphics [System.Windows.Forms]System.Windows.Forms.PaintEventArgs::get_Graphics()
		IL_00ee: ldloc.s 4
		IL_00f0: ldloc.2
		IL_00f1: callvirt instance void [System.Drawing]System.Drawing.Graphics::FillPath(class [System.Drawing]System.Drawing.Brush, class [System.Drawing]System.Drawing.Drawing2D.GraphicsPath)
		// }
		IL_00f6: nop
		IL_00f7: ret
	} // end of method HelloForm::OnPaint

	.method private hidebysig static 
		void Main () cil managed 
	{
		.custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = (
			01 00 00 00
		)
		// Method begins at RVA 0x2180
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
