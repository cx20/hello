.assembly extern mscorlib
{
    .publickeytoken = (
        b7 7a 5c 56 19 34 e0 89
    )
    .ver 4:0:0:0
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
// MVID: {6157DEF4-95DC-4D33-8693-34B5E7FF0D39}
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
        // Code size: 114 (0x72)
        .maxstack 6
        .entrypoint
        .locals init (
            [0] class [mscorlib]System.Type,
            [1] object,
            [2] object[],
            [3] object,
            [4] bool
        )

        IL_0000: nop
        IL_0001: ldstr "Shell.Application"
        IL_0006: call class [mscorlib]System.Type [mscorlib]System.Type::GetTypeFromProgID(string)
        IL_000b: stloc.0
        IL_000c: ldloc.0
        IL_000d: call object [mscorlib]System.Activator::CreateInstance(class [mscorlib]System.Type)
        IL_0012: stloc.1
        IL_0013: ldc.i4.4
        IL_0014: newarr [mscorlib]System.Object
        IL_0019: dup
        IL_001a: ldc.i4.0
        IL_001b: ldc.i4.0
        IL_001c: box [mscorlib]System.Int32
        IL_0021: stelem.ref
        IL_0022: dup
        IL_0023: ldc.i4.1
        IL_0024: ldstr "Hello, COM(MSIL) World!"
        IL_0029: stelem.ref
        IL_002a: dup
        IL_002b: ldc.i4.2
        IL_002c: ldc.i4.0
        IL_002d: box [mscorlib]System.Int32
        IL_0032: stelem.ref
        IL_0033: dup
        IL_0034: ldc.i4.3
        IL_0035: ldc.i4.s 36
        IL_0037: box [mscorlib]System.Int32
        IL_003c: stelem.ref
        IL_003d: stloc.2
        IL_003e: ldloc.1
        IL_003f: callvirt instance class [mscorlib]System.Type [mscorlib]System.Object::GetType()
        IL_0044: ldstr "BrowseForFolder"
        IL_0049: ldc.i4 256
        IL_004e: ldnull
        IL_004f: ldloc.1
        IL_0050: ldloc.2
        IL_0051: callvirt instance object [mscorlib]System.Type::InvokeMember(string, valuetype [mscorlib]System.Reflection.BindingFlags, class [mscorlib]System.Reflection.Binder, object, object[])
        IL_0056: stloc.3
        IL_0057: ldloc.3
        IL_0058: ldnull
        IL_0059: cgt.un
        IL_005b: stloc.s 4
        IL_005d: ldloc.s 4
        IL_005f: brfalse.s IL_006a

        IL_0061: nop
        IL_0062: ldloc.3
        IL_0063: call int32 [mscorlib]System.Runtime.InteropServices.Marshal::ReleaseComObject(object)
        IL_0068: pop
        IL_0069: nop

        IL_006a: ldloc.1
        IL_006b: call int32 [mscorlib]System.Runtime.InteropServices.Marshal::ReleaseComObject(object)
        IL_0070: pop
        IL_0071: ret
    } // end of method Hello::Main

    .method public hidebysig specialname rtspecialname 
        instance void .ctor () cil managed 
    {
        // Method begins at RVA 0x20ea
        // Header size: 1
        // Code size: 8 (0x8)
        .maxstack 8

        IL_0000: ldarg.0
        IL_0001: call instance void [mscorlib]System.Object::.ctor()
        IL_0006: nop
        IL_0007: ret
    } // end of method Hello::.ctor

} // end of class Hello

