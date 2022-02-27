using System;
using System.Threading;

using SharpDX;
using SharpDX.DXGI;
using SharpDX.Direct3D12;
using SharpDX.Windows;

static class Program
{
    [STAThread]
    static void Main()
    {
        var form = new RenderForm("Hello, World!")
        {
            Width = 640,
            Height = 480
        };
        form.Show();

        using (var app = new HelloTriangle())
        {
            app.Initialize(form);

            using (var loop = new RenderLoop(form))
            {
                while (loop.NextFrame())
                {
                    app.Update();
                    app.Render();
                }
            }
        }
    }
}

public class HelloTriangle : IDisposable
{
    public void Initialize(RenderForm form)
    {
        LoadPipeline(form);
        LoadAssets();
    }

    private void LoadPipeline(RenderForm form)
    {
        int width = form.ClientSize.Width;
        int height = form.ClientSize.Height;

        viewport.Width = width;
        viewport.Height = height;
        viewport.MaxDepth = 1.0f;

        scissorRect.Right = width;
        scissorRect.Bottom = height;

        device = new SharpDX.Direct3D12.Device(null, SharpDX.Direct3D.FeatureLevel.Level_11_0);
        using (var factory = new Factory4())
        {
            var queueDesc = new CommandQueueDescription(CommandListType.Direct);
            commandQueue = device.CreateCommandQueue(queueDesc);

            var swapChainDesc = new SwapChainDescription()
            {
                BufferCount = FrameCount,
                ModeDescription = new ModeDescription(width, height, new Rational(60, 1), Format.R8G8B8A8_UNorm),
                Usage = Usage.RenderTargetOutput,
                SwapEffect = SwapEffect.FlipDiscard,
                OutputHandle = form.Handle,
                SampleDescription = new SampleDescription(1, 0),
                IsWindowed = true
            };

            var tempSwapChain = new SwapChain(factory, commandQueue, swapChainDesc);
            swapChain = tempSwapChain.QueryInterface<SwapChain3>();
            tempSwapChain.Dispose();
            frameIndex = swapChain.CurrentBackBufferIndex;
        }

        var rtvHeapDesc = new DescriptorHeapDescription()
        {
            DescriptorCount = FrameCount,
            Flags = DescriptorHeapFlags.None,
            Type = DescriptorHeapType.RenderTargetView
        };

        renderTargetViewHeap = device.CreateDescriptorHeap(rtvHeapDesc);

        rtvDescriptorSize = device.GetDescriptorHandleIncrementSize(DescriptorHeapType.RenderTargetView);

        var rtvHandle = renderTargetViewHeap.CPUDescriptorHandleForHeapStart;
        for (int n = 0; n < FrameCount; n++)
        {
            renderTargets[n] = swapChain.GetBackBuffer<SharpDX.Direct3D12.Resource>(n);
            device.CreateRenderTargetView(renderTargets[n], null, rtvHandle);
            rtvHandle += rtvDescriptorSize;
        }

        commandAllocator = device.CreateCommandAllocator(CommandListType.Direct);
    }

    private void LoadAssets()
    {
        var rootSignatureDesc = new RootSignatureDescription(RootSignatureFlags.AllowInputAssemblerInputLayout);
        rootSignature = device.CreateRootSignature(rootSignatureDesc.Serialize());

        const string shaderSource = 
            "struct PSInput                                                      \n" + 
            "{                                                                   \n" + 
            "    float4 position : SV_POSITION;                                  \n" + 
            "    float4 color : COLOR;                                           \n" + 
            "};                                                                  \n" + 
            "                                                                    \n" + 
            "PSInput VSMain(float4 position : POSITION, float4 color : COLOR)    \n" + 
            "{                                                                   \n" + 
            "    PSInput result;                                                 \n" + 
            "                                                                    \n" + 
            "    result.position = position;                                     \n" + 
            "    result.color = color;                                           \n" + 
            "                                                                    \n" + 
            "    return result;                                                  \n" + 
            "}                                                                   \n" + 
            "                                                                    \n" + 
            "float4 PSMain(PSInput input) : SV_TARGET                            \n" + 
            "{                                                                   \n" + 
            "    return input.color;                                             \n" + 
            "}                                                                   \n";


        var vertexShader = new ShaderBytecode(SharpDX.D3DCompiler.ShaderBytecode.Compile(shaderSource, "VSMain", "vs_5_0"));
        var pixelShader  = new ShaderBytecode(SharpDX.D3DCompiler.ShaderBytecode.Compile(shaderSource, "PSMain", "ps_5_0"));

        var inputElementDescs = new []
        {
            new InputElement("POSITION", 0, Format.R32G32B32_Float,     0, 0),
            new InputElement("COLOR",    0, Format.R32G32B32A32_Float, 12, 0)
        };

        var psoDesc = new GraphicsPipelineStateDescription()
        {
            InputLayout = new InputLayoutDescription(inputElementDescs),
            RootSignature = rootSignature,
            VertexShader = vertexShader,
            PixelShader = pixelShader,
            RasterizerState = RasterizerStateDescription.Default(),
            BlendState = BlendStateDescription.Default(),
            DepthStencilFormat = SharpDX.DXGI.Format.D32_Float,
            DepthStencilState = new DepthStencilStateDescription() { IsDepthEnabled = false, IsStencilEnabled = false },
            SampleMask = int.MaxValue,
            PrimitiveTopologyType = PrimitiveTopologyType.Triangle,
            RenderTargetCount = 1,
            Flags = PipelineStateFlags.None,
            SampleDescription = new SharpDX.DXGI.SampleDescription(1, 0),
            StreamOutput = new StreamOutputDescription()
        };
        psoDesc.RenderTargetFormats[0] = SharpDX.DXGI.Format.R8G8B8A8_UNorm;

        pipelineState = device.CreateGraphicsPipelineState(psoDesc);

        commandList = device.CreateCommandList(CommandListType.Direct, commandAllocator, pipelineState);

        float aspectRatio = viewport.Width / viewport.Height;

        var triangleVertices = new []
        {
                new Vertex() {Position=new Vector3( 0.0f,  0.5f * aspectRatio, 0.0f), Color=new Vector4(1.0f, 0.0f, 0.0f, 1.0f ) },
                new Vertex() {Position=new Vector3( 0.5f, -0.5f * aspectRatio, 0.0f), Color=new Vector4(0.0f, 1.0f, 0.0f, 1.0f) },
                new Vertex() {Position=new Vector3(-0.5f, -0.5f * aspectRatio, 0.0f), Color=new Vector4(0.0f, 0.0f, 1.0f, 1.0f ) },
        };

        int vertexBufferSize = Utilities.SizeOf(triangleVertices);

        vertexBuffer = device.CreateCommittedResource(new HeapProperties(HeapType.Upload), HeapFlags.None, ResourceDescription.Buffer(vertexBufferSize), ResourceStates.GenericRead);

        IntPtr pVertexDataBegin = vertexBuffer.Map(0);
        Utilities.Write(pVertexDataBegin, triangleVertices, 0, triangleVertices.Length);
        vertexBuffer.Unmap(0);

        vertexBufferView = new VertexBufferView();
        vertexBufferView.BufferLocation = vertexBuffer.GPUVirtualAddress;
        vertexBufferView.StrideInBytes = Utilities.SizeOf<Vertex>();
        vertexBufferView.SizeInBytes = vertexBufferSize;

        commandList.Close();

        fence = device.CreateFence(0, FenceFlags.None);
        fenceValue = 1;

        fenceEvent = new AutoResetEvent(false);
    }

    private void PopulateCommandList()
    {
        commandAllocator.Reset();

        commandList.Reset(commandAllocator, pipelineState);

        commandList.SetGraphicsRootSignature(rootSignature);
        commandList.SetViewport(viewport);
        commandList.SetScissorRectangles(scissorRect);

        commandList.ResourceBarrierTransition(renderTargets[frameIndex], ResourceStates.Present, ResourceStates.RenderTarget);

        var rtvHandle = renderTargetViewHeap.CPUDescriptorHandleForHeapStart;
        rtvHandle += frameIndex * rtvDescriptorSize;
        commandList.SetRenderTargets(rtvHandle, null);

        commandList.ClearRenderTargetView(rtvHandle, new Color4(0, 0.0F, 0.0f, 1), 0, null);

        commandList.PrimitiveTopology = SharpDX.Direct3D.PrimitiveTopology.TriangleList;
        commandList.SetVertexBuffer(0, vertexBufferView);
        commandList.DrawInstanced(3, 1, 0, 0);

        commandList.ResourceBarrierTransition(renderTargets[frameIndex], ResourceStates.RenderTarget, ResourceStates.Present);

        commandList.Close();
    }

    private void WaitForPreviousFrame()
    {
        int localFence = fenceValue;
        commandQueue.Signal(this.fence, localFence);
        fenceValue++;

        if (this.fence.CompletedValue < localFence)
        {
            this.fence.SetEventOnCompletion(localFence, fenceEvent.SafeWaitHandle.DangerousGetHandle());
            fenceEvent.WaitOne();
        }

        frameIndex = swapChain.CurrentBackBufferIndex;
    }

    public void Update()
    {
    }

    public void Render()
    {
        PopulateCommandList();

        commandQueue.ExecuteCommandList(commandList);

        swapChain.Present(1, 0);

        WaitForPreviousFrame();
    }

    public void Dispose()
    {
        WaitForPreviousFrame();

        foreach (var target in renderTargets)
        {
            target.Dispose();
        }
        commandAllocator.Dispose();
        commandQueue.Dispose();
        rootSignature.Dispose();
        renderTargetViewHeap.Dispose();
        pipelineState.Dispose();
        commandList.Dispose();
        vertexBuffer.Dispose();
        fence.Dispose();
        swapChain.Dispose();
        device.Dispose();
    }


    struct Vertex
    {
        public Vector3 Position;
        public Vector4 Color;
    };

    const int FrameCount = 2;

    private ViewportF viewport;
    private SharpDX.Rectangle scissorRect;

    private SwapChain3 swapChain;
    private SharpDX.Direct3D12.Device device;
    private readonly SharpDX.Direct3D12.Resource[] renderTargets = new SharpDX.Direct3D12.Resource[FrameCount];
    private CommandAllocator commandAllocator;
    private CommandQueue commandQueue;
    private RootSignature rootSignature;
    private DescriptorHeap renderTargetViewHeap;
    private PipelineState pipelineState;
    private GraphicsCommandList commandList;
    private int rtvDescriptorSize;

    SharpDX.Direct3D12.Resource vertexBuffer;
    VertexBufferView vertexBufferView;

    private int frameIndex;
    private AutoResetEvent fenceEvent;

    private Fence fence;
    private int fenceValue;
}
