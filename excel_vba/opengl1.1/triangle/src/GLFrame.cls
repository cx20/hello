VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "GLFrame"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private WithEvents Frame As MSForms.Frame
Attribute Frame.VB_VarHelpID = -1
Private Const PIX_SCALE As Double = (1 / 72) * 96

Public Event Load()
Public Event Paint()
Private Declare PtrSafe Function WindowFromAccessibleObject Lib "oleacc.dll" (ByVal IAcessible As Object, ByRef hWnd As LongPtr) As LongPtr
Private GL As GL

Private Sub Class_Terminate()
    GL.PaintEnd
End Sub

Public Sub Refresh()
    RaiseEvent Paint
End Sub

Public Property Get Width() As Double
    Width = Frame.Width * PIX_SCALE
End Property

Public Property Get Height() As Double
    Height = Frame.Height * PIX_SCALE
End Property

Public Sub Init(ByRef TargetFrame As MSForms.Frame, ByRef RefGL As GL)
    Dim hw As LongPtr
    Set GL = RefGL
    DoEvents
    WindowFromAccessibleObject TargetFrame, hw
    With GL
        .hWnd = hw
        .PaintStart
        .ClearColor 1, 1, 1, 1
        .Enable GL_DEPTH_TEST
    End With
    Set Frame = TargetFrame
    DoEvents
    RaiseEvent Load
End Sub
