function Main
{
   MessageBox 0 "Hello, Win32 API(PowerShell)!" "Hello, World!" 0
}

## Invoke a Win32 P/Invoke call. 
## http://www.leeholmes.com/blog/2006/07/21/get-the-owner-of-a-process-in-powershell-%e2%80%93-pinvoke-and-refout-parameters/
function Invoke-Win32([string] $dllName, [Type] $returnType, [string] $methodName,  
   [Type[]] $parameterTypes, [Object[]] $parameters) 
{ 
   ## Begin to build the dynamic assembly 
   $domain = [AppDomain]::CurrentDomain 
   $name = New-Object Reflection.AssemblyName 'PInvokeAssembly' 
   $assembly = $domain.DefineDynamicAssembly($name, 'Run') 
   $module = $assembly.DefineDynamicModule('PInvokeModule') 
   $type = $module.DefineType('PInvokeType', "Public,BeforeFieldInit") 

   ## Define the actual P/Invoke method
   $method = $type.DefineMethod($methodName, 'Public,HideBySig,Static,PinvokeImpl',  
      $returnType, $parameterTypes) 

   ## Apply the P/Invoke constructor 
   $ctor = [Runtime.InteropServices.DllImportAttribute].GetConstructor([string]) 
   $attr = New-Object Reflection.Emit.CustomAttributeBuilder $ctor, $dllName 
   $method.SetCustomAttribute($attr) 

   ## Create the temporary type, and invoke the method. 
   $realType = $type.CreateType() 
   $realType.InvokeMember($methodName, 'Public,Static,InvokeMethod', $null, $null,  
      $parameters) 
} 

function MessageBox([Int32] $hWnd, [String] $lpText, [String] $lpCaption, [Int32] $uType) 
{ 
   $parameterTypes = [Int32], [String], [String], [Int32]
   $parameters = $hWnd, $lpText, $lpCaption, $uType

   Invoke-Win32 "user32.dll" ([Int32]) "MessageBoxA" $parameterTypes $parameters
} 

. Main
