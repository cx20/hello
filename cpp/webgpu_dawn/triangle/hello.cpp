#include <GLFW/glfw3.h>
#define GLFW_EXPOSE_NATIVE_WIN32
#include <GLFW/glfw3native.h>

#include <webgpu/webgpu_cpp.h>
#include <dawn/native/DawnNative.h>

#include <iostream>
#include <vector>
#include <memory>

const uint32_t WIDTH = 800;
const uint32_t HEIGHT = 600;

const char* shaderCode = R"(
struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec3f,
};

@vertex
fn vs_main(@location(0) position: vec2f, @location(1) color: vec3f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.color = color;
    return output;
}

@fragment
fn fs_main(@location(0) color: vec3f) -> @location(0) vec4f {
    return vec4f(color, 1.0);
}
)";

struct Vertex {
    float position[2];
    float color[3];
};

const std::vector<Vertex> vertices = {
    {{ 0.0f,  0.5f}, {1.0f, 0.0f, 0.0f}},
    {{-0.5f, -0.5f}, {0.0f, 1.0f, 0.0f}},
    {{ 0.5f, -0.5f}, {0.0f, 0.0f, 1.0f}},
};

class WebGPUApp {
public:
    GLFWwindow* window = nullptr;
    std::unique_ptr<dawn::native::Instance> dawnInstance;
    wgpu::Instance instance;
    wgpu::Surface surface;
    wgpu::Adapter adapter;
    wgpu::Device device;
    wgpu::Queue queue;
    wgpu::RenderPipeline pipeline;
    wgpu::Buffer vertexBuffer;
    wgpu::TextureFormat swapChainFormat = wgpu::TextureFormat::BGRA8Unorm;

    bool initialize() {
        if (!glfwInit()) return false;

        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
        window = glfwCreateWindow(WIDTH, HEIGHT, "Hello, World!", nullptr, nullptr);
        if (!window) return false;

        dawnInstance = std::make_unique<dawn::native::Instance>();
        instance = wgpu::Instance(dawnInstance->Get());

        createSurface();

        if (!requestAdapter()) return false;

        if (!requestDevice()) return false;

        queue = device.GetQueue();
        configureSurface();
        createPipeline();
        createVertexBuffer();

        return true;
    }

    void createSurface() {
        wgpu::SurfaceSourceWindowsHWND windowsSource;
        windowsSource.hwnd = glfwGetWin32Window(window);
        windowsSource.hinstance = GetModuleHandle(nullptr);

        wgpu::SurfaceDescriptor surfaceDesc;
        surfaceDesc.nextInChain = &windowsSource;
        surface = instance.CreateSurface(&surfaceDesc);
    }

    bool requestAdapter() {
        wgpu::RequestAdapterOptions adapterOpts = {};
        adapterOpts.compatibleSurface = surface;
        adapterOpts.powerPreference = wgpu::PowerPreference::HighPerformance;

        bool done = false;
        bool success = false;

        instance.RequestAdapter(
            &adapterOpts,
            wgpu::CallbackMode::AllowSpontaneous,
            [&](wgpu::RequestAdapterStatus status, wgpu::Adapter resultAdapter, wgpu::StringView message) {
                if (status == wgpu::RequestAdapterStatus::Success) {
                    adapter = resultAdapter;
                    success = true;
                } else {
                    std::cerr << "Failed to get adapter: " << std::string_view(message) << std::endl;
                }
                done = true;
            });

        while (!done) {
            instance.ProcessEvents();
        }

        if (success) {
            wgpu::AdapterInfo info;
            adapter.GetInfo(&info);
            std::cout << "Adapter: " << std::string_view(info.device) << std::endl;
            std::cout << "Backend: " << static_cast<int>(info.backendType) << std::endl;
        }

        return success;
    }

    bool requestDevice() {
        wgpu::DeviceDescriptor deviceDesc = {};

        bool done = false;
        bool success = false;

        adapter.RequestDevice(
            &deviceDesc,
            wgpu::CallbackMode::AllowSpontaneous,
            [&](wgpu::RequestDeviceStatus status, wgpu::Device resultDevice, wgpu::StringView message) {
                if (status == wgpu::RequestDeviceStatus::Success) {
                    device = resultDevice;
                    success = true;
                } else {
                    std::cerr << "Failed to get device: " << std::string_view(message) << std::endl;
                }
                done = true;
            });

        while (!done) {
            instance.ProcessEvents();
        }

        return success;
    }

    void configureSurface() {
        wgpu::SurfaceConfiguration config = {};
        config.device = device;
        config.format = swapChainFormat;
        config.width = WIDTH;
        config.height = HEIGHT;
        config.presentMode = wgpu::PresentMode::Fifo;
        config.alphaMode = wgpu::CompositeAlphaMode::Opaque;
        config.usage = wgpu::TextureUsage::RenderAttachment;
        surface.Configure(&config);
    }

    void createPipeline() {
        wgpu::ShaderSourceWGSL wgslSource;
        wgslSource.code = shaderCode;

        wgpu::ShaderModuleDescriptor shaderDesc;
        shaderDesc.nextInChain = &wgslSource;
        wgpu::ShaderModule shaderModule = device.CreateShaderModule(&shaderDesc);

        std::vector<wgpu::VertexAttribute> attributes(2);
        attributes[0].format = wgpu::VertexFormat::Float32x2;
        attributes[0].offset = 0;
        attributes[0].shaderLocation = 0;
        attributes[1].format = wgpu::VertexFormat::Float32x3;
        attributes[1].offset = 8;
        attributes[1].shaderLocation = 1;

        wgpu::VertexBufferLayout vertexLayout = {};
        vertexLayout.arrayStride = sizeof(Vertex);
        vertexLayout.stepMode = wgpu::VertexStepMode::Vertex;
        vertexLayout.attributeCount = attributes.size();
        vertexLayout.attributes = attributes.data();

        wgpu::ColorTargetState colorTarget = {};
        colorTarget.format = swapChainFormat;
        colorTarget.writeMask = wgpu::ColorWriteMask::All;

        wgpu::FragmentState fragment = {};
        fragment.module = shaderModule;
        fragment.entryPoint = "fs_main";
        fragment.targetCount = 1;
        fragment.targets = &colorTarget;

        wgpu::RenderPipelineDescriptor pipelineDesc = {};
        pipelineDesc.vertex.module = shaderModule;
        pipelineDesc.vertex.entryPoint = "vs_main";
        pipelineDesc.vertex.bufferCount = 1;
        pipelineDesc.vertex.buffers = &vertexLayout;
        pipelineDesc.fragment = &fragment;
        pipelineDesc.primitive.topology = wgpu::PrimitiveTopology::TriangleList;
        pipelineDesc.primitive.cullMode = wgpu::CullMode::None;
        pipelineDesc.multisample.count = 1;
        pipelineDesc.multisample.mask = 0xFFFFFFFF;

        pipeline = device.CreateRenderPipeline(&pipelineDesc);
    }

    void createVertexBuffer() {
        wgpu::BufferDescriptor bufferDesc = {};
        bufferDesc.size = vertices.size() * sizeof(Vertex);
        bufferDesc.usage = wgpu::BufferUsage::Vertex | wgpu::BufferUsage::CopyDst;
        vertexBuffer = device.CreateBuffer(&bufferDesc);
        queue.WriteBuffer(vertexBuffer, 0, vertices.data(), bufferDesc.size);
    }

    void render() {
        wgpu::SurfaceTexture surfaceTexture;
        surface.GetCurrentTexture(&surfaceTexture);
        
        if (surfaceTexture.status != wgpu::SurfaceGetCurrentTextureStatus::SuccessOptimal &&
            surfaceTexture.status != wgpu::SurfaceGetCurrentTextureStatus::SuccessSuboptimal) {
            return;
        }

        wgpu::TextureView view = surfaceTexture.texture.CreateView();

        wgpu::CommandEncoder encoder = device.CreateCommandEncoder();

        wgpu::RenderPassColorAttachment colorAttachment = {};
        colorAttachment.view = view;
        colorAttachment.loadOp = wgpu::LoadOp::Clear;
        colorAttachment.storeOp = wgpu::StoreOp::Store;
        colorAttachment.clearValue = {0.1, 0.1, 0.1, 1.0};

        wgpu::RenderPassDescriptor renderPassDesc = {};
        renderPassDesc.colorAttachmentCount = 1;
        renderPassDesc.colorAttachments = &colorAttachment;

        wgpu::RenderPassEncoder pass = encoder.BeginRenderPass(&renderPassDesc);
        pass.SetPipeline(pipeline);
        pass.SetVertexBuffer(0, vertexBuffer, 0, vertices.size() * sizeof(Vertex));
        pass.Draw(3, 1, 0, 0);
        pass.End();

        wgpu::CommandBuffer cmd = encoder.Finish();
        queue.Submit(1, &cmd);
        surface.Present();
    }

    void run() {
        while (!glfwWindowShouldClose(window)) {
            glfwPollEvents();
            render();
        }
    }

    void cleanup() {
        vertexBuffer = nullptr;
        pipeline = nullptr;
        queue = nullptr;
        device = nullptr;
        adapter = nullptr;
        surface = nullptr;
        instance = nullptr;
        dawnInstance.reset();
        if (window) glfwDestroyWindow(window);
        glfwTerminate();
    }
};

int main() {
    WebGPUApp app;
    if (!app.initialize()) {
        std::cerr << "Failed to initialize" << std::endl;
        return 1;
    }
    std::cout << "Running WebGPU with Dawn (D3D12 backend)..." << std::endl;
    app.run();
    app.cleanup();
    return 0;
}
