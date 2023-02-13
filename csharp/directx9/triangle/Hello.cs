// forked from https://gregs-blog.com/2008/02/29/managed-directx-c-graphics-tutorial-2-drawing-a-triangle/

using System;
using System.Windows.Forms;
using Microsoft.DirectX;
using Microsoft.DirectX.Direct3D;

class Hello : Form
{
   private Device m_device = null;

   Hello()
   {
      const int WIDTH = 640;
      const int HEIGHT = 480;
      this.ClientSize = new System.Drawing.Size(WIDTH, HEIGHT);
      this.Text = "Hello, World!";
   }

   void InitGraphics()
   {
      PresentParameters present_params = new PresentParameters();

      present_params.Windowed = true;
      present_params.SwapEffect = SwapEffect.Discard;

      m_device = new Device(0, DeviceType.Hardware, this,
                            CreateFlags.SoftwareVertexProcessing, present_params);
   }

   protected override void OnPaint(PaintEventArgs e)
   {
      CustomVertex.TransformedColored[] vertexes = new CustomVertex.TransformedColored[3];

      vertexes[0].Position = new Vector4(300, 100, 0, 1.0f);
      vertexes[0].Color = System.Drawing.Color.FromArgb(0, 255, 0).ToArgb();
      vertexes[1].Position = new Vector4(500, 400, 0, 1.0f);
      vertexes[1].Color = System.Drawing.Color.FromArgb(0, 0, 255).ToArgb();
      vertexes[2].Position = new Vector4(100, 400, 0, 1.0f);
      vertexes[2].Color = System.Drawing.Color.FromArgb(255, 0, 0).ToArgb();

      m_device.Clear(ClearFlags.Target, System.Drawing.Color.FromArgb(0, 0, 0).ToArgb(), 1.0f, 0);
      m_device.BeginScene();
      m_device.VertexFormat = CustomVertex.TransformedColored.Format;
      m_device.DrawUserPrimitives(PrimitiveType.TriangleList, 1, vertexes);
      m_device.EndScene();
      m_device.Present();
   }

   static void Main()
   {
      Hello MainForm = new Hello();
      MainForm.InitGraphics();
      Application.Run(MainForm);
   }
}
