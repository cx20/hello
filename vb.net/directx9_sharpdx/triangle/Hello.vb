Imports System
Imports System.Drawing
Imports System.Runtime.CompilerServices
Imports System.Windows.Forms
Imports SharpDX
Imports SharpDX.Direct3D9
Imports SharpDX.Windows
Imports Color = SharpDX.Color

Friend Structure Vertex
    Public Position As Vector4
    Public Color As ColorBGRA
End Structure

Class Program
    Const WIDTH = 640
    Const HEIGHT = 480

    Public Shared Sub Main()
        Dim renderForm As RenderForm = New RenderForm("Hello, World!")
        Dim device As Device = New Device(
            New Direct3D(), 
            0, 
            DeviceType.Hardware,
            renderForm.Handle,
            CreateFlags.HardwareVertexProcessing,
            New PresentParameters() { New PresentParameters(640, 480) }
        )
        Dim vertices As VertexBuffer = New VertexBuffer(
            device, 
            60, 
            Usage.[WriteOnly], 
            VertexFormat.Texture0, 
            Pool.Managed
        )
        vertices.Lock(0, 0, LockFlags.None).WriteRange(Of Vertex)(New Vertex() { 
            New Vertex() With { .Color = Color.Red, .Position = New Vector4(300F, 100F, 0F, 1F) }, 
            New Vertex() With { .Color = Color.Blue, .Position = New Vector4(500F, 400F, 0F, 1F) }, 
            New Vertex() With { .Color = Color.Green, .Position = New Vector4(100F, 400F, 0F, 1F) } 
        })
        vertices.Unlock()
        Dim elements As VertexElement() = New VertexElement() { 
            New VertexElement(0, 0, DeclarationType.Float4, DeclarationMethod.[Default], DeclarationUsage.PositionTransformed, 0), 
            New VertexElement(0, 16, DeclarationType.Color, DeclarationMethod.[Default], DeclarationUsage.Color, 0), VertexElement.VertexDeclarationEnd 
        }
        Dim vertexDecl As VertexDeclaration = New VertexDeclaration(device, elements)

        RenderLoop.Run(renderForm, Sub()
            device.Clear(ClearFlags.Target Or ClearFlags.ZBuffer, Color.Black, 1F, 0)
            device.BeginScene()
            device.SetStreamSource(0, vertices, 0, 20)
            device.VertexDeclaration = vertexDecl
            device.DrawPrimitives(PrimitiveType.TriangleList, 0, 1)
            device.EndScene()
            device.Present()
        End Sub, False)
    End Sub

End Class
