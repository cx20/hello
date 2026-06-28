// File : hello.c
// Compile : emcc hello.c -std=c11 -s WASM=1 -O3 --use-port=emdawnwebgpu -o index.js
//
// forked from https://github.com/cwoffenden/hello-webgpu

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <webgpu/webgpu.h>
#include <emscripten/html5.h>
#include <emscripten/em_js.h>

static WGPUInstance instance;
static WGPUDevice   device;
static WGPUQueue    queue;
static WGPUSurface  surface;

// On the web the preferred canvas format is typically BGRA8Unorm.
static WGPUTextureFormat surfaceFormat = WGPUTextureFormat_BGRA8Unorm;

static WGPURenderPipeline pipeline;
static WGPUBuffer vertBuf; // vertex buffer with triangle position and colours
static WGPUBuffer indxBuf; // index buffer

// Query the current drawing-buffer size (the full browser window).
EM_JS(int, canvas_get_width,  (), { return window.innerWidth;  });
EM_JS(int, canvas_get_height, (), { return window.innerHeight; });

static uint32_t curW = 0;
static uint32_t curH = 0;

static const char triangle_vert_wgsl[] =
	"struct VertexOut {\n"
	"  @location(0) vCol : vec3<f32>,\n"
	"  @builtin(position) Position : vec4<f32>\n"
	"}\n"
	"@vertex\n"
	"fn main(\n"
	"  @location(0) aPos : vec3<f32>,\n"
	"  @location(1) aCol : vec3<f32>\n"
	") -> VertexOut {\n"
	"  var output : VertexOut;\n"
	"  output.Position = vec4<f32>(aPos, 1.0);\n"
	"  output.vCol = aCol;\n"
	"  return output;\n"
	"}\n";

static const char triangle_frag_wgsl[] =
	"@fragment\n"
	"fn main(@location(0) vCol : vec3<f32>) -> @location(0) vec4<f32> {\n"
	"  return vec4<f32>(vCol, 1.0);\n"
	"}\n";

static void configureSurface(uint32_t w, uint32_t h) {
	WGPUSurfaceConfiguration config = {0};
	config.device      = device;
	config.format      = surfaceFormat;
	config.usage       = WGPUTextureUsage_RenderAttachment;
	config.width       = w;
	config.height      = h;
	config.alphaMode   = WGPUCompositeAlphaMode_Auto;
	config.presentMode = WGPUPresentMode_Fifo;
	wgpuSurfaceConfigure(surface, &config);
	curW = w;
	curH = h;
}

static void createSurface(void) {
	WGPUEmscriptenSurfaceSourceCanvasHTMLSelector canvasDesc = {0};
	canvasDesc.chain.sType = WGPUSType_EmscriptenSurfaceSourceCanvasHTMLSelector;
	canvasDesc.selector = (WGPUStringView){ "canvas", WGPU_STRLEN };

	WGPUSurfaceDescriptor surfDesc = {0};
	surfDesc.nextInChain = &canvasDesc.chain;

	surface = wgpuInstanceCreateSurface(instance, &surfDesc);

	configureSurface((uint32_t)canvas_get_width(), (uint32_t)canvas_get_height());
}

static WGPUShaderModule createShader(const char* code) {
	WGPUShaderSourceWGSL wgsl = {0};
	wgsl.chain.sType = WGPUSType_ShaderSourceWGSL;
	wgsl.code = (WGPUStringView){ code, WGPU_STRLEN };
	WGPUShaderModuleDescriptor desc = {0};
	desc.nextInChain = &wgsl.chain;
	return wgpuDeviceCreateShaderModule(device, &desc);
}

static WGPUBuffer createBuffer(const void* data, size_t size, WGPUBufferUsage usage) {
	WGPUBufferDescriptor desc = {0};
	desc.usage = WGPUBufferUsage_CopyDst | usage;
	desc.size  = size;
	WGPUBuffer buffer = wgpuDeviceCreateBuffer(device, &desc);
	wgpuQueueWriteBuffer(queue, buffer, 0, data, size);
	return buffer;
}

static void createPipelineAndBuffers(void) {
	WGPUShaderModule vertMod = createShader(triangle_vert_wgsl);
	WGPUShaderModule fragMod = createShader(triangle_frag_wgsl);

	// Simple pipeline layout without bind group layouts
	WGPUPipelineLayoutDescriptor layoutDesc = {0};
	WGPUPipelineLayout pipelineLayout = wgpuDeviceCreatePipelineLayout(device, &layoutDesc);

	// describe buffer layouts
	WGPUVertexAttribute vertAttrs[2] = {0};
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

	// Fragment state
	WGPUBlendState blend = {0};
	blend.color.operation = WGPUBlendOperation_Add;
	blend.color.srcFactor = WGPUBlendFactor_One;
	blend.color.dstFactor = WGPUBlendFactor_Zero;
	blend.alpha.operation = WGPUBlendOperation_Add;
	blend.alpha.srcFactor = WGPUBlendFactor_One;
	blend.alpha.dstFactor = WGPUBlendFactor_Zero;
	WGPUColorTargetState colorTarget = {0};
	colorTarget.format = surfaceFormat;
	colorTarget.blend = &blend;
	colorTarget.writeMask = WGPUColorWriteMask_All;

	WGPUFragmentState fragment = {0};
	fragment.module = fragMod;
	fragment.entryPoint = (WGPUStringView){ "main", WGPU_STRLEN };
	fragment.targetCount = 1;
	fragment.targets = &colorTarget;

	WGPURenderPipelineDescriptor desc = {0};
	desc.fragment = &fragment;

	// Other state
	desc.layout = pipelineLayout;
	desc.depthStencil = NULL;

	desc.vertex.module = vertMod;
	desc.vertex.entryPoint = (WGPUStringView){ "main", WGPU_STRLEN };
	desc.vertex.bufferCount = 1;
	desc.vertex.buffers = &vertexBufferLayout;

	desc.multisample.count = 1;
	desc.multisample.mask = 0xFFFFFFFF;
	desc.multisample.alphaToCoverageEnabled = false;

	desc.primitive.frontFace = WGPUFrontFace_CCW;
	desc.primitive.cullMode = WGPUCullMode_None;
	desc.primitive.topology = WGPUPrimitiveTopology_TriangleList;
	desc.primitive.stripIndexFormat = WGPUIndexFormat_Undefined;

	pipeline = wgpuDeviceCreateRenderPipeline(device, &desc);

	wgpuPipelineLayoutRelease(pipelineLayout);
	wgpuShaderModuleRelease(fragMod);
	wgpuShaderModuleRelease(vertMod);

	// create the buffers (x, y, z, r, g, b)
	float const vertData[] = {
		-0.5f, -0.5f, 0.0f, 0.0f, 0.0f, 1.0f, // v0
		 0.5f, -0.5f, 0.0f, 0.0f, 1.0f, 0.0f, // v1
		-0.0f,  0.5f, 0.0f, 1.0f, 0.0f, 0.0f, // v2
	};
	uint16_t const indxData[] = {
		0, 1, 2,
		0 // padding (better way of doing this?)
	};
	vertBuf = createBuffer(vertData, sizeof(vertData), WGPUBufferUsage_Vertex);
	indxBuf = createBuffer(indxData, sizeof(indxData), WGPUBufferUsage_Index);
}

static EM_BOOL redraw(double time, void* userData) {
	(void)time; (void)userData;
	// Follow the browser window size (reconfigure the surface on resize).
	uint32_t w = (uint32_t)canvas_get_width();
	uint32_t h = (uint32_t)canvas_get_height();
	if (w != curW || h != curH) {
		configureSurface(w, h);
	}

	WGPUSurfaceTexture surfaceTexture;
	wgpuSurfaceGetCurrentTexture(surface, &surfaceTexture);								// acquire the current texture
	WGPUTextureView backBufView = wgpuTextureCreateView(surfaceTexture.texture, NULL);	// create textureView

	WGPURenderPassColorAttachment colorDesc = {0};
	colorDesc.view    = backBufView;
	colorDesc.depthSlice = WGPU_DEPTH_SLICE_UNDEFINED;
	colorDesc.loadOp  = WGPULoadOp_Clear;
	colorDesc.storeOp = WGPUStoreOp_Store;
	colorDesc.clearValue.r = 1.0f;
	colorDesc.clearValue.g = 1.0f;
	colorDesc.clearValue.b = 1.0f;
	colorDesc.clearValue.a = 1.0f;

	WGPURenderPassDescriptor renderPass = {0};
	renderPass.colorAttachmentCount = 1;
	renderPass.colorAttachments = &colorDesc;

	WGPUCommandEncoder encoder = wgpuDeviceCreateCommandEncoder(device, NULL);				// create encoder
	WGPURenderPassEncoder pass = wgpuCommandEncoderBeginRenderPass(encoder, &renderPass);	// create pass

	// draw the triangle (comment these four lines to simply clear the screen)
	wgpuRenderPassEncoderSetPipeline(pass, pipeline);
	wgpuRenderPassEncoderSetVertexBuffer(pass, 0, vertBuf, 0, WGPU_WHOLE_SIZE);
	wgpuRenderPassEncoderSetIndexBuffer(pass, indxBuf, WGPUIndexFormat_Uint16, 0, WGPU_WHOLE_SIZE);
	wgpuRenderPassEncoderDrawIndexed(pass, 3, 1, 0, 0, 0);

	wgpuRenderPassEncoderEnd(pass);
	wgpuRenderPassEncoderRelease(pass);														// release pass
	WGPUCommandBuffer commands = wgpuCommandEncoderFinish(encoder, NULL);					// create commands
	wgpuCommandEncoderRelease(encoder);														// release encoder

	wgpuQueueSubmit(queue, 1, &commands);
	wgpuCommandBufferRelease(commands);														// release commands
	wgpuTextureViewRelease(backBufView);													// release textureView
	wgpuTextureRelease(surfaceTexture.texture);												// release surface texture

	return EM_TRUE; // keep the rAF loop running
}

// Called once the device has been obtained: set up the surface, pipeline and
// start the render loop.
static void start(void) {
	queue = wgpuDeviceGetQueue(device);
	createSurface();
	createPipelineAndBuffers();
	emscripten_request_animation_frame_loop(redraw, NULL);
}

static void onDeviceRequestEnded(WGPURequestDeviceStatus status, WGPUDevice dev, WGPUStringView message, void* userdata1, void* userdata2) {
	(void)userdata1; (void)userdata2;
	if (status != WGPURequestDeviceStatus_Success) {
		printf("Failed to get a WebGPU device: %.*s\n", (int)message.length, message.data);
		return;
	}
	device = dev;
	start();
}

static void onAdapterRequestEnded(WGPURequestAdapterStatus status, WGPUAdapter adapter, WGPUStringView message, void* userdata1, void* userdata2) {
	(void)userdata1; (void)userdata2;
	if (status != WGPURequestAdapterStatus_Success) {
		printf("Failed to get a WebGPU adapter: %.*s\n", (int)message.length, message.data);
		return;
	}
	WGPUDeviceDescriptor deviceDesc = {0};
	WGPURequestDeviceCallbackInfo callbackInfo = {0};
	callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous;
	callbackInfo.callback = onDeviceRequestEnded;
	wgpuAdapterRequestDevice(adapter, &deviceDesc, callbackInfo);
}

int main(void) {
	instance = wgpuCreateInstance(NULL);

	WGPURequestAdapterCallbackInfo callbackInfo = {0};
	callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous;
	callbackInfo.callback = onAdapterRequestEnded;
	wgpuInstanceRequestAdapter(instance, NULL, callbackInfo);

	return 0;
}
