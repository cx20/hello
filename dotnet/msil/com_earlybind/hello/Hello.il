.assembly extern mscorlib
{
    .publickeytoken = (
        b7 7a 5c 56 19 34 e0 89
    )
    .ver 4:0:0:0
}
.assembly extern Shell32
{
    .ver 1:0:0:0
}
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
// MVID: {0E611EB9-A2EA-4D87-A217-2CDA476A3127}
.imagebase 0x00400000
.file alignment 0x00000200
.stackreserve 0x00100000
.subsystem 0x0003 // WindowsCui
.corflags 0x00000001 // ILOnly
.custom instance void System.Runtime.CompilerServices.RefSafetyRulesAttribute::.ctor(int32) = (
    01 00 0b 00 00 00 00 00
)


.class private auto ansi '<Module>'
{
} // end of class <Module>

.class private auto ansi sealed beforefieldinit Microsoft.CodeAnalysis.EmbeddedAttribute
    extends [mscorlib]System.Attribute
{
    .custom instance void [mscorlib]System.Runtime.CompilerServices.CompilerGeneratedAttribute::.ctor() = (
        01 00 00 00
    )
    .custom instance void Microsoft.CodeAnalysis.EmbeddedAttribute::.ctor() = (
        01 00 00 00
    )
    // Methods
    .method public hidebysig specialname rtspecialname 
        instance void .ctor () cil managed 
    {
        // Method begins at RVA 0x2050
        // Header size: 1
        // Code size: 8 (0x8)
        .maxstack 8

        IL_0000: ldarg.0
        IL_0001: call instance void [mscorlib]System.Attribute::.ctor()
        IL_0006: nop
        IL_0007: ret
    } // end of method EmbeddedAttribute::.ctor

} // end of class Microsoft.CodeAnalysis.EmbeddedAttribute

.class private auto ansi sealed beforefieldinit System.Runtime.CompilerServices.RefSafetyRulesAttribute
    extends [mscorlib]System.Attribute
{
    .custom instance void [mscorlib]System.Runtime.CompilerServices.CompilerGeneratedAttribute::.ctor() = (
        01 00 00 00
    )
    .custom instance void Microsoft.CodeAnalysis.EmbeddedAttribute::.ctor() = (
        01 00 00 00
    )
    .custom instance void [mscorlib]System.AttributeUsageAttribute::.ctor(valuetype [mscorlib]System.AttributeTargets) = (
        01 00 02 00 00 00 02 00 54 02 0d 41 6c 6c 6f 77
        4d 75 6c 74 69 70 6c 65 00 54 02 09 49 6e 68 65
        72 69 74 65 64 00
    )
    // Fields
    .field public initonly int32 Version

    // Methods
    .method public hidebysig specialname rtspecialname 
        instance void .ctor (
            int32 ''
        ) cil managed 
    {
        // Method begins at RVA 0x2059
        // Header size: 1
        // Code size: 15 (0xf)
        .maxstack 8

        IL_0000: ldarg.0
        IL_0001: call instance void [mscorlib]System.Attribute::.ctor()
        IL_0006: nop
        IL_0007: ldarg.0
        IL_0008: ldarg.1
        IL_0009: stfld int32 System.Runtime.CompilerServices.RefSafetyRulesAttribute::Version
        IL_000e: ret
    } // end of method RefSafetyRulesAttribute::.ctor

} // end of class System.Runtime.CompilerServices.RefSafetyRulesAttribute

.class private auto ansi beforefieldinit Hello
    extends [mscorlib]System.Object
{
    // Methods
    .method private hidebysig static 
        void Main (
            string[] args
        ) cil managed 
    {
        // Method begins at RVA 0x206c
        // Header size: 12
        // Code size: 96 (0x60)
        .maxstack 5
        .entrypoint
        .locals init (
            [0] class [mscorlib]System.Type,
            [1] class [Shell32]Shell32.IShellDispatch,
            [2] object,
            [3] class [Shell32]Shell32.Folder,
            [4] bool
        )

        IL_0000: nop
        IL_0001: ldstr "Shell.Application"
        IL_0006: call class [mscorlib]System.Type [mscorlib]System.Type::GetTypeFromProgID(string)
        IL_000b: stloc.0
        IL_000c: ldloc.0
        IL_000d: call object [mscorlib]System.Activator::CreateInstance(class [mscorlib]System.Type)
        IL_0012: castclass [Shell32]Shell32.IShellDispatch
        IL_0017: stloc.1
        IL_0018: ldc.i4.s 36
        IL_001a: box [mscorlib]System.Int32
        IL_001f: stloc.2
        IL_0020: ldloc.1
        IL_0021: ldc.i4.0
        IL_0022: ldstr "Hello, COM(MSIL) World!"
        IL_0027: ldc.i4.0
        IL_0028: ldloc.2
        IL_0029: callvirt instance class [Shell32]Shell32.Folder [Shell32]Shell32.IShellDispatch::BrowseForFolder(int32, string, int32, object)
        IL_002e: stloc.3
        IL_002f: ldloc.3
        IL_0030: ldnull
        IL_0031: cgt.un
        IL_0033: stloc.s 4
        IL_0035: ldloc.s 4
        IL_0037: brfalse.s IL_0058

        IL_0039: nop
        IL_003a: ldstr "Selected: "
        IL_003f: ldloc.3
        IL_0040: callvirt instance string [Shell32]Shell32.Folder::get_Title()
        IL_0045: call string [mscorlib]System.String::Concat(string, string)
        IL_004a: call void [mscorlib]System.Console::WriteLine(string)
        IL_004f: nop
        IL_0050: ldloc.3
        IL_0051: call int32 [mscorlib]System.Runtime.InteropServices.Marshal::ReleaseComObject(object)
        IL_0056: pop
        IL_0057: nop

        IL_0058: ldloc.1
        IL_0059: call int32 [mscorlib]System.Runtime.InteropServices.Marshal::ReleaseComObject(object)
        IL_005e: pop
        IL_005f: ret
    } // end of method Hello::Main

    .method public hidebysig specialname rtspecialname 
        instance void .ctor () cil managed 
    {
        // Method begins at RVA 0x20d8
        // Header size: 1
        // Code size: 8 (0x8)
        .maxstack 8

        IL_0000: ldarg.0
        IL_0001: call instance void [mscorlib]System.Object::.ctor()
        IL_0006: nop
        IL_0007: ret
    } // end of method Hello::.ctor

} // end of class Hello

