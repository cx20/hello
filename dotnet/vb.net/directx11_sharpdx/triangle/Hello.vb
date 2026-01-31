Imports System
Imports System.Drawing
Imports System.Runtime.CompilerServices
Imports System.Windows.Forms
Imports SharpDX
Imports SharpDX.D3DCompiler
Imports SharpDX.Direct3D
Imports SharpDX.Direct3D11
Imports SharpDX.DXGI
Imports SharpDX.Windows
Imports Color = SharpDX.Color
Imports Buffer = SharpDX.Direct3D11.Buffer
Imports Device = SharpDX.Direct3D11.Device

Class Program
    Const WIDTH = 640
    Const HEIGHT = 480

    Public Shared Sub Main()
        Dim renderForm As RenderForm = New RenderForm("Hello, World!")
        Dim swapChainDescription As SwapChainDescription = New SwapChainDescription() With { 
            .BufferCount = 1, 
            .ModeDescription = New ModeDescription(640, 480, New Rational(60, 1), 28), 
            .IsWindowed = True, 
            .OutputHandle = renderForm.Handle, 
            .SampleDescription = New SampleDescription(1, 0), 
            .SwapEffect = 0, 
            .Usage = 32 
        }
        Dim swapChain As SwapChain
        Dim device As Device
        Device.CreateWithSwapChain(1, 0, swapChainDescription, device, swapChain)
        Dim context As DeviceContext = device.ImmediateContext()
        Dim parent As Factory = swapChain.GetParent(Of Factory)()
        parent.MakeWindowAssociation(renderForm.Handle, 1)
        Dim texture2D As Texture2D = Texture2D.FromSwapChain(Of Texture2D)(swapChain, 0)
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
            0, 
            0, 
            "unknown", 
            0, 
            Nothing
        )
        Dim vertexShader As VertexShader = New VertexShader(device, compilationResult, Nothing)
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
            0, 
            0, 
            "unknown", 
            0, 
            Nothing
        )
        Dim pixelShader As PixelShader = New PixelShader(device, compilationResult2, Nothing)
        Dim inputLayout As InputLayout = New InputLayout(
            device, 
            ShaderSignature.GetInputSignature(compilationResult), 
            New InputElement() { 
                New InputElement("POSITION", 0, 2, 0, 0), 
                New InputElement("COLOR", 0, 2, 16, 0) 
            }
        )
        Dim buffer As Buffer = Buffer.Create(Of Vector4)(
            device, 1, 
            New Vector4() {
                New Vector4( 0.0F,  0.5F, 0.5F, 1F), New Vector4(1F, 0F, 0F, 1F),
                New Vector4( 0.5F, -0.5F, 0.5F, 1F), New Vector4(0F, 1F, 0F, 1F),
                New Vector4(-0.5F, -0.5F, 0.5F, 1F), New Vector4(0F, 0F, 1F, 1F) 
            }, 
            0, 
            0, 
            0, 
            0, 
            0
        )
        context.InputAssembler().InputLayout = inputLayout
        context.InputAssembler().PrimitiveTopology = 4
        context.InputAssembler().SetVertexBuffers(0, New VertexBufferBinding(buffer, 32, 0))
        context.VertexShader().[Set](vertexShader)
        context.Rasterizer().SetViewport(New Viewport(0, 0, 640, 480, 0F, 1F))
        context.PixelShader().[Set](pixelShader)
        context.OutputMerger().SetTargets(renderView)

        RenderLoop.Run(
            renderForm, 
            Sub()
                context.ClearRenderTargetView(renderView, Color.Black)
                context.Draw(3, 0)
                swapChain.Present(0, 0)
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
