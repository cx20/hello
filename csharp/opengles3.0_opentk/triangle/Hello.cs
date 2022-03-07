using OpenTK.Graphics.OpenGL4;
using OpenTK.Mathematics;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.GraphicsLibraryFramework;
using OpenTK.Windowing.Desktop;

public class Shader
{
    public readonly int Handle;

    public Shader()
    {
        const string vertexSource =
            "#version 300 es                              \n" + 
            "in  vec3 position;                           \n" + 
            "in  vec3 color;                              \n" + 
            "out vec4 vColor;                             \n" + 
            "void main()                                  \n" + 
            "{                                            \n" + 
            "  vColor = vec4(color, 1.0);                 \n" + 
            "  gl_Position = vec4(position, 1.0);         \n" + 
            "}                                            \n";
        const string fragmentSource =
            "#version 300 es                              \n" + 
            "precision mediump float;                     \n" + 
            "in  vec4 vColor;                             \n" + 
            "out vec4 outColor;                           \n" + 
            "void main()                                  \n" + 
            "{                                            \n" + 
            "  outColor = vColor;                         \n" + 
            "}                                            \n";

        var shaderSource = vertexSource;
        var vertexShader = GL.CreateShader(ShaderType.VertexShader);

        GL.ShaderSource(vertexShader, shaderSource);
        CompileShader(vertexShader);

        shaderSource = fragmentSource;
        var fragmentShader = GL.CreateShader(ShaderType.FragmentShader);
        GL.ShaderSource(fragmentShader, shaderSource);
        CompileShader(fragmentShader);

        Handle = GL.CreateProgram();

        GL.AttachShader(Handle, vertexShader);
        GL.AttachShader(Handle, fragmentShader);

        LinkProgram(Handle);

        GL.DetachShader(Handle, vertexShader);
        GL.DetachShader(Handle, fragmentShader);
        GL.DeleteShader(fragmentShader);
        GL.DeleteShader(vertexShader);

        GL.GetProgram(Handle, GetProgramParameterName.ActiveUniforms, out var numberOfUniforms);

    }

    private static void CompileShader(int shader)
    {
        GL.CompileShader(shader);
        GL.GetShader(shader, ShaderParameter.CompileStatus, out var code);
    }

    private static void LinkProgram(int program)
    {
        GL.LinkProgram(program);
        GL.GetProgram(program, GetProgramParameterName.LinkStatus, out var code);
    }

    public void Use()
    {
        GL.UseProgram(Handle);
    }

    public int GetAttribLocation(string attribName)
    {
        return GL.GetAttribLocation(Handle, attribName);
    }

}

public class HelloWindow : GameWindow
{
    private readonly float[] _vertices =
    {
        -0.5f, -0.5f, 0.0f,
         0.5f, -0.5f, 0.0f,
         0.0f,  0.5f, 0.0f 
    };

    private readonly float[] _colors = {
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    };
    
    private int[] _vbo;
    private int _vao;
    private Shader _shader;

    public HelloWindow(GameWindowSettings gameWindowSettings, NativeWindowSettings nativeWindowSettings)
        : base(gameWindowSettings, nativeWindowSettings)
    {
        _vbo = new int[2];
        _shader = new Shader();
    }

    protected override void OnLoad()
    {
        base.OnLoad();

        GL.ClearColor(0.0f, 0.0f, 0.0f, 0.0f);

        _vao = GL.GenVertexArray();
        GL.BindVertexArray(_vao);

        GL.GenBuffers(2, _vbo);

        GL.BindBuffer(BufferTarget.ArrayBuffer, _vbo[0]);
        GL.EnableVertexArrayAttrib(_vao, 0);
        GL.BufferData(BufferTarget.ArrayBuffer, _vertices.Length * sizeof(float), _vertices, BufferUsageHint.StaticDraw);
        GL.VertexAttribPointer(0, 3, VertexAttribPointerType.Float, false, 0, 0);

        GL.BindBuffer(BufferTarget.ArrayBuffer, _vbo[1]);
        GL.EnableVertexArrayAttrib(_vao, 1);
        GL.BufferData(BufferTarget.ArrayBuffer, _colors.Length * sizeof(float), _colors, BufferUsageHint.StaticDraw);
        GL.VertexAttribPointer(1, 3, VertexAttribPointerType.Float, false, 0, 0);

        GL.BindVertexArray(0);

        _shader.Use();
    }

    protected override void OnRenderFrame(FrameEventArgs e)
    {
        base.OnRenderFrame(e);

        GL.Clear(ClearBufferMask.ColorBufferBit);

        _shader.Use();

        GL.BindVertexArray(_vao);

        GL.DrawArrays(PrimitiveType.Triangles, 0, 3);

        SwapBuffers();
    }

    protected override void OnUnload()
    {
        GL.BindBuffer(BufferTarget.ArrayBuffer, 0);
        GL.BindVertexArray(0);
        GL.UseProgram(0);

        GL.DeleteBuffer(_vbo[0]);
        GL.DeleteVertexArray(_vao);

        GL.DeleteProgram(_shader.Handle);

        base.OnUnload();
    }
}

class Program
{
    private static void Main()
    {
        var nativeWindowSettings = new NativeWindowSettings()
        {
            Size = new Vector2i(640, 480),
            Title = "Hello, World!",
        };

        using (var window = new HelloWindow(GameWindowSettings.Default, nativeWindowSettings))
        {
            window.Run();
        }
    }
}
