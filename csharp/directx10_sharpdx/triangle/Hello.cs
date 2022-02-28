// forked from https://github.com/sharpdx/SharpDX-Samples/blob/master/Desktop/Direct3D10/MiniTri/Program.cs

using System;
using SharpDX;
using SharpDX.D3DCompiler;
using SharpDX.Direct3D;
using SharpDX.Direct3D10;
using SharpDX.DXGI;
using SharpDX.Windows;
using Buffer = SharpDX.Direct3D10.Buffer;
using Device = SharpDX.Direct3D10.Device;

namespace MiniTri
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            var form = new RenderForm("Hello, World!");

            var desc = new SwapChainDescription()
               {
                   BufferCount = 1,
                   ModeDescription= new ModeDescription(640, 480, new Rational(60, 1), Format.R8G8B8A8_UNorm),
                   IsWindowed = true,
                   OutputHandle = form.Handle,
                   SampleDescription = new SampleDescription(1, 0),
                   SwapEffect = SwapEffect.Discard,
                   Usage = Usage.RenderTargetOutput
               };

            Device device;
            SwapChain swapChain;
            Device.CreateWithSwapChain(SharpDX.Direct3D10.DriverType.Hardware, DeviceCreationFlags.None, desc, out device, out swapChain);
            var context = device;

            var factory = swapChain.GetParent<Factory>();
            factory.MakeWindowAssociation(form.Handle, WindowAssociationFlags.IgnoreAll);

            var backBuffer = Texture2D.FromSwapChain<Texture2D>(swapChain, 0);
            var renderView = new RenderTargetView(device, backBuffer);

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
            var vertexShader = new VertexShader(device, vertexShaderByteCode);

            var pixelShaderByteCode = ShaderBytecode.Compile(shaderSource, "PS", "ps_4_0", ShaderFlags.None, EffectFlags.None);
            var pixelShader = new PixelShader(device, pixelShaderByteCode);

            var layout = new InputLayout(
                device,
                ShaderSignature.GetInputSignature(vertexShaderByteCode),
                new[]
                {
                    new InputElement("POSITION", 0, Format.R32G32B32A32_Float,  0, 0),
                    new InputElement("COLOR",    0, Format.R32G32B32A32_Float, 16, 0)
                });

            var vertices = Buffer.Create(device, BindFlags.VertexBuffer, 
                new[]
                {
                    new Vector4( 0.0f,  0.5f, 0.5f, 1.0f), new Vector4(1.0f, 0.0f, 0.0f, 1.0f),
                    new Vector4( 0.5f, -0.5f, 0.5f, 1.0f), new Vector4(0.0f, 1.0f, 0.0f, 1.0f),
                    new Vector4(-0.5f, -0.5f, 0.5f, 1.0f), new Vector4(0.0f, 0.0f, 1.0f, 1.0f)
                });

            context.InputAssembler.InputLayout = layout;
            context.InputAssembler.PrimitiveTopology = PrimitiveTopology.TriangleList;
            context.InputAssembler.SetVertexBuffers(0, new VertexBufferBinding(vertices, 32, 0));
            context.VertexShader.Set(vertexShader);
            context.Rasterizer.SetViewports(new Viewport(0, 0, 640, 480, 0.0f, 1.0f));
            context.PixelShader.Set(pixelShader);
            context.OutputMerger.SetTargets(renderView);

            RenderLoop.Run(form, () =>
              {
                  context.ClearRenderTargetView(renderView, Color.Black);
                  context.Draw(3, 0);
                  swapChain.Present(0, PresentFlags.None);
              });

            vertexShaderByteCode.Dispose();
            vertexShader.Dispose();
            pixelShaderByteCode.Dispose();
            pixelShader.Dispose();
            vertices.Dispose();
            layout.Dispose();
            renderView.Dispose();
            backBuffer.Dispose();
            context.ClearState();
            context.Flush();
            device.Dispose();
            context.Dispose();
            swapChain.Dispose();
            factory.Dispose();
        }
    }
}