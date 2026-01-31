Imports System
Imports System.Drawing
Imports System.Runtime.CompilerServices
Imports System.Windows.Forms
Imports SharpDX
Imports SharpDX.D3DCompiler
Imports SharpDX.Direct3D
Imports SharpDX.Direct3D10
Imports SharpDX.DXGI
Imports SharpDX.Windows
Imports Color = SharpDX.Color
Imports Buffer = SharpDX.Direct3D10.Buffer
Imports Device = SharpDX.Direct3D10.Device

Class Program
    Const WIDTH = 640
    Const HEIGHT = 480

    Public Shared Sub Main()
        Dim renderForm As RenderForm = New RenderForm("Hello, World!")
        Dim swapChainDescription As SwapChainDescription = New SwapChainDescription() With { 
            .BufferCount = 1, 
            .ModeDescription = New ModeDescription(
                WIDTH, 
                HEIGHT, 
                New Rational(60, 1), 
                Format.R8G8B8A8_UNorm
            ), 
            .IsWindowed = True, 
            .OutputHandle = renderForm.Handle, 
            .SampleDescription = New SampleDescription(1, 0), 
            .SwapEffect = SwapEffect.Discard, 
            .Usage = Usage.RenderTargetOutput 
        }
        Dim swapChain As SwapChain
        Dim device As SharpDX.Direct3D10.Device
        SharpDX.Direct3D10.Device.CreateWithSwapChain(SharpDX.Direct3D10.DriverType.Hardware, DeviceCreationFlags.None, swapChainDescription, device, swapChain)
        Dim context As SharpDX.Direct3D10.Device = device
        Dim parent As Factory = swapChain.GetParent(Of Factory)()
        parent.MakeWindowAssociation(renderForm.Handle, WindowAssociationFlags.IgnoreAll)

        Dim texture2D As Texture2D = SharpDX.Direct3D10.Resource.FromSwapChain(Of Texture2D)(swapChain, 0)
        Dim renderView As RenderTargetView = New RenderTargetView(device, texture2D)
        Dim compilationResult As CompilationResult = ShaderBytecode.Compile(
            "struct VS_IN                         " & vbLf & 
            "{                                    " & vbLf & 
            "    float4 pos : POSITION;           " & vbLf & 
            "    float4 col : COLOR;              " & vbLf & 
            "};                                   " & vbLf & 
            "                                     " & vbLf & 
            "struct PS_IN                         " & vbLf & 
            "{                                    " & vbLf & 
            "    float4 pos : SV_POSITION;        " & vbLf & 
            "    float4 col : COLOR;              " & vbLf & 
            "};                                   " & vbLf & 
            "                                     " & vbLf & 
            "PS_IN VS( VS_IN input )              " & vbLf & 
            "{                                    " & vbLf & 
            "    PS_IN output = (PS_IN)0;         " & vbLf & 
            "                                     " & vbLf & 
            "    output.pos = input.pos;          " & vbLf & 
            "    output.col = input.col;          " & vbLf & 
            "                                     " & vbLf & 
            "    return output;                   " & vbLf & 
            "}                                    " & vbLf & 
            "                                     " & vbLf & 
            "float4 PS( PS_IN input ) : SV_Target " & vbLf & 
            "{                                    " & vbLf & 
            "    return input.col;                " & vbLf & 
            "}                                    " & vbLf, 
            "VS", 
            "vs_4_0", 
            ShaderFlags.OptimizationLevel1, 
            EffectFlags.None, 
            "unknown", 
            SecondaryDataFlags.None, 
            Nothing
        )
        Dim vertexShader As VertexShader = New VertexShader(device, compilationResult)
        Dim compilationResult2 As CompilationResult = ShaderBytecode.Compile(
            "struct VS_IN                         " & vbLf & 
            "{                                    " & vbLf & 
            "    float4 pos : POSITION;           " & vbLf & 
            "    float4 col : COLOR;              " & vbLf & 
            "};                                   " & vbLf & 
            "                                     " & vbLf & 
            "struct PS_IN                         " & vbLf & 
            "{                                    " & vbLf & 
            "    float4 pos : SV_POSITION;        " & vbLf & 
            "    float4 col : COLOR;              " & vbLf & 
            "};                                   " & vbLf & 
            "                                     " & vbLf & 
            "PS_IN VS( VS_IN input )              " & vbLf & 
            "{                                    " & vbLf & 
            "    PS_IN output = (PS_IN)0;         " & vbLf & 
            "                                     " & vbLf & 
            "    output.pos = input.pos;          " & vbLf & 
            "    output.col = input.col;          " & vbLf & 
            "                                     " & vbLf & 
            "    return output;                   " & vbLf & 
            "}                                    " & vbLf & 
            "                                     " & vbLf & 
            "float4 PS( PS_IN input ) : SV_Target " & vbLf & 
            "{                                    " & vbLf & 
            "    return input.col;                " & vbLf & 
            "}                                    " & vbLf, 
            "PS", 
            "ps_4_0", 
            ShaderFlags.OptimizationLevel1, 
            EffectFlags.None, 
            "unknown", 
            SecondaryDataFlags.None, 
            Nothing
        )
        Dim pixelShader As PixelShader = New PixelShader(device, compilationResult2)

        Dim inputLayout As InputLayout = New InputLayout(device, 
            ShaderSignature.GetInputSignature(compilationResult), 
            New InputElement() { 
                New InputElement("POSITION", 0, Format.R32G32B32A32_Float, 0, 0), 
                New InputElement("COLOR", 0, Format.R32G32B32A32_Float, 16, 0) 
            })
        Dim buffer As SharpDX.Direct3D10.Buffer = SharpDX.Direct3D10.Buffer.Create(Of Vector4)(
            device, 
            BindFlags.VertexBuffer, 
            New Vector4() { 
                New Vector4(0F, 0.5F, 0.5F, 1F),
                New Vector4(1F, 0F, 0F, 1F),
                New Vector4(0.5F, -0.5F, 0.5F, 1F),
                New Vector4(0F, 1F, 0F, 1F),
                New Vector4(-0.5F, -0.5F, 0.5F, 1F),
                New Vector4(0F, 0F, 1F, 1F) 
            }, 
            0, 
            ResourceUsage.[Default], 
            CpuAccessFlags.None, 
            ResourceOptionFlags.None, 
            0
        )
        context.InputAssembler.InputLayout = inputLayout
        context.InputAssembler.PrimitiveTopology = PrimitiveTopology.TriangleList
        context.InputAssembler.SetVertexBuffers(0, New VertexBufferBinding(buffer, 32, 0))
        context.VertexShader.[Set](vertexShader)
        context.Rasterizer.SetViewports(New Viewport(0, 0, 640, 480, 0F, 1F))
        context.PixelShader.[Set](pixelShader)
        context.OutputMerger.SetTargets(renderView)

        RenderLoop.Run(
            renderForm, 
            Sub()
                context.ClearRenderTargetView(renderView, Color.Black)
                context.Draw(3, 0)
                swapChain.Present(0, PresentFlags.None)
            End Sub, 
            False
        )

        compilationResult.Dispose()
        vertexShader.Dispose()
        compilationResult2.Dispose()
        pixelShader.Dispose()
        buffer.Dispose()
        inputLayout.Dispose()
        renderView.Dispose()
        texture2D.Dispose()
        context.ClearState()
        context.Flush()
        device.Dispose()
        context.Dispose()
        swapChain.Dispose()
        parent.Dispose()
    End Sub
End Class
