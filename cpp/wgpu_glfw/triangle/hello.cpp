// forked from https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/main.cpp

#include <glfw3webgpu.h>
#include <GLFW/glfw3.h>

#define WEBGPU_CPP_IMPLEMENTATION
#include <webgpu.hpp>
#include <wgpu.h> // wgpuTextureViewDrop

#include <iostream>
#include <cassert>

using namespace wgpu;

char const triangle_vert_wgsl[] = R"(
	struct VertexOut {
		@location(0) vCol : vec3<f32>,
		@builtin(position) Position : vec4<f32>
	}
	@vertex
	fn main(
		@location(0) aPos : vec3<f32>,
		@location(1) aCol : vec3<f32>
	) -> VertexOut {
		var output : VertexOut;
		output.Position = vec4<f32>(aPos, 1.0);
		output.vCol = aCol;
		return output;
	}
)";

char const triangle_frag_wgsl[] = R"(
	@fragment
	fn main(@location(0) vCol : vec3<f32>) -> @location(0) vec4<f32> {
		return vec4<f32>(vCol, 1.0);
	}
)";

ShaderModule createShader(Device& device, const char* shaderSource) {
	ShaderModuleDescriptor shaderDesc{};
	ShaderModuleWGSLDescriptor shaderCodeDesc{};
	shaderCodeDesc.chain.next = nullptr;
	shaderCodeDesc.chain.sType = SType::ShaderModuleWGSLDescriptor;
	shaderDesc.nextInChain = &shaderCodeDesc.chain;
	shaderCodeDesc.code = shaderSource;
	ShaderModule shaderModule = device.createShaderModule(shaderDesc);
	
	return shaderModule;
}

WGPUBuffer createBuffer(Device& device, Queue& queue, const void* data, size_t size, WGPUBufferUsage usage) {
	BufferDescriptor desc = {};
	desc.usage = WGPUBufferUsage_CopyDst | usage;
	desc.size  = size;
	Buffer buffer = device.createBuffer(desc);
	queue.writeBuffer(buffer, 0, data, size);
	return buffer;
}

int main (int, char**) 
{

	Instance instance = createInstance(InstanceDescriptor{});
	glfwInit();

	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
	GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", NULL, NULL);

	Surface surface = glfwGetWGPUSurface(instance, window);
	RequestAdapterOptions adapterOpts{};
	adapterOpts.compatibleSurface = surface;
	Adapter adapter = instance.requestAdapter(adapterOpts);

	DeviceDescriptor deviceDesc{};
	deviceDesc.label = "My Device";
	deviceDesc.requiredFeaturesCount = 0;
	deviceDesc.requiredLimits = nullptr;
	deviceDesc.defaultQueue.label = "The default queue";
	Device device = adapter.requestDevice(deviceDesc);

	// Add an error callback for more debug info
	// (TODO: fix the callback in the webgpu.hpp wrapper)
	auto myCallback = [](ErrorType type, char const* message) {
		std::cout << "Device error: type " << type;
		if (message) std::cout << " (message: " << message << ")";
		std::cout << std::endl;
	};
	struct Context {
		decltype(myCallback) theCallback;
	};
	Context ctx = { myCallback };
	static auto cCallback = [](WGPUErrorType type, char const* message, void* userdata) -> void {
		Context& ctx = *reinterpret_cast<Context*>(userdata);
		ctx.theCallback(static_cast<ErrorType>(type), message);
	};
	wgpuDeviceSetUncapturedErrorCallback(device, cCallback, reinterpret_cast<void*>(&ctx));

	Queue queue = device.getQueue();

	std::cout << "Creating swapchain..." << std::endl;
	TextureFormat swapChainFormat = surface.getPreferredFormat(adapter);
	SwapChainDescriptor swapChainDesc = {};
	swapChainDesc.width = 640;
	swapChainDesc.height = 480;
	swapChainDesc.usage = TextureUsage::RenderAttachment;
	swapChainDesc.format = swapChainFormat;
	swapChainDesc.presentMode = PresentMode::Fifo;
	SwapChain swapChain = device.createSwapChain(surface, swapChainDesc);

	ShaderModule vertShaderModule = createShader(device, triangle_vert_wgsl);
	ShaderModule fragShaderModule = createShader(device, triangle_frag_wgsl);

	std::cout << "Creating render pipeline..." << std::endl;
	RenderPipelineDescriptor pipelineDesc{};

	// describe buffer layouts
	WGPUVertexAttribute vertAttrs[2] = {};
	vertAttrs[0].format = WGPUVertexFormat_Float32x3;
	vertAttrs[0].offset = 0;
	vertAttrs[0].shaderLocation = 0;
	vertAttrs[1].format = WGPUVertexFormat_Float32x3;
	vertAttrs[1].offset = 3 * sizeof(float);
	vertAttrs[1].shaderLocation = 1;
	WGPUVertexBufferLayout vertexBufferLayout = {};
	vertexBufferLayout.arrayStride = 6 * sizeof(float);
	vertexBufferLayout.attributeCount = 2;
	vertexBufferLayout.attributes = vertAttrs;
	
	// Vertex fetch
	// (We don't use any input buffer so far)
	pipelineDesc.vertex.bufferCount = 1;
	pipelineDesc.vertex.buffers = &vertexBufferLayout;

	// Vertex shader
	pipelineDesc.vertex.module = vertShaderModule;
	pipelineDesc.vertex.entryPoint = "main";

	pipelineDesc.primitive.topology = PrimitiveTopology::TriangleList;

	// Fragment shader
	FragmentState fragmentState{};
	pipelineDesc.fragment = &fragmentState;
	fragmentState.module = fragShaderModule;
	fragmentState.entryPoint = "main";
	fragmentState.constantCount = 0;
	fragmentState.constants = nullptr;

	ColorTargetState colorTarget{};
	colorTarget.format = swapChainFormat;
	//colorTarget.blend = &blendState;
	colorTarget.writeMask = ColorWriteMask::All; // We could write to only some of the color channels.

	// We have only one target because our render pass has only one output color
	// attachment.
	fragmentState.targetCount = 1;
	fragmentState.targets = &colorTarget;
	
	// Depth and stencil tests are not used here
	pipelineDesc.depthStencil = nullptr;

	// Multi-sampling
	// Samples per pixel
	pipelineDesc.multisample.count = 1;
	// Default value for the mask, meaning "all bits on"
	pipelineDesc.multisample.mask = ~0u;
	// Default value as well (irrelevant for count = 1 anyways)
	pipelineDesc.multisample.alphaToCoverageEnabled = false;

	// Pipeline layout
	// (Our example does not use any resource)
	PipelineLayoutDescriptor layoutDesc{};
	layoutDesc.bindGroupLayoutCount = 0;
	layoutDesc.bindGroupLayouts = nullptr;
	PipelineLayout layout = device.createPipelineLayout(layoutDesc);
	pipelineDesc.layout = layout;

	// create the buffers (x, y, z, r, g, b)
	float const vertData[] = {
		 0.0f,  0.5f, 0.0f, 1.0f, 0.0f, 0.0f, // v0
		 0.5f, -0.5f, 0.0f, 0.0f, 1.0f, 0.0f, // v1
		-0.5f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f, // v2
	};
	uint16_t const indxData[] = {
		0, 1, 2,
		0 // padding (better way of doing this?)
	};

	Buffer vertBuf = createBuffer(device, queue, vertData, sizeof(vertData),  BufferUsage::Vertex);
	Buffer indxBuf = createBuffer(device, queue, indxData, sizeof(indxData),  BufferUsage::Index);

	RenderPipeline pipeline = device.createRenderPipeline(pipelineDesc);
	std::cout << "Render pipeline: " << pipeline << std::endl;

	while (!glfwWindowShouldClose(window)) {
		glfwPollEvents();

		TextureView nextTexture = swapChain.getCurrentTextureView();
		if (!nextTexture) {
			std::cerr << "Cannot acquire next swap chain texture" << std::endl;
			return 1;
		}

		CommandEncoderDescriptor commandEncoderDesc{};
		commandEncoderDesc.label = "Command Encoder";
		CommandEncoder encoder = device.createCommandEncoder(commandEncoderDesc);
		
		RenderPassDescriptor renderPassDesc{};

		WGPURenderPassColorAttachment renderPassColorAttachment = {};
		renderPassColorAttachment.view = nextTexture;
		renderPassColorAttachment.resolveTarget = nullptr;
		renderPassColorAttachment.loadOp = LoadOp::Clear;
		renderPassColorAttachment.storeOp = StoreOp::Store;
		renderPassColorAttachment.clearValue = Color{ 0.0, 0.0, 0.0, 1.0 };
		renderPassDesc.colorAttachmentCount = 1;
		renderPassDesc.colorAttachments = &renderPassColorAttachment;

		renderPassDesc.depthStencilAttachment = nullptr;
		renderPassDesc.timestampWriteCount = 0;
		renderPassDesc.timestampWrites = nullptr;
		RenderPassEncoder renderPass = encoder.beginRenderPass(renderPassDesc);

		renderPass.setPipeline(pipeline);
		renderPass.setVertexBuffer(0, vertBuf, 0, WGPU_WHOLE_SIZE);
		renderPass.setIndexBuffer(indxBuf, WGPUIndexFormat_Uint16, 0, WGPU_WHOLE_SIZE);
		renderPass.drawIndexed(3, 1, 0, 0, 0);

		renderPass.end();
		
		wgpuTextureViewDrop(nextTexture);

		CommandBufferDescriptor cmdBufferDescriptor{};
		cmdBufferDescriptor.label = "Command buffer";
		CommandBuffer command = encoder.finish(cmdBufferDescriptor);
		queue.submit(command);

		swapChain.present();
	}

	glfwDestroyWindow(window);
	glfwTerminate();

	return 0;
}
