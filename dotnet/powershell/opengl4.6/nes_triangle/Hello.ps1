$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$framework = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319'
$sourcePath = Join-Path $PSScriptRoot 'Hello.cs'
$source = Get-Content -Raw -Path $sourcePath
$source = $source.Replace('AppDomain.CurrentDomain.BaseDirectory', 'Environment.CurrentDirectory')

$parameters = New-Object System.CodeDom.Compiler.CompilerParameters
$parameters.GenerateExecutable = $false
$parameters.GenerateInMemory = $true
$parameters.IncludeDebugInformation = $false
[void]$parameters.ReferencedAssemblies.AddRange(@(
    "$framework\System.dll",
    "$framework\System.Drawing.dll",
    "$framework\System.Windows.Forms.dll"
))

$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$results = $provider.CompileAssemblyFromSource($parameters, $source)

if ($results.Errors.Count -gt 0) {
    $messages = $results.Errors | ForEach-Object { $_.ToString() }
    throw ($messages -join [Environment]::NewLine)
}

$type = $results.CompiledAssembly.GetType('HelloForm', $true)
$method = $type.GetMethod('Main', [System.Reflection.BindingFlags] 'Public, NonPublic, Static')
[void]$method.Invoke($null, $null)
