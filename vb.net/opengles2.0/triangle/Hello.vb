Imports System
Imports System.Drawing
Imports System.Runtime.InteropServices
Imports System.Windows.Forms

Friend Class HelloForm
    Inherits Form

    Public Structure PIXELFORMATDESCRIPTOR
        Public nSize           As UShort
        Public nVersion        As UShort
        Public dwFlags         As UInteger
        Public iPixelType      As Byte
        Public cColorBits      As Byte
        Public cRedBits        As Byte
        Public cRedShift       As Byte
        Public cGreenBits      As Byte
        Public cGreenShift     As Byte
        Public cBlueBits       As Byte
        Public cBlueShift      As Byte
        Public cAlphaBits      As Byte
        Public cAlphaShift     As Byte
        Public cAccumBits      As Byte
        Public cAccumRedBits   As Byte
        Public cAccumGreenBits As Byte
        Public cAccumBlueBits  As Byte
        Public cAccumAlphaBits As Byte
        Public cDepthBits      As Byte
        Public cStencilBits    As Byte
        Public cAuxBuffers     As Byte
        Public iLayerType      As Byte
        Public bReserved       As Byte
        Public dwLayerMask     As UInteger
        Public dwVisibleMask   As UInteger
        Public dwDamageMask    As UInteger
    End Structure
    
    Delegate Sub glGenBuffersDelegate(n As Integer, buffers As UInteger())
    Delegate Sub glBindBufferDelegate(target As UInteger, buffer As UInteger)
    Delegate Sub glBufferDataFloatDelegate(target As UInteger, size As Integer, data As Single(), usage As UInteger)
    Delegate Function glCreateShaderDelegate(type As UInteger) As UInteger
    Delegate Sub glShaderSourceDelegate(shader As UInteger, count As Integer, [string] As String(), length As Integer())
    Delegate Sub glCompileShaderDelegate(shader As UInteger)
    Delegate Function glCreateProgramDelegate() As UInteger
    Delegate Sub glAttachShaderDelegate(program As UInteger, shader As UInteger)
    Delegate Sub glLinkProgramDelegate(program As UInteger)
    Delegate Sub glUseProgramDelegate(program As UInteger)
    Delegate Function glGetAttribLocationDelegate(program As UInteger, name As String) As UInteger
    Delegate Sub glEnableVertexAttribArrayDelegate(index As UInteger)
    Delegate Sub glVertexAttribPointerDelegate(index As UInteger, size As Integer, type As UInteger, normalized As Boolean, stride As Integer, pointer As IntPtr)
    Delegate Function wglCreateContextAttribsARBDelegate(hDC As IntPtr, hShareContext As IntPtr, attribList As Integer()) As IntPtr
    
    Const GL_TRIANGLES        As Integer = 4
    Const GL_TRIANGLE_STRIP   As Integer = 5
    Const GL_FLOAT            As Integer = &h1406
    Const GL_VERTEX_ARRAY     As Integer = &h8074
    Const GL_COLOR_ARRAY      As Integer = &h8076
    Const GL_ARRAY_BUFFER     As Integer = &h8892
    Const GL_STATIC_DRAW      As Integer = &h88E4
    Const GL_FRAGMENT_SHADER  As Integer = &h8B30
    Const GL_VERTEX_SHADER    As Integer = &h8B31
    Const GL_COLOR_BUFFER_BIT As Integer = &h00004000

    Const PFD_TYPE_RGBA       As Integer = 0
    Const PFD_DOUBLEBUFFER    As Integer = 1
    Const PFD_DRAW_TO_WINDOW  As Integer = 4
    Const PFD_SUPPORT_OPENGL  As Integer = 32

    Private glGenBuffers               As glGenBuffersDelegate
    Private glBindBuffer               As glBindBufferDelegate
    Private glBufferDataFloat          As glBufferDataFloatDelegate
    Private glCreateShader             As glCreateShaderDelegate
    Private glShaderSource             As glShaderSourceDelegate
    Private glCompileShader            As glCompileShaderDelegate
    Private glCreateProgram            As glCreateProgramDelegate
    Private glAttachShader             As glAttachShaderDelegate
    Private glLinkProgram              As glLinkProgramDelegate
    Private glUseProgram               As glUseProgramDelegate
    Private glGetAttribLocation        As glGetAttribLocationDelegate
    Private glEnableVertexAttribArray  As glEnableVertexAttribArrayDelegate
    Private glVertexAttribPointer      As glVertexAttribPointerDelegate
    Private wglCreateContextAttribsARB As wglCreateContextAttribsARBDelegate

    Private hDC As IntPtr = CType(0, IntPtr)
    Private hGLRC As IntPtr = CType(0, IntPtr)
    Private vbo As UInteger()
    Private posAttrib As UInteger
    Private colAttrib As UInteger

    Dim vertexSource As String = "" & _
        "attribute vec3 position;                     " & vbCrLf & _
        "attribute vec3 color;                        " & vbCrLf & _
        "varying   vec4 vColor;                       " & vbCrLf & _
        "void main()                                  " & vbCrLf & _
        "{                                            " & vbCrLf & _
        "  vColor = vec4(color, 1.0);                 " & vbCrLf & _
        "  gl_Position = vec4(position, 1.0);         " & vbCrLf & _
        "}                                            "

    Dim fragmentSource As String = "" & _
        "precision mediump float;                     " & vbCrLf & _
        "varying  vec4 vColor;                        " & vbCrLf & _
        "void main()                                  " & vbCrLf & _
        "{                                            " & vbCrLf & _
        "  gl_FragColor = vColor;                     " & vbCrLf & _
        "}                                            "

    Declare Function GetDC Lib "user32.dll" (ptr As IntPtr) As IntPtr
    Declare Function ReleaseDC Lib "user32.dll" (hWnd As IntPtr, hDc As IntPtr) As IntPtr
    Declare Function ChoosePixelFormat Lib "gdi32.dll" (hdc As IntPtr, <[In]()> ByRef pfd As PIXELFORMATDESCRIPTOR) As Integer
    Declare Function SetPixelFormat Lib "gdi32.dll" (hdc As IntPtr, format As Integer, <[In]()> ByRef pfd As PIXELFORMATDESCRIPTOR) As Boolean
    Declare Function SwapBuffers Lib "gdi32.dll" (hDC As IntPtr) As Boolean
    Declare Function wglCreateContext Lib "opengl32" (hdc As IntPtr) As IntPtr
    Declare Function wglMakeCurrent Lib "opengl32" (hdc As IntPtr, hglrc As IntPtr) As Integer
    Declare Function wglDeleteContext Lib "opengl32" (hglrc As IntPtr) As Integer
    Declare Sub glClearColor Lib "opengl32" (red As Single, green As Single, blue As Single, alpha As Single)
    Declare Sub glClear Lib "opengl32" (mask As UInteger)
    Declare Sub glBegin Lib "opengl32" (mode As UInteger)
    Declare Sub glColor3f Lib "opengl32" (red As Single, green As Single, blue As Single)
    Declare Sub glVertex2f Lib "opengl32" (x As Single, y As Single)
    Declare Sub glEnd Lib "opengl32" ()
    Declare Sub glEnableClientState Lib "opengl32" (array As UInteger)
    Declare Sub glColorPointer Lib "opengl32" (size As UInteger, type As UInteger, stride As UInteger, pointer As IntPtr)
    Declare Sub glVertexPointer Lib "opengl32" (size As UInteger, type As UInteger, stride As UInteger, pointer As IntPtr)
    Declare Sub glDrawArrays Lib "opengl32" (mode As UInteger, first As UInteger, count As UInteger)
    Declare Function wglGetProcAddress Lib "opengl32" (functionName As String) As IntPtr

    Public Sub New()
        MyBase.Size = New Size(640, 480)
        Me.Text = "Hello, World!"
        Me.vbo = New UInteger(2 - 1) {}
    End Sub

    Protected Overrides Sub OnHandleCreated(e As EventArgs)
        MyBase.OnHandleCreated(e)
        Me.EnableOpenGL()
        Me.InitOpenGLFunc()
        Me.InitShader()
    End Sub

    Protected Overrides Sub OnPaint(e As PaintEventArgs)
        MyBase.OnPaint(e)
        Me.DrawTriangle()
    End Sub

    Private Sub EnableOpenGL()
        Dim pfd As PIXELFORMATDESCRIPTOR = Nothing
        pfd.dwFlags    = PFD_SUPPORT_OPENGL Or PFD_DRAW_TO_WINDOW Or PFD_DOUBLEBUFFER
        pfd.iPixelType = PFD_TYPE_RGBA
        pfd.cColorBits = 32
        pfd.cAlphaBits = 8
        pfd.cDepthBits = 24

        Me.hDC = GetDC(MyBase.Handle)
        Dim format As Integer = ChoosePixelFormat(Me.hDC, pfd)
        SetPixelFormat(Me.hDC, format, pfd)

        Dim hGLRC_old As IntPtr = wglCreateContext(Me.hDC)
        wglMakeCurrent(Me.hDC, hGLRC_old)

        Dim wglCreateContextAttribsARBPtr As IntPtr = wglGetProcAddress("wglCreateContextAttribsARB")
        wglCreateContextAttribsARB = Marshal.GetDelegateForFunctionPointer(Of wglCreateContextAttribsARBDelegate)(wglCreateContextAttribsARBPtr)

        Me.hGLRC = wglCreateContextAttribsARB(Me.hDC, IntPtr.Zero, Nothing)

        wglMakeCurrent(Me.hDC, Me.hGLRC)
        wglDeleteContext(hGLRC_old)

    End Sub

    Private Sub InitOpenGLFunc()
        Dim glGenBuffersPtr              As IntPtr = wglGetProcAddress("glGenBuffers")
        Dim glBindBufferPtr              As IntPtr = wglGetProcAddress("glBindBuffer")
        Dim glBufferDataPtr              As IntPtr = wglGetProcAddress("glBufferData")
        Dim glCreateShaderPtr            As IntPtr = wglGetProcAddress("glCreateShader")
        Dim glShaderSourcePtr            As IntPtr = wglGetProcAddress("glShaderSource")
        Dim glCompileShaderPtr           As IntPtr = wglGetProcAddress("glCompileShader")
        Dim glCreateProgramPtr           As IntPtr = wglGetProcAddress("glCreateProgram")
        Dim glAttachShaderPtr            As IntPtr = wglGetProcAddress("glAttachShader")
        Dim glLinkProgramPtr             As IntPtr = wglGetProcAddress("glLinkProgram")
        Dim glUseProgramPtr              As IntPtr = wglGetProcAddress("glUseProgram")
        Dim glGetAttribLocationPtr       As IntPtr = wglGetProcAddress("glGetAttribLocation")
        Dim glEnableVertexAttribArrayPtr As IntPtr = wglGetProcAddress("glEnableVertexAttribArray")
        Dim glVertexAttribPointerPtr     As IntPtr = wglGetProcAddress("glVertexAttribPointer")

        Me.glGenBuffers              = Marshal.GetDelegateForFunctionPointer(Of glGenBuffersDelegate             )(glGenBuffersPtr             )
        Me.glBindBuffer              = Marshal.GetDelegateForFunctionPointer(Of glBindBufferDelegate             )(glBindBufferPtr             )
        Me.glBufferDataFloat         = Marshal.GetDelegateForFunctionPointer(Of glBufferDataFloatDelegate        )(glBufferDataPtr             )
        Me.glCreateShader            = Marshal.GetDelegateForFunctionPointer(Of glCreateShaderDelegate           )(glCreateShaderPtr           )
        Me.glShaderSource            = Marshal.GetDelegateForFunctionPointer(Of glShaderSourceDelegate           )(glShaderSourcePtr           )
        Me.glCompileShader           = Marshal.GetDelegateForFunctionPointer(Of glCompileShaderDelegate          )(glCompileShaderPtr          )
        Me.glCreateProgram           = Marshal.GetDelegateForFunctionPointer(Of glCreateProgramDelegate          )(glCreateProgramPtr          )
        Me.glAttachShader            = Marshal.GetDelegateForFunctionPointer(Of glAttachShaderDelegate           )(glAttachShaderPtr           )
        Me.glLinkProgram             = Marshal.GetDelegateForFunctionPointer(Of glLinkProgramDelegate            )(glLinkProgramPtr            )
        Me.glUseProgram              = Marshal.GetDelegateForFunctionPointer(Of glUseProgramDelegate             )(glUseProgramPtr             )
        Me.glGetAttribLocation       = Marshal.GetDelegateForFunctionPointer(Of glGetAttribLocationDelegate      )(glGetAttribLocationPtr      )
        Me.glEnableVertexAttribArray = Marshal.GetDelegateForFunctionPointer(Of glEnableVertexAttribArrayDelegate)(glEnableVertexAttribArrayPtr)
        Me.glVertexAttribPointer     = Marshal.GetDelegateForFunctionPointer(Of glVertexAttribPointerDelegate    )(glVertexAttribPointerPtr    )
    End Sub

    Private Sub InitShader()
        Dim vertexShader As UInteger = Me.glCreateShader(GL_VERTEX_SHADER)
        Dim array As String() = New String() {""}
        array(0) = vertexSource
        Me.glShaderSource(vertexShader, 1, array, Nothing)
        Me.glCompileShader(vertexShader)

        Dim fragmentShader As UInteger = Me.glCreateShader(GL_FRAGMENT_SHADER)
        array(0) = fragmentSource
        Me.glShaderSource(fragmentShader, 1, array, Nothing)
        Me.glCompileShader(fragmentShader)

        Dim program As UInteger = Me.glCreateProgram()

        Me.glAttachShader(program, vertexShader)
        Me.glAttachShader(program, fragmentShader)
        Me.glLinkProgram(program)
        Me.glUseProgram(program)

        Me.posAttrib = Me.glGetAttribLocation(program, "position")
        Me.glEnableVertexAttribArray(Me.posAttrib)
        Me.colAttrib = Me.glGetAttribLocation(program, "color")
        Me.glEnableVertexAttribArray(Me.colAttrib)

        Me.glGenBuffers(2, Me.vbo)

        Dim vertices As Single() = { _
            -0.5F, -0.5F, 0.0F, _
             0.5F, -0.5F, 0.0F, _
             0.0F,  0.5F, 0.0F  _
        }

        Dim colors As Single() = { _
             1.0F,  0.0F,  0.0F, _
             0.0F,  1.0F,  0.0F, _
             0.0F,  0.0F,  1.0F  _
        }
        
        Me.glBindBuffer(GL_ARRAY_BUFFER, Me.vbo(0))
        Me.glBufferDataFloat(GL_ARRAY_BUFFER, vertices.Length * 4, vertices, GL_STATIC_DRAW)
        Me.glBindBuffer(GL_ARRAY_BUFFER, Me.vbo(1))
        Me.glBufferDataFloat(GL_ARRAY_BUFFER, colors.Length * 4, colors, GL_STATIC_DRAW)
    End Sub

    Private Sub DrawTriangle()
        glClearColor(0F, 0F, 0F, 1F)
        glClear(GL_COLOR_BUFFER_BIT)

        Me.glBindBuffer(GL_ARRAY_BUFFER, Me.vbo(0))
        Me.glVertexAttribPointer(Me.posAttrib, 3, GL_FLOAT, False, 0, IntPtr.Zero)
        Me.glBindBuffer(GL_ARRAY_BUFFER, Me.vbo(1))
        Me.glVertexAttribPointer(Me.colAttrib, 3, GL_FLOAT, False, 0, IntPtr.Zero)

        glDrawArrays(GL_TRIANGLES, 0, 3)

        SwapBuffers(Me.hDC)
    End Sub

    <STAThread()> _
    Public Shared Sub Main()
        Dim mainForm As HelloForm = New HelloForm()
        Application.Run(mainForm)
    End Sub
End Class
