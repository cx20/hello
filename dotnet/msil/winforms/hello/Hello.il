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
// MVID: {DAB98F69-1FCC-4246-8D4E-891BD230820C}
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
		// Header size: 12
		// Code size: 93 (0x5d)
		.maxstack 3
		.locals init (
			[0] class [System.Windows.Forms]System.Windows.Forms.Label
		)

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
		// 	Label value = new Label
		// 	{
		// 		Size = new Size(320, 20),
		// 		Text = "Hello, Windows Forms(MSIL) World!"
		// 	};
		IL_0029: nop
		IL_002a: newobj instance void [System.Windows.Forms]System.Windows.Forms.Label::.ctor()
		IL_002f: stloc.0
		IL_0030: ldloc.0
		IL_0031: ldc.i4 320
		IL_0036: ldc.i4.s 20
		IL_0038: newobj instance void [System.Drawing]System.Drawing.Size::.ctor(int32, int32)
		IL_003d: callvirt instance void [System.Windows.Forms]System.Windows.Forms.Control::set_Size(valuetype [System.Drawing]System.Drawing.Size)
		// (no C# code)
		IL_0042: nop
		IL_0043: ldloc.0
		IL_0044: ldstr "Hello, Windows Forms(MSIL) World!"
		IL_0049: callvirt instance void [System.Windows.Forms]System.Windows.Forms.Control::set_Text(string)
		// base.Controls.Add(value);
		IL_004e: nop
		IL_004f: ldarg.0
		IL_0050: call instance class [System.Windows.Forms]System.Windows.Forms.Control/ControlCollection [System.Windows.Forms]System.Windows.Forms.Control::get_Controls()
		IL_0055: ldloc.0
		IL_0056: callvirt instance void [System.Windows.Forms]System.Windows.Forms.Control/ControlCollection::Add(class [System.Windows.Forms]System.Windows.Forms.Control)
		// }
		IL_005b: nop
		IL_005c: ret
	} // end of method HelloForm::.ctor

	.method private hidebysig static 
		void Main () cil managed 
	{
		.custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = (
			01 00 00 00
		)
		// Method begins at RVA 0x20bc
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
