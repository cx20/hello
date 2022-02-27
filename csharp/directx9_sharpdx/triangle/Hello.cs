// forked from https://github.com/sharpdx/SharpDX-Samples/blob/master/Desktop/Direct3D9/MiniTri/Program.cs

using System;
using System.Runtime.InteropServices;
using SharpDX;
using SharpDX.Direct3D9;
using SharpDX.Windows;
using Color = SharpDX.Color;

[StructLayout(LayoutKind.Sequential)]
struct Vertex
{
    public Vector4 Position;
    public SharpDX.ColorBGRA Color;
}

static class Program
{
    [STAThread]
    static void Main()
    {
        var form = new RenderForm("Hello, World!");
        var device = new Device(
            new Direct3D(),
            0,
            DeviceType.Hardware,
            form.Handle,
            CreateFlags.HardwareVertexProcessing,
            new PresentParameters(640, 480)
        );

        var vertices = new VertexBuffer(device, 3 * 20, Usage.WriteOnly, VertexFormat.None, Pool.Managed);
        vertices.Lock(0, 0, LockFlags.None).WriteRange(new[] {
            new Vertex() { Color = Color.Red,   Position = new Vector4(300.0f, 100.0f, 0.0f, 1.0f) },
            new Vertex() { Color = Color.Blue,  Position = new Vector4(500.0f, 400.0f, 0.0f, 1.0f) },
            new Vertex() { Color = Color.Green, Position = new Vector4(100.0f, 400.0f, 0.0f, 1.0f) }
        });
        vertices.Unlock();

        var vertexElems = new[] {
            new VertexElement(0, 0, DeclarationType.Float4, DeclarationMethod.Default, DeclarationUsage.PositionTransformed, 0),
            new VertexElement(0, 16, DeclarationType.Color, DeclarationMethod.Default, DeclarationUsage.Color, 0),
            VertexElement.VertexDeclarationEnd
        };

        var vertexDecl = new VertexDeclaration(device, vertexElems);

        RenderLoop.Run(form, () =>
        {
            device.Clear(ClearFlags.Target | ClearFlags.ZBuffer, Color.Black, 1.0f, 0);
            device.BeginScene();

            device.SetStreamSource(0, vertices, 0, 20);
            device.VertexDeclaration = vertexDecl;
            device.DrawPrimitives(PrimitiveType.TriangleList, 0, 1);

            device.EndScene();
            device.Present();
        });
    }
}

