.assembly extern mscorlib {}
.assembly Hello {}

.method static void Main() cil managed {
    .entrypoint
    ldstr "Hello, MSIL World!"
    call void [mscorlib]System.Console::WriteLine(string)
    ret
}
