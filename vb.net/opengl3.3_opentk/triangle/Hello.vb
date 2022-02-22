Imports OpenTK.Graphics.OpenGL4
Imports OpenTK.Mathematics
Imports OpenTK.Windowing.Common
Imports OpenTK.Windowing.GraphicsLibraryFramework
Imports OpenTK.Windowing.Desktop

Public Class Shader
    Public Handle As Integer

    Public Sub New()
        Dim vertexSource As String = "" & _
            "#version 330 core                            " & vbCrLf & _
            "layout(location = 0) in  vec3 position;      " & vbCrLf & _
            "layout(location = 1) in  vec3 color;         " & vbCrLf & _
            "out vec4 vColor;                             " & vbCrLf & _
            "void main()                                  " & vbCrLf & _
            "{                                            " & vbCrLf & _
            "  vColor = vec4(color, 1.0);                 " & vbCrLf & _
            "  gl_Position = vec4(position, 1.0);         " & vbCrLf & _
            "}                                            "
        Dim fragmentSource As String = "" & _
            "#version 330 core                            " & vbCrLf & _
            "precision mediump float;                     " & vbCrLf & _
            "in  vec4 vColor;                             " & vbCrLf & _
            "out vec4 outColor;                           " & vbCrLf & _
            "void main()                                  " & vbCrLf & _
            "{                                            " & vbCrLf & _
            "  outColor = vColor;                         " & vbCrLf & _
            "}                                            "

        Dim vertexShader As Integer = GL.CreateShader(ShaderType.VertexShader)
        GL.ShaderSource(vertexShader, vertexSource)
        Shader.CompileShader(vertexShader)

        Dim fragmentShader As Integer = GL.CreateShader(ShaderType.FragmentShader)
        GL.ShaderSource(fragmentShader, fragmentSource)
        Shader.CompileShader(fragmentShader)

        Me.Handle = GL.CreateProgram()

        GL.AttachShader(Me.Handle, vertexShader)
        GL.AttachShader(Me.Handle, fragmentShader)

        Shader.LinkProgram(Me.Handle)

        GL.DetachShader(Me.Handle, vertexShader)
        GL.DetachShader(Me.Handle, fragmentShader)
        GL.DeleteShader(fragmentShader)
        GL.DeleteShader(vertexShader)

        Dim numberOfUniforms As Integer
        GL.GetProgram(Me.Handle, GetProgramParameterName.ActiveUniforms, numberOfUniforms)

    End Sub

    Private Shared Sub CompileShader(shader As Integer)
        GL.CompileShader(shader)
        Dim code As Integer
        GL.GetShader(shader, ShaderParameter.CompileStatus, code)
    End Sub

    Private Shared Sub LinkProgram(program As Integer)
        GL.LinkProgram(program)
        Dim code As Integer
        GL.GetProgram(program, GetProgramParameterName.LinkStatus, code)
    End Sub

    Public Sub Use()
        GL.UseProgram(Me.Handle)
    End  Sub

    Public Function GetAttribLocation(attribName As String)
        Return GL.GetAttribLocation(Me.Handle, attribName)
    End Function

End Class

Public Class HelloWindow 
    Inherits GameWindow

    Private _vertices As Single() = { _
        -0.5F, -0.5F, 0.0F, _
         0.5F, -0.5F, 0.0F, _
         0.0F,  0.5F, 0.0F  _
    }

    Private _colors As Single() = { _
         1.0F,  0.0F,  0.0F, _
         0.0F,  1.0F,  0.0F, _
         0.0F,  0.0F,  1.0F  _
    }
    
    Private _vbo As Integer()
    Private _vao As Integer
    Private _shader As Shader

    Public Sub New(gameWindowSettings As GameWindowSettings, nativeWindowSettings As NativeWindowSettings )
        MyBase.New(gameWindowSettings, nativeWindowSettings)
        Me._vbo = New Integer(2 - 1) {}
        Me._shader = New Shader()
    End Sub

    Protected Overrides Sub OnLoad()
        MyBase.OnLoad()

        GL.ClearColor(0.0F, 0.0F, 0.0F, 0.0F)

        _vao = GL.GenVertexArray()
        GL.BindVertexArray(Me._vao)

        GL.GenBuffers(2, Me._vbo)

        GL.BindBuffer(BufferTarget.ArrayBuffer, Me._vbo(0))
        GL.EnableVertexArrayAttrib(Me._vao, 0)
        GL.BufferData(BufferTarget.ArrayBuffer, _vertices.Length * 4, _vertices, BufferUsageHint.StaticDraw)
        GL.VertexAttribPointer(0, 3, VertexAttribPointerType.Float, False, 0, 0)

        GL.BindBuffer(BufferTarget.ArrayBuffer, Me._vbo(1))
        GL.EnableVertexArrayAttrib(Me._vao, 1)
        GL.BufferData(BufferTarget.ArrayBuffer, _colors.Length * 4, _colors, BufferUsageHint.StaticDraw)
        GL.VertexAttribPointer(1, 3, VertexAttribPointerType.Float, False, 0, 0)

        GL.BindVertexArray(0)

        _shader.Use()
    End Sub

    Protected Overrides Sub OnRenderFrame(e As FrameEventArgs)
        MyBase.OnRenderFrame(e)

        GL.Clear(ClearBufferMask.ColorBufferBit)

        _shader.Use()

        GL.BindVertexArray(Me._vao)

        GL.DrawArrays(PrimitiveType.Triangles, 0, 3)

        SwapBuffers()
    End Sub

    Protected Overrides Sub OnUnload()
        GL.BindBuffer(BufferTarget.ArrayBuffer, 0)
        GL.BindVertexArray(0)
        GL.UseProgram(0)

        GL.DeleteBuffer(Me._vbo(0))
        GL.DeleteVertexArray(Me._vao)

        GL.DeleteProgram(_shader.Handle)

        MyBase.OnUnload()
    End Sub
End Class

Class Program
    Public Shared Sub Main()
        Dim nativeWindowSettings As NativeWindowSettings = New NativeWindowSettings() With { .Size = New Vector2i(640, 480), .Title = "Hello, World!" }

        Dim helloWindow As HelloWindow = New HelloWindow(GameWindowSettings.[Default], nativeWindowSettings)
        helloWindow.Run()
    End Sub
End Class
