# forked from https://github.com/pygfx/wgpu-py/blob/main/examples/triangle.py

import wgpu
import numpy as np

vertex_shader_source = """
struct VertexInput {
    @location(0) position : vec3<f32>,
    @location(1) color : vec4<f32>
};
struct VertexOutput {
    @builtin(position) Position : vec4<f32>,
    @location(0) fragColor : vec4<f32>,
};

@stage(vertex)
fn main(in: VertexInput) -> VertexOutput {
    var output : VertexOutput;
    output.fragColor = in.color;
    output.Position = vec4<f32>(in.position, 1.0);
    return output;

}
"""

fragment_shader_source = """
struct VertexInput {
    @location(0) fragColor : vec4<f32>
};

struct FragmentOutput {
    @location(0) outColor : vec4<f32>
};

@stage(fragment)
fn main(in: VertexInput) -> FragmentOutput {
    var output : FragmentOutput;
    output.outColor = in.fragColor;
    return output;
}
"""

def main(canvas, power_preference="high-performance", limits=None):
    adapter = wgpu.request_adapter(canvas=None, power_preference=power_preference)
    device = adapter.request_device(required_limits=limits)
    return _main(canvas, device)

async def main_async(canvas):
    adapter = await wgpu.request_adapter_async(
        canvas=canvas, power_preference="high-performance"
    )
    device = await adapter.request_device_async(required_limits={})
    return _main(canvas, device)

def _main(canvas, device):

    vertex_shader = device.create_shader_module(code=vertex_shader_source)
    fragment_shader = device.create_shader_module(code=fragment_shader_source)

    pipeline_layout = device.create_pipeline_layout(bind_group_layouts=[])

    present_context = canvas.get_context()
    render_texture_format = present_context.get_preferred_format(device.adapter)
    present_context.configure(device=device, format=render_texture_format)

    vertex_data = np.array(
        [
            [ 0.0,  0.5, 0.0],
            [ 0.5, -0.5, 0.0],
            [-0.5, -0.5, 0.0],
        ],
        dtype=np.float32,
    )

    color_data = np.array(
        [
            [1.0, 0.0, 0.0, 1.0],
            [0.0, 1.0, 0.0, 1.0],
            [0.0, 0.0, 1.0, 1.0],
        ],
        dtype=np.float32,
    )

    vertex_buffer = device.create_buffer_with_data(
        data=vertex_data, usage=wgpu.BufferUsage.VERTEX
    )

    color_buffer = device.create_buffer_with_data(
        data=color_data, usage=wgpu.BufferUsage.VERTEX
    )

    render_pipeline = device.create_render_pipeline(
        layout=pipeline_layout,
        vertex={
            "module": vertex_shader,
            "entry_point": "main",
            "buffers": [
                {
                    "array_stride": 3 * 4,
                    "step_mode": wgpu.VertexStepMode.vertex,
                    "attributes": [
                        {
                            "format": wgpu.VertexFormat.float32x3,
                            "offset": 0,
                            "shader_location": 0,
                        },
                    ],
                },
                {
                    "array_stride": 4 * 4,
                    "step_mode": wgpu.VertexStepMode.vertex,
                    "attributes": [
                        {
                            "format": wgpu.VertexFormat.float32x4,
                            "offset": 0,
                            "shader_location": 1,
                        },
                    ],
                },
            ],
        },
        primitive={
            "topology": wgpu.PrimitiveTopology.triangle_list,
        },
        fragment={
            "module": fragment_shader,
            "entry_point": "main",
            "targets": [
                {
                    "format": render_texture_format,
                },
            ],
        },
    )

    def draw_frame():
        current_texture_view = present_context.get_current_texture()
        command_encoder = device.create_command_encoder()

        render_pass = command_encoder.begin_render_pass(
            color_attachments=[
                {
                    "view": current_texture_view,
                    "clear_value": (0, 0, 0, 1),
                    "load_op": wgpu.LoadOp.clear,
                    "store_op": wgpu.StoreOp.store,
                }
            ],
        )

        render_pass.set_pipeline(render_pipeline)
        render_pass.set_vertex_buffer(0, vertex_buffer)
        render_pass.set_vertex_buffer(1, color_buffer)
        render_pass.draw(3, 1, 0, 0)
        render_pass.end()
        device.queue.submit([command_encoder.finish()])

    canvas.request_draw(draw_frame)
    return device

if __name__ == "__main__":

    import wgpu.backends.rs  # noqa: F401, Select Rust backend
    from wgpu.gui.auto import WgpuCanvas, run

    canvas = WgpuCanvas(size=(640, 480), title="Hello, World!")
    main(canvas)
    run()
