#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec2 fragCoord;

// Fullscreen triangle technique (3 vertices cover entire screen)
vec2 positions[3] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 3.0, -1.0),
    vec2(-1.0,  3.0)
);

void main() {
    vec2 pos = positions[gl_VertexIndex];
    gl_Position = vec4(pos, 0.0, 1.0);
    // Flip Y coordinate to match OpenGL coordinate system
    fragCoord = vec2(pos.x * 0.5 + 0.5, 1.0 - (pos.y * 0.5 + 0.5));
}
