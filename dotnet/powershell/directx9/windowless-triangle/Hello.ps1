$source = @"
using System;
using System.Drawing;
using System.Windows.Forms;
using Microsoft.DirectX;
using Microsoft.DirectX.Direct3D;

public class HelloForm : Form
{
   private Device m_device = null;

   HelloForm()
   {
      const int WIDTH = 640;
      const int HEIGHT = 480;
      this.ClientSize = new System.Drawing.Size(WIDTH, HEIGHT);
      this.Text = "Hello, World!";

      this.FormBorderStyle = FormBorderStyle.None;
      this.BackColor = Color.Black;
      this.TransparencyKey = Color.Black;
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

   public static void Main()
   {
      HelloForm form = new HelloForm();
      form.InitGraphics();
      Application.Run(form);
   }
}
"@
$path = "C:\Windows\Microsoft.NET\Framework\v4.0.30319"
$assemblies = @(
	"$path\System.dll",
	"$path\System.Windows.Forms.dll",
	"$path\System.Drawing.dll",
	"C:\Windows\assembly\GAC\Microsoft.DirectX\1.0.2902.0__31bf3856ad364e35\Microsoft.DirectX.dll",
	"C:\Windows\assembly\GAC\Microsoft.DirectX.Direct3D\1.0.2902.0__31bf3856ad364e35\Microsoft.DirectX.Direct3D.dll",
	"C:\Windows\assembly\GAC_MSIL\Microsoft.VisualC\8.0.0.0__b03f5f7f11d50a3a\Microsoft.VisualC.Dll"
)
$cp = [System.CodeDom.Compiler.CompilerParameters]::new($assemblies)
Add-Type -Language CSharp -TypeDefinition $source -CompilerParameters $cp
[void][HelloForm]::Main()
