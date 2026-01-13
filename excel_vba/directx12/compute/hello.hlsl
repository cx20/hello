/*
 * Harmonograph HLSL Shaders for DirectX 12 (with Animation)
 */

// Constant Buffer: Must match VBA struct layout
cbuffer HarmonographParams : register(b0)
{
    float A1, f1, p1, d1;
    float A2, f2, p2, d2;
    float A3, f3, p3, d3;
    float A4, f4, p4, d4;
    uint max_num;
    float time;           // Animation time from VBA
    float2 padding;
    float2 resolution;
    float2 padding2;
};

// UAVs
RWStructuredBuffer<float4> positionBuffer : register(u0);
RWStructuredBuffer<float4> colorBuffer : register(u1);

// SRVs
StructuredBuffer<float4> positionSRV : register(t0);
StructuredBuffer<float4> colorSRV : register(t1);

float3 hsv2rgb(float h, float s, float v)
{
    float c = v * s;
    float hp = h / 60.0;
    float x = c * (1.0 - abs(fmod(hp, 2.0) - 1.0));
    float3 rgb;

    if (hp < 1.0) rgb = float3(c, x, 0.0);
    else if (hp < 2.0) rgb = float3(x, c, 0.0);
    else if (hp < 3.0) rgb = float3(0.0, c, x);
    else if (hp < 4.0) rgb = float3(0.0, x, c);
    else if (hp < 5.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);

    float m = v - c;
    return rgb + float3(m, m, m);
}

[numthreads(64, 1, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint idx = dispatchThreadID.x;
    if (idx >= max_num) return;

    float t = (float)idx * 0.01 + time * 0.5;  // Add animation offset
    float PI = 3.14159265;

    // Harmonograph Equations
    float x = A1 * sin(f1 * t + PI * p1) * exp(-d1 * t) +
              A2 * sin(f2 * t + PI * p2) * exp(-d2 * t);

    float y = A3 * sin(f3 * t + PI * p3) * exp(-d3 * t) +
              A4 * sin(f4 * t + PI * p4) * exp(-d4 * t);

    // Z axis
    float z = A1 * cos(f1 * t + PI * p1) * exp(-d1 * t);

    positionBuffer[idx] = float4(x, y, z, 1.0);

    // Animate color based on time
    float hue = fmod(((float)idx / (float)max_num + time * 0.1) * 360.0, 360.0);
    float3 rgb = hsv2rgb(hue, 1.0, 1.0);
    colorBuffer[idx] = float4(rgb, 1.0);
}

// --------------------------------------------------------
// Graphics Pipeline (DirectX Coordinate System)
// --------------------------------------------------------

// Perspective Fov Left-Handed (Z range 0.0 to 1.0)
float4x4 perspective(float fov, float aspect, float nearZ, float farZ)
{
    float rad = radians(fov / 2.0);
    float yScale = 1.0 / tan(rad);
    float xScale = yScale / aspect;

    // DX uses Column-Major packing by default in constant buffers,
    // but here we are constructing matrix for MUL(vector, matrix).
    // The standard DX projection matrix (Left Handed, 0 to 1 depth):
    return float4x4(
        xScale, 0, 0, 0,
        0, yScale, 0, 0,
        0, 0, farZ / (farZ - nearZ), 1,
        0, 0, -nearZ * farZ / (farZ - nearZ), 0
    );
}

// LookAt Left-Handed
float4x4 lookAt(float3 eye, float3 target, float3 up)
{
    float3 zaxis = normalize(target - eye); // Forward
    float3 xaxis = normalize(cross(up, zaxis)); // Right
    float3 yaxis = cross(zaxis, xaxis); // Up

    return float4x4(
        xaxis.x, yaxis.x, zaxis.x, 0,
        xaxis.y, yaxis.y, zaxis.y, 0,
        xaxis.z, yaxis.z, zaxis.z, 0,
        -dot(xaxis, eye), -dot(yaxis, eye), -dot(zaxis, eye), 1
    );
}

struct VSOutput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;

    float4 pos = positionSRV[vertexID];
    float4 col = colorSRV[vertexID];

    float4x4 proj = perspective(45.0, resolution.x / resolution.y, 1.0, 500.0);
    
    // Rotating camera for animation
    float angle = time * 0.3;
    float camDist = 150.0;
    float3 cameraPos = float3(sin(angle) * camDist, 50.0, -cos(angle) * camDist); 
    float3 cameraTarget = float3(0, 0, 0);
    float3 cameraUp = float3(0, 1, 0);
    float4x4 view = lookAt(cameraPos, cameraTarget, cameraUp);

    output.position = mul(mul(pos, view), proj);
    output.color = col;

    return output;
}

float4 PSMain(VSOutput input) : SV_TARGET
{
    return input.color;
}
