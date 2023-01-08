const main = () => {
    init();
}

const vertexShaderWGSL = `

struct VertexOutput {
    @builtin(position) Position : vec4<f32>,
    @location(0) fragColor : vec4<f32>
}

@vertex
fn main(
    @location(0) position : vec3<f32>,
    @location(1) color : vec4<f32>
) -> VertexOutput {
    var output : VertexOutput;
    output.fragColor = color;
    output.Position = vec4<f32>(position, 1.0);
    return output;
}`;
const fragmentShaderWGSL = `

struct FragmentOutput {
    @location(0) outColor : vec4<f32>
}

@fragment
fn main(
    @location(0) fragColor : vec4<f32>
) -> FragmentOutput {
    var output : FragmentOutput;
    output.outColor = fragColor;
    return output;
}
`;

async function init() {
    const gpu = navigator.gpu;
    const adapter = await gpu.requestAdapter();
    const device = await adapter.requestDevice();

    const c = document.getElementById("canvas");
    c.width = window.innerWidth;
    c.height = window.innerHeight;
    const ctx = c.getContext("webgpu") as GPUCanvasContext;
    const format = navigator.gpu.getPreferredCanvasFormat();
    ctx.configure({
      device,
      format: format,
      alphaMode: 'opaque',
    });

    let vShaderModule = makeShaderModule_WGSL(device, vertexShaderWGSL);
    let fShaderModule = makeShaderModule_WGSL(device, fragmentShaderWGSL);

    let positions = [ 
         0.0, 0.5, 0.0, // v0
        -0.5,-0.5, 0.0, // v1
         0.5,-0.5, 0.0  // v2
    ];
    let colors = [ 
        1.0, 0.0, 0.0, 1.0, // v0
        0.0, 1.0, 0.0, 1.0, // v1
        0.0, 0.0, 1.0, 1.0  // v2
    ];
    let vertexBuffer = makeVertexBuffer(device, new Float32Array(positions));
    let colorBuffer = makeVertexBuffer(device, new Float32Array(colors));

    const pipeline = device.createRenderPipeline({
        layout: "auto",
        vertex: {
            module: vShaderModule,
            entryPoint: "main",
            buffers: [
                {
                    arrayStride: 3 * 4,
                    attributes: [
                        {
                            // position
                            shaderLocation: 0,
                            offset: 0,
                            format: "float32x3"
                        }
                    ]
                },
                {
                    arrayStride: 4 * 4,
                    attributes: [
                        {
                            // color
                            shaderLocation: 1,
                            offset:  0,
                            format: "float32x4"
                        }
                    ]
                }
            ]
        },
        fragment: {
            module: fShaderModule,
            entryPoint: "main",
            targets: [
                {
                    format: format
                }
            ]
        },
        primitive: {
            topology: "triangle-strip",
            stripIndexFormat: "uint32"
        },
    });

    let render = function () {
        const commandEncoder = device.createCommandEncoder();
        const textureView = ctx.getCurrentTexture().createView();
        const renderPassDescriptor = {
            colorAttachments: [{
                view: textureView,
                loadValue: {r: 1, g: 1, b: 1, a: 1},
                storeOp: "store"
            }]
        };
        const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
        passEncoder.setPipeline(pipeline);
        passEncoder.setVertexBuffer(0, vertexBuffer);
        passEncoder.setVertexBuffer(1, colorBuffer);
        passEncoder.draw(3, 1, 0, 0);
        passEncoder.endPass();
        device.queue.submit([commandEncoder.finish()]);
        requestAnimationFrame(render);
    }
    requestAnimationFrame(render);
}

function makeShaderModule_WGSL(device, source) {
    let shaderModuleDescriptor = {
        code: source
    };
    let shaderModule = device.createShaderModule(shaderModuleDescriptor);
    return shaderModule;
}

function makeVertexBuffer(device, data) {
    const verticesBuffer = device.createBuffer({
        size: data.byteLength,
        usage: GPUBufferUsage.VERTEX,
        mappedAtCreation: true,
    });
    new Float32Array(verticesBuffer.getMappedRange()).set(data);
    verticesBuffer.unmap();
    return verticesBuffer;
}

window.onload = main;