Imports System
Imports System.Drawing
Imports System.Windows.Forms
Imports System.Runtime.InteropServices
Imports System.IO
Imports System.Collections.Generic
Imports System.Diagnostics
Imports System.Text


' ============================================================
' DbgLog: Console + OutputDebugString (DebugView visible)
' ============================================================
Public Module DbgLog
    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Sub OutputDebugString(ByVal s As String)
    End Sub

    Public Sub Log(ByVal msg As String)
        Dim line As String = "[RayVK] " & msg
        Console.WriteLine(line)
        OutputDebugString(line & vbCrLf)
    End Sub

    Public Sub LogFmt(ByVal fmt As String, ByVal ParamArray args() As Object)
        Log(String.Format(fmt, args))
    End Sub

    Public Sub LogEx(ByVal ctx As String, ByVal ex As Exception)
        Dim sb As New System.Text.StringBuilder()
        sb.AppendLine("*** EXCEPTION in " & ctx & " ***")
        sb.AppendLine("  Type   : " & ex.GetType().FullName)
        sb.AppendLine("  Message: " & ex.Message)
        sb.AppendLine("  Stack  :")
        sb.AppendLine(ex.StackTrace)
        If ex.InnerException IsNot Nothing Then
            sb.AppendLine("  Inner  : " & ex.InnerException.Message)
        End If
        Log(sb.ToString())
    End Sub

    Public Sub LogFrame(ByVal frame As Integer, ByVal msg As String)
        If frame <= 5 OrElse (frame Mod 300) = 0 Then
            Log("[Frame " & frame.ToString() & "] " & msg)
        End If
    End Sub
End Module

' ========================================================================================================
' Shader Compiler Class (Using shaderc_shared.dll)
' Compiles GLSL source code to SPIR-V bytecode at runtime.
' ========================================================================================================
Public Class ShaderCompiler
    Private Const LibName As String = "shaderc_shared.dll"

    Public Enum ShaderKind As Integer
        Vertex = 0
        Fragment = 1
        Compute = 2
        Geometry = 3
        TessControl = 4
        TessEvaluation = 5
    End Enum

    Private Enum CompilationStatus As Integer
        Success = 0
        InvalidStage = 1
        CompilationError = 2
        InternalError = 3
        NullResultObject = 4
        InvalidAssembly = 5
        ValidationError = 6
        TransformationError = 7
        ConfigurationError = 8
    End Enum

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compiler_initialize() As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compiler_release(ByVal compiler As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compile_options_initialize() As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compile_options_set_optimization_level(ByVal options As IntPtr, ByVal level As Integer)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_compile_options_release(ByVal options As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_compile_into_spv(
        ByVal compiler As IntPtr,
        <MarshalAs(UnmanagedType.LPStr)> ByVal source_text As String,
        ByVal source_text_size As UIntPtr,
        ByVal shader_kind As Integer,
        <MarshalAs(UnmanagedType.LPStr)> ByVal input_file_name As String,
        <MarshalAs(UnmanagedType.LPStr)> ByVal entry_point_name As String,
        ByVal additional_options As IntPtr) As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Sub shaderc_result_release(ByVal result As IntPtr)
    End Sub

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_length(ByVal result As IntPtr) As UIntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_bytes(ByVal result As IntPtr) As IntPtr
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_compilation_status(ByVal result As IntPtr) As CompilationStatus
    End Function

    <DllImport(LibName, CallingConvention:=CallingConvention.Cdecl)>
    Private Shared Function shaderc_result_get_error_message(ByVal result As IntPtr) As IntPtr
    End Function

    ''' <summary>Compiles a GLSL source string to SPIR-V bytecode.</summary>
    Public Shared Function Compile(ByVal source As String, ByVal kind As ShaderKind,
                                   Optional ByVal fileName As String = "shader.glsl",
                                   Optional ByVal entryPoint As String = "main") As Byte()
        Dim compiler As IntPtr = shaderc_compiler_initialize()
        Dim options As IntPtr = shaderc_compile_options_initialize()

        ' Optimization Level: Performance (2)
        shaderc_compile_options_set_optimization_level(options, 2)

        Try
            Dim result As IntPtr = shaderc_compile_into_spv(
                compiler,
                source,
                CType(Encoding.UTF8.GetByteCount(source), UIntPtr),
                CInt(kind),
                fileName,
                entryPoint,
                options)

            Try
                Dim status As CompilationStatus = shaderc_result_get_compilation_status(result)
                If status <> CompilationStatus.Success Then
                    Dim errorMsg As String = Marshal.PtrToStringAnsi(shaderc_result_get_error_message(result))
                    Throw New Exception($"Shader compilation failed: {errorMsg}")
                End If

                Dim length As ULong = CULng(shaderc_result_get_length(result))
                Dim bytesPtr As IntPtr = shaderc_result_get_bytes(result)

                Dim bytecode(length - 1) As Byte
                Marshal.Copy(bytesPtr, bytecode, 0, CInt(length))
                Return bytecode
            Finally
                shaderc_result_release(result)
            End Try
        Finally
            shaderc_compile_options_release(options)
            shaderc_compiler_release(compiler)
        End Try
    End Function
End Class

' ========================================================================================================
' Main Application - Vulkan 1.4 Raymarching in VB.NET
' Renders an animated SDF scene with soft shadows, ambient occlusion, and fog
' using a fullscreen triangle and push constants for time/resolution.
' ========================================================================================================
Class RaymarchingForm
    Inherits Form

    ' ---- Vertex shader source (GLSL 450) ----
    ' Generates a fullscreen triangle from gl_VertexIndex alone (no vertex buffer needed).
    Private Const VERT_SHADER_SRC As String =
        "#version 450" & vbLf &
        "#extension GL_ARB_separate_shader_objects : enable" & vbLf &
        "layout(location = 0) out vec2 fragCoord;" & vbLf &
        "vec2 positions[3] = vec2[](" & vbLf &
        "    vec2(-1.0, -1.0)," & vbLf &
        "    vec2( 3.0, -1.0)," & vbLf &
        "    vec2(-1.0,  3.0)" & vbLf &
        ");" & vbLf &
        "void main() {" & vbLf &
        "    vec2 pos = positions[gl_VertexIndex];" & vbLf &
        "    gl_Position = vec4(pos, 0.0, 1.0);" & vbLf &
        "    // UV in [0,1] range with Y flipped to match convention" & vbLf &
        "    fragCoord = vec2(pos.x * 0.5 + 0.5, 1.0 - (pos.y * 0.5 + 0.5));" & vbLf &
        "}"

    ' ---- Fragment shader source (GLSL 450) ----
    ' Ray marching scene: animated sphere + rotating torus + checkerboard floor.
    ' Features: SDF blending, soft shadows (64 steps), ambient occlusion, fog, gamma correction.
    Private Const FRAG_SHADER_SRC As String =
        "#version 450" & vbLf &
        "#extension GL_ARB_separate_shader_objects : enable" & vbLf &
        "layout(location = 0) in vec2 fragCoord;" & vbLf &
        "layout(location = 0) out vec4 outColor;" & vbLf &
        "// Push constants: time and resolution passed from the CPU each frame" & vbLf &
        "layout(push_constant) uniform PushConstants {" & vbLf &
        "    float iTime;" & vbLf &
        "    float padding;" & vbLf &
        "    vec2 iResolution;" & vbLf &
        "} pc;" & vbLf &
        "const int MAX_STEPS = 100;" & vbLf &
        "const float MAX_DIST = 100.0;" & vbLf &
        "const float SURF_DIST = 0.001;" & vbLf &
        "// Sphere SDF" & vbLf &
        "float sdSphere(vec3 p, float r) { return length(p) - r; }" & vbLf &
        "// Box SDF" & vbLf &
        "float sdBox(vec3 p, vec3 b) {" & vbLf &
        "    vec3 q = abs(p) - b;" & vbLf &
        "    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);" & vbLf &
        "}" & vbLf &
        "// Torus SDF" & vbLf &
        "float sdTorus(vec3 p, vec2 t) {" & vbLf &
        "    vec2 q = vec2(length(p.xz) - t.x, p.y);" & vbLf &
        "    return length(q) - t.y;" & vbLf &
        "}" & vbLf &
        "// Smooth minimum for blending two shapes" & vbLf &
        "float smin(float a, float b, float k) {" & vbLf &
        "    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);" & vbLf &
        "    return mix(b, a, h) - k * h * (1.0 - h);" & vbLf &
        "}" & vbLf &
        "// Combined scene distance function" & vbLf &
        "float GetDist(vec3 p) {" & vbLf &
        "    // Animated sphere bouncing on a sinusoidal path" & vbLf &
        "    float sphere = sdSphere(p - vec3(sin(pc.iTime) * 1.5, 0.5 + sin(pc.iTime * 2.0) * 0.3, 0.0), 0.5);" & vbLf &
        "    // Torus rotating in XZ then XY axes" & vbLf &
        "    float angle = pc.iTime * 0.5;" & vbLf &
        "    vec3 tp = p - vec3(0.0, 0.5, 0.0);" & vbLf &
        "    float cosA = cos(angle), sinA = sin(angle);" & vbLf &
        "    vec2 rxz = vec2(cosA * tp.x - sinA * tp.z, sinA * tp.x + cosA * tp.z);" & vbLf &
        "    tp.x = rxz.x; tp.z = rxz.y;" & vbLf &
        "    float angle2 = angle * 0.7;" & vbLf &
        "    float cosA2 = cos(angle2), sinA2 = sin(angle2);" & vbLf &
        "    vec2 rxy = vec2(cosA2 * tp.x - sinA2 * tp.y, sinA2 * tp.x + cosA2 * tp.y);" & vbLf &
        "    tp.x = rxy.x; tp.y = rxy.y;" & vbLf &
        "    float torus = sdTorus(tp, vec2(0.8, 0.2));" & vbLf &
        "    // Ground plane at y = -0.5" & vbLf &
        "    float plane = p.y + 0.5;" & vbLf &
        "    // Smooth blend sphere and torus, then min with plane" & vbLf &
        "    float d = smin(sphere, torus, 0.3);" & vbLf &
        "    d = min(d, plane);" & vbLf &
        "    return d;" & vbLf &
        "}" & vbLf &
        "// Sphere-tracing ray marcher" & vbLf &
        "float RayMarch(vec3 ro, vec3 rd) {" & vbLf &
        "    float d = 0.0;" & vbLf &
        "    for (int i = 0; i < MAX_STEPS; i++) {" & vbLf &
        "        vec3 p = ro + rd * d;" & vbLf &
        "        float ds = GetDist(p);" & vbLf &
        "        d += ds;" & vbLf &
        "        if (d > MAX_DIST || ds < SURF_DIST) break;" & vbLf &
        "    }" & vbLf &
        "    return d;" & vbLf &
        "}" & vbLf &
        "// Estimate surface normal via finite differences" & vbLf &
        "vec3 GetNormal(vec3 p) {" & vbLf &
        "    float d = GetDist(p);" & vbLf &
        "    vec2 e = vec2(0.001, 0.0);" & vbLf &
        "    vec3 n = d - vec3(GetDist(p - e.xyy), GetDist(p - e.yxy), GetDist(p - e.yyx));" & vbLf &
        "    return normalize(n);" & vbLf &
        "}" & vbLf &
        "// Soft shadow (64 march steps, penumbra factor k)" & vbLf &
        "float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {" & vbLf &
        "    float res = 1.0;" & vbLf &
        "    float t = mint;" & vbLf &
        "    for (int i = 0; i < 64; i++) {" & vbLf &
        "        if (t >= maxt) break;" & vbLf &
        "        float h = GetDist(ro + rd * t);" & vbLf &
        "        if (h < 0.001) return 0.0;" & vbLf &
        "        res = min(res, k * h / t);" & vbLf &
        "        t += h;" & vbLf &
        "    }" & vbLf &
        "    return res;" & vbLf &
        "}" & vbLf &
        "// Ambient occlusion (5 sample steps along normal)" & vbLf &
        "float GetAO(vec3 p, vec3 n) {" & vbLf &
        "    float occ = 0.0, sca = 1.0;" & vbLf &
        "    for (int i = 0; i < 5; i++) {" & vbLf &
        "        float h = 0.01 + 0.12 * float(i) / 4.0;" & vbLf &
        "        float d = GetDist(p + h * n);" & vbLf &
        "        occ += (h - d) * sca;" & vbLf &
        "        sca *= 0.95;" & vbLf &
        "    }" & vbLf &
        "    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);" & vbLf &
        "}" & vbLf &
        "void main() {" & vbLf &
        "    // Map UV to [-0.5, 0.5] and correct for aspect ratio" & vbLf &
        "    vec2 uv = fragCoord - 0.5;" & vbLf &
        "    uv.x *= pc.iResolution.x / pc.iResolution.y;" & vbLf &
        "    // Camera: positioned above and behind the scene" & vbLf &
        "    vec3 ro = vec3(0.0, 1.5, -4.0);" & vbLf &
        "    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));" & vbLf &
        "    // Light source above and to the right" & vbLf &
        "    vec3 lightPos = vec3(3.0, 5.0, -2.0);" & vbLf &
        "    float d = RayMarch(ro, rd);" & vbLf &
        "    vec3 col = vec3(0.0);" & vbLf &
        "    if (d < MAX_DIST) {" & vbLf &
        "        vec3 p = ro + rd * d;" & vbLf &
        "        vec3 n = GetNormal(p);" & vbLf &
        "        vec3 l = normalize(lightPos - p);" & vbLf &
        "        vec3 v = normalize(ro - p);" & vbLf &
        "        vec3 r = reflect(-l, n);" & vbLf &
        "        // Material: blue-ish for shapes, checkerboard for floor" & vbLf &
        "        vec3 matCol = vec3(0.4, 0.6, 0.9);" & vbLf &
        "        if (p.y < -0.49) {" & vbLf &
        "            float check = mod(floor(p.x) + floor(p.z), 2.0);" & vbLf &
        "            matCol = mix(vec3(0.2, 0.2, 0.2), vec3(0.8, 0.8, 0.8), check);" & vbLf &
        "        }" & vbLf &
        "        float diff   = max(dot(n, l), 0.0);" & vbLf &
        "        float spec   = pow(max(dot(r, v), 0.0), 32.0);" & vbLf &
        "        float ao     = GetAO(p, n);" & vbLf &
        "        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);" & vbLf &
        "        vec3 ambient = vec3(0.1, 0.12, 0.15);" & vbLf &
        "        col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;" & vbLf &
        "        // Distance-based fog blending into the background" & vbLf &
        "        col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));" & vbLf &
        "    } else {" & vbLf &
        "        // Sky: vertical gradient from dark blue to near-black" & vbLf &
        "        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);" & vbLf &
        "    }" & vbLf &
        "    // Gamma correction (approximate sRGB)" & vbLf &
        "    col = pow(col, vec3(0.4545));" & vbLf &
        "    outColor = vec4(col, 1.0);" & vbLf &
        "}"

    ' ---- Win32 helpers ----
    <DllImport("kernel32.dll", CharSet:=CharSet.Auto)>
    Private Shared Function GetModuleHandle(ByVal lpModuleName As String) As IntPtr
    End Function

    ' ---- Vulkan enumerations ----
    Public Enum VkPhysicalDeviceType
        VK_PHYSICAL_DEVICE_TYPE_OTHER = 0
        VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = 1
        VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = 2
        VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = 3
        VK_PHYSICAL_DEVICE_TYPE_CPU = 4
    End Enum

    Public Enum VkDebugUtilsMessageSeverityFlagsEXT As UInteger
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT = &H1UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT = &H10UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT = &H100UI
        VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT = &H1000UI
    End Enum

    Public Enum VkDebugUtilsMessageTypeFlagsEXT As UInteger
        VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT = &H1UI
        VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT = &H2UI
        VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT = &H4UI
    End Enum

    Public Enum VkStructureType As UInteger
        VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
        VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
        VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
        VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
        VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9
        VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
        VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO = 27
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
        VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
        VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
        VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001001
        VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT = 1000128004
    End Enum

    Public Enum VkFormat As Integer
        VK_FORMAT_UNDEFINED = 0
        VK_FORMAT_B8G8R8A8_SRGB = 50
        VK_FORMAT_B8G8R8A8_UNORM = 44
        VK_FORMAT_R8G8B8A8_SRGB = 43
    End Enum

    Public Enum VkColorSpaceKHR
        VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
    End Enum

    Public Enum VkPresentModeKHR
        VK_PRESENT_MODE_IMMEDIATE_KHR = 0
        VK_PRESENT_MODE_MAILBOX_KHR = 1
        VK_PRESENT_MODE_FIFO_KHR = 2
        VK_PRESENT_MODE_FIFO_RELAXED_KHR = 3
    End Enum

    Public Enum VkSharingMode
        VK_SHARING_MODE_EXCLUSIVE = 0
        VK_SHARING_MODE_CONCURRENT = 1
    End Enum

    Public Enum VkImageUsageFlags As UInteger
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = &H10UI
    End Enum

    Public Enum VkCompositeAlphaFlagsKHR As UInteger
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = &H1UI
    End Enum

    Public Enum VkImageViewType
        VK_IMAGE_VIEW_TYPE_2D = 1
    End Enum

    Public Enum VkComponentSwizzle
        VK_COMPONENT_SWIZZLE_IDENTITY = 0
    End Enum

    Public Enum VkImageAspectFlags As UInteger
        VK_IMAGE_ASPECT_COLOR_BIT = &H1UI
    End Enum

    Public Enum VkShaderStageFlags As UInteger
        VK_SHADER_STAGE_VERTEX_BIT = &H1UI
        VK_SHADER_STAGE_FRAGMENT_BIT = &H10UI
    End Enum

    Public Enum VkPrimitiveTopology
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
    End Enum

    Public Enum VkPolygonMode
        VK_POLYGON_MODE_FILL = 0
    End Enum

    Public Enum VkCullModeFlags As UInteger
        VK_CULL_MODE_NONE = 0
        VK_CULL_MODE_BACK_BIT = &H2UI
    End Enum

    Public Enum VkFrontFace
        VK_FRONT_FACE_COUNTER_CLOCKWISE = 0
        VK_FRONT_FACE_CLOCKWISE = 1
    End Enum

    Public Enum VkSampleCountFlags As UInteger
        VK_SAMPLE_COUNT_1_BIT = &H1UI
    End Enum

    Public Enum VkBlendFactor
        VK_BLEND_FACTOR_ZERO = 0
        VK_BLEND_FACTOR_ONE = 1
    End Enum

    Public Enum VkBlendOp
        VK_BLEND_OP_ADD = 0
    End Enum

    Public Enum VkColorComponentFlags As UInteger
        VK_COLOR_COMPONENT_R_BIT = &H1UI
        VK_COLOR_COMPONENT_G_BIT = &H2UI
        VK_COLOR_COMPONENT_B_BIT = &H4UI
        VK_COLOR_COMPONENT_A_BIT = &H8UI
    End Enum

    Public Enum VkAttachmentLoadOp
        VK_ATTACHMENT_LOAD_OP_CLEAR = 1
        VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
    End Enum

    Public Enum VkAttachmentStoreOp
        VK_ATTACHMENT_STORE_OP_STORE = 0
        VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
    End Enum

    Public Enum VkImageLayout
        VK_IMAGE_LAYOUT_UNDEFINED = 0
        VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
    End Enum

    Public Enum VkPipelineBindPoint
        VK_PIPELINE_BIND_POINT_GRAPHICS = 0
    End Enum

    Public Enum VkCommandPoolCreateFlags As UInteger
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = &H2UI
    End Enum

    Public Enum VkCommandBufferLevel
        VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
    End Enum

    Public Enum VkSubpassContents
        VK_SUBPASS_CONTENTS_INLINE = 0
    End Enum

    Public Enum VkPipelineStageFlags As UInteger
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = &H400UI
    End Enum

    Public Enum VkCommandBufferUsageFlags As UInteger
        VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT = &H4UI
    End Enum

    Public Enum VkResult
        VK_SUCCESS = 0
        VK_NOT_READY = 1
        VK_ERROR_OUT_OF_HOST_MEMORY = -1
        VK_ERROR_DEVICE_LOST = -4
        VK_ERROR_SURFACE_LOST_KHR = -1000000000
        VK_SUBOPTIMAL_KHR = 1000001003
        VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    End Enum

    Public Enum VkBool32
        [False] = 0
        [True] = 1
    End Enum

    ' Dynamic state tokens (viewport and scissor are set per-frame)
    Public Enum VkDynamicState As UInteger
        VK_DYNAMIC_STATE_VIEWPORT = 0
        VK_DYNAMIC_STATE_SCISSOR = 1
    End Enum

    ' ---- Vulkan structures ----
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkOffset2D
        Public x As Integer
        Public y As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent2D
        Public width As UInteger
        Public height As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkExtent3D
        Public width As UInteger
        Public height As UInteger
        Public depth As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRect2D
        Public offset As VkOffset2D
        Public extent As VkExtent2D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkViewport
        Public x As Single
        Public y As Single
        Public width As Single
        Public height As Single
        Public minDepth As Single
        Public maxDepth As Single
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkApplicationInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        <MarshalAs(UnmanagedType.LPStr)> Public pApplicationName As String
        Public applicationVersion As UInteger
        <MarshalAs(UnmanagedType.LPStr)> Public pEngineName As String
        Public engineVersion As UInteger
        Public apiVersion As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkInstanceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public pApplicationInfo As IntPtr
        Public enabledLayerCount As UInteger
        Public ppEnabledLayerNames As IntPtr
        Public enabledExtensionCount As UInteger
        Public ppEnabledExtensionNames As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkPhysicalDeviceProperties
        Public apiVersion As UInteger
        Public driverVersion As UInteger
        Public vendorID As UInteger
        Public deviceID As UInteger
        Public deviceType As VkPhysicalDeviceType
        <MarshalAs(UnmanagedType.ByValTStr, SizeConst:=256)> Public deviceName As String
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=16)> Public pipelineCacheUUID() As Byte
        Public limits As VkPhysicalDeviceLimits
        Public sparseProperties As VkPhysicalDeviceSparseProperties
    End Structure

    ' Large structure holding all hardware limits - only a subset is used here.
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceLimits
        Public maxImageDimension1D As UInteger
        Public maxImageDimension2D As UInteger
        Public maxImageDimension3D As UInteger
        Public maxImageDimensionCube As UInteger
        Public maxImageArrayLayers As UInteger
        Public maxTexelBufferElements As UInteger
        Public maxUniformBufferRange As UInteger
        Public maxStorageBufferRange As UInteger
        Public maxPushConstantsSize As UInteger
        Public maxMemoryAllocationCount As UInteger
        Public maxSamplerAllocationCount As UInteger
        Public bufferImageGranularity As ULong
        Public sparseAddressSpaceSize As ULong
        Public maxBoundDescriptorSets As UInteger
        Public maxPerStageDescriptorSamplers As UInteger
        Public maxPerStageDescriptorUniformBuffers As UInteger
        Public maxPerStageDescriptorStorageBuffers As UInteger
        Public maxPerStageDescriptorSampledImages As UInteger
        Public maxPerStageDescriptorStorageImages As UInteger
        Public maxPerStageDescriptorInputAttachments As UInteger
        Public maxPerStageResources As UInteger
        Public maxDescriptorSetSamplers As UInteger
        Public maxDescriptorSetUniformBuffers As UInteger
        Public maxDescriptorSetUniformBuffersDynamic As UInteger
        Public maxDescriptorSetStorageBuffers As UInteger
        Public maxDescriptorSetStorageBuffersDynamic As UInteger
        Public maxDescriptorSetSampledImages As UInteger
        Public maxDescriptorSetStorageImages As UInteger
        Public maxDescriptorSetInputAttachments As UInteger
        Public maxVertexInputAttributes As UInteger
        Public maxVertexInputBindings As UInteger
        Public maxVertexInputAttributeOffset As UInteger
        Public maxVertexInputBindingStride As UInteger
        Public maxVertexOutputComponents As UInteger
        Public maxTessellationGenerationLevel As UInteger
        Public maxTessellationPatchSize As UInteger
        Public maxTessellationControlPerVertexInputComponents As UInteger
        Public maxTessellationControlPerVertexOutputComponents As UInteger
        Public maxTessellationControlPerPatchOutputComponents As UInteger
        Public maxTessellationControlTotalOutputComponents As UInteger
        Public maxTessellationEvaluationInputComponents As UInteger
        Public maxTessellationEvaluationOutputComponents As UInteger
        Public maxGeometryShaderInvocations As UInteger
        Public maxGeometryInputComponents As UInteger
        Public maxGeometryOutputComponents As UInteger
        Public maxGeometryOutputVertices As UInteger
        Public maxGeometryTotalOutputComponents As UInteger
        Public maxFragmentInputComponents As UInteger
        Public maxFragmentOutputAttachments As UInteger
        Public maxFragmentDualSrcAttachments As UInteger
        Public maxFragmentCombinedOutputResources As UInteger
        Public maxComputeSharedMemorySize As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=3)> Public maxComputeWorkGroupCount() As UInteger
        Public maxComputeWorkGroupInvocations As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=3)> Public maxComputeWorkGroupSize() As UInteger
        Public subPixelPrecisionBits As UInteger
        Public subTexelPrecisionBits As UInteger
        Public mipmapPrecisionBits As UInteger
        Public maxDrawIndexedIndexValue As UInteger
        Public maxDrawIndirectCount As UInteger
        Public maxSamplerLodBias As Single
        Public maxSamplerAnisotropy As Single
        Public maxViewports As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public maxViewportDimensions() As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public viewportBoundsRange() As Single
        Public viewportSubPixelBits As UInteger
        Public minMemoryMapAlignment As UIntPtr
        Public minTexelBufferOffsetAlignment As ULong
        Public minUniformBufferOffsetAlignment As ULong
        Public minStorageBufferOffsetAlignment As ULong
        Public minTexelOffset As Integer
        Public maxTexelOffset As UInteger
        Public minTexelGatherOffset As Integer
        Public maxTexelGatherOffset As UInteger
        Public minInterpolationOffset As Single
        Public maxInterpolationOffset As Single
        Public subPixelInterpolationOffsetBits As UInteger
        Public maxFramebufferWidth As UInteger
        Public maxFramebufferHeight As UInteger
        Public maxFramebufferLayers As UInteger
        Public framebufferColorSampleCounts As UInteger
        Public framebufferDepthSampleCounts As UInteger
        Public framebufferStencilSampleCounts As UInteger
        Public framebufferNoAttachmentsSampleCounts As UInteger
        Public maxColorAttachments As UInteger
        Public sampledImageColorSampleCounts As UInteger
        Public sampledImageIntegerSampleCounts As UInteger
        Public sampledImageDepthSampleCounts As UInteger
        Public sampledImageStencilSampleCounts As UInteger
        Public storageImageSampleCounts As UInteger
        Public maxSampleMaskWords As UInteger
        Public timestampComputeAndGraphics As UInteger
        Public timestampPeriod As Single
        Public maxClipDistances As UInteger
        Public maxCullDistances As UInteger
        Public maxCombinedClipAndCullDistances As UInteger
        Public discreteQueuePriorities As UInteger
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public pointSizeRange() As Single
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> Public lineWidthRange() As Single
        Public pointSizeGranularity As Single
        Public lineWidthGranularity As Single
        Public strictLines As UInteger
        Public standardSampleLocations As UInteger
        Public optimalBufferCopyOffsetAlignment As ULong
        Public optimalBufferCopyRowPitchAlignment As ULong
        Public nonCoherentAtomSize As ULong
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceSparseProperties
        Public residencyStandard2DBlockShape As UInteger
        Public residencyStandard2DMultisampleBlockShape As UInteger
        Public residencyStandard3DBlockShape As UInteger
        Public residencyAlignedMipSize As UInteger
        Public residencyNonResidentStrict As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkQueueFamilyProperties
        Public queueFlags As UInteger
        Public queueCount As UInteger
        Public timestampValidBits As UInteger
        Public minImageTransferGranularity As VkExtent3D
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPhysicalDeviceFeatures
        ' 55 boolean fields - all zeroed by default (no special features required)
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=55)>
        Public fields() As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceQueueCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public queueFamilyIndex As UInteger
        Public queueCount As UInteger
        Public pQueuePriorities As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDeviceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public queueCreateInfoCount As UInteger
        Public pQueueCreateInfos As IntPtr
        Public enabledLayerCount As UInteger
        Public ppEnabledLayerNames As IntPtr
        Public enabledExtensionCount As UInteger
        Public ppEnabledExtensionNames As IntPtr
        Public pEnabledFeatures As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkWin32SurfaceCreateInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public hinstance As IntPtr
        Public hwnd As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceCapabilitiesKHR
        Public minImageCount As UInteger
        Public maxImageCount As UInteger
        Public currentExtent As VkExtent2D
        Public minImageExtent As VkExtent2D
        Public maxImageExtent As VkExtent2D
        Public maxImageArrayLayers As UInteger
        Public supportedTransforms As UInteger
        Public currentTransform As UInteger
        Public supportedCompositeAlpha As UInteger
        Public supportedUsageFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSurfaceFormatKHR
        Public format As VkFormat
        Public colorSpace As VkColorSpaceKHR
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSwapchainCreateInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public surface As IntPtr
        Public minImageCount As UInteger
        Public imageFormat As VkFormat
        Public imageColorSpace As VkColorSpaceKHR
        Public imageExtent As VkExtent2D
        Public imageArrayLayers As UInteger
        Public imageUsage As VkImageUsageFlags
        Public imageSharingMode As VkSharingMode
        Public queueFamilyIndexCount As UInteger
        Public pQueueFamilyIndices As IntPtr
        Public preTransform As UInteger
        Public compositeAlpha As VkCompositeAlphaFlagsKHR
        Public presentMode As VkPresentModeKHR
        Public clipped As VkBool32
        Public oldSwapchain As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkComponentMapping
        Public r As VkComponentSwizzle
        Public g As VkComponentSwizzle
        Public b As VkComponentSwizzle
        Public a As VkComponentSwizzle
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageSubresourceRange
        Public aspectMask As VkImageAspectFlags
        Public baseMipLevel As UInteger
        Public levelCount As UInteger
        Public baseArrayLayer As UInteger
        Public layerCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkImageViewCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public image As IntPtr
        Public viewType As VkImageViewType
        Public format As VkFormat
        Public components As VkComponentMapping
        Public subresourceRange As VkImageSubresourceRange
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkShaderModuleCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public codeSize As UIntPtr
        Public pCode As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineShaderStageCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public stage As VkShaderStageFlags
        Public [module] As IntPtr
        Public pName As IntPtr
        Public pSpecializationInfo As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineVertexInputStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public vertexBindingDescriptionCount As UInteger
        Public pVertexBindingDescriptions As IntPtr
        Public vertexAttributeDescriptionCount As UInteger
        Public pVertexAttributeDescriptions As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineInputAssemblyStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public topology As VkPrimitiveTopology
        Public primitiveRestartEnable As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineViewportStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public viewportCount As UInteger
        Public pViewports As IntPtr
        Public scissorCount As UInteger
        Public pScissors As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineRasterizationStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public depthClampEnable As VkBool32
        Public rasterizerDiscardEnable As VkBool32
        Public polygonMode As VkPolygonMode
        Public cullMode As VkCullModeFlags
        Public frontFace As VkFrontFace
        Public depthBiasEnable As VkBool32
        Public depthBiasConstantFactor As Single
        Public depthBiasClamp As Single
        Public depthBiasSlopeFactor As Single
        Public lineWidth As Single
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineMultisampleStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public rasterizationSamples As VkSampleCountFlags
        Public sampleShadingEnable As VkBool32
        Public minSampleShading As Single
        Public pSampleMask As IntPtr
        Public alphaToCoverageEnable As VkBool32
        Public alphaToOneEnable As VkBool32
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendAttachmentState
        Public blendEnable As VkBool32
        Public srcColorBlendFactor As VkBlendFactor
        Public dstColorBlendFactor As VkBlendFactor
        Public colorBlendOp As VkBlendOp
        Public srcAlphaBlendFactor As VkBlendFactor
        Public dstAlphaBlendFactor As VkBlendFactor
        Public alphaBlendOp As VkBlendOp
        Public colorWriteMask As VkColorComponentFlags
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineColorBlendStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public logicOpEnable As VkBool32
        Public logicOp As Integer
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        <MarshalAs(UnmanagedType.ByValArray, SizeConst:=4)> Public blendConstants() As Single
    End Structure

    ''' <summary>Specifies the stage range and size for push constant data.</summary>
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPushConstantRange
        Public stageFlags As VkShaderStageFlags
        Public offset As UInteger
        Public size As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineLayoutCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public setLayoutCount As UInteger
        Public pSetLayouts As IntPtr
        Public pushConstantRangeCount As UInteger
        Public pPushConstantRanges As IntPtr
    End Structure

    ''' <summary>Specifies which pipeline states use dynamic commands instead of baked values.</summary>
    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPipelineDynamicStateCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public dynamicStateCount As UInteger
        Public pDynamicStates As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentDescription
        Public flags As UInteger
        Public format As VkFormat
        Public samples As VkSampleCountFlags
        Public loadOp As VkAttachmentLoadOp
        Public storeOp As VkAttachmentStoreOp
        Public stencilLoadOp As VkAttachmentLoadOp
        Public stencilStoreOp As VkAttachmentStoreOp
        Public initialLayout As VkImageLayout
        Public finalLayout As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkAttachmentReference
        Public attachment As UInteger
        Public layout As VkImageLayout
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubpassDescription
        Public flags As UInteger
        Public pipelineBindPoint As VkPipelineBindPoint
        Public inputAttachmentCount As UInteger
        Public pInputAttachments As IntPtr
        Public colorAttachmentCount As UInteger
        Public pColorAttachments As IntPtr
        Public pResolveAttachments As IntPtr
        Public pDepthStencilAttachment As IntPtr
        Public preserveAttachmentCount As UInteger
        Public pPreserveAttachments As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubpassDependency
        Public srcSubpass As UInteger
        Public dstSubpass As UInteger
        Public srcStageMask As VkPipelineStageFlags
        Public dstStageMask As VkPipelineStageFlags
        Public srcAccessMask As UInteger
        Public dstAccessMask As UInteger
        Public dependencyFlags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        Public subpassCount As UInteger
        Public pSubpasses As IntPtr
        Public dependencyCount As UInteger
        Public pDependencies As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkGraphicsPipelineCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public stageCount As UInteger
        Public pStages As IntPtr
        Public pVertexInputState As IntPtr
        Public pInputAssemblyState As IntPtr
        Public pTessellationState As IntPtr
        Public pViewportState As IntPtr
        Public pRasterizationState As IntPtr
        Public pMultisampleState As IntPtr
        Public pDepthStencilState As IntPtr
        Public pColorBlendState As IntPtr
        Public pDynamicState As IntPtr
        Public layout As IntPtr
        Public renderPass As IntPtr
        Public subpass As UInteger
        Public basePipelineHandle As IntPtr
        Public basePipelineIndex As Integer
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkFramebufferCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public renderPass As IntPtr
        Public attachmentCount As UInteger
        Public pAttachments As IntPtr
        Public width As UInteger
        Public height As UInteger
        Public layers As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandPoolCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As VkCommandPoolCreateFlags
        Public queueFamilyIndex As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferAllocateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public commandPool As IntPtr
        Public level As VkCommandBufferLevel
        Public commandBufferCount As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkCommandBufferBeginInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As VkCommandBufferUsageFlags
        Public pInheritanceInfo As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkClearColorValue
        Public float32_0 As Single
        Public float32_1 As Single
        Public float32_2 As Single
        Public float32_3 As Single
    End Structure

    <StructLayout(LayoutKind.Explicit)>
    Public Structure VkClearValue
        <FieldOffset(0)> Public color As VkClearColorValue
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkRenderPassBeginInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public renderPass As IntPtr
        Public framebuffer As IntPtr
        Public renderArea As VkRect2D
        Public clearValueCount As UInteger
        Public pClearValues As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSubmitInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public waitSemaphoreCount As UInteger
        Public pWaitSemaphores As IntPtr
        Public pWaitDstStageMask As IntPtr
        Public commandBufferCount As UInteger
        Public pCommandBuffers As IntPtr
        Public signalSemaphoreCount As UInteger
        Public pSignalSemaphores As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkPresentInfoKHR
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public waitSemaphoreCount As UInteger
        Public pWaitSemaphores As IntPtr
        Public swapchainCount As UInteger
        Public pSwapchains As IntPtr
        Public pImageIndices As IntPtr
        Public pResults As IntPtr
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkSemaphoreCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkFenceCreateInfo
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
    End Structure

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Ansi)>
    Public Structure VkDebugUtilsMessengerCallbackDataEXT
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        <MarshalAs(UnmanagedType.LPStr)> Public pMessageIdName As String
        Public messageIdNumber As Integer
        <MarshalAs(UnmanagedType.LPStr)> Public pMessage As String
        Public queueLabelCount As UInteger
        Public pQueueLabels As IntPtr
        Public cmdBufLabelCount As UInteger
        Public pCmdBufLabels As IntPtr
        Public objectCount As UInteger
        Public pObjects As IntPtr
    End Structure

    ''' <summary>Push constant block layout matching the GLSL shader declaration.</summary>
    <StructLayout(LayoutKind.Sequential)>
    Public Structure PushConstants
        Public iTime As Single       ' Elapsed time in seconds
        Public padding As Single     ' Alignment padding (unused)
        Public iResolutionX As Single ' Viewport width
        Public iResolutionY As Single ' Viewport height
    End Structure

    Delegate Function DebugCallback(ByVal messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT,
                                     ByVal messageTypes As VkDebugUtilsMessageTypeFlagsEXT,
                                     ByRef pCallbackData As VkDebugUtilsMessengerCallbackDataEXT,
                                     ByVal pUserData As IntPtr) As VkBool32

    <StructLayout(LayoutKind.Sequential)>
    Public Structure VkDebugUtilsMessengerCreateInfoEXT
        Public sType As VkStructureType
        Public pNext As IntPtr
        Public flags As UInteger
        Public messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT
        Public messageType As VkDebugUtilsMessageTypeFlagsEXT
        Public pfnUserCallback As IntPtr
        Public pUserData As IntPtr
    End Structure

    ' ---- Vulkan function imports ----
    Private Const VulkanLib As String = "vulkan-1.dll"

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateInstance(ByRef pCreateInfo As VkInstanceCreateInfo, ByVal pAllocator As IntPtr, ByRef pInstance As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyInstance(ByVal instance As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkEnumeratePhysicalDevices(ByVal instance As IntPtr, ByRef pPhysicalDeviceCount As UInteger, ByVal pPhysicalDevices As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetPhysicalDeviceProperties(ByVal physicalDevice As IntPtr, ByRef pProperties As VkPhysicalDeviceProperties)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetPhysicalDeviceQueueFamilyProperties(ByVal physicalDevice As IntPtr, ByRef pQueueFamilyPropertyCount As UInteger, ByVal pQueueFamilyProperties As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateDevice(ByVal physicalDevice As IntPtr, ByRef pCreateInfo As VkDeviceCreateInfo, ByVal pAllocator As IntPtr, ByRef pDevice As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyDevice(ByVal device As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkGetDeviceQueue(ByVal device As IntPtr, ByVal queueFamilyIndex As UInteger, ByVal queueIndex As UInteger, ByRef pQueue As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall, CharSet:=CharSet.Ansi)>
    Private Shared Function vkGetInstanceProcAddr(ByVal instance As IntPtr, <MarshalAs(UnmanagedType.LPStr)> ByVal pName As String) As IntPtr
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceSupportKHR(ByVal physicalDevice As IntPtr, ByVal queueFamilyIndex As UInteger, ByVal surface As IntPtr, ByRef pSupported As VkBool32) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ByVal physicalDevice As IntPtr, ByVal surface As IntPtr, ByRef pSurfaceCapabilities As VkSurfaceCapabilitiesKHR) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetPhysicalDeviceSurfaceFormatsKHR(ByVal physicalDevice As IntPtr, ByVal surface As IntPtr, ByRef pSurfaceFormatCount As UInteger, ByVal pSurfaceFormats As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateSwapchainKHR(ByVal device As IntPtr, ByRef pCreateInfo As VkSwapchainCreateInfoKHR, ByVal pAllocator As IntPtr, ByRef pSwapchain As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySwapchainKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkGetSwapchainImagesKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByRef pSwapchainImageCount As UInteger, ByVal pSwapchainImages As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateImageView(ByVal device As IntPtr, ByRef pCreateInfo As VkImageViewCreateInfo, ByVal pAllocator As IntPtr, ByRef pImageView As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyImageView(ByVal device As IntPtr, ByVal imageView As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateShaderModule(ByVal device As IntPtr, ByRef pCreateInfo As VkShaderModuleCreateInfo, ByVal pAllocator As IntPtr, ByRef pShaderModule As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyShaderModule(ByVal device As IntPtr, ByVal shaderModule As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreatePipelineLayout(ByVal device As IntPtr, ByRef pCreateInfo As VkPipelineLayoutCreateInfo, ByVal pAllocator As IntPtr, ByRef pPipelineLayout As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyPipelineLayout(ByVal device As IntPtr, ByVal pipelineLayout As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateRenderPass(ByVal device As IntPtr, ByRef pCreateInfo As VkRenderPassCreateInfo, ByVal pAllocator As IntPtr, ByRef pRenderPass As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyRenderPass(ByVal device As IntPtr, ByVal renderPass As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateGraphicsPipelines(ByVal device As IntPtr, ByVal pipelineCache As IntPtr, ByVal createInfoCount As UInteger, ByVal pCreateInfos As IntPtr, ByVal pAllocator As IntPtr, ByVal pPipelines As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyPipeline(ByVal device As IntPtr, ByVal pipeline As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateFramebuffer(ByVal device As IntPtr, ByRef pCreateInfo As VkFramebufferCreateInfo, ByVal pAllocator As IntPtr, ByRef pFramebuffer As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyFramebuffer(ByVal device As IntPtr, ByVal framebuffer As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateCommandPool(ByVal device As IntPtr, ByRef pCreateInfo As VkCommandPoolCreateInfo, ByVal pAllocator As IntPtr, ByRef pCommandPool As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyCommandPool(ByVal device As IntPtr, ByVal commandPool As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkAllocateCommandBuffers(ByVal device As IntPtr, ByRef pAllocateInfo As VkCommandBufferAllocateInfo, ByVal pCommandBuffers As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkResetCommandBuffer(ByVal commandBuffer As IntPtr, ByVal flags As UInteger) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkBeginCommandBuffer(ByVal commandBuffer As IntPtr, ByRef pBeginInfo As VkCommandBufferBeginInfo) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkEndCommandBuffer(ByVal commandBuffer As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdBeginRenderPass(ByVal commandBuffer As IntPtr, ByRef pRenderPassBegin As VkRenderPassBeginInfo, ByVal contents As VkSubpassContents)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdEndRenderPass(ByVal commandBuffer As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdBindPipeline(ByVal commandBuffer As IntPtr, ByVal pipelineBindPoint As VkPipelineBindPoint, ByVal pipeline As IntPtr)
    End Sub

    ' Sets the viewport dynamically each frame (allows resize without pipeline rebuild)
    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdSetViewport(ByVal commandBuffer As IntPtr, ByVal firstViewport As UInteger, ByVal viewportCount As UInteger, ByRef pViewports As VkViewport)
    End Sub

    ' Sets the scissor rectangle dynamically each frame
    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdSetScissor(ByVal commandBuffer As IntPtr, ByVal firstScissor As UInteger, ByVal scissorCount As UInteger, ByRef pScissors As VkRect2D)
    End Sub

    ' Pushes small constant data (time, resolution) directly into the pipeline without a descriptor set
    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdPushConstants(ByVal commandBuffer As IntPtr, ByVal layout As IntPtr, ByVal stageFlags As VkShaderStageFlags, ByVal offset As UInteger, ByVal size As UInteger, ByVal pValues As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkCmdDraw(ByVal commandBuffer As IntPtr, ByVal vertexCount As UInteger, ByVal instanceCount As UInteger, ByVal firstVertex As UInteger, ByVal firstInstance As UInteger)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkQueueSubmit(ByVal queue As IntPtr, ByVal submitCount As UInteger, ByRef pSubmits As VkSubmitInfo, ByVal fence As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkDeviceWaitIdle(ByVal device As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkAcquireNextImageKHR(ByVal device As IntPtr, ByVal swapchain As IntPtr, ByVal timeout As ULong, ByVal semaphore As IntPtr, ByVal fence As IntPtr, ByRef pImageIndex As UInteger) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkQueuePresentKHR(ByVal queue As IntPtr, ByRef pPresentInfo As VkPresentInfoKHR) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateSemaphore(ByVal device As IntPtr, ByRef pCreateInfo As VkSemaphoreCreateInfo, ByVal pAllocator As IntPtr, ByRef pSemaphore As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySemaphore(ByVal device As IntPtr, ByVal semaphore As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkCreateFence(ByVal device As IntPtr, ByRef pCreateInfo As VkFenceCreateInfo, ByVal pAllocator As IntPtr, ByRef pFence As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroyFence(ByVal device As IntPtr, ByVal fence As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkWaitForFences(ByVal device As IntPtr, ByVal fenceCount As UInteger, ByRef pFences As IntPtr, ByVal waitAll As VkBool32, ByVal timeout As ULong) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Function vkResetFences(ByVal device As IntPtr, ByVal fenceCount As UInteger, ByRef pFences As IntPtr) As VkResult
    End Function

    <DllImport(VulkanLib, CallingConvention:=CallingConvention.StdCall)>
    Private Shared Sub vkDestroySurfaceKHR(ByVal instance As IntPtr, ByVal surface As IntPtr, ByVal pAllocator As IntPtr)
    End Sub

    Delegate Function vkCreateWin32SurfaceKHRFunc(ByVal instance As IntPtr, ByRef pCreateInfo As VkWin32SurfaceCreateInfoKHR, ByVal pAllocator As IntPtr, ByRef pSurface As IntPtr) As VkResult
    Delegate Function vkCreateDebugUtilsMessengerEXTFunc(ByVal instance As IntPtr, ByRef pCreateInfo As VkDebugUtilsMessengerCreateInfoEXT, ByVal pAllocator As IntPtr, ByRef pMessenger As IntPtr) As VkResult
    Delegate Sub vkDestroyDebugUtilsMessengerEXTFunc(ByVal instance As IntPtr, ByVal messenger As IntPtr, ByVal pAllocator As IntPtr)

    ' ---- Member variables ----
    Private instance As IntPtr
    Private physicalDevice As IntPtr
    Private device As IntPtr
    Private graphicsQueue As IntPtr
    Private presentQueue As IntPtr
    Private surface As IntPtr
    Private swapChain As IntPtr
    Private swapChainImages() As IntPtr
    Private swapChainImageViews() As IntPtr
    Private swapChainImageFormat As VkFormat
    Private swapChainExtent As VkExtent2D
    Private renderPass As IntPtr
    Private pipelineLayout As IntPtr
    Private graphicsPipeline As IntPtr
    Private swapChainFramebuffers() As IntPtr
    Private commandPool As IntPtr
    Private commandBuffers() As IntPtr  ' One per frame-in-flight
    Private imageAvailableSemaphores() As IntPtr
    Private renderFinishedSemaphores() As IntPtr
    Private inFlightFences() As IntPtr
    Private currentFrame As Integer = 0
    Private frameIndex As Integer = 0
    Private Const MAX_FRAMES_IN_FLIGHT As Integer = 2
    Private debugMessenger As IntPtr
    Private debugCallbackDelegate As DebugCallback
    Private vertShaderModule As IntPtr
    Private fragShaderModule As IntPtr

    ' Timer and stopwatch drive the animation loop
    Private animTimer As Timer
    Private stopwatch As New Stopwatch()

    ' ---- Constructor ----
    Public Sub New()
        Me.Text = "Raymarching - Vulkan 1.4 / VB.NET"
        Me.ClientSize = New Size(800, 600)
        Me.StartPosition = FormStartPosition.CenterScreen

        AddHandler Me.Load, AddressOf HandleLoad
        AddHandler Me.FormClosing, AddressOf HandleFormClosing
        AddHandler Me.Resize, AddressOf HandleResize

        DbgLog.Log("New: InitVulkan start")
        Try
            InitVulkan()
        Catch ex As Exception
            DbgLog.LogEx("New/InitVulkan", ex)
            MessageBox.Show("Vulkan init failed:" & vbCrLf & ex.Message & vbCrLf & vbCrLf & ex.StackTrace, _
                "Fatal Init Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
            Environment.Exit(1)
        End Try
        DbgLog.Log("New: InitVulkan complete")

        ' Start animation timer (~60 FPS)
        animTimer = New Timer()
        animTimer.Interval = 16
        AddHandler animTimer.Tick, AddressOf HandleTimerTick
        animTimer.Start()
        stopwatch.Start()
    End Sub

    Private Sub HandleLoad(ByVal sender As Object, ByVal e As EventArgs)
        DbgLog.Log("HandleLoad: window shown OK")
    End Sub

    Private Sub HandleFormClosing(ByVal sender As Object, ByVal e As FormClosingEventArgs)
        DbgLog.Log("HandleFormClosing: cleanup start")
        If animTimer IsNot Nothing Then animTimer.Stop()
        Cleanup()
    End Sub

    Private Sub HandleResize(ByVal sender As Object, ByVal e As EventArgs)
        DbgLog.LogFmt("HandleResize: {0}x{1}", ClientSize.Width, ClientSize.Height)
        If device <> IntPtr.Zero AndAlso ClientSize.Width > 0 AndAlso ClientSize.Height > 0 Then
            Try
                vkDeviceWaitIdle(device)
                RecreateSwapChain()
            Catch ex As Exception
                DbgLog.LogEx("HandleResize/RecreateSwapChain", ex)
            End Try
        End If
    End Sub

    Private Sub HandleTimerTick(ByVal sender As Object, ByVal e As EventArgs)
        Try
            DrawFrame()
        Catch ex As Exception
            DbgLog.LogEx("HandleTimerTick/DrawFrame frame=" & frameIndex.ToString(), ex)
            animTimer.Stop()
            MessageBox.Show("DrawFrame exception:" & vbCrLf & ex.Message & vbCrLf & vbCrLf & ex.StackTrace, _
                "Fatal DrawFrame Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
        End Try
    End Sub

    Protected Overrides Sub OnPaintBackground(ByVal e As PaintEventArgs)
        ' Suppress default background painting to avoid flicker
    End Sub

    ' ---- Initialization ----
    Private Sub InitVulkan()
        DbgLog.Log("InitVulkan: [ 1/13] CreateInstance")            : CreateInstance()
        DbgLog.Log("InitVulkan: [ 2/13] SetupDebugMessenger")       : SetupDebugMessenger()
        DbgLog.Log("InitVulkan: [ 3/13] CreateSurface")             : CreateSurface()
        DbgLog.Log("InitVulkan: [ 4/13] PickPhysicalDevice")        : PickPhysicalDevice()
        DbgLog.Log("InitVulkan: [ 5/13] CreateLogicalDevice")       : CreateLogicalDevice()
        DbgLog.Log("InitVulkan: [ 6/13] CreateSwapChain")           : CreateSwapChain()
        DbgLog.Log("InitVulkan: [ 7/13] CreateSwapChainImageViews") : CreateSwapChainImageViews()
        DbgLog.Log("InitVulkan: [ 8/13] CreateRenderPass")          : CreateRenderPass()
        DbgLog.Log("InitVulkan: [ 9/13] CreateGraphicsPipeline")    : CreateGraphicsPipeline()
        DbgLog.Log("InitVulkan: [10/13] CreateFramebuffers")        : CreateFramebuffers()
        DbgLog.Log("InitVulkan: [11/13] CreateCommandPool")         : CreateCommandPool()
        DbgLog.Log("InitVulkan: [12/13] CreateCommandBuffer")       : CreateCommandBuffer()
        DbgLog.Log("InitVulkan: [13/13] CreateSyncObjects")         : CreateSyncObjects()
        DbgLog.Log("InitVulkan: *** ALL STEPS COMPLETE ***")
    End Sub

    ' ---- Instance ----
    Private Sub CreateInstance()
        Dim appInfo As New VkApplicationInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Vulkan Raymarching VB.NET",
            .applicationVersion = MakeVersion(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = MakeVersion(1, 0, 0),
            .apiVersion = MakeVersion(1, 4, 0)
        }

        Dim extensions() As String = {"VK_KHR_surface", "VK_KHR_win32_surface", "VK_EXT_debug_utils"}
        Dim extensionsPtr As IntPtr = StringArrayToPtr(extensions)

        Dim validationLayers() As String = {"VK_LAYER_KHRONOS_validation"}
        Dim layersPtr As IntPtr = StringArrayToPtr(validationLayers)

        Dim appInfoPtr As IntPtr = Marshal.AllocHGlobal(Marshal.SizeOf(GetType(VkApplicationInfo)))
        Marshal.StructureToPtr(appInfo, appInfoPtr, False)

        Try
            Dim createInfo As New VkInstanceCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo = appInfoPtr,
                .enabledExtensionCount = CUInt(extensions.Length),
                .ppEnabledExtensionNames = extensionsPtr,
                .enabledLayerCount = CUInt(validationLayers.Length),
                .ppEnabledLayerNames = layersPtr
            }

            If vkCreateInstance(createInfo, IntPtr.Zero, instance) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create Vulkan instance!")
            End If
        Finally
            Marshal.DestroyStructure(appInfoPtr, GetType(VkApplicationInfo))
            Marshal.FreeHGlobal(appInfoPtr)
            FreeStringArray(extensionsPtr, extensions.Length)
            FreeStringArray(layersPtr, validationLayers.Length)
        End Try

        DbgLog.Log($"[CreateInstance] instance={instance}")
    End Sub

    ' ---- Debug messenger ----
    Private Sub SetupDebugMessenger()
        debugCallbackDelegate = AddressOf DebugCallbackFunction

        Dim createInfo As New VkDebugUtilsMessengerCreateInfoEXT With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .messageSeverity = VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT Or
                               VkDebugUtilsMessageSeverityFlagsEXT.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT Or
                           VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT Or
                           VkDebugUtilsMessageTypeFlagsEXT.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = Marshal.GetFunctionPointerForDelegate(debugCallbackDelegate)
        }

        Dim funcPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")
        If funcPtr <> IntPtr.Zero Then
            Dim fn As vkCreateDebugUtilsMessengerEXTFunc =
                CType(Marshal.GetDelegateForFunctionPointer(funcPtr, GetType(vkCreateDebugUtilsMessengerEXTFunc)), vkCreateDebugUtilsMessengerEXTFunc)
            fn(instance, createInfo, IntPtr.Zero, debugMessenger)
        End If
    End Sub

    Private Function DebugCallbackFunction(ByVal messageSeverity As VkDebugUtilsMessageSeverityFlagsEXT,
                                           ByVal messageTypes As VkDebugUtilsMessageTypeFlagsEXT,
                                           ByRef pCallbackData As VkDebugUtilsMessengerCallbackDataEXT,
                                           ByVal pUserData As IntPtr) As VkBool32
        DbgLog.Log($"[Validation] {pCallbackData.pMessage}")
        Return VkBool32.False
    End Function

    ' ---- Surface ----
    Private Sub CreateSurface()
        Dim createInfo As New VkWin32SurfaceCreateInfoKHR With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hinstance = GetModuleHandle(Nothing),
            .hwnd = Me.Handle
        }

        Dim funcPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkCreateWin32SurfaceKHR")
        Dim fn As vkCreateWin32SurfaceKHRFunc =
            CType(Marshal.GetDelegateForFunctionPointer(funcPtr, GetType(vkCreateWin32SurfaceKHRFunc)), vkCreateWin32SurfaceKHRFunc)

        If fn(instance, createInfo, IntPtr.Zero, surface) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create window surface!")
        End If
        DbgLog.Log($"[CreateSurface] surface={surface}")
    End Sub

    ' ---- Physical device ----
    Private Sub PickPhysicalDevice()
        Dim deviceCount As UInteger = 0
        vkEnumeratePhysicalDevices(instance, deviceCount, IntPtr.Zero)
        If deviceCount = 0 Then Throw New Exception("No GPUs with Vulkan support found!")

        Dim devices(deviceCount - 1) As IntPtr
        Dim h As GCHandle = GCHandle.Alloc(devices, GCHandleType.Pinned)
        Try
            vkEnumeratePhysicalDevices(instance, deviceCount, h.AddrOfPinnedObject())
            physicalDevice = devices(0)
        Finally
            h.Free()
        End Try

        Dim props As New VkPhysicalDeviceProperties()
        InitPhysicalDeviceProperties(props)
        vkGetPhysicalDeviceProperties(physicalDevice, props)
        DbgLog.Log($"[PickPhysicalDevice] GPU: {props.deviceName}")
    End Sub

    ' ---- Logical device ----
    Private Sub CreateLogicalDevice()
        Dim queueFamilyIndex As UInteger = FindQueueFamily()
        Dim queuePriority As Single = 1.0F
        Dim priorityHandle As GCHandle = GCHandle.Alloc(queuePriority, GCHandleType.Pinned)

        Dim queueCreateInfo As New VkDeviceQueueCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = queueFamilyIndex,
            .queueCount = 1,
            .pQueuePriorities = priorityHandle.AddrOfPinnedObject()
        }
        Dim queueHandle As GCHandle = GCHandle.Alloc(queueCreateInfo, GCHandleType.Pinned)

        Dim deviceExtensions() As String = {"VK_KHR_swapchain"}
        Dim extensionsPtr As IntPtr = StringArrayToPtr(deviceExtensions)

        Try
            Dim createInfo As New VkDeviceCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                .pQueueCreateInfos = queueHandle.AddrOfPinnedObject(),
                .queueCreateInfoCount = 1,
                .enabledExtensionCount = CUInt(deviceExtensions.Length),
                .ppEnabledExtensionNames = extensionsPtr,
                .enabledLayerCount = 0,
                .pEnabledFeatures = IntPtr.Zero
            }

            If vkCreateDevice(physicalDevice, createInfo, IntPtr.Zero, device) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create logical device!")
            End If

            vkGetDeviceQueue(device, queueFamilyIndex, 0, graphicsQueue)
            vkGetDeviceQueue(device, queueFamilyIndex, 0, presentQueue)
        Finally
            priorityHandle.Free()
            queueHandle.Free()
            FreeStringArray(extensionsPtr, deviceExtensions.Length)
        End Try
        DbgLog.Log($"[CreateLogicalDevice] device={device}")
    End Sub

    Private Function FindQueueFamily() As UInteger
        Dim count As UInteger = 0
        vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, IntPtr.Zero)
        Dim families(count - 1) As VkQueueFamilyProperties
        Dim h As GCHandle = GCHandle.Alloc(families, GCHandleType.Pinned)
        Try
            vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, count, h.AddrOfPinnedObject())
            For i As UInteger = 0 To count - 1
                If (families(i).queueFlags And &H1UI) <> 0 Then ' VK_QUEUE_GRAPHICS_BIT
                    Dim presentSupport As VkBool32 = VkBool32.False
                    vkGetPhysicalDeviceSurfaceSupportKHR(physicalDevice, i, surface, presentSupport)
                    If presentSupport = VkBool32.True Then Return i
                End If
            Next
        Finally
            h.Free()
        End Try
        Throw New Exception("Failed to find a suitable queue family!")
    End Function

    ' ---- Swapchain ----
    Private Sub CreateSwapChain()
        Dim caps As VkSurfaceCapabilitiesKHR
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, surface, caps)

        Dim formatCount As UInteger = 0
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, formatCount, IntPtr.Zero)
        Dim formats(formatCount - 1) As VkSurfaceFormatKHR
        Dim fh As GCHandle = GCHandle.Alloc(formats, GCHandleType.Pinned)
        vkGetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, surface, formatCount, fh.AddrOfPinnedObject())
        fh.Free()

        ' Prefer UNORM to avoid double gamma correction (shader does its own gamma)
        Dim chosenFormat As VkSurfaceFormatKHR = formats(0)
        For Each fmt As VkSurfaceFormatKHR In formats
            If fmt.format = VkFormat.VK_FORMAT_B8G8R8A8_UNORM AndAlso fmt.colorSpace = VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR Then
                chosenFormat = fmt
                Exit For
            End If
        Next

        swapChainImageFormat = chosenFormat.format
        swapChainExtent = caps.currentExtent

        Dim imageCount As UInteger = caps.minImageCount + 1
        If caps.maxImageCount > 0 AndAlso imageCount > caps.maxImageCount Then
            imageCount = caps.maxImageCount
        End If

        Dim createInfo As New VkSwapchainCreateInfoKHR With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = imageCount,
            .imageFormat = chosenFormat.format,
            .imageColorSpace = chosenFormat.colorSpace,
            .imageExtent = swapChainExtent,
            .imageArrayLayers = 1,
            .imageUsage = VkImageUsageFlags.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = VkSharingMode.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform = caps.currentTransform,
            .compositeAlpha = VkCompositeAlphaFlagsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR,
            .clipped = VkBool32.True,
            .oldSwapchain = IntPtr.Zero
        }

        If vkCreateSwapchainKHR(device, createInfo, IntPtr.Zero, swapChain) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create swap chain!")
        End If

        Dim imgCount As UInteger = 0
        vkGetSwapchainImagesKHR(device, swapChain, imgCount, IntPtr.Zero)
        ReDim swapChainImages(imgCount - 1)
        Dim ih As GCHandle = GCHandle.Alloc(swapChainImages, GCHandleType.Pinned)
        vkGetSwapchainImagesKHR(device, swapChain, imgCount, ih.AddrOfPinnedObject())
        ih.Free()

        DbgLog.Log($"[CreateSwapChain] {imgCount} images, {swapChainExtent.width}x{swapChainExtent.height}")
    End Sub

    ' ---- Image views ----
    Private Sub CreateSwapChainImageViews()
        ReDim swapChainImageViews(swapChainImages.Length - 1)
        For i As Integer = 0 To swapChainImages.Length - 1
            Dim createInfo As New VkImageViewCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = swapChainImages(i),
                .viewType = VkImageViewType.VK_IMAGE_VIEW_TYPE_2D,
                .format = swapChainImageFormat,
                .components = New VkComponentMapping With {
                    .r = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY
                },
                .subresourceRange = New VkImageSubresourceRange With {
                    .aspectMask = VkImageAspectFlags.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1
                }
            }
            If vkCreateImageView(device, createInfo, IntPtr.Zero, swapChainImageViews(i)) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create image view!")
            End If
        Next
    End Sub

    ' ---- Render pass (color attachment only, no depth) ----
    Private Sub CreateRenderPass()
        ' Single color attachment - ray marching does not need a depth buffer
        Dim colorAttachment As New VkAttachmentDescription With {
            .format = swapChainImageFormat,
            .samples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
        }

        Dim colorAttachmentRef As New VkAttachmentReference With {
            .attachment = 0,
            .layout = VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL
        }

        Dim colorRefHandle As GCHandle = GCHandle.Alloc(colorAttachmentRef, GCHandleType.Pinned)

        Dim subpass As New VkSubpassDescription With {
            .pipelineBindPoint = VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = colorRefHandle.AddrOfPinnedObject(),
            .pDepthStencilAttachment = IntPtr.Zero
        }

        ' Dependency: wait for previous frame's color output before writing new one
        Dim dependency As New VkSubpassDependency With {
            .srcSubpass = &HFFFFFFFFUI, ' VK_SUBPASS_EXTERNAL
            .dstSubpass = 0,
            .srcStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .dstStageMask = VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .srcAccessMask = 0,
            .dstAccessMask = &H100UI ' VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT
        }

        Dim attachments() As VkAttachmentDescription = {colorAttachment}
        Dim attachHandle As GCHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
        Dim subpassHandle As GCHandle = GCHandle.Alloc(subpass, GCHandleType.Pinned)
        Dim depHandle As GCHandle = GCHandle.Alloc(dependency, GCHandleType.Pinned)

        Try
            Dim renderPassInfo As New VkRenderPassCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
                .attachmentCount = 1,
                .pAttachments = attachHandle.AddrOfPinnedObject(),
                .subpassCount = 1,
                .pSubpasses = subpassHandle.AddrOfPinnedObject(),
                .dependencyCount = 1,
                .pDependencies = depHandle.AddrOfPinnedObject()
            }

            If vkCreateRenderPass(device, renderPassInfo, IntPtr.Zero, renderPass) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create render pass!")
            End If
        Finally
            colorRefHandle.Free()
            attachHandle.Free()
            subpassHandle.Free()
            depHandle.Free()
        End Try
        DbgLog.Log($"[CreateRenderPass] renderPass={renderPass}")
    End Sub

    ' ---- Graphics pipeline ----
    Private Sub CreateGraphicsPipeline()
        ' Compile embedded GLSL source to SPIR-V at runtime via shaderc
        Dim vertSpirv As Byte() = ShaderCompiler.Compile(VERT_SHADER_SRC, ShaderCompiler.ShaderKind.Vertex, "raymarching.vert")
        Dim fragSpirv As Byte() = ShaderCompiler.Compile(FRAG_SHADER_SRC, ShaderCompiler.ShaderKind.Fragment, "raymarching.frag")

        vertShaderModule = CreateShaderModule(vertSpirv)
        fragShaderModule = CreateShaderModule(fragSpirv)

        Dim mainNamePtr As IntPtr = Marshal.StringToHGlobalAnsi("main")

        Dim vertStageInfo As New VkPipelineShaderStageCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VkShaderStageFlags.VK_SHADER_STAGE_VERTEX_BIT,
            .[module] = vertShaderModule,
            .pName = mainNamePtr,
            .pSpecializationInfo = IntPtr.Zero
        }

        Dim fragStageInfo As New VkPipelineShaderStageCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT,
            .[module] = fragShaderModule,
            .pName = mainNamePtr,
            .pSpecializationInfo = IntPtr.Zero
        }

        Dim shaderStages() As VkPipelineShaderStageCreateInfo = {vertStageInfo, fragStageInfo}

        ' No vertex buffer - positions are computed from gl_VertexIndex in the vertex shader
        Dim vertexInputInfo As New VkPipelineVertexInputStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 0,
            .vertexAttributeDescriptionCount = 0
        }

        Dim inputAssembly As New VkPipelineInputAssemblyStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = VkBool32.False
        }

        ' Viewport and scissor are dynamic: set via vkCmdSetViewport / vkCmdSetScissor each frame.
        ' This allows correct rendering after window resize without rebuilding the pipeline.
        Dim viewportState As New VkPipelineViewportStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = IntPtr.Zero, ' dynamic
            .scissorCount = 1,
            .pScissors = IntPtr.Zero  ' dynamic
        }

        ' Cull mode NONE: fullscreen triangle covers the whole screen, culling would discard it
        Dim rasterizer As New VkPipelineRasterizationStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = VkBool32.False,
            .rasterizerDiscardEnable = VkBool32.False,
            .polygonMode = VkPolygonMode.VK_POLYGON_MODE_FILL,
            .cullMode = VkCullModeFlags.VK_CULL_MODE_NONE,
            .frontFace = VkFrontFace.VK_FRONT_FACE_COUNTER_CLOCKWISE,
            .depthBiasEnable = VkBool32.False,
            .lineWidth = 1.0F
        }

        Dim multisampling As New VkPipelineMultisampleStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = VkBool32.False,
            .rasterizationSamples = VkSampleCountFlags.VK_SAMPLE_COUNT_1_BIT
        }

        ' Standard opaque blending (no alpha blending needed for ray marching)
        Dim colorBlendAttachment As New VkPipelineColorBlendAttachmentState With {
            .blendEnable = VkBool32.False,
            .colorWriteMask = VkColorComponentFlags.VK_COLOR_COMPONENT_R_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_G_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_B_BIT Or
                              VkColorComponentFlags.VK_COLOR_COMPONENT_A_BIT
        }

        Dim colorBlendAttachmentHandle As GCHandle = GCHandle.Alloc(colorBlendAttachment, GCHandleType.Pinned)

        Dim colorBlending As New VkPipelineColorBlendStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = VkBool32.False,
            .attachmentCount = 1,
            .pAttachments = colorBlendAttachmentHandle.AddrOfPinnedObject()
        }
        colorBlending.blendConstants = New Single() {0.0F, 0.0F, 0.0F, 0.0F}

        Dim colorBlendingPtr As IntPtr = Marshal.AllocHGlobal(Marshal.SizeOf(GetType(VkPipelineColorBlendStateCreateInfo)))
        Marshal.StructureToPtr(colorBlending, colorBlendingPtr, False)

        ' Register viewport and scissor as dynamic states
        Dim dynamicStates() As UInteger = {CUInt(VkDynamicState.VK_DYNAMIC_STATE_VIEWPORT), CUInt(VkDynamicState.VK_DYNAMIC_STATE_SCISSOR)}
        Dim dynamicStatesHandle As GCHandle = GCHandle.Alloc(dynamicStates, GCHandleType.Pinned)

        Dim dynamicState As New VkPipelineDynamicStateCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = CUInt(dynamicStates.Length),
            .pDynamicStates = dynamicStatesHandle.AddrOfPinnedObject()
        }

        ' Push constant range: 16 bytes (iTime + padding + iResolutionX + iResolutionY),
        ' accessible from the fragment shader only.
        Dim pushConstantRange As New VkPushConstantRange With {
            .stageFlags = VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT,
            .offset = 0,
            .size = 16
        }
        Dim pushConstantHandle As GCHandle = GCHandle.Alloc(pushConstantRange, GCHandleType.Pinned)

        Dim pipelineLayoutInfo As New VkPipelineLayoutCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 0,
            .pSetLayouts = IntPtr.Zero,
            .pushConstantRangeCount = 1,
            .pPushConstantRanges = pushConstantHandle.AddrOfPinnedObject()
        }

        If vkCreatePipelineLayout(device, pipelineLayoutInfo, IntPtr.Zero, pipelineLayout) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create pipeline layout!")
        End If

        Dim shaderStagesHandle As GCHandle = GCHandle.Alloc(shaderStages, GCHandleType.Pinned)
        Dim vertexInputHandle As GCHandle = GCHandle.Alloc(vertexInputInfo, GCHandleType.Pinned)
        Dim inputAssemblyHandle As GCHandle = GCHandle.Alloc(inputAssembly, GCHandleType.Pinned)
        Dim viewportStateHandle As GCHandle = GCHandle.Alloc(viewportState, GCHandleType.Pinned)
        Dim rasterizerHandle As GCHandle = GCHandle.Alloc(rasterizer, GCHandleType.Pinned)
        Dim multisamplingHandle As GCHandle = GCHandle.Alloc(multisampling, GCHandleType.Pinned)
        Dim dynamicStateHandle As GCHandle = GCHandle.Alloc(dynamicState, GCHandleType.Pinned)

        Try
            Dim pipelineInfo As New VkGraphicsPipelineCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
                .stageCount = 2,
                .pStages = shaderStagesHandle.AddrOfPinnedObject(),
                .pVertexInputState = vertexInputHandle.AddrOfPinnedObject(),
                .pInputAssemblyState = inputAssemblyHandle.AddrOfPinnedObject(),
                .pTessellationState = IntPtr.Zero,
                .pViewportState = viewportStateHandle.AddrOfPinnedObject(),
                .pRasterizationState = rasterizerHandle.AddrOfPinnedObject(),
                .pMultisampleState = multisamplingHandle.AddrOfPinnedObject(),
                .pDepthStencilState = IntPtr.Zero, ' no depth testing for ray marching
                .pColorBlendState = colorBlendingPtr,
                .pDynamicState = dynamicStateHandle.AddrOfPinnedObject(),
                .layout = pipelineLayout,
                .renderPass = renderPass,
                .subpass = 0,
                .basePipelineHandle = IntPtr.Zero,
                .basePipelineIndex = -1
            }

            Dim pipelineInfoHandle As GCHandle = GCHandle.Alloc(pipelineInfo, GCHandleType.Pinned)
            Dim pipelineResultHandle As GCHandle = GCHandle.Alloc(graphicsPipeline, GCHandleType.Pinned)

            Try
                If vkCreateGraphicsPipelines(device, IntPtr.Zero, 1, pipelineInfoHandle.AddrOfPinnedObject(), IntPtr.Zero, pipelineResultHandle.AddrOfPinnedObject()) <> VkResult.VK_SUCCESS Then
                    Throw New Exception("Failed to create graphics pipeline!")
                End If
                graphicsPipeline = CType(pipelineResultHandle.Target, IntPtr)
            Finally
                pipelineInfoHandle.Free()
                pipelineResultHandle.Free()
            End Try
        Finally
            colorBlendAttachmentHandle.Free()
            dynamicStatesHandle.Free()
            pushConstantHandle.Free()
            shaderStagesHandle.Free()
            vertexInputHandle.Free()
            inputAssemblyHandle.Free()
            viewportStateHandle.Free()
            rasterizerHandle.Free()
            multisamplingHandle.Free()
            dynamicStateHandle.Free()
            Marshal.FreeHGlobal(colorBlendingPtr)
            If mainNamePtr <> IntPtr.Zero Then Marshal.FreeHGlobal(mainNamePtr)
        End Try

        ' Shader modules are no longer needed after pipeline creation
        vkDestroyShaderModule(device, vertShaderModule, IntPtr.Zero)
        vkDestroyShaderModule(device, fragShaderModule, IntPtr.Zero)
        vertShaderModule = IntPtr.Zero
        fragShaderModule = IntPtr.Zero

        DbgLog.Log($"[CreateGraphicsPipeline] pipeline={graphicsPipeline}")
    End Sub

    Private Function CreateShaderModule(ByVal code As Byte()) As IntPtr
        Dim codeHandle As GCHandle = GCHandle.Alloc(code, GCHandleType.Pinned)
        Try
            Dim createInfo As New VkShaderModuleCreateInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                .codeSize = CType(code.Length, UIntPtr),
                .pCode = codeHandle.AddrOfPinnedObject()
            }
            Dim shaderModule As IntPtr
            If vkCreateShaderModule(device, createInfo, IntPtr.Zero, shaderModule) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create shader module!")
            End If
            Return shaderModule
        Finally
            codeHandle.Free()
        End Try
    End Function

    ' ---- Framebuffers (color only) ----
    Private Sub CreateFramebuffers()
        ReDim swapChainFramebuffers(swapChainImageViews.Length - 1)
        For i As Integer = 0 To swapChainImageViews.Length - 1
            ' Only the color view - no depth attachment
            Dim attachments() As IntPtr = {swapChainImageViews(i)}
            Dim attachHandle As GCHandle = GCHandle.Alloc(attachments, GCHandleType.Pinned)
            Try
                Dim fbInfo As New VkFramebufferCreateInfo With {
                    .sType = VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                    .renderPass = renderPass,
                    .attachmentCount = 1,
                    .pAttachments = attachHandle.AddrOfPinnedObject(),
                    .width = swapChainExtent.width,
                    .height = swapChainExtent.height,
                    .layers = 1
                }
                If vkCreateFramebuffer(device, fbInfo, IntPtr.Zero, swapChainFramebuffers(i)) <> VkResult.VK_SUCCESS Then
                    Throw New Exception("Failed to create framebuffer!")
                End If
            Finally
                attachHandle.Free()
            End Try
        Next
        DbgLog.Log($"[CreateFramebuffers] {swapChainFramebuffers.Length} framebuffers")
    End Sub

    ' ---- Command pool & buffer ----
    Private Sub CreateCommandPool()
        Dim poolInfo As New VkCommandPoolCreateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = VkCommandPoolCreateFlags.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = FindQueueFamily()
        }
        If vkCreateCommandPool(device, poolInfo, IntPtr.Zero, commandPool) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to create command pool!")
        End If
    End Sub

    Private Sub CreateCommandBuffer()
        ' Allocate one command buffer per frame-in-flight so each frame can record
        ' independently without waiting for the previous frame's GPU execution.
        ReDim commandBuffers(MAX_FRAMES_IN_FLIGHT - 1)
        Dim allocInfo As New VkCommandBufferAllocateInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = commandPool,
            .level = VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = CUInt(MAX_FRAMES_IN_FLIGHT)
        }
        Dim h As GCHandle = GCHandle.Alloc(commandBuffers, GCHandleType.Pinned)
        Try
            If vkAllocateCommandBuffers(device, allocInfo, h.AddrOfPinnedObject()) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to allocate command buffers!")
            End If
            commandBuffers = CType(h.Target, IntPtr())
        Finally
            h.Free()
        End Try
        DbgLog.LogFmt("CreateCommandBuffer: allocated {0} command buffers", MAX_FRAMES_IN_FLIGHT)
    End Sub

    ' ---- Synchronization primitives ----
    Private Sub CreateSyncObjects()
        ReDim imageAvailableSemaphores(MAX_FRAMES_IN_FLIGHT - 1)
        ReDim renderFinishedSemaphores(MAX_FRAMES_IN_FLIGHT - 1)
        ReDim inFlightFences(MAX_FRAMES_IN_FLIGHT - 1)

        Dim semInfo As New VkSemaphoreCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO}
        Dim fenceInfo As New VkFenceCreateInfo With {.sType = VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, .flags = 1} ' VK_FENCE_CREATE_SIGNALED_BIT

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            If vkCreateSemaphore(device, semInfo, IntPtr.Zero, imageAvailableSemaphores(i)) <> VkResult.VK_SUCCESS OrElse
               vkCreateSemaphore(device, semInfo, IntPtr.Zero, renderFinishedSemaphores(i)) <> VkResult.VK_SUCCESS OrElse
               vkCreateFence(device, fenceInfo, IntPtr.Zero, inFlightFences(i)) <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to create synchronization objects!")
            End If
        Next
    End Sub

    ' ---- Rendering ----
    Private Sub DrawFrame()
        If device = IntPtr.Zero Then Return

        currentFrame = frameIndex Mod MAX_FRAMES_IN_FLIGHT
        DbgLog.LogFrame(frameIndex, "start cf=" & currentFrame.ToString())

        ' Wait for this slot's previous submit to complete
        vkWaitForFences(device, 1, inFlightFences(currentFrame), VkBool32.True, ULong.MaxValue)
        vkResetFences(device, 1, inFlightFences(currentFrame))
        DbgLog.LogFrame(frameIndex, "fence OK")

        Dim imageIndex As UInteger = 0
        Dim result As VkResult = vkAcquireNextImageKHR(device, swapChain, ULong.MaxValue, imageAvailableSemaphores(currentFrame), IntPtr.Zero, imageIndex)
        DbgLog.LogFrame(frameIndex, "AcquireNextImage result=" & result.ToString() & " idx=" & imageIndex.ToString())

        If result = VkResult.VK_ERROR_OUT_OF_DATE_KHR Then
            RecreateSwapChain()
            Return
        ElseIf result <> VkResult.VK_SUCCESS AndAlso result <> VkResult.VK_SUBOPTIMAL_KHR Then
            Throw New Exception($"Failed to acquire swapchain image: {result}")
        End If

        ' Record commands for this frame
        Dim beginInfo As New VkCommandBufferBeginInfo With {
            .sType = VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = VkCommandBufferUsageFlags.VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT
        }

        ' Reset this frame's command buffer before re-recording
        vkResetCommandBuffer(commandBuffers(currentFrame), 0)
        If vkBeginCommandBuffer(commandBuffers(currentFrame), beginInfo) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to begin command buffer!")
        End If

        ' Clear to black
        Dim clearValue As New VkClearValue()
        clearValue.color = New VkClearColorValue With {.float32_0 = 0.0F, .float32_1 = 0.0F, .float32_2 = 0.0F, .float32_3 = 1.0F}

        Dim clearValueHandle As GCHandle = GCHandle.Alloc(clearValue, GCHandleType.Pinned)

        Try
            Dim renderPassBeginInfo As New VkRenderPassBeginInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                .renderPass = renderPass,
                .framebuffer = swapChainFramebuffers(imageIndex),
                .renderArea = New VkRect2D With {
                    .offset = New VkOffset2D With {.x = 0, .y = 0},
                    .extent = swapChainExtent
                },
                .clearValueCount = 1,
                .pClearValues = clearValueHandle.AddrOfPinnedObject()
            }

            vkCmdBeginRenderPass(commandBuffers(currentFrame), renderPassBeginInfo, VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE)
            vkCmdBindPipeline(commandBuffers(currentFrame), VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline)

            ' Set dynamic viewport matching the current swapchain extent
            Dim viewport As New VkViewport With {
                .x = 0.0F,
                .y = 0.0F,
                .width = CSng(swapChainExtent.width),
                .height = CSng(swapChainExtent.height),
                .minDepth = 0.0F,
                .maxDepth = 1.0F
            }
            vkCmdSetViewport(commandBuffers(currentFrame), 0, 1, viewport)

            ' Set dynamic scissor matching the current swapchain extent
            Dim scissor As New VkRect2D With {
                .offset = New VkOffset2D With {.x = 0, .y = 0},
                .extent = swapChainExtent
            }
            vkCmdSetScissor(commandBuffers(currentFrame), 0, 1, scissor)

            ' Upload push constants: elapsed time + framebuffer resolution
            Dim pc As New PushConstants With {
                .iTime = CSng(stopwatch.Elapsed.TotalSeconds),
                .padding = 0.0F,
                .iResolutionX = CSng(swapChainExtent.width),
                .iResolutionY = CSng(swapChainExtent.height)
            }
            Dim pcSize As Integer = Marshal.SizeOf(GetType(PushConstants))
            Dim pcPtr As IntPtr = Marshal.AllocHGlobal(pcSize)
            Try
                Marshal.StructureToPtr(pc, pcPtr, False)
                vkCmdPushConstants(commandBuffers(currentFrame), pipelineLayout, VkShaderStageFlags.VK_SHADER_STAGE_FRAGMENT_BIT, 0, CUInt(pcSize), pcPtr)
            Finally
                Marshal.FreeHGlobal(pcPtr)
            End Try

            ' Draw fullscreen triangle (3 vertices, no vertex buffer)
            vkCmdDraw(commandBuffers(currentFrame), 3, 1, 0, 0)

            vkCmdEndRenderPass(commandBuffers(currentFrame))
        Finally
            clearValueHandle.Free()
        End Try

        If vkEndCommandBuffer(commandBuffers(currentFrame)) <> VkResult.VK_SUCCESS Then
            Throw New Exception("Failed to end command buffer!")
        End If

        ' Submit to the graphics queue
        Dim waitStageFlags As UInteger = CUInt(VkPipelineStageFlags.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT)
        Dim waitStageHandle As GCHandle = GCHandle.Alloc(waitStageFlags, GCHandleType.Pinned)
        Dim waitSemHandle As GCHandle = GCHandle.Alloc(imageAvailableSemaphores(currentFrame), GCHandleType.Pinned)
        Dim signalSemHandle As GCHandle = GCHandle.Alloc(renderFinishedSemaphores(currentFrame), GCHandleType.Pinned)
        Dim cmdBufHandle As GCHandle = GCHandle.Alloc(commandBuffers(currentFrame), GCHandleType.Pinned)

        Try
            Dim submitInfo As New VkSubmitInfo With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
                .waitSemaphoreCount = 1,
                .pWaitSemaphores = waitSemHandle.AddrOfPinnedObject(),
                .pWaitDstStageMask = waitStageHandle.AddrOfPinnedObject(),
                .commandBufferCount = 1,
                .pCommandBuffers = cmdBufHandle.AddrOfPinnedObject(),
                .signalSemaphoreCount = 1,
                .pSignalSemaphores = signalSemHandle.AddrOfPinnedObject()
            }

            Dim submitRes As VkResult = vkQueueSubmit(graphicsQueue, 1, submitInfo, inFlightFences(currentFrame))
            DbgLog.LogFrame(frameIndex, "QueueSubmit=" & submitRes.ToString())
            If submitRes <> VkResult.VK_SUCCESS Then
                Throw New Exception("Failed to submit draw command buffer: " & submitRes.ToString())
            End If
        Finally
            waitStageHandle.Free()
            waitSemHandle.Free()
            signalSemHandle.Free()
            cmdBufHandle.Free()
        End Try

        ' Present the rendered image
        Dim swapChainHandle As GCHandle = GCHandle.Alloc(swapChain, GCHandleType.Pinned)
        Dim imageIndexHandle As GCHandle = GCHandle.Alloc(imageIndex, GCHandleType.Pinned)
        Dim presentWaitSemHandle As GCHandle = GCHandle.Alloc(renderFinishedSemaphores(currentFrame), GCHandleType.Pinned)

        Try
            Dim presentInfo As New VkPresentInfoKHR With {
                .sType = VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
                .waitSemaphoreCount = 1,
                .pWaitSemaphores = presentWaitSemHandle.AddrOfPinnedObject(),
                .swapchainCount = 1,
                .pSwapchains = swapChainHandle.AddrOfPinnedObject(),
                .pImageIndices = imageIndexHandle.AddrOfPinnedObject(),
                .pResults = IntPtr.Zero
            }

            result = vkQueuePresentKHR(presentQueue, presentInfo)
            DbgLog.LogFrame(frameIndex, "QueuePresent=" & result.ToString())
        Finally
            swapChainHandle.Free()
            imageIndexHandle.Free()
            presentWaitSemHandle.Free()
        End Try

        If result = VkResult.VK_ERROR_OUT_OF_DATE_KHR OrElse result = VkResult.VK_SUBOPTIMAL_KHR Then
            RecreateSwapChain()
        ElseIf result <> VkResult.VK_SUCCESS Then
            Throw New Exception($"Failed to present swapchain image: {result}")
        End If

        frameIndex += 1
        DbgLog.LogFrame(frameIndex, "done")
    End Sub

    ' ---- Swapchain recreation on resize ----
    Private Sub RecreateSwapChain()
        vkDeviceWaitIdle(device)

        ' Destroy old swapchain resources
        For Each fb As IntPtr In swapChainFramebuffers
            vkDestroyFramebuffer(device, fb, IntPtr.Zero)
        Next
        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero)
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero)
        For Each iv As IntPtr In swapChainImageViews
            vkDestroyImageView(device, iv, IntPtr.Zero)
        Next
        vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero)

        ' Rebuild
        CreateSwapChain()
        CreateSwapChainImageViews()
        CreateRenderPass()
        CreateGraphicsPipeline()
        CreateFramebuffers()
        DbgLog.Log("[RecreateSwapChain] Done")
    End Sub

    ' ---- Cleanup ----
    Public Sub Cleanup()
        If device = IntPtr.Zero Then Return

        vkDeviceWaitIdle(device)

        For Each fb As IntPtr In swapChainFramebuffers
            vkDestroyFramebuffer(device, fb, IntPtr.Zero)
        Next

        vkDestroyPipeline(device, graphicsPipeline, IntPtr.Zero)
        vkDestroyPipelineLayout(device, pipelineLayout, IntPtr.Zero)
        vkDestroyRenderPass(device, renderPass, IntPtr.Zero)

        For Each iv As IntPtr In swapChainImageViews
            vkDestroyImageView(device, iv, IntPtr.Zero)
        Next

        vkDestroySwapchainKHR(device, swapChain, IntPtr.Zero)

        For i As Integer = 0 To MAX_FRAMES_IN_FLIGHT - 1
            vkDestroySemaphore(device, imageAvailableSemaphores(i), IntPtr.Zero)
            vkDestroySemaphore(device, renderFinishedSemaphores(i), IntPtr.Zero)
            vkDestroyFence(device, inFlightFences(i), IntPtr.Zero)
        Next

        vkDestroyCommandPool(device, commandPool, IntPtr.Zero)
        vkDestroyDevice(device, IntPtr.Zero)

        If debugMessenger <> IntPtr.Zero Then
            Dim destroyPtr As IntPtr = vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")
            If destroyPtr <> IntPtr.Zero Then
                Dim destroyFn As vkDestroyDebugUtilsMessengerEXTFunc =
                    CType(Marshal.GetDelegateForFunctionPointer(destroyPtr, GetType(vkDestroyDebugUtilsMessengerEXTFunc)), vkDestroyDebugUtilsMessengerEXTFunc)
                destroyFn(instance, debugMessenger, IntPtr.Zero)
            End If
        End If

        vkDestroySurfaceKHR(instance, surface, IntPtr.Zero)
        vkDestroyInstance(instance, IntPtr.Zero)
        DbgLog.Log("[Cleanup] Done")
    End Sub

    ' ---- Utility helpers ----
    Private Function MakeVersion(ByVal major As UInteger, ByVal minor As UInteger, ByVal patch As UInteger) As UInteger
        Return (major << 22) Or (minor << 12) Or patch
    End Function

    Private Function StringArrayToPtr(ByVal strings As String()) As IntPtr
        Dim ptrs(strings.Length - 1) As IntPtr
        For i As Integer = 0 To strings.Length - 1
            ptrs(i) = Marshal.StringToHGlobalAnsi(strings(i))
        Next
        Dim arrayPtr As IntPtr = Marshal.AllocHGlobal(IntPtr.Size * strings.Length)
        Marshal.Copy(ptrs, 0, arrayPtr, strings.Length)
        Return arrayPtr
    End Function

    Private Sub FreeStringArray(ByVal arrayPtr As IntPtr, ByVal count As Integer)
        Dim ptrs(count - 1) As IntPtr
        Marshal.Copy(arrayPtr, ptrs, 0, count)
        For Each ptr As IntPtr In ptrs
            Marshal.FreeHGlobal(ptr)
        Next
        Marshal.FreeHGlobal(arrayPtr)
    End Sub

    ' Safe initializer: allocates embedded managed arrays in VkPhysicalDeviceProperties
    Private Shared Sub InitPhysicalDeviceProperties(ByRef props As VkPhysicalDeviceProperties)
        If props.pipelineCacheUUID Is Nothing OrElse props.pipelineCacheUUID.Length <> 16 Then
            props.pipelineCacheUUID = New Byte(15) {}
        End If
        Dim lim As VkPhysicalDeviceLimits = props.limits
        If lim.maxComputeWorkGroupCount Is Nothing Then lim.maxComputeWorkGroupCount = New UInteger(2) {}
        If lim.maxComputeWorkGroupSize Is Nothing Then lim.maxComputeWorkGroupSize = New UInteger(2) {}
        If lim.maxViewportDimensions Is Nothing Then lim.maxViewportDimensions = New UInteger(1) {}
        If lim.viewportBoundsRange Is Nothing Then lim.viewportBoundsRange = New Single(1) {}
        If lim.pointSizeRange Is Nothing Then lim.pointSizeRange = New Single(1) {}
        If lim.lineWidthRange Is Nothing Then lim.lineWidthRange = New Single(1) {}
        props.limits = lim
    End Sub

    ' ---- Entry point ----
    <STAThread>
    Shared Sub Main()
        ' Catch all unhandled exceptions and log them to Console and DebugView
        AddHandler AppDomain.CurrentDomain.UnhandledException, _
            Sub(s As Object, ev As UnhandledExceptionEventArgs)
                Dim ex As Exception = TryCast(ev.ExceptionObject, Exception)
                If ex IsNot Nothing Then
                    DbgLog.LogEx("AppDomain.UnhandledException", ex)
                Else
                    DbgLog.Log("AppDomain.UnhandledException: non-Exception object: " & ev.ExceptionObject.ToString())
                End If
            End Sub
        AddHandler Application.ThreadException, _
            Sub(s As Object, ev As System.Threading.ThreadExceptionEventArgs)
                DbgLog.LogEx("Application.ThreadException", ev.Exception)
                MessageBox.Show("Thread exception:" & vbCrLf & ev.Exception.Message & vbCrLf & vbCrLf & ev.Exception.StackTrace, _
                    "Thread Exception", MessageBoxButtons.OK, MessageBoxIcon.Error)
            End Sub
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException)
        Application.EnableVisualStyles()
        DbgLog.Log("Main: Application starting")
        Application.Run(New RaymarchingForm())
        DbgLog.Log("Main: Application exit")
    End Sub
End Class
