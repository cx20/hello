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
// MVID: {49D4F3CC-8F86-41D2-BEF4-38DF6E23FE63}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0002 // WindowsGui
.corflags 0x00000001 // ILOnly

.class public auto ansi beforefieldinit Hello
	extends [mscorlib]System.Object
{
	// Methods
	.method public hidebysig static 
		void Main () cil managed 
	{
		.custom instance void [mscorlib]System.STAThreadAttribute::.ctor() = (
			01 00 00 00
		)
		// Method begins at RVA 0x2050
		// Header size: 12
		// Code size: 64 (0x40)
		.maxstack 2
		.entrypoint
		.locals init (
			[0] class [PresentationFramework]System.Windows.Window,
			[1] class [PresentationFramework]System.Windows.Application,
			[2] class [mscorlib]System.IO.FileStream
		)

		// {
		IL_0000: nop
		// Window window = null;
		IL_0001: ldnull
		IL_0002: stloc.0
		// using (FileStream stream = new FileStream("Hello.xaml", FileMode.Open))
		IL_0003: ldstr "Hello.xaml"
		IL_0008: ldc.i4.3
		IL_0009: newobj instance void [mscorlib]System.IO.FileStream::.ctor(string, valuetype [mscorlib]System.IO.FileMode)
		IL_000e: stloc.2
		.try
		{
			// {
			IL_000f: nop
			// window = (Window)XamlReader.Load((Stream)stream);
			IL_0010: ldloc.2
			IL_0011: call object [PresentationFramework]System.Windows.Markup.XamlReader::Load(class [mscorlib]System.IO.Stream)
			IL_0016: castclass [PresentationFramework]System.Windows.Window
			IL_001b: stloc.0
			// }
			IL_001c: nop
			IL_001d: leave.s IL_002a
		} // end .try
		finally
		{
			// (no C# code)
			IL_001f: ldloc.2
			IL_0020: brfalse.s IL_0029

			IL_0022: ldloc.2
			IL_0023: callvirt instance void [mscorlib]System.IDisposable::Dispose()
			IL_0028: nop

			// window.Show();
			IL_0029: endfinally
		} // end handler

		IL_002a: ldloc.0
		IL_002b: callvirt instance void [PresentationFramework]System.Windows.Window::Show()
		// Application application = new Application();
		IL_0030: nop
		IL_0031: newobj instance void [PresentationFramework]System.Windows.Application::.ctor()
		IL_0036: stloc.1
		// application.Run(window);
		IL_0037: ldloc.1
		IL_0038: ldloc.0
		IL_0039: callvirt instance int32 [PresentationFramework]System.Windows.Application::Run(class [PresentationFramework]System.Windows.Window)
		IL_003e: pop
		// }
		IL_003f: ret
	} // end of method Hello::Main

	.method public hidebysig specialname rtspecialname 
		instance void .ctor () cil managed 
	{
		// Method begins at RVA 0x20ac
		// Header size: 1
		// Code size: 8 (0x8)
		.maxstack 8

		// {
		IL_0000: ldarg.0
		// (no C# code)
		IL_0001: call instance void [mscorlib]System.Object::.ctor()
		// }
		IL_0006: nop
		IL_0007: ret
	} // end of method Hello::.ctor

} // end of class Hello
