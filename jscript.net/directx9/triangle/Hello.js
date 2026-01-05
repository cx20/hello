import System;
import System.Drawing;
import System.Reflection;
import System.Runtime.InteropServices;
import System.Windows.Forms;

// Load assemblies dynamically
Console.WriteLine("Loading assemblies...");
var dxAssembly = Assembly.Load("Microsoft.DirectX, Version=1.0.2902.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
var d3dAssembly = Assembly.Load("Microsoft.DirectX.Direct3D, Version=1.0.2902.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35");
Console.WriteLine("Assemblies loaded.");

// Get types
var DeviceType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.Device");
var PresentParametersType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.PresentParameters");
var SwapEffectType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.SwapEffect");
var CreateFlagsType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.CreateFlags");
var DeviceTypeEnum = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.DeviceType");
var ClearFlagsType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.ClearFlags");
var PrimitiveTypeEnum = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.PrimitiveType");
var VertexFormatsType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.VertexFormats");
var TransformedColoredType = d3dAssembly.GetType("Microsoft.DirectX.Direct3D.CustomVertex+TransformedColored");

// Global variables
var device: Object = null;
var form: Form = null;
var tcConstructor: ConstructorInfo = null;  // TransformedColored constructor

// BindingFlags
var bfPublicInstance: BindingFlags = BindingFlags.Public | BindingFlags.Instance;
var bfSetProperty: BindingFlags = bfPublicInstance | BindingFlags.SetProperty;
var bfSetField: BindingFlags = bfPublicInstance | BindingFlags.SetField;
var bfInvokeMethod: BindingFlags = bfPublicInstance | BindingFlags.InvokeMethod;

// Find TransformedColored constructor (5 arguments: x, y, z, rhw, color)
function FindTransformedColoredConstructor(): ConstructorInfo {
    var ctors = TransformedColoredType.GetConstructors();
    for (var i: int = 0; i < ctors.Length; i++) {
        var ctor: ConstructorInfo = ConstructorInfo(ctors.GetValue(i));
        var parms = ctor.GetParameters();
        if (parms.Length == 5) {
            return ctor;
        }
    }
    return null;
}

// Helper function: Create instance with default constructor
function CreateInstance(t: Type): Object {
    try {
        return Activator.CreateInstance(t);
    } catch (e) {
        Console.WriteLine("Activator.CreateInstance failed: " + e.Message);
    }
    return null;
}

// Helper function: Create instance with arguments (with type checking)
function CreateInstanceWithArgs(t: Type, args: Object[], expectedParamType: Type): Object {
    var ctors = t.GetConstructors();
    for (var i: int = 0; i < ctors.Length; i++) {
        var ctor: ConstructorInfo = ConstructorInfo(ctors.GetValue(i));
        var paramInfos = ctor.GetParameters();
        if (paramInfos.Length == args.Length) {
            // Check the type of the 3rd parameter if expectedParamType is specified
            if (expectedParamType != null && paramInfos.Length > 2) {
                var param2: ParameterInfo = ParameterInfo(paramInfos.GetValue(2));
                if (param2.ParameterType != expectedParamType) {
                    continue;
                }
            }
            return ctor.Invoke(args);
        }
    }
    return null;
}

// Helper function: Set member (field or property)
function SetMember(t: Type, name: String, target: Object, value: Object, isField: Boolean): void {
    var flags: BindingFlags = isField ? bfSetField : bfSetProperty;
    var args: Object[] = new Object[1];
    args[0] = value;
    t.InvokeMember(name, flags, null, target, args);
}

// Helper function: Call method
function CallMethod(t: Type, name: String, target: Object, args: Object[]): Object {
    return t.InvokeMember(name, bfInvokeMethod, null, target, args);
}

// Initialize Direct3D
function InitGraphics(targetForm: Form): void {
    // Create PresentParameters
    var parameters = CreateInstance(PresentParametersType);
    if (parameters == null) {
        Console.WriteLine("Failed to create PresentParameters!");
        return;
    }
    
    // Set properties
    SetMember(PresentParametersType, "Windowed", parameters, true, false);
    
    var swapDiscard = Enum.Parse(SwapEffectType, "Discard");
    SetMember(PresentParametersType, "SwapEffect", parameters, swapDiscard, false);
    
    // Get CreateFlags and DeviceType values
    var softwareVP = Enum.Parse(CreateFlagsType, "SoftwareVertexProcessing");
    var hardwareDevice = Enum.Parse(DeviceTypeEnum, "Hardware");
    
    // Create parameter array
    var paramsArray: System.Array = System.Array.CreateInstance(PresentParametersType, 1);
    paramsArray.SetValue(parameters, 0);
    
    // Create Device using IntPtr version of constructor
    var ctorParams: Object[] = new Object[5];
    ctorParams[0] = 0;
    ctorParams[1] = hardwareDevice;
    ctorParams[2] = targetForm.Handle;
    ctorParams[3] = softwareVP;
    ctorParams[4] = paramsArray;
    device = CreateInstanceWithArgs(DeviceType, ctorParams, Type.GetType("System.IntPtr"));
    
    // Get TransformedColored constructor
    tcConstructor = FindTransformedColoredConstructor();
}

// Create a vertex
function CreateVertex(x: float, y: float, color: int): Object {
    var args: Object[] = new Object[5];
    args[0] = Single(x);
    args[1] = Single(y);
    args[2] = Single(0);    // z
    args[3] = Single(1);    // rhw
    args[4] = color;
    return tcConstructor.Invoke(args);
}

// Render frame
function Render(): void {
    if (device == null) return;
    
    // Create vertex array
    var vertices: System.Array = System.Array.CreateInstance(TransformedColoredType, 3);
    
    // Set vertices (top-center: green, bottom-right: blue, bottom-left: red)
    vertices.SetValue(CreateVertex(320, 100, Color.FromArgb(0, 255, 0).ToArgb()), 0);
    vertices.SetValue(CreateVertex(520, 380, Color.FromArgb(0, 0, 255).ToArgb()), 1);
    vertices.SetValue(CreateVertex(120, 380, Color.FromArgb(255, 0, 0).ToArgb()), 2);
    
    // Clear
    var clearTarget = Enum.Parse(ClearFlagsType, "Target");
    var clearArgs: Object[] = new Object[4];
    clearArgs[0] = clearTarget;
    clearArgs[1] = Color.Black.ToArgb();
    clearArgs[2] = Single(1.0);
    clearArgs[3] = 0;
    CallMethod(DeviceType, "Clear", device, clearArgs);
    
    // Begin scene
    CallMethod(DeviceType, "BeginScene", device, null);
    
    // Set vertex format
    var diffuse = Enum.Parse(VertexFormatsType, "Diffuse");
    var transformed = Enum.Parse(VertexFormatsType, "Transformed");
    var vertexFormat: int = int(diffuse) | int(transformed);
    var formatValue = Enum.ToObject(VertexFormatsType, vertexFormat);
    SetMember(DeviceType, "VertexFormat", device, formatValue, false);
    
    // Draw triangle
    var triangleList = Enum.Parse(PrimitiveTypeEnum, "TriangleList");
    var drawArgs: Object[] = new Object[3];
    drawArgs[0] = triangleList;
    drawArgs[1] = 1;
    drawArgs[2] = vertices;
    CallMethod(DeviceType, "DrawUserPrimitives", device, drawArgs);
    
    // End scene
    CallMethod(DeviceType, "EndScene", device, null);
    
    // Present
    CallMethod(DeviceType, "Present", device, null);
}

// Cleanup resources
function Cleanup(): void {
    if (device != null) {
        CallMethod(DeviceType, "Dispose", device, null);
        device = null;
    }
}

// Main entry point
function Main(): void {
    Application.EnableVisualStyles();
    
    form = new Form();
    form.ClientSize = new Size(640, 480);
    form.Text = "Hello, World! (JScript.NET + Managed DirectX)";
    form.Show();
    
    InitGraphics(form);
    
    // Message loop
    while (form.Created) {
        Render();
        Application.DoEvents();
        System.Threading.Thread.Sleep(16);  // ~60 FPS
    }
    
    Cleanup();
}

Main();
