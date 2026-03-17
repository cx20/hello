# Hello, WinRT(F#) World!

Display a Windows Toast Notification using WinRT from F# (.NET Framework).

## compile:

```
build.bat
```

## Result:

```
+-------------------------------+
|   Hello, World!             X |
|                               |
| Hello, WinRT(F#) World!       |
|                               |
+-------------------------------+
```

## Note

The F# compiler (`fsc`) does not emit the `windowsruntime` keyword on the `.assembly extern Windows` reference in the output IL, unlike `csc` (C#) and `vbc` (VB.NET). This causes the CLR to attempt resolving `Windows, Version=255.255.255.255` as a regular .NET assembly instead of using the WinRT type loader, resulting in a `System.IO.FileNotFoundException` at runtime.

`build.bat` works around this by post-processing the compiled binary with `ildasm`/`ilasm`:

1. Disassemble `Hello.exe` to IL using `ildasm`
2. Replace `.assembly extern Windows` with `.assembly extern windowsruntime Windows`
3. Reassemble with `ilasm`

This adds the `WindowsRuntime` content type flag (`0x200`) to the `AssemblyRef`, allowing the CLR to resolve WinRT types from `%WINDIR%\System32\WinMetadata\` automatically — the same behavior that `csc` and `vbc` produce by default.
