/*
 * Harmonograph HLSL Shaders for DirectX 12
 * - Compute Shader: Calculates harmonograph positions and colors
 * - Vertex Shader: Transforms positions with 3D camera
 * - Pixel Shader: Outputs vertex colors
 */

/* Constant buffer for harmonograph parameters */
cbuffer HarmonographParams : register(b0)
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float3 padding;
    float2 resolution;
    float2 padding2;
};

/* UAV buffers for compute shader output / SRV for vertex shader input */
RWStructuredBuffer<float4> positionBuffer : register(u0);
RWStructuredBuffer<float4> colorBuffer : register(u1);

StructuredBuffer<float4> positionSRV : register(t0);
StructuredBuffer<float4> colorSRV : register(t1);

/* HSV to RGB conversion */
float3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0));
    float3 rgb;

    if (hp < 1.0)
        rgb = float3(c, x, 0.0);
    else if (hp < 2.0)
        rgb = float3(x, c, 0.0);
    else if (hp < 3.0)
        rgb = float3(0.0, c, x);
    else if (hp < 4.0)
        rgb = float3(0.0, x, c);
    else if (hp < 5.0)
        rgb = float3(x, 0.0, c);
    else
        rgb = float3(c, 0.0, x);

    float m = v - c;
    return rgb + float3(m, m, m);
}

/* Compute Shader */
[numthreads(64, 1, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint idx = dispatchThreadID.x;
    if (idx >= max_num)
        return;

    float t = (float)idx * 0.001;
    float PI = 3.14159265;

    /* Harmonograph equations */
    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * cos(f2 * t + PI * p2) * exp(-d2 * t);

    positionBuffer[idx] = float4(x, y, z, 1.0);

    /* Color: hue from t */
    float hue = fmod((t / 20.0) * 360.0, 360.0);
    float3 rgb = hsv2rgb(hue, 1.0, 1.0);
    colorBuffer[idx] = float4(rgb, 1.0);
}

/* Matrix helper functions */
float4x4 perspective(float fov, float aspect, float nearZ, float farZ)
{
    float rad = radians(fov / 2.0);
    float v = 1.0 / tan(rad);
    float u = v / aspect;
    float w = nearZ - farZ;

    return float4x4(
        u, 0, 0, 0,
        0, v, 0, 0,
        0, 0, (nearZ + farZ) / w, -1,
        0, 0, (nearZ * farZ * 2.0) / w, 0
    );
}

float4x4 lookAt(float3 eye, float3 center, float3 up)
{
    float3 w = normalize(eye - center);
    float3 u = normalize(cross(up, w));
    float3 v = cross(w, u);

    return float4x4(
        u.x, v.x, w.x, 0,
        u.y, v.y, w.y, 0,
        u.z, v.z, w.z, 0,
        -dot(u, eye), -dot(v, eye), -dot(w, eye), 1
    );
}

/* Vertex Shader output */
struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

/* Vertex Shader */
VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;

    float4 pos = positionSRV[vertexID];

    /* Camera setup */
    float4x4 proj = perspective(45.0, resolution.x / resolution.y, 0.1, 200.0);
    float3 cameraPos = float3(0, 5, 10);
    float3 cameraTarget = float3(0, 0, 0);
    float3 cameraUp = float3(0, 1, 0);
    float4x4 view = lookAt(cameraPos, cameraTarget, cameraUp);

    output.position = mul(mul(pos, view), proj);
    output.color = colorSRV[vertexID];

    return output;
}

/* Pixel Shader */
float4 PSMain(VSOutput input) : SV_TARGET
{
    return input.color;
}
