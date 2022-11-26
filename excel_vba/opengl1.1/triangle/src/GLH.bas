Attribute VB_Name = "GLH"
Option Explicit
Public Enum Glenum

    GL_AMBIENT_AND_DIFFUSE = &H1602
    GL_COLOR_BUFFER_BIT = &H4000
    GL_DEPTH_BUFFER_BIT = &H100
    GL_DEPTH_TEST = &HB71
    GL_LIGHT0 = &H4000
    GL_LIGHTING = &HB50
    GL_MODELVIEW = &H1700
    GL_PROJECTION = &H1701
    GL_TRIANGLES = &H4
    GL_FRONT = 1028
    GL_VERTEX_ARRAY = &H8074&
    GL_NORMAL_ARRAY = &H8075&
    GL_COLOR_ARRAY = &H8076&
    GL_DOUBLE = &H140A
    PFD_DOUBLEBUFFER = 1
    PFD_DRAW_TO_WINDOW = 4
    PFD_SUPPORT_OPENGL = 32
End Enum

Public Type PIXELFORMATDESCRIPTOR
    nSize As Long
    nVersion As Long
    dwFlags As Long
    iPixelType As Byte
    cColorBits As Byte
    cRedBits As Byte
    cRedShift As Byte
    cGreenBits As Byte
    cGreenShift As Byte
    cBlueBits As Byte
    cBlueShift As Byte
    cAlphaBits As Byte
    cAlphaShift As Byte
    cAccumBits As Byte
    cAccumRedBits As Byte
    cAccumGreenBits As Byte
    cAccumBlueBits As Byte
    cAccumAlphaBits As Byte
    cDepthBits As Byte
    cStencilBits As Byte
    cAuxBuffers As Byte
    iLayerType As Byte
    bReserved As Byte
    dwLayerMask As Long
    dwVisibleMask As Long
    dwDamageMask As Long
End Type

Public Sub ShowForm()
    Dim frm
    Set frm = New UserForm1
    frm.Show
End Sub
