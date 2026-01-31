struct PSInput
{
    float4 position : SV_POSITION;
    float4 color : COLOR;
};

PSInput VSMain(uint vertexId : SV_VertexID)
{
    PSInput result;

    // Generate triangle vertices procedurally
    float4 positions[3] = {
        float4( 0.0f,  0.5f, 0.0f, 1.0f),
        float4( 0.5f, -0.5f, 0.0f, 1.0f),
        float4(-0.5f, -0.5f, 0.0f, 1.0f)
    };

    float4 colors[3] = {
        float4(1.0f, 0.0f, 0.0f, 1.0f),  // red
        float4(0.0f, 1.0f, 0.0f, 1.0f),  // green
        float4(0.0f, 0.0f, 1.0f, 1.0f)   // blue
    };

    result.position = positions[vertexId % 3];
    result.color = colors[vertexId % 3];

    return result;
}

float4 PSMain(PSInput input) : SV_TARGET
{
    return input.color;
}