#version 450

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor = col[idx];
}
