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
// MVID: {8581AC6D-0946-4D15-A0DF-DCB93760FAC7}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0003 // WindowsCui
.corflags 0x00000001 // ILOnly

.class private auto ansi beforefieldinit Hello
	extends [mscorlib]System.Object
{
	// Methods
	.method private hidebysig static pinvokeimpl("user32.dll" autochar winapi) 
		uint32 MessageBox (
			native int hWnd,
			string lpText,
			string lpCaption,
			uint32 uType
		) cil managed preservesig 
	{
	} // end of method Hello::MessageBox

	.method private hidebysig static 
		void Main (
			string[] args
		) cil managed 
	{
		// Method begins at RVA 0x2050
		// Header size: 1
		// Code size: 25 (0x19)
		.maxstack 8
		.entrypoint

		// {
		IL_0000: nop
		// MessageBox(new IntPtr(0), "Hello, Win32 API(MSIL) World!", "Hello, World!", 0u);
		IL_0001: ldc.i4.0
		IL_0002: newobj instance void [mscorlib]System.IntPtr::.ctor(int32)
		IL_0007: ldstr "Hello, Win32 API(MSIL) World!"
		IL_000c: ldstr "Hello, World!"
		IL_0011: ldc.i4.0
		IL_0012: call uint32 Hello::MessageBox(native int, string, string, uint32)
		IL_0017: pop
		// }
		IL_0018: ret
	} // end of method Hello::Main

	.method public hidebysig specialname rtspecialname 
		instance void .ctor () cil managed 
	{
		// Method begins at RVA 0x206a
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
