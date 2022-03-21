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

    Const GL_TRIANGLES        As Integer = &h0004
    Const GL_COLOR_BUFFER_BIT As Integer = &h00004000

    Const PFD_TYPE_RGBA       As Integer = 0
    Const PFD_DOUBLEBUFFER    As Integer = 1
    Const PFD_DRAW_TO_WINDOW  As Integer = 4
    Const PFD_SUPPORT_OPENGL  As Integer = 32

    Private hDC As IntPtr = CType(0, IntPtr)
    Private hGLRC As IntPtr = CType(0, IntPtr)

    Declare Function GetDC Lib "user32.dll" (ptr As IntPtr) As IntPtr
    Declare Function ReleaseDC Lib "user32.dll" (hWnd As IntPtr, hDc As IntPtr) As IntPtr
    Declare Function ChoosePixelFormat Lib "gdi32.dll" (hdc As IntPtr, ByRef pfd As PIXELFORMATDESCRIPTOR) As Integer
    Declare Function SetPixelFormat Lib "gdi32.dll" (hdc As IntPtr, format As Integer, ByRef pfd As PIXELFORMATDESCRIPTOR) As Boolean
    Declare Function SwapBuffers Lib "gdi32.dll" (hDC As IntPtr) As Boolean
    Declare Function wglCreateContext Lib "opengl32" (hdc As UInteger) As UInteger
    Declare Function wglMakeCurrent Lib "opengl32" (hdc As UInteger, hglrc As UInteger) As Integer
    Declare Function wglDeleteContext Lib "opengl32" (hglrc As UInteger) As Integer
    Declare Sub glClearColor Lib "opengl32" (red As Single, green As Single, blue As Single, alpha As Single)
    Declare Sub glClear Lib "opengl32" (mask As UInteger)
    Declare Sub glBegin Lib "opengl32" (mode As UInteger)
    Declare Sub glColor3f Lib "opengl32.dll" (red As Single, green As Single, blue As Single)
    Declare Sub glVertex2f Lib "opengl32.dll" (x As Single, y As Single)
    Declare Sub glEnd Lib "opengl32.dll" ()

    Public Sub New()
        MyBase.Size = New Size(640, 480)
        Me.Text = "Hello, World!"
    End Sub

    Protected Overrides Sub OnHandleCreated(e As EventArgs)
        MyBase.OnHandleCreated(e)

        Dim pfd As PIXELFORMATDESCRIPTOR = Nothing
        pfd.dwFlags    = PFD_SUPPORT_OPENGL Or PFD_DRAW_TO_WINDOW Or PFD_DOUBLEBUFFER
        pfd.iPixelType = PFD_TYPE_RGBA
        pfd.cColorBits = 32
        pfd.cAlphaBits = 8
        pfd.cDepthBits = 24
        
        ' TODO : GetDC has failed in some cases, so this needs to be investigated.
        Me.hDC = GetDC(Handle)
        Dim format As Integer = ChoosePixelFormat(Me.hDC, pfd)
        SetPixelFormat(Me.hDC, format, pfd)

        Me.hGLRC = wglCreateContext(Me.hDC)
        wglMakeCurrent(Me.hDC, Me.hGLRC)
    End Sub

    Protected Overrides Sub OnPaint(e As PaintEventArgs)
        MyBase.OnPaint(e)

        glClearColor(0F, 0F, 0F, 1F)
        glClear(GL_COLOR_BUFFER_BIT)

        glBegin(GL_TRIANGLES)
            glColor3f(1F, 0F, 0F)
            glVertex2f(0F, 0.5F)
            glColor3f(0F, 1F, 0F)
            glVertex2f(0.5F, -0.5F)
            glColor3f(0F, 0F, 1F)
            glVertex2f(-0.5F, -0.5F)
        glEnd()

        SwapBuffers(Me.hDC)
    End Sub

    <STAThread()> _
    Shared Sub Main()
        Dim mainForm As HelloForm = New HelloForm()
        Application.Run(mainForm)
    End Sub
End Class
