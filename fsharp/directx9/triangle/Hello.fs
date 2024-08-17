open System
open System.Drawing
open System.Windows.Forms
open Microsoft.DirectX
open Microsoft.DirectX.Direct3D

type HelloForm() as this =
    inherit Form()

    let mutable device : Device = null

    do
        this.ClientSize <- Size(640, 480)
        this.Text <- "Hello, World!"
        this.InitGraphics()

    member this.InitGraphics() =
        let parameters = PresentParameters()
        parameters.Windowed <- true
        parameters.SwapEffect <- SwapEffect.Discard

        device <- new Device(0, DeviceType.Hardware, this, CreateFlags.SoftwareVertexProcessing, [|parameters|])

    override this.OnPaint e =
        let vertices = Array.zeroCreate<CustomVertex.TransformedColored> 3
        
        vertices.[0].Position <- Vector4(300.0f, 100.0f, 0.0f, 1.0f)
        vertices.[0].Color <- Color.FromArgb(0, 255, 0).ToArgb()
        
        vertices.[1].Position <- Vector4(500.0f, 400.0f, 0.0f, 1.0f)
        vertices.[1].Color <- Color.FromArgb(0, 0, 255).ToArgb()
        
        vertices.[2].Position <- Vector4(100.0f, 400.0f, 0.0f, 1.0f)
        vertices.[2].Color <- Color.FromArgb(255, 0, 0).ToArgb()

        device.Clear(ClearFlags.Target, Color.FromArgb(0, 0, 0).ToArgb(), 1.0f, 0)
        device.BeginScene()
        
        device.VertexFormat <- VertexFormats.Diffuse ||| VertexFormats.Transformed
        device.DrawUserPrimitives(PrimitiveType.TriangleList, 1, vertices)
        
        device.EndScene()
        device.Present()

[<STAThread>]
[<EntryPoint>]
let main argv = 
    Application.EnableVisualStyles()
    Application.SetCompatibleTextRenderingDefault(false)
    
    use form = new HelloForm()
    Application.Run(form)
    0