# forked from https://github.com/pygfx/wgpu-py/blob/main/examples/triangle.py

import wgpu
import numpy as np

shader_source_with_buffers = """
struct VertexInput {
    @location(0) position : vec3<f32>,
    @location(1) color : vec4<f32>,
};
struct VertexOutput {
    @location(0) color : vec4<f32>,
    @builtin(position) pos: vec4<f32>,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    out.pos = vec4<f32>(in.position, 1.0);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let physical_color = pow(in.color.rgb, vec3<f32>(2.2));  // gamma correct
    return vec4<f32>(physical_color, in.color.a);
}
"""

vertex_data = np.array(
    [
        [ 0.0,  0.5, 0.0], # Vertex 1
        [ 0.5, -0.5, 0.0], # Vertex 2
        [-0.5, -0.5, 0.0], # Vertex 3
    ],
    dtype=np.float32,
)

color_data = np.array(
    [
        [1.0, 0.0, 0.0, 1.0],  # Red
        [0.0, 1.0, 0.0, 1.0],  # Green
        [0.0, 0.0, 1.0, 1.0],  # Blue
    ],
    dtype=np.float32,
)

def get_render_pipeline_kwargs_with_buffers(canvas, device):
    context = canvas.get_context("wgpu")
    render_texture_format = context.get_preferred_format(device.adapter)
    context.configure(device=device, format=render_texture_format)

    shader = device.create_shader_module(code=shader_source_with_buffers)
    pipeline_layout = device.create_pipeline_layout(bind_group_layouts=[])

    vertex_buffer = device.create_buffer_with_data(
        data=vertex_data.tobytes(),
        usage=wgpu.BufferUsage.VERTEX,
    )

    color_buffer = device.create_buffer_with_data(
        data=color_data.tobytes(),
        usage=wgpu.BufferUsage.VERTEX,
    )

    return dict(
        layout=pipeline_layout,
        vertex={
            "module": shader,
            "entry_point": "vs_main",
            "buffers": [
                {
                    "array_stride": 3 * 4,  # 3 floats (x, y, z), 4 bytes per float
                    "step_mode": wgpu.VertexStepMode.vertex,
                    "attributes": [
                        {"format": wgpu.VertexFormat.float32x3, "offset": 0, "shader_location": 0},  # position
                    ],
                },
                {
                    "array_stride": 4 * 4,  # 4 floats (r, g, b, a), 4 bytes per float
                    "step_mode": wgpu.VertexStepMode.vertex,
                    "attributes": [
                        {"format": wgpu.VertexFormat.float32x4, "offset": 0, "shader_location": 1},  # color
                    ],
                },
            ],
        },
        depth_stencil=None,
        multisample=None,
        fragment={
            "module": shader,
            "entry_point": "fs_main",
            "targets": [
                {
                    "format": render_texture_format,
                    "blend": {
                        "color": {},
                        "alpha": {},
                    },
                },
            ],
        },
    ), vertex_buffer, color_buffer

def get_draw_function_with_buffers(canvas, device, render_pipeline, vertex_buffer, color_buffer):
    def draw_frame_sync():
        current_texture = canvas.get_context("wgpu").get_current_texture()
        command_encoder = device.create_command_encoder()

        render_pass = command_encoder.begin_render_pass(
            color_attachments=[
                {
                    "view": current_texture.create_view(),
                    "resolve_target": None,
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

    return draw_frame_sync

if __name__ == "__main__":
    from wgpu.gui.auto import WgpuCanvas, run

    canvas = WgpuCanvas(size=(640, 480), title="Hello, World!")
    device = wgpu.gpu.request_adapter_sync().request_device_sync()
    pipeline_kwargs, vertex_buffer, color_buffer = get_render_pipeline_kwargs_with_buffers(canvas, device)
    render_pipeline = device.create_render_pipeline(**pipeline_kwargs)
    draw_frame = get_draw_function_with_buffers(canvas, device, render_pipeline, vertex_buffer, color_buffer)
    canvas.request_draw(draw_frame)
    run()
