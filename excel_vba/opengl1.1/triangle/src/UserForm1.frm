VERSION 5.00
Begin {C62A69F0-16DC-11CE-9E98-00AA00574A4F} UserForm1 
   Caption         =   "Hello, Triangle World!"
   ClientHeight    =   7485
   ClientLeft      =   120
   ClientTop       =   465
   ClientWidth     =   9480
   OleObjectBlob   =   "UserForm1.frx":0000
   StartUpPosition =   1  'オーナー フォームの中央
End
Attribute VB_Name = "UserForm1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private WithEvents glControl As GLFrame
Attribute glControl.VB_VarHelpID = -1
Private GL As GL

Sub UserForm_Initialize()
    Set glControl = New GLFrame
    Set GL = New GL
End Sub

Sub UserForm_Activate()
    glControl.Init Me.Frame1, GL
End Sub

Sub GLControl_Load()
    With GL
        .Viewport 0, 0, glControl.Width, glControl.Height
    End With
    glControl.Refresh
End Sub

Sub GLControl_Paint()
    Dim Color(0 To 8) As Double
    Color(0) = 1#
    Color(1) = 0#
    Color(2) = 0#
    Color(3) = 0#
    Color(4) = 1#
    Color(5) = 0#
    Color(6) = 0#
    Color(7) = 0#
    Color(8) = 1#
    
    Dim Vertex(0 To 8) As Double
    Vertex(0) = 0#
    Vertex(1) = 0.5
    Vertex(2) = 0#
    Vertex(3) = 0.5
    Vertex(4) = -0.5
    Vertex(5) = 0#
    Vertex(6) = -0.5
    Vertex(7) = -0.5
    Vertex(8) = 0#

    With GL
        .Clear GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT

        .EnableClientState GL_COLOR_ARRAY
        .EnableClientState GL_VERTEX_ARRAY
        .ColorPointer 3, GL_DOUBLE, 0, VarPtr(Color(0))
        .VertexPointer 3, GL_DOUBLE, 0, VarPtr(Vertex(0))
        .DrawArrays GL_TRIANGLES, 0, UBound(Vertex) + 1
        .DisableClientState GL_COLOR_ARRAY
        .DisableClientState GL_VERTEX_ARRAY
        .SwapBuffers
    End With
End Sub
