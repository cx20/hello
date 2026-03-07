struct PSInput
{
    float4 position : SV_Position;
    float4 color    : COLOR;
};

[outputtopology("triangle")]
[numthreads(1, 1, 1)]
void MSMain(
    out vertices PSInput outVerts[3],
    out indices uint3 outIndices[1])
{
    SetMeshOutputCounts(3, 1);

    outVerts[0].position = float4( 0.0f,  0.5f, 0.0f, 1.0f);
    outVerts[0].color    = float4( 1.0f,  0.0f, 0.0f, 1.0f);

    outVerts[1].position = float4( 0.5f, -0.5f, 0.0f, 1.0f);
    outVerts[1].color    = float4( 0.0f,  1.0f, 0.0f, 1.0f);

    outVerts[2].position = float4(-0.5f, -0.5f, 0.0f, 1.0f);
    outVerts[2].color    = float4( 0.0f,  0.0f, 1.0f, 1.0f);

    outIndices[0] = uint3(0, 1, 2);
}

float4 PSMain(PSInput input) : SV_Target
{
    return input.color;
}