using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;

using SharpDX;
using SharpDX.DXGI;
using SharpDX.Direct3D;
using SharpDX.Direct3D11;

using SharpDX.D3DCompiler;

static class Program
{
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        using (GameForm form = new GameForm())
        {
            form.Exec();
            form.Close();
        }
    }
}
    
public class GameForm : Form, IDisposable
{
    SharpDX.Direct3D11.Device Device { get { return _device; } }
    SharpDX.Direct3D11.Device _device = null;

    SwapChain _SwapChain;
    Texture2D _BackBuffer;

    RenderTargetView _RenderTarget3D;
    IntPtr DisplayHandle { get { return Handle; } }

    public GameForm()
    {
        MaximizeBox = false;
        Size = new Size( 640, 480 );
        Text = "Hello, World!";
    }

    public void Exec()
    {
        Initialize();

        Show();
        while (Created)
        {
            MainLoop();
            Application.DoEvents();
            Thread.Sleep(16);
        }
    }

    public void Initialize()
    {
        var desc = new SwapChainDescription()
        {
            BufferCount = 1,
            ModeDescription = new ModeDescription(ClientSize.Width, ClientSize.Height, new Rational(60, 1), Format.R8G8B8A8_UNorm),
            IsWindowed = true,
            OutputHandle = DisplayHandle,
            SampleDescription = new SampleDescription(1, 0),
            SwapEffect = SwapEffect.Discard,
            Usage = Usage.RenderTargetOutput
        };

        SharpDX.Direct3D11.Device.CreateWithSwapChain(
            DriverType.Hardware,
            DeviceCreationFlags.BgraSupport,
            new[] { SharpDX.Direct3D.FeatureLevel.Level_11_0 },
            desc,
            out _device, out _SwapChain);

        var factory = _SwapChain.GetParent<SharpDX.DXGI.Factory>();
        factory.MakeWindowAssociation(DisplayHandle, WindowAssociationFlags.IgnoreAll);

        _BackBuffer = Texture2D.FromSwapChain<Texture2D>(_SwapChain, 0);

        InitializeDirect3D();
    }

    public void InitializeDirect3D()
    {
        _RenderTarget3D = new RenderTargetView(_device, _BackBuffer);

        const string shaderSource = 
            "struct VS_IN                         \n" + 
            "{                                    \n" + 
            "    float4 pos : POSITION;           \n" + 
            "    float4 col : COLOR;              \n" + 
            "};                                   \n" + 
            "                                     \n" + 
            "struct PS_IN                         \n" + 
            "{                                    \n" + 
            "    float4 pos : SV_POSITION;        \n" + 
            "    float4 col : COLOR;              \n" + 
            "};                                   \n" + 
            "                                     \n" + 
            "PS_IN VS( VS_IN input )              \n" + 
            "{                                    \n" + 
            "    PS_IN output = (PS_IN)0;         \n" + 
            "                                     \n" + 
            "    output.pos = input.pos;          \n" + 
            "    output.col = input.col;          \n" + 
            "                                     \n" + 
            "    return output;                   \n" + 
            "}                                    \n" + 
            "                                     \n" + 
            "float4 PS( PS_IN input ) : SV_Target \n" + 
            "{                                    \n" + 
            "    return input.col;                \n" + 
            "}                                    \n";

        var vertexShaderByteCode = ShaderBytecode.Compile(shaderSource, "VS", "vs_4_0", ShaderFlags.None, EffectFlags.None);
        var vertexShader = new VertexShader(_device, vertexShaderByteCode);
        
        var pixelShaderByteCode = ShaderBytecode.Compile(shaderSource, "PS", "ps_4_0", ShaderFlags.None, EffectFlags.None);
        var pixelShader = new PixelShader(_device, pixelShaderByteCode);

        var layout = new InputLayout(
            _device,
            ShaderSignature.GetInputSignature(vertexShaderByteCode),
            new[]
                {
                    new InputElement("POSITION", 0, Format.R32G32B32A32_Float, 0, 0),
                    new InputElement("COLOR", 0, Format.R32G32B32A32_Float, 16, 0)
                });

        var context = _device.ImmediateContext;
        context.InputAssembler.InputLayout = layout;
        context.InputAssembler.PrimitiveTopology = PrimitiveTopology.TriangleList;
        context.VertexShader.Set(vertexShader);
        context.PixelShader.Set(pixelShader);
        context.Rasterizer.SetViewport(new Viewport(0, 0, ClientSize.Width, ClientSize.Height, 0.0f, 1.0f));
        context.OutputMerger.SetTargets(_RenderTarget3D);

        var vertices = SharpDX.Direct3D11.Buffer.Create(_device, BindFlags.VertexBuffer, new[]
                              {
                                  new Vector4( 0.0f,  0.5f, 0.5f, 1.0f), new Vector4(1.0f, 0.0f, 0.0f, 1.0f),
                                  new Vector4( 0.5f, -0.5f, 0.5f, 1.0f), new Vector4(0.0f, 1.0f, 0.0f, 1.0f),
                                  new Vector4(-0.5f, -0.5f, 0.5f, 1.0f), new Vector4(0.0f, 0.0f, 1.0f, 1.0f)
                              });
        context.InputAssembler.SetVertexBuffers(0, new VertexBufferBinding(vertices, Utilities.SizeOf<Vector4>() * 2, 0));
    }

    public void MainLoop()
    {
        var context = _device.ImmediateContext;
        context.ClearRenderTargetView(_RenderTarget3D, SharpDX.Color.Black);
        context.Draw(3, 0);
        _SwapChain.Present(0, PresentFlags.None);
    }
/*
    public void Dispose()
    {
        var context = _device?.ImmediateContext;
        
        _RenderTarget3D?.Dispose();
        _BackBuffer?.Dispose();
        context?.ClearState();
        context?.Flush();
        _device?.Dispose();
        context?.Dispose();
        _SwapChain?.Dispose();

        base.Dispose();
    }
*/
}
