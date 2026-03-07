struct VSOutput
{
    float3 position : POSITION;
    float4 color    : COLOR;
};

struct HSOutput
{
    float3 position : POSITION;
    float4 color    : COLOR;
};

struct HSConstants
{
    float edges[3]  : SV_TessFactor;
    float inside    : SV_InsideTessFactor;
};

struct DSOutput
{
    float4 position : SV_Position;
    float4 color    : COLOR;
};

// The vertex shader generates three control points without using a vertex buffer.
VSOutput VSMain(uint vertexID : SV_VertexID)
{
    VSOutput output;

    if (vertexID == 0)
    {
        output.position = float3( 0.0f,  0.6f, 0.0f);
        output.color    = float4( 1.0f,  0.0f, 0.0f, 1.0f);
    }
    else if (vertexID == 1)
    {
        output.position = float3( 0.6f, -0.6f, 0.0f);
        output.color    = float4( 0.0f,  1.0f, 0.0f, 1.0f);
    }
    else
    {
        output.position = float3(-0.6f, -0.6f, 0.0f);
        output.color    = float4( 0.0f,  0.0f, 1.0f, 1.0f);
    }

    return output;
}

// The patch constant function sets tessellation density.
// Larger values create more generated vertices.
HSConstants HSConstantFunc(
    InputPatch<VSOutput, 3> patch,
    uint patchID : SV_PrimitiveID)
{
    HSConstants output;

    output.edges[0] = 8.0f;
    output.edges[1] = 8.0f;
    output.edges[2] = 8.0f;
    output.inside   = 8.0f;

    return output;
}

// The hull shader passes through the control points.
[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("HSConstantFunc")]
HSOutput HSMain(
    InputPatch<VSOutput, 3> patch,
    uint controlPointID : SV_OutputControlPointID,
    uint patchID : SV_PrimitiveID)
{
    HSOutput output;
    output.position = patch[controlPointID].position;
    output.color    = patch[controlPointID].color;
    return output;
}

// The domain shader evaluates the tessellated vertices.
// It interpolates position and color using barycentric coordinates.
[domain("tri")]
DSOutput DSMain(
    HSConstants hsConstData,
    const OutputPatch<HSOutput, 3> patch,
    float3 bary : SV_DomainLocation)
{
    DSOutput output;

    float3 position =
        patch[0].position * bary.x +
        patch[1].position * bary.y +
        patch[2].position * bary.z;

    float4 color =
        patch[0].color * bary.x +
        patch[1].color * bary.y +
        patch[2].color * bary.z;

    output.position = float4(position, 1.0f);
    output.color    = color;

    return output;
}

float4 PSMain(DSOutput input) : SV_Target
{
    return input.color;
}