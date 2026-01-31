import System;
import System.Reflection;
import System.Reflection.Emit;
import System.Runtime;
import System.Text;
 
// Invoke a Win32 P/Invoke call.
// http://www.leeholmes.com/blog/2006/07/21/get-the-owner-of-a-process-in-powershell-%e2%80%93-pinvoke-and-refout-parameters
function InvokeWin32(dllName:String, returnType:Type,
  methodName:String, parameterTypes:Type[], parameters:Object[])
{
  // Begin to build the dynamic assembly
  var domain = AppDomain.CurrentDomain;
  var name = new System.Reflection.AssemblyName('PInvokeAssembly');
  var assembly = domain.DefineDynamicAssembly(name, AssemblyBuilderAccess.Run);
  var module = assembly.DefineDynamicModule('PInvokeModule');
  var type = module.DefineType('PInvokeType',TypeAttributes.Public + TypeAttributes.BeforeFieldInit);
 
  // Define the actual P/Invoke method
  var method = type.DefineMethod(methodName, MethodAttributes.Public + MethodAttributes.HideBySig + MethodAttributes.Static + MethodAttributes.PinvokeImpl, returnType, parameterTypes);
 
  // Apply the P/Invoke constructor
  var ctor = System.Runtime.InteropServices.DllImportAttribute.GetConstructor([Type.GetType("System.String")]);
  var attr = new System.Reflection.Emit.CustomAttributeBuilder(ctor, [dllName]);
  method.SetCustomAttribute(attr);
 
  // Create the temporary type, and invoke the method.
  var realType = type.CreateType();
  return realType.InvokeMember(methodName, BindingFlags.Public + BindingFlags.Static + BindingFlags.InvokeMethod, null, null, parameters);
}
 
function MessageBox(hWnd:Int32, lpText:String, lpCaption:String, uType:Int32) 
{ 
   var parameterTypes:Type[] = [Type.GetType("System.Int32"),Type.GetType("System.String"),Type.GetType("System.String"),Type.GetType("System.Int32")];
   var parameters:Object[] = [hWnd, lpText, lpCaption, uType];
 
   return InvokeWin32("user32.dll", Type.GetType("System.Int32"), "MessageBoxA", parameterTypes,  parameters );
} 
 
MessageBox( 0, "Hello, Win32 API(JScript.NET) World!", "Hello, World!", 0 );
