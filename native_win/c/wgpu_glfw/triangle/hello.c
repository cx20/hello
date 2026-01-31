// reference:
//   https://github.com/eliemichel/LearnWebGPU-Code/blob/step030/main.cpp
//   https://github.com/gfx-rs/wgpu-native/blob/master/examples/triangle/main.c

#include <windows.h>
#include <glfw3webgpu.h>
#include <GLFW/glfw3.h>

#include <wgpu.h> // wgpuTextureViewDrop

#include <stdio.h>
#include <stdlib.h>

#define WGPULimits_DEFAULT  \
	(WGPULimits)            \
	{                       \
		.maxBindGroups = 8, \
	}

const char *triangle_vert_wgsl =
	"    struct VertexOut {\n"
	"        @location(0) vCol : vec3<f32>,\n"
	"        @builtin(position) Position : vec4<f32>\n"
	"    }\n"
	"    @vertex\n"
	"    fn main(\n"
	"        @location(0) aPos : vec3<f32>,\n"
	"        @location(1) aCol : vec3<f32>\n"
	"    ) -> VertexOut {\n"
	"        var output : VertexOut;\n"
	"        output.Position = vec4<f32>(aPos, 1.0);\n"
	"        output.vCol = aCol;\n"
	"        return output;\n"
	"    }\n";

const char *triangle_frag_wgsl =
	"    @fragment\n"
	"    fn main(@location(0) vCol : vec3<f32>) -> @location(0) vec4<f32> {\n"
	"        return vec4<f32>(vCol, 1.0);\n"
	"    }\n";

static void handle_device_lost(WGPUDeviceLostReason reason, const char *message, void *userdata)
{
	printf("DEVICE LOST (%d): %s\n", reason, message);
}

static void handle_uncaptured_error(WGPUErrorType type, const char *message, void *userdata)
{

	printf("UNCAPTURED ERROR (%d): %s\n", type, message);
}

void request_adapter_callback(WGPURequestAdapterStatus status, WGPUAdapter received, const char *message, void *userdata)
{
	*(WGPUAdapter *)userdata = received;
}

void request_device_callback(WGPURequestDeviceStatus status, WGPUDevice received, const char *message, void *userdata)
{
	*(WGPUDevice *)userdata = received;
}

WGPUShaderModule create_shader(WGPUDevice device, const char *code, const char *label)
{
	WGPUShaderModuleWGSLDescriptor wgsl = {
		.chain.sType = WGPUSType_ShaderModuleWGSLDescriptor,
		.code = code,
	};

	return wgpuDeviceCreateShaderModule(
		device,
		&(WGPUShaderModuleDescriptor){
			.nextInChain = (WGPUChainedStruct *)(&wgsl),
			.label = label,
		});
}

WGPUBuffer create_buffer(WGPUDevice device, WGPUQueue queue, const void *data, size_t size, WGPUBufferUsage usage)
{
	WGPUBuffer buffer = wgpuDeviceCreateBuffer(
		device,
		&(WGPUBufferDescriptor){
			.usage = WGPUBufferUsage_CopyDst | usage,
			.size = size,
		}
	);
	wgpuQueueWriteBuffer(queue, buffer, 0, data, size);
	return buffer;
}

int main()
{
	glfwInit();

	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);
	GLFWwindow *window = glfwCreateWindow(640, 480, "Hello, World!", NULL, NULL);

	WGPUInstance instance = wgpuCreateInstance(&(WGPUInstanceDescriptor){.nextInChain = NULL});

	HWND hwnd = glfwGetWin32Window(window);
	HINSTANCE hinstance = GetModuleHandle(NULL);
	WGPUSurface surface = wgpuInstanceCreateSurface(
		instance,
		&(WGPUSurfaceDescriptor){
			.label = NULL,
			.nextInChain =
				(const WGPUChainedStruct *)&(WGPUSurfaceDescriptorFromWindowsHWND){
					.chain =
						(WGPUChainedStruct){
							.next = NULL,
							.sType = WGPUSType_SurfaceDescriptorFromWindowsHWND,
						},
					.hinstance = hinstance,
					.hwnd = hwnd,
				},
		});

	WGPUAdapter adapter;
	wgpuInstanceRequestAdapter(
		instance,
		&(WGPURequestAdapterOptions){
			.nextInChain = NULL,
			.compatibleSurface = NULL,
		},
		request_adapter_callback, (void *)&adapter
	);

	WGPUDevice device;
	wgpuAdapterRequestDevice(
		adapter,
		&(WGPUDeviceDescriptor){
			.nextInChain = NULL,
			.label = "Device",
			.requiredLimits =
				&(WGPURequiredLimits){
					.nextInChain = NULL,
					.limits = WGPULimits_DEFAULT,
				},
			.defaultQueue =
				(WGPUQueueDescriptor){
					.nextInChain = NULL,
					.label = NULL,
				},
		},
		request_device_callback, (void *)&device
	);

	wgpuDeviceSetUncapturedErrorCallback(device, handle_uncaptured_error, NULL);
	wgpuDeviceSetDeviceLostCallback(device, handle_device_lost, NULL);

	WGPUQueue queue = wgpuDeviceGetQueue(device);

	printf("Creating swapchain...\n");
	WGPUTextureFormat swapChainFormat = wgpuSurfaceGetPreferredFormat(surface, adapter);
	WGPUShaderModule vertShaderModule = create_shader(device, triangle_vert_wgsl, NULL);
	WGPUShaderModule fragShaderModule = create_shader(device, triangle_frag_wgsl, NULL);

	// create the buffers (x, y, z, r, g, b)
	float const vertData[] = {
		 0.0f,  0.5f, 0.0f, 1.0f, 0.0f, 0.0f,	// v0
		 0.5f, -0.5f, 0.0f, 0.0f, 1.0f, 0.0f,	// v1
		-0.5f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f,	// v2
	};
	uint16_t const indxData[] = {
		0, 1, 2,
		0 // padding (better way of doing this?)
	};

	WGPUBuffer vertBuf = create_buffer(device, queue, vertData, sizeof(vertData), WGPUBufferUsage_Vertex);
	WGPUBuffer indxBuf = create_buffer(device, queue, indxData, sizeof(indxData), WGPUBufferUsage_Index);

	// describe buffer layouts
	WGPUVertexAttribute vertAttrs[2];
	vertAttrs[0].format = WGPUVertexFormat_Float32x3;
	vertAttrs[0].offset = 0;
	vertAttrs[0].shaderLocation = 0;
	vertAttrs[1].format = WGPUVertexFormat_Float32x3;
	vertAttrs[1].offset = 3 * sizeof(float);
	vertAttrs[1].shaderLocation = 1;

	WGPUVertexBufferLayout vertexBufferLayout = {0};
	vertexBufferLayout.arrayStride = 6 * sizeof(float);
	vertexBufferLayout.attributeCount = 2;
	vertexBufferLayout.attributes = vertAttrs;

	printf("Creating render pipeline...\n");
	WGPURenderPipeline pipeline = wgpuDeviceCreateRenderPipeline(
		device,
		&(WGPURenderPipelineDescriptor){
			.label = "Render pipeline",
			.vertex =
				(WGPUVertexState){
					.module = vertShaderModule,
					.entryPoint = "main",
					.bufferCount = 1,
					.buffers = &vertexBufferLayout,
				},
			.primitive =
				(WGPUPrimitiveState){
					.topology = WGPUPrimitiveTopology_TriangleList,
					.stripIndexFormat = WGPUIndexFormat_Undefined,
					.frontFace = WGPUFrontFace_CCW,
					.cullMode = WGPUCullMode_None},
			.multisample =
				(WGPUMultisampleState){
					.count = 1,
					.mask = ~0,
					.alphaToCoverageEnabled = false,
				},
			.fragment =
				&(WGPUFragmentState){
					.module = fragShaderModule,
					.entryPoint = "main",
					.targetCount = 1,
					.targets =
						&(WGPUColorTargetState){
							.format = swapChainFormat,
							.blend =
								&(WGPUBlendState){
									.color =
										(WGPUBlendComponent){
											.srcFactor = WGPUBlendFactor_One,
											.dstFactor = WGPUBlendFactor_Zero,
											.operation = WGPUBlendOperation_Add,
										},
									.alpha =
										(WGPUBlendComponent){
											.srcFactor = WGPUBlendFactor_One,
											.dstFactor = WGPUBlendFactor_Zero,
											.operation = WGPUBlendOperation_Add,
										}
								},
							.writeMask = WGPUColorWriteMask_All
						},
				},
			.depthStencil = NULL,
		});

	int prevWidth = 0;
	int prevHeight = 0;
	glfwGetWindowSize(window, &prevWidth, &prevHeight);

	WGPUSwapChain swapChain = wgpuDeviceCreateSwapChain(
		device, 
		surface,
		&(WGPUSwapChainDescriptor){
			.usage = WGPUTextureUsage_RenderAttachment,
			.format = swapChainFormat,
			.width = prevWidth,
			.height = prevHeight,
			.presentMode = WGPUPresentMode_Fifo,
		}
	);

	while (!glfwWindowShouldClose(window))
	{
		WGPUTextureView nextTexture = NULL;

		for (int attempt = 0; attempt < 2; attempt++)
		{
			int width = 0;
			int height = 0;
			glfwGetWindowSize(window, &width, &height);

			if (width != prevWidth || height != prevHeight)
			{
				prevWidth = width;
				prevHeight = height;

				swapChain = wgpuDeviceCreateSwapChain(
					device, 
					surface,
					&(WGPUSwapChainDescriptor){
						.usage = WGPUTextureUsage_RenderAttachment,
						.format = swapChainFormat,
						.width = prevWidth,
						.height = prevHeight,
						.presentMode = WGPUPresentMode_Fifo,
					}
				);
			}

			nextTexture = wgpuSwapChainGetCurrentTextureView(swapChain);

			if (attempt == 0 && !nextTexture)
			{
				printf("wgpuSwapChainGetCurrentTextureView() failed; trying to create a new swap chain...\n");
				prevWidth = 0;
				prevHeight = 0;
				continue;
			}

			break;
		}

		if (!nextTexture)
		{
			printf("Cannot acquire next swap chain texture\n");
			return 1;
		}

		WGPUCommandEncoder encoder = wgpuDeviceCreateCommandEncoder(
			device, &(WGPUCommandEncoderDescriptor){.label = "Command Encoder"});

		WGPURenderPassEncoder renderPass = wgpuCommandEncoderBeginRenderPass(
			encoder, 
			&(WGPURenderPassDescriptor){
				.colorAttachments =
					&(WGPURenderPassColorAttachment){
						.view = nextTexture,
						.resolveTarget = NULL,
						.loadOp = WGPULoadOp_Clear,
						.storeOp = WGPUStoreOp_Store,
						.clearValue =
							(WGPUColor){
								.r = 0.0,
								.g = 0.0,
								.b = 0.0,
								.a = 1.0,
							},
					},
				.colorAttachmentCount = 1,
				.depthStencilAttachment = NULL,
			}
		);

		wgpuRenderPassEncoderSetPipeline(renderPass, pipeline);
		wgpuRenderPassEncoderSetVertexBuffer(renderPass, 0, vertBuf, 0, WGPU_WHOLE_SIZE);
		wgpuRenderPassEncoderSetIndexBuffer(renderPass, indxBuf, WGPUIndexFormat_Uint16, 0, WGPU_WHOLE_SIZE);
		wgpuRenderPassEncoderDrawIndexed(renderPass, 3, 1, 0, 0, 0);
		wgpuRenderPassEncoderEnd(renderPass);
		wgpuTextureViewDrop(nextTexture);

		WGPUQueue queue = wgpuDeviceGetQueue(device);
		WGPUCommandBuffer cmdBuffer = wgpuCommandEncoderFinish(
			encoder,
			&(WGPUCommandBufferDescriptor){.label = NULL}
		);

		wgpuQueueSubmit(queue, 1, &cmdBuffer);
		wgpuSwapChainPresent(swapChain);

		glfwPollEvents();
	}

	glfwDestroyWindow(window);
	glfwTerminate();

	return 0;
}
