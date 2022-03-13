Imports System
Imports System.Runtime.InteropServices
Imports System.Threading

Imports SharpDX
Imports SharpDX.DXGI
Imports SharpDX.Direct3D
Imports SharpDX.Direct3D12
Imports SharpDX.Windows

Friend Module Program
    Const WIDTH = 640
    Const HEIGHT = 480

    Public Sub Main()
        Dim renderForm As RenderForm = New RenderForm("Hello, World!") With { .Width = WIDTH, .Height = HEIGHT }
        renderForm.Show()
        Using helloTriangle As HelloTriangle = New HelloTriangle()
            helloTriangle.Initialize(renderForm)
            Using renderLoop As RenderLoop = New RenderLoop(renderForm)
                While renderLoop.NextFrame()
                    helloTriangle.Update()
                    helloTriangle.Render()
                End While
            End Using
        End Using
    End Sub
End Module

Public Class HelloTriangle
    Implements IDisposable

    Public Structure Vertex
        Public Position As Vector3
        Public Color As Vector4
    End Structure

    Private Const FrameCount As Integer = 2
    Private viewport As ViewportF
    Private scissorRect As Rectangle
    Private swapChain As SwapChain3
    Private device As SharpDX.Direct3D12.Device
    Private renderTargets As SharpDX.Direct3D12.Resource() = New SharpDX.Direct3D12.Resource(2 - 1) {}
    Private commandAllocator As CommandAllocator
    Private commandQueue As CommandQueue
    Private rootSignature As RootSignature
    Private renderTargetViewHeap As DescriptorHeap
    Private pipelineState As PipelineState
    Private commandList As GraphicsCommandList
    Private rtvDescriptorSize As Integer
    Private vertexBuffer As SharpDX.Direct3D12.Resource
    Private vertexBufferView As VertexBufferView
    Private frameIndex As Integer
    Private fenceEvent As AutoResetEvent
    Private fence As Fence
    Private fenceValue As Integer
    Public Sub Initialize(form As RenderForm)
        Me.LoadPipeline(form)
        Me.LoadAssets()
    End Sub

    Private Sub LoadPipeline(form As RenderForm)
        Dim width As Integer = form.ClientSize.Width
        Dim height As Integer = form.ClientSize.Height
        Me.viewport.Width = CSng(width)
        Me.viewport.Height = CSng(height)
        Me.viewport.MaxDepth = 1F
        Me.scissorRect.Right = width
        Me.scissorRect.Bottom = height
        Me.device = New SharpDX.Direct3D12.Device(Nothing, FeatureLevel.Level_11_0)
        Using factory As Factory4 = New Factory4()
            Dim description As CommandQueueDescription = New CommandQueueDescription(CommandListType.Direct, CommandQueueFlags.None)
            Me.commandQueue = Me.device.CreateCommandQueue(description)
            Dim description2 As SwapChainDescription = New SwapChainDescription() With { 
                .BufferCount = 2, 
                .ModeDescription = New ModeDescription(width, height, New Rational(60, 1), Format.R8G8B8A8_UNorm), 
                .Usage = Usage.RenderTargetOutput, 
                .SwapEffect = SwapEffect.FlipDiscard, 
                .OutputHandle = form.Handle, 
                .SampleDescription = New SampleDescription(1, 0), 
                .IsWindowed = True }
            Dim swapChain As SwapChain = New SwapChain(factory, Me.commandQueue, description2)
            Me.swapChain = swapChain.QueryInterface(Of SwapChain3)()
            swapChain.Dispose()
            Me.frameIndex = Me.swapChain.CurrentBackBufferIndex
        End Using
        Dim descriptorHeapDesc As DescriptorHeapDescription = New DescriptorHeapDescription() With { 
            .DescriptorCount = 2, 
            .Flags = DescriptorHeapFlags.None, 
            .Type = DescriptorHeapType.RenderTargetView 
        }
        Me.renderTargetViewHeap = Me.device.CreateDescriptorHeap(descriptorHeapDesc)
        Me.rtvDescriptorSize = Me.device.GetDescriptorHandleIncrementSize(DescriptorHeapType.RenderTargetView)
        Dim cpuDescriptorHandle As CpuDescriptorHandle = Me.renderTargetViewHeap.CPUDescriptorHandleForHeapStart
        For i As Integer = 0 To 2 - 1
            Me.renderTargets(i) = Me.swapChain.GetBackBuffer(Of SharpDX.Direct3D12.Resource)(i)
            Me.device.CreateRenderTargetView(Me.renderTargets(i), Nothing, cpuDescriptorHandle)
            cpuDescriptorHandle += Me.rtvDescriptorSize
        Next
        Me.commandAllocator = Me.device.CreateCommandAllocator(CommandListType.Direct)
    End Sub

    Private Sub LoadAssets()
        Dim rootSignatureDescription As RootSignatureDescription = New RootSignatureDescription(RootSignatureFlags.AllowInputAssemblerInputLayout, Nothing, Nothing)
        Me.rootSignature = Me.device.CreateRootSignature(rootSignatureDescription.Serialize())
        Dim vertexShader As SharpDX.Direct3D12.ShaderBytecode = New SharpDX.Direct3D12.ShaderBytecode(
            SharpDX.D3DCompiler.ShaderBytecode.Compile(
                "struct PSInput                                                      " & vbLf & 
                "{                                                                   " & vbLf & 
                "    float4 position : SV_POSITION;                                  " & vbLf & 
                "    float4 color : COLOR;                                           " & vbLf & 
                "};                                                                  " & vbLf & 
                "                                                                    " & vbLf & 
                "PSInput VSMain(float4 position : POSITION, float4 color : COLOR)    " & vbLf & 
                "{                                                                   " & vbLf & 
                "    PSInput result;                                                 " & vbLf & 
                "                                                                    " & vbLf & 
                "    result.position = position;                                     " & vbLf & 
                "    result.color = color;                                           " & vbLf & 
                "                                                                    " & vbLf & 
                "    return result;                                                  " & vbLf & 
                "}                                                                   " & vbLf & 
                "                                                                    " & vbLf & 
                "float4 PSMain(PSInput input) : SV_TARGET                            " & vbLf & 
                "{                                                                   " & vbLf & 
                "    return input.color;                                             " & vbLf & 
                "}                                                                   " & vbLf, 
                "VSMain", 
                "vs_5_0", 
                0, 
                0, 
                "unknown", 
                0, 
                Nothing
            )
        )
        Dim pixelShader As SharpDX.Direct3D12.ShaderBytecode = New SharpDX.Direct3D12.ShaderBytecode(
            SharpDX.D3DCompiler.ShaderBytecode.Compile(
                "struct PSInput                                                      " & vbLf & 
                "{                                                                   " & vbLf & 
                "    float4 position : SV_POSITION;                                  " & vbLf & 
                "    float4 color : COLOR;                                           " & vbLf & 
                "};                                                                  " & vbLf & 
                "                                                                    " & vbLf & 
                "PSInput VSMain(float4 position : POSITION, float4 color : COLOR)    " & vbLf & 
                "{                                                                   " & vbLf & 
                "    PSInput result;                                                 " & vbLf & 
                "                                                                    " & vbLf & 
                "    result.position = position;                                     " & vbLf & 
                "    result.color = color;                                           " & vbLf & 
                "                                                                    " & vbLf & 
                "    return result;                                                  " & vbLf & 
                "}                                                                   " & vbLf & 
                "                                                                    " & vbLf & 
                "float4 PSMain(PSInput input) : SV_TARGET                            " & vbLf & 
                "{                                                                   " & vbLf & 
                "    return input.color;                                             " & vbLf & 
                "}                                                                   " & vbLf, 
                "PSMain", 
                "ps_5_0", 
                0, 
                0, 
                "unknown", 
                0, 
                Nothing
            )
        )
        Dim elements As InputElement() = New InputElement() { 
            New InputElement("POSITION", 0, Format.R32G32B32_Float, 0, 0), 
            New InputElement("COLOR", 0, Format.R32G32B32A32_Float, 12, 0) 
        }
        Dim graphicsPipelineStateDescription As GraphicsPipelineStateDescription = New GraphicsPipelineStateDescription() With { 
            .InputLayout = New InputLayoutDescription(elements), 
            .RootSignature = Me.rootSignature, 
            .VertexShader = vertexShader, 
            .PixelShader = pixelShader, 
            .RasterizerState = RasterizerStateDescription.[Default](), 
            .BlendState = BlendStateDescription.[Default](), 
            .DepthStencilFormat = Format.D32_Float, 
            .DepthStencilState = New DepthStencilStateDescription() With { 
                .IsDepthEnabled = False, 
                .IsStencilEnabled = False 
            }, 
            .SampleMask = 2147483647, 
            .PrimitiveTopologyType = PrimitiveTopologyType.Triangle, 
            .RenderTargetCount = 1, 
            .Flags = PipelineStateFlags.None, 
            .SampleDescription = New SampleDescription(1, 0), 
            .StreamOutput = New StreamOutputDescription() 
        }
        graphicsPipelineStateDescription.RenderTargetFormats(0) = Format.R8G8B8A8_UNorm
        Me.pipelineState = Me.device.CreateGraphicsPipelineState(graphicsPipelineStateDescription)
        Me.commandList = Me.device.CreateCommandList(CommandListType.Direct, Me.commandAllocator, Me.pipelineState)
        Dim num As Single = Me.viewport.Width / Me.viewport.Height
        Dim array As HelloTriangle.Vertex() = New HelloTriangle.Vertex() { 
            New HelloTriangle.Vertex() With { .Position = New Vector3( 0.0F,  0.5F * num, 0F), .Color = New Vector4(1F, 0F, 0F, 1F) }, 
            New HelloTriangle.Vertex() With { .Position = New Vector3( 0.5F, -0.5F * num, 0F), .Color = New Vector4(0F, 1F, 0F, 1F) }, 
            New HelloTriangle.Vertex() With { .Position = New Vector3(-0.5F, -0.5F * num, 0F), .Color = New Vector4(0F, 0F, 1F, 1F) } }
        Dim num2 As Integer = Utilities.SizeOf(Of HelloTriangle.Vertex)(array)
        Me.vertexBuffer = Me.device.CreateCommittedResource(
            New HeapProperties(HeapType.Upload, 1, 1), 
            HeapFlags.None, ResourceDescription.Buffer(CLng(num2), 
            ResourceFlags.None, 0L), 
            ResourceStates.GenericRead, 
            Nothing
        )
        Utilities.Write(Of HelloTriangle.Vertex)(Me.vertexBuffer.Map(0, Nothing), array, 0, array.Length)
        Me.vertexBuffer.Unmap(0, Nothing)
        Me.vertexBufferView = Nothing
        Me.vertexBufferView.BufferLocation = Me.vertexBuffer.GPUVirtualAddress
        Me.vertexBufferView.StrideInBytes = Utilities.SizeOf(Of HelloTriangle.Vertex)()
        Me.vertexBufferView.SizeInBytes = num2
        Me.commandList.Close()
        Me.fence = Me.device.CreateFence(0L, FenceFlags.None)
        Me.fenceValue = 1
        Me.fenceEvent = New AutoResetEvent(False)
    End Sub

    Private Sub PopulateCommandList()
        Me.commandAllocator.Reset()
        Me.commandList.Reset(Me.commandAllocator, Me.pipelineState)
        Me.commandList.SetGraphicsRootSignature(Me.rootSignature)
        Me.commandList.SetViewport(Me.viewport)
        Me.commandList.SetScissorRectangles(Me.scissorRect)
        Me.commandList.ResourceBarrierTransition(Me.renderTargets(Me.frameIndex), ResourceStates.Common, ResourceStates.RenderTarget)
        Dim cpuDescriptorHandle As CpuDescriptorHandle = Me.renderTargetViewHeap.CPUDescriptorHandleForHeapStart
        cpuDescriptorHandle += Me.frameIndex * Me.rtvDescriptorSize
        Me.commandList.SetRenderTargets(New CpuDescriptorHandle?(cpuDescriptorHandle), Nothing)
        Me.commandList.ClearRenderTargetView(cpuDescriptorHandle, New Color4(0F, 0F, 0F, 1F), 0, Nothing)
        Me.commandList.PrimitiveTopology = PrimitiveTopology.TriangleList
        Me.commandList.SetVertexBuffer(0, Me.vertexBufferView)
        Me.commandList.DrawInstanced(3, 1, 0, 0)
        Me.commandList.ResourceBarrierTransition(Me.renderTargets(Me.frameIndex), ResourceStates.RenderTarget, ResourceStates.Common)
        Me.commandList.Close()
    End Sub

    Private Sub WaitForPreviousFrame()
        Dim num As Integer = Me.fenceValue
        Me.commandQueue.Signal(Me.fence, CLng(num))
        Me.fenceValue += 1
        If Me.fence.CompletedValue < CLng(num) Then
            Me.fence.SetEventOnCompletion(CLng(num), Me.fenceEvent.SafeWaitHandle.DangerousGetHandle())
            Me.fenceEvent.WaitOne()
        End If
        Me.frameIndex = Me.swapChain.CurrentBackBufferIndex
    End Sub

    Public Sub Update()
    End Sub

    Public Sub Render()
        Me.PopulateCommandList()
        Me.commandQueue.ExecuteCommandList(Me.commandList)
        Me.swapChain.Present(1, PresentFlags.None)
        Me.WaitForPreviousFrame()
    End Sub

    Public Sub Dispose() Implements IDisposable.Dispose
        Me.WaitForPreviousFrame()
        Dim array As SharpDX.Direct3D12.Resource() = Me.renderTargets
        For i As Integer = 0 To array.Length - 1
            array(i).Dispose()
        Next
        Me.commandAllocator.Dispose()
        Me.commandQueue.Dispose()
        Me.rootSignature.Dispose()
        Me.renderTargetViewHeap.Dispose()
        Me.pipelineState.Dispose()
        Me.commandList.Dispose()
        Me.vertexBuffer.Dispose()
        Me.fence.Dispose()
        Me.swapChain.Dispose()
        Me.device.Dispose()
    End Sub

End Class
