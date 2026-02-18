open System
open System.Drawing
open System.Runtime.InteropServices
open System.Windows.Forms
open System.IO
open System.Text
open System.Diagnostics

// ========================================================================================================
// Debug Logging Utilities
// ========================================================================================================

module DebugLog =
    let WriteLine (msg: string) = 
        let timestamp = System.DateTime.Now.ToString("HH:mm:ss.fff")
        let formattedMsg = sprintf "[%s] %s" timestamp msg
        Console.WriteLine(formattedMsg)
        Debug.WriteLine(formattedMsg)
    
    let WriteError (msg: string) =
        let timestamp = System.DateTime.Now.ToString("HH:mm:ss.fff")
        let formattedMsg = sprintf "[%s] ERROR: %s" timestamp msg
        Console.ForegroundColor <- ConsoleColor.Red
        Console.WriteLine(formattedMsg)
        Console.ResetColor()
        Debug.WriteLine(formattedMsg)
    
    let WriteSuccess (msg: string) =
        let timestamp = System.DateTime.Now.ToString("HH:mm:ss.fff")
        let formattedMsg = sprintf "[%s] OK: %s" timestamp msg
        Console.ForegroundColor <- ConsoleColor.Green
        Console.WriteLine(formattedMsg)
        Console.ResetColor()
        Debug.WriteLine(formattedMsg)

// ========================================================================================================
// Shader Compiler (Using shaderc_shared.dll)
// ========================================================================================================

module ShaderCompiler =
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compiler_initialize()
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compiler_release(IntPtr compiler)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compile_options_initialize()
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compile_options_set_optimization_level(IntPtr options, int level)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_compile_options_release(IntPtr options)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_compile_into_spv(IntPtr compiler, [<MarshalAs(UnmanagedType.LPStr)>] string source, unativeint size, int kind, [<MarshalAs(UnmanagedType.LPStr)>] string fileName, [<MarshalAs(UnmanagedType.LPStr)>] string entryPoint, IntPtr options)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern void private shaderc_result_release(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern unativeint private shaderc_result_get_length(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_result_get_bytes(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern int private shaderc_result_get_compilation_status(IntPtr result)
    
    [<DllImport("shaderc_shared.dll", CallingConvention = CallingConvention.Cdecl)>]
    extern IntPtr private shaderc_result_get_error_message(IntPtr result)

    let Compile (source: string) (kind: int) (fileName: string) : byte[] =
        DebugLog.WriteLine(sprintf "ShaderCompiler.Compile() - START: %s (kind=%d)" fileName kind)
        
        let compiler = shaderc_compiler_initialize()
        if compiler = IntPtr.Zero then
            DebugLog.WriteError("Failed to initialize shaderc compiler")
            
        let options = shaderc_compile_options_initialize()
        if options = IntPtr.Zero then
            DebugLog.WriteError("Failed to initialize shaderc compile options")
            
        shaderc_compile_options_set_optimization_level(options, 2)
        DebugLog.WriteLine(sprintf "Shader compilation options set (optimization level=2)")
        
        try
            let sourceSize = unativeint (Encoding.UTF8.GetByteCount(source))
            DebugLog.WriteLine(sprintf "Compiling %s: source size = %d bytes" fileName (int sourceSize))
            
            let result = shaderc_compile_into_spv(compiler, source, sourceSize, kind, fileName, "main", options)
            
            try
                let status = shaderc_result_get_compilation_status(result)
                if status <> 0 then
                    let errorMsg = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    DebugLog.WriteError(sprintf "Shader compilation failed (status=%d): %s" status errorMsg)
                    failwithf "Shader compilation failed: %s" errorMsg
                
                let length = int (shaderc_result_get_length(result))
                DebugLog.WriteLine(sprintf "SPIR-V code generated: %d bytes" length)
                
                let bytesPtr = shaderc_result_get_bytes(result)
                let bytecode = Array.zeroCreate<byte> length
                Marshal.Copy(bytesPtr, bytecode, 0, length)
                
                DebugLog.WriteSuccess(sprintf "Shader compiled: %s" fileName)
                bytecode
            finally
                shaderc_result_release(result)
        finally
            shaderc_compile_options_release(options)
            shaderc_compiler_release(compiler)


// ========================================================================================================
// Main Entry Point - Harmonograph Compute Shader Sample
// ========================================================================================================

[<EntryPoint>]
let main argv =
    DebugLog.WriteLine("======== MAIN APPLICATION START ========")
    DebugLog.WriteLine(sprintf "Process ID: %d" (System.Diagnostics.Process.GetCurrentProcess().Id))
    DebugLog.WriteLine(sprintf "Working Directory: %s" (System.Environment.CurrentDirectory))
    DebugLog.WriteLine("")
    
    // Harmonograph compute shader source code
    // Calculates a mathematical harmonograph pattern using stacked sinusoids with damping
    let computeShaderSource = @"#version 450
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// Storage buffers for output positions and colors
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

// Uniform buffer for animation parameters
layout(std140, binding = 2) uniform Params
{
    uint  max_num;
    float dt;
    float scale;
    float pad0;
    // Four sinusoid parameters (A=amplitude, f=frequency, p=phase, d=damping)
    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;

// Convert HSV color to RGB
vec3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
    vec3 rgb;
    if      (hp < 1.0) rgb = vec3(c, x, 0.0);
    else if (hp < 2.0) rgb = vec3(x, c, 0.0);
    else if (hp < 3.0) rgb = vec3(0.0, c, x);
    else if (hp < 4.0) rgb = vec3(0.0, x, c);
    else if (hp < 5.0) rgb = vec3(x, 0.0, c);
    else               rgb = vec3(c, 0.0, x);
    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= u.max_num) return;

    float t  = float(idx) * u.dt;
    float PI = 3.141592653589793;

    // Harmonograph equations: combination of two damped sinusoids per axis
    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) +
              u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);

    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) +
              u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);

    vec2 p = vec2(x, y) * u.scale;
    pos[idx] = vec4(p.x, p.y, 0.0, 1.0);

    // Map time to HSV hue for color animation
    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb  = hsv2rgb(hue, 1.0, 1.0);
    col[idx]  = vec4(rgb, 1.0);
}"

    // Vertex shader - reads computed positions and colors from storage buffers
    let vertexShaderSource = @"#version 450
layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor = col[idx];
}"

    // Fragment shader - outputs the colors computed by the compute shader
    let fragmentShaderSource = @"#version 450
layout(location = 0) in  vec4 vColor;
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = vColor;
}"

    DebugLog.WriteLine("========== SHADER COMPILATION PHASE ==========")
    DebugLog.WriteLine("")
    
    try
        // Compile shaders
        DebugLog.WriteLine("main() - Initiating shader compilation with shaderc...")
        DebugLog.WriteLine("")
        
        DebugLog.WriteLine("[Phase 1/3] Compiling compute shader...")
        let computeSpirv = ShaderCompiler.Compile computeShaderSource 2 "harmonograph.comp"
        DebugLog.WriteLine(sprintf "            Result: %d bytes (SPIR-V)" computeSpirv.Length)
        
        DebugLog.WriteLine("[Phase 2/3] Compiling vertex shader...")
        let vertexSpirv = ShaderCompiler.Compile vertexShaderSource 0 "harmonograph.vert"
        DebugLog.WriteLine(sprintf "            Result: %d bytes (SPIR-V)" vertexSpirv.Length)
        
        DebugLog.WriteLine("[Phase 3/3] Compiling fragment shader...")
        let fragmentSpirv = ShaderCompiler.Compile fragmentShaderSource 1 "harmonograph.frag"
        DebugLog.WriteLine(sprintf "            Result: %d bytes (SPIR-V)" fragmentSpirv.Length)
        
        DebugLog.WriteLine("")
        DebugLog.WriteSuccess("All shaders compiled successfully!")
        
        DebugLog.WriteLine("")
        DebugLog.WriteLine("======== APPLICATION FEATURES ========")
        DebugLog.WriteLine("Sample Type:  Vulkan 1.4 Compute Shader + Graphics Pipeline")
        DebugLog.WriteLine("Pattern:      Harmonograph (Mathematical Parametric Curve)")
        DebugLog.WriteLine("Compute:      4x Damped Sinusoids = 500,000 Path Points")
        DebugLog.WriteLine("Rendering:    Line Strip (GL_LINE_STRIP)")
        DebugLog.WriteLine("Colors:      HSV -> RGB Animation")
        DebugLog.WriteLine("Buffers:      Storage Buffer (Positions) + Storage Buffer (Colors)")
        DebugLog.WriteLine("")
        DebugLog.WriteLine("======== STATUS ========")
        DebugLog.WriteSuccess("Shader compilation phase: COMPLETE")
        DebugLog.WriteLine("")
        DebugLog.WriteLine("NOTE: Full Vulkan runtime implementation would include:")
        DebugLog.WriteLine("  - Instance & Surface creation")
        DebugLog.WriteLine("  - Physical device selection")
        DebugLog.WriteLine("  - Logical device & queue creation")
        DebugLog.WriteLine("  - Swapchain & renderpass setup")
        DebugLog.WriteLine("  - Pipeline & buffer creation")
        DebugLog.WriteLine("  - Command recording & execution")
        DebugLog.WriteLine("  - Window display with continuous rendering")
        DebugLog.WriteLine("")
        DebugLog.WriteLine("======== MAIN APPLICATION END ========")
        DebugLog.WriteLine("")
        
        0
    with
    | ex -> 
        DebugLog.WriteLine("")
        DebugLog.WriteError("Exception occurred during shader compilation!")
        DebugLog.WriteError(sprintf "Exception Type: %s" (ex.GetType().Name))
        DebugLog.WriteError(sprintf "Message: %s" ex.Message)
        if ex.InnerException <> null then
            DebugLog.WriteError(sprintf "Inner Exception: %s" ex.InnerException.Message)
        DebugLog.WriteError(sprintf "Stack Trace: %s" ex.StackTrace)
        DebugLog.WriteLine("")
        DebugLog.WriteLine("======== MAIN APPLICATION END (ERROR) ========")
        DebugLog.WriteLine("")
        1
