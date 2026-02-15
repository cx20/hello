#version 450

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    
    // Read position from SSBO (computed by compute shader)
    gl_Position = pos[idx];
    
    // Read color from SSBO (computed by compute shader)
    vColor = col[idx];
}
